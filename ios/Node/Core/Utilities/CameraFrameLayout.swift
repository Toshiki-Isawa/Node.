import CoreGraphics
import UIKit

/// カメラ画面の観測枠（レティクル）レイアウト。プレビュー・保存・オーバーレイで共通利用する。
enum CameraFrameLayout {
    static let insetXRatio: CGFloat = 0.10
    static let insetTopRatio: CGFloat = 0.14
    static let insetBottomRatio: CGFloat = 0.22

    static func frame(in size: CGSize) -> CGRect {
        let insetX = size.width * insetXRatio
        let insetTop = size.height * insetTopRatio
        let insetBottom = size.height * insetBottomRatio
        return CGRect(
            x: insetX,
            y: insetTop,
            width: size.width - insetX * 2,
            height: size.height - insetTop - insetBottom
        )
    }

    static func aspectRatio(for size: CGSize) -> CGFloat {
        let observationFrame = frame(in: size)
        guard observationFrame.height > 0 else { return 3.0 / 4.0 }
        return observationFrame.width / observationFrame.height
    }

    static var currentAspectRatio: CGFloat {
        aspectRatio(for: UIScreen.main.bounds.size)
    }
}
