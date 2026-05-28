import AVFoundation
import UIKit

enum TimelapseVideoError: LocalizedError {
    case noFrames
    case imageLoadFailed
    case writerFailed(String)

    var errorDescription: String? {
        switch self {
        case .noFrames:
            return String(localized: "タイムラプス用の画像がありません。")
        case .imageLoadFailed:
            return String(localized: "観測画像の読み込みに失敗しました。")
        case .writerFailed(let detail):
            return String(localized: "動画の生成に失敗しました。(\(detail))")
        }
    }
}

enum TimelapseVideoGenerator {
    static let maxFrames = 60

    static func generate(
        imagePaths: [String],
        imageStore: ImageStore,
        maxLongEdge: CGFloat,
        secondsPerFrame: Double,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        let images = try loadImages(paths: imagePaths, imageStore: imageStore)
        guard !images.isEmpty else { throw TimelapseVideoError.noFrames }

        let outputSize = portraitOutputSize(maxLongEdge: maxLongEdge)
        let outputURL = try makeOutputURL()

        try await writeVideo(
            images: images,
            to: outputURL,
            size: outputSize,
            secondsPerFrame: secondsPerFrame,
            progress: progress
        )
        return outputURL
    }

    // MARK: - Private

    private static func loadImages(paths: [String], imageStore: ImageStore) throws -> [UIImage] {
        var images: [UIImage] = []
        images.reserveCapacity(paths.count)
        for path in paths {
            guard let image = imageStore.loadImage(path: path) else {
                throw TimelapseVideoError.imageLoadFailed
            }
            images.append(image)
        }
        return images
    }

    private static func portraitOutputSize(maxLongEdge: CGFloat) -> CGSize {
        let height = CGFloat(evenDimension(maxLongEdge))
        let width = CGFloat(
            evenDimension(maxLongEdge * TimelapseRequirements.aspectRatioWidth / TimelapseRequirements.aspectRatioHeight)
        )
        return CGSize(width: max(width, 2), height: max(height, 2))
    }

    private static func evenDimension(_ value: CGFloat) -> Int {
        let rounded = max(2, Int(value.rounded()))
        return rounded.isMultiple(of: 2) ? rounded : rounded - 1
    }

    private static func makeOutputURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Node/timelapse", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("\(UUID().uuidString).mp4")
    }

    private static func writeVideo(
        images: [UIImage],
        to outputURL: URL,
        size: CGSize,
        secondsPerFrame: Double,
        progress: (@Sendable (Double) -> Void)?
    ) async throws {
        try await Task.detached(priority: .userInitiated) {
            try writeVideoSync(
                images: images,
                to: outputURL,
                size: size,
                secondsPerFrame: secondsPerFrame,
                progress: progress
            )
        }.value
    }

    private static func writeVideoSync(
        images: [UIImage],
        to outputURL: URL,
        size: CGSize,
        secondsPerFrame: Double,
        progress: (@Sendable (Double) -> Void)?
    ) throws {
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = false

        let pixelAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: pixelAttributes
        )

        guard writer.canAdd(input) else {
            throw TimelapseVideoError.writerFailed(String(localized: "入力を追加できません"))
        }
        writer.add(input)
        guard writer.startWriting() else {
            throw TimelapseVideoError.writerFailed(writer.error?.localizedDescription ?? String(localized: "開始失敗"))
        }
        writer.startSession(atSourceTime: .zero)

        let frameDuration = CMTimeMakeWithSeconds(max(secondsPerFrame, 0.04), preferredTimescale: 600)
        let total = images.count

        for (index, image) in images.enumerated() {
            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.005)
            }
            guard let buffer = pixelBuffer(from: image, size: size) else {
                throw TimelapseVideoError.writerFailed(String(localized: "フレーム変換失敗"))
            }
            let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(index))
            guard adaptor.append(buffer, withPresentationTime: presentationTime) else {
                throw TimelapseVideoError.writerFailed(String(localized: "フレーム書き込み失敗"))
            }
            progress?(Double(index + 1) / Double(total))
        }

        input.markAsFinished()

        let semaphore = DispatchSemaphore(value: 0)
        var finishError: Error?
        writer.finishWriting {
            if let error = writer.error {
                finishError = TimelapseVideoError.writerFailed(error.localizedDescription)
            }
            semaphore.signal()
        }
        semaphore.wait()

        if let finishError {
            throw finishError
        }
        guard writer.status == .completed else {
            throw TimelapseVideoError.writerFailed(writer.error?.localizedDescription ?? String(localized: "不明"))
        }
    }

    private static func pixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let frame = renderer.image { _ in
            UIColor.black.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            let drawRect = aspectFillRect(imageSize: image.size, in: size)
            image.draw(in: drawRect)
        }

        guard let cgImage = frame.cgImage else { return nil }

        let width = Int(size.width)
        let height = Int(size.height)
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            nil,
            &buffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer = buffer else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            return nil
        }

        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        // CVPixelBuffer の CGContext は左下原点。向きは正規化済み CGImage をそのまま描画する
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))

        return pixelBuffer
    }

    private static func aspectFillRect(imageSize: CGSize, in canvasSize: CGSize) -> CGRect {
        let widthRatio = canvasSize.width / imageSize.width
        let heightRatio = canvasSize.height / imageSize.height
        let scale = max(widthRatio, heightRatio)
        let scaled = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(
            x: (canvasSize.width - scaled.width) / 2,
            y: (canvasSize.height - scaled.height) / 2
        )
        return CGRect(origin: origin, size: scaled)
    }
}
