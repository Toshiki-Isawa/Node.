import UIKit

enum ObservationImageProcessor {
    /// 観測保存用。向きのみ正規化する。
    static func prepareForStorage(_ image: UIImage) -> UIImage {
        image.normalizedOrientation()
    }

    /// 観測枠アスペクトへ中央クロップする。カメラ撮影・ライブラリ取り込み共通の前処理。
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

    /// ライブラリや撮影画像を観測枠アスペクトに揃える。
    static func prepareImportedPhoto(_ image: UIImage, aspectRatio: CGFloat) -> UIImage {
        cropToAspectRatio(image, aspectRatio: aspectRatio)
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
