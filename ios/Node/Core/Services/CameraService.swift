import AVFoundation
import CoreMotion
import SwiftUI
import UIKit

@MainActor
final class CameraService: NSObject, ObservableObject {
    @Published private(set) var isAuthorized = false
    @Published private(set) var isRunning = false
    @Published private(set) var isCaptureReady = false
    @Published private(set) var rollDegrees: Double = 0
    @Published var showGrid = true
    @Published var showReferenceOverlay = true
    @Published var useFrontCamera = false

    /// シミュレータでは AVFoundation の撮影接続が有効にならないため写真ライブラリを使う。
    static var usesPhotoLibraryFallback: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let motionManager = CMotionManager()
    private var currentInput: AVCaptureDeviceInput?
    private var isPhotoOutputAttached = false
    private var captureContinuation: CheckedContinuation<UIImage, Error>?
    weak var previewLayer: AVCaptureVideoPreviewLayer?
    @Published private(set) var previewBounds: CGSize = UIScreen.main.bounds.size

    var observationFrameRect: CGRect {
        CameraFrameLayout.frame(in: previewBounds)
    }

    var observationFrameAspectRatio: CGFloat {
        CameraFrameLayout.aspectRatio(for: previewBounds)
    }

    func updatePreviewBounds(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        guard previewBounds != size else { return }
        previewBounds = size
    }

    override init() {
        super.init()
        if Self.usesPhotoLibraryFallback {
            isAuthorized = true
            isCaptureReady = true
        } else {
            checkAuthorization()
        }
    }

    func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        default:
            isAuthorized = false
        }
    }

    func requestAuthorization() async -> Bool {
        if Self.usesPhotoLibraryFallback {
            isAuthorized = true
            isCaptureReady = true
            return true
        }
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        isAuthorized = granted
        return granted
    }

    func configure() throws {
        guard !Self.usesPhotoLibraryFallback else { return }

        session.beginConfiguration()
        session.sessionPreset = .photo

        if let input = currentInput {
            session.removeInput(input)
            currentInput = nil
        }

        let position: AVCaptureDevice.Position = useFrontCamera ? .front : .back
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            throw CameraError.deviceUnavailable
        }

        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw CameraError.deviceUnavailable
        }
        session.addInput(input)
        currentInput = input

        if !isPhotoOutputAttached, session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .speed
            isPhotoOutputAttached = true
        }

        applyPortraitOrientation(to: previewLayer?.connection)
        applyPortraitOrientation(to: photoOutput.connection(with: .video))

        session.commitConfiguration()
        updateCaptureReadiness()
    }

    func start() async {
        guard !Self.usesPhotoLibraryFallback else { return }

        if session.isRunning {
            await waitUntilCaptureReady()
            return
        }

        motionManager.startUpdates { [weak self] roll in
            Task { @MainActor in
                self?.rollDegrees = roll
            }
        }

        nonisolated(unsafe) let session = session
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
                Task { @MainActor in
                    self.isRunning = true
                    continuation.resume()
                }
            }
        }

        await waitUntilCaptureReady()
    }

    func stop() {
        guard !Self.usesPhotoLibraryFallback else { return }
        guard session.isRunning else { return }
        motionManager.stopUpdates()
        nonisolated(unsafe) let session = session
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            session.stopRunning()
            Task { @MainActor in
                self?.isRunning = false
                self?.isCaptureReady = false
            }
        }
    }

    func flipCamera() throws {
        guard !Self.usesPhotoLibraryFallback else { return }
        useFrontCamera.toggle()
        try configure()
        if isRunning {
            Task { await start() }
        }
    }

    func cancelCapture() {
        if let continuation = captureContinuation {
            captureContinuation = nil
            continuation.resume(throwing: CameraError.cancelled)
        }
    }

    func capturePhoto() async throws -> UIImage {
        if Self.usesPhotoLibraryFallback {
            throw CameraError.usePhotoLibrary
        }

        await waitUntilCaptureReady()

        guard isCaptureReady else {
            throw CameraError.notReady
        }

        return try await withCheckedThrowingContinuation { continuation in
            captureContinuation = continuation
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func waitUntilCaptureReady(timeout: TimeInterval = 4) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            updateCaptureReadiness()
            if isCaptureReady { return }
            try? await Task.sleep(for: .milliseconds(50))
        }
        updateCaptureReadiness()
    }

    private func updateCaptureReadiness() {
        guard !Self.usesPhotoLibraryFallback else {
            isCaptureReady = true
            return
        }
        guard session.isRunning, isPhotoOutputAttached else {
            isCaptureReady = false
            return
        }
        guard let connection = photoOutput.connection(with: .video) else {
            isCaptureReady = false
            return
        }
        isCaptureReady = connection.isEnabled && connection.isActive
    }

    private func applyPortraitOrientation(to connection: AVCaptureConnection?) {
        CameraOrientation.applyPortrait(to: connection)
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                captureContinuation?.resume(throwing: error)
                captureContinuation = nil
                return
            }
            guard let data = photo.fileDataRepresentation(),
                  let image = UIImage(data: data) else {
                captureContinuation?.resume(throwing: CameraError.captureFailed)
                captureContinuation = nil
                return
            }
            captureContinuation?.resume(returning: ObservationImageProcessor.prepareForStorage(image))
            captureContinuation = nil
        }
    }
}

enum CameraError: Error, LocalizedError {
    case deviceUnavailable
    case captureFailed
    case notReady
    case usePhotoLibrary
    case cancelled

    var errorDescription: String? {
        switch self {
        case .deviceUnavailable: return String(localized: "カメラを利用できません。")
        case .captureFailed: return String(localized: "撮影に失敗しました。")
        case .notReady: return String(localized: "カメラの準備ができていません。少し待ってから再試行してください。")
        case .usePhotoLibrary: return String(localized: "写真ライブラリから選択してください。")
        case .cancelled: return nil
        }
    }
}

// MARK: - Core Motion wrapper

private final class CMotionManager {
    private let manager = CMMotionManager()

    func startUpdates(handler: @escaping (Double) -> Void) {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { motion, _ in
            guard let motion else { return }
            let roll = motion.attitude.roll * 180 / .pi
            handler(roll)
        }
    }

    func stopUpdates() {
        manager.stopDeviceMotionUpdates()
    }
}

private enum CameraOrientation {
    static func applyPortrait(to connection: AVCaptureConnection?) {
        guard let connection else { return }
        if connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
    }
}

struct AVCameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    var cameraService: CameraService?

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.isUserInteractionEnabled = false
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        CameraOrientation.applyPortrait(to: view.previewLayer.connection)
        view.onBoundsChange = { [weak cameraService] size in
            Task { @MainActor in
                cameraService?.updatePreviewBounds(size)
            }
        }
        cameraService?.previewLayer = view.previewLayer
        cameraService?.updatePreviewBounds(view.bounds.size)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
        CameraOrientation.applyPortrait(to: uiView.previewLayer.connection)
        cameraService?.previewLayer = uiView.previewLayer
        cameraService?.updatePreviewBounds(uiView.bounds.size)
    }
}

final class PreviewView: UIView {
    var onBoundsChange: ((CGSize) -> Void)?

    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
        onBoundsChange?(bounds.size)
    }
}
