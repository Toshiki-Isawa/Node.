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
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let videoDataQueue = DispatchQueue(label: "app.node.camera.frameAnalysis", qos: .userInitiated)
    private let motionManager = CMotionManager()
    private var currentInput: AVCaptureDeviceInput?
    private var isPhotoOutputAttached = false
    private var isVideoOutputAttached = false
    private var captureContinuation: CheckedContinuation<UIImage, Error>?

    /// ライブフレームの受け口。位置合わせ解析が有効なときだけ設定する（`nil` で省電力停止）。
    /// `nonisolated` な delegate からロック越しに読むため `FrameForwarder` に保持する。
    private let frameForwarder = FrameForwarder()

    /// ライブフレーム転送先を設定する。video data queue 上で呼ばれるクロージャ。
    func setFrameHandler(_ handler: ((CVPixelBuffer, CGImagePropertyOrientation) -> Void)?) {
        frameForwarder.set(handler)
    }
    weak var previewLayer: AVCaptureVideoPreviewLayer?
    @Published private(set) var previewBounds: CGSize = UIScreen.main.bounds.size

    /// 端末の向きに応じてプレビュー/撮影接続の回転角を供給する（iOS 17+）。
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var previewRotationObservation: NSKeyValueObservation?
    private var captureRotationObservation: NSKeyValueObservation?

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

        if !isVideoOutputAttached, session.canAddOutput(videoDataOutput) {
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            ]
            videoDataOutput.setSampleBufferDelegate(self, queue: videoDataQueue)
            session.addOutput(videoDataOutput)
            isVideoOutputAttached = true
        }

        setupRotationCoordinator(device: device)

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

    /// プレビュー用 `AVCaptureVideoPreviewLayer` を受け取り、回転追従を構成する。
    /// `updateUIView` から繰り返し呼ばれるため、レイヤーが変わったとき以外は再構成しない。
    func setPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        let isSameLayer = previewLayer === layer
        previewLayer = layer
        guard let device = currentInput?.device else { return }
        if !isSameLayer || rotationCoordinator == nil {
            setupRotationCoordinator(device: device)
        }
    }

    /// 端末の向きに応じてプレビュー/撮影接続の回転角を自動更新する。
    private func setupRotationCoordinator(device: AVCaptureDevice) {
        previewRotationObservation?.invalidate()
        captureRotationObservation?.invalidate()

        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        rotationCoordinator = coordinator

        applyPreviewRotation(coordinator.videoRotationAngleForHorizonLevelPreview)
        applyCaptureRotation(coordinator.videoRotationAngleForHorizonLevelCapture)

        previewRotationObservation = coordinator.observe(
            \.videoRotationAngleForHorizonLevelPreview,
            options: [.new]
        ) { [weak self] _, change in
            guard let angle = change.newValue else { return }
            Task { @MainActor in self?.applyPreviewRotation(angle) }
        }

        captureRotationObservation = coordinator.observe(
            \.videoRotationAngleForHorizonLevelCapture,
            options: [.new]
        ) { [weak self] _, change in
            guard let angle = change.newValue else { return }
            Task { @MainActor in self?.applyCaptureRotation(angle) }
        }
    }

    /// 解析用フレームの向きを撮影と一致させる。`onPixelBuffer` 側でも orientation を渡すが、
    /// connection 側を撮影と同じ角度に保つことで参照画像（保存写真）と座標系を揃える。
    private func applyVideoDataRotation(_ angle: CGFloat) {
        guard let connection = videoDataOutput.connection(with: .video),
              connection.isVideoRotationAngleSupported(angle) else { return }
        connection.videoRotationAngle = angle
    }

    private func applyPreviewRotation(_ angle: CGFloat) {
        guard let connection = previewLayer?.connection,
              connection.isVideoRotationAngleSupported(angle) else { return }
        connection.videoRotationAngle = angle
    }

    private func applyCaptureRotation(_ angle: CGFloat) {
        if let connection = photoOutput.connection(with: .video),
           connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
        applyVideoDataRotation(angle)
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

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // 解析が無効（参照なし・撮影中）のときは何もしない＝省電力。
        guard let handler = frameForwarder.handler(),
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        // connection 側で撮影と同じ回転を当てているため、解析には .up を渡す。
        handler(pixelBuffer, .up)
    }
}

/// video data queue（`nonisolated`）と main の双方からフレーム転送先を安全に読み書きするためのホルダー。
private final class FrameForwarder: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: ((CVPixelBuffer, CGImagePropertyOrientation) -> Void)?

    func set(_ handler: ((CVPixelBuffer, CGImagePropertyOrientation) -> Void)?) {
        lock.lock()
        stored = handler
        lock.unlock()
    }

    func handler() -> ((CVPixelBuffer, CGImagePropertyOrientation) -> Void)? {
        lock.lock()
        defer { lock.unlock() }
        return stored
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

struct AVCameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    var cameraService: CameraService?

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.isUserInteractionEnabled = false
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.onBoundsChange = { [weak cameraService] size in
            Task { @MainActor in
                cameraService?.updatePreviewBounds(size)
            }
        }
        cameraService?.setPreviewLayer(view.previewLayer)
        cameraService?.updatePreviewBounds(view.bounds.size)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
        cameraService?.setPreviewLayer(uiView.previewLayer)
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
