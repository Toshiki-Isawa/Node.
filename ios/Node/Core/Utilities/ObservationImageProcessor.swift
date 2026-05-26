import AVFoundation
import UIKit

enum ObservationImageProcessor {
    /// 観測保存用。向きのみ正規化する。
    static func prepareForStorage(_ image: UIImage) -> UIImage {
        image.normalizedOrientation()
    }

    /// プレビュー上の観測枠と同一範囲へクロップする（WYSIWYG 撮影）。
    static func cropToPreviewFrame(
        _ image: UIImage,
        previewLayer: AVCaptureVideoPreviewLayer,
        frameInLayer: CGRect
    ) -> UIImage {
        let oriented = prepareForStorage(image)
        guard let cgImage = oriented.cgImage else { return oriented }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        let bounds = CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight)
        let targetAspect = frameInLayer.width / max(frameInLayer.height, 1)

        let cropRect = cropRectInImagePixels(
            previewLayer: previewLayer,
            frameInLayer: frameInLayer,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            targetAspect: targetAspect
        ).intersection(bounds)

        guard cropRect.width > 1, cropRect.height > 1,
              let cropped = cgImage.cropping(to: cropRect.integral) else {
            return oriented
        }
        return UIImage(cgImage: cropped, scale: oriented.scale, orientation: .up)
    }

    /// ライブラリ import 等、プレビュー layer が無い場合の中央クロップ。
    static func cropToAspectRatio(_ image: UIImage, aspectRatio: CGFloat) -> UIImage {
        guard aspectRatio > 0 else { return prepareForStorage(image) }

        let oriented = prepareForStorage(image)
        guard let cgImage = oriented.cgImage else { return oriented }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        let cropRect = symmetricTrimToAspect(bounds, aspectRatio: aspectRatio)

        guard let cropped = cgImage.cropping(to: cropRect.integral) else { return oriented }
        return UIImage(cgImage: cropped, scale: oriented.scale, orientation: .up)
    }

    /// カメラ撮影画像を観測枠用に加工する（向き正規化 + プレビュー枠クロップ）。
    static func prepareCapturedPhoto(
        _ image: UIImage,
        previewLayer: AVCaptureVideoPreviewLayer?,
        frameInLayer: CGRect
    ) -> UIImage {
        if let previewLayer {
            return cropToPreviewFrame(image, previewLayer: previewLayer, frameInLayer: frameInLayer)
        }
        return cropToAspectRatio(image, aspectRatio: CameraFrameLayout.currentAspectRatio)
    }

    /// ライブラリ等の画像を観測枠用に加工する。
    static func prepareImportedPhoto(_ image: UIImage, aspectRatio: CGFloat) -> UIImage {
        cropToAspectRatio(image, aspectRatio: aspectRatio)
    }

    private static func cropRectInImagePixels(
        previewLayer: AVCaptureVideoPreviewLayer,
        frameInLayer: CGRect,
        imageWidth: CGFloat,
        imageHeight: CGFloat,
        targetAspect: CGFloat
    ) -> CGRect {
        let cropMetadata = previewLayer.metadataOutputRectConverted(fromLayerRect: frameInLayer)

        let cropRect = CGRect(
            x: cropMetadata.origin.x * imageWidth,
            y: cropMetadata.origin.y * imageHeight,
            width: cropMetadata.width * imageWidth,
            height: cropMetadata.height * imageHeight
        )

        return symmetricTrimToAspect(cropRect, aspectRatio: targetAspect)
    }

    /// 矩形の中心を保ったままアスペクト比だけを観測枠に合わせる。
    private static func symmetricTrimToAspect(_ rect: CGRect, aspectRatio: CGFloat) -> CGRect {
        guard rect.width > 0, rect.height > 0, aspectRatio > 0 else { return rect }

        let currentAspect = rect.width / rect.height
        guard abs(currentAspect - aspectRatio) > 0.001 else { return rect }

        if currentAspect > aspectRatio {
            let newWidth = rect.height * aspectRatio
            return CGRect(
                x: rect.midX - newWidth / 2,
                y: rect.origin.y,
                width: newWidth,
                height: rect.height
            )
        }

        let newHeight = rect.width / aspectRatio
        return CGRect(
            x: rect.origin.x,
            y: rect.midY - newHeight / 2,
            width: rect.width,
            height: newHeight
        )
    }
}

extension UIImage {
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
