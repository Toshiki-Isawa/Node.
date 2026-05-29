import CoreGraphics
import UIKit

/// カメラ画面の観測枠（レティクル）レイアウト。プレビュー・保存・オーバーレイで共通利用する。
/// 縦向き（iPhone 既定）は観測枠＝プレビュー全面で従来どおり。
/// 横向き（iPad マルチタスク等）はプレビューを上向きに保ったまま、中央へ縦構図の
/// 観測枠を置き、保存画像が常に縦構図に揃うようにする。
enum CameraFrameLayout {
    static func frame(in size: CGSize) -> CGRect {
        guard size.width > 0, size.height > 0 else {
            return CGRect(origin: .zero, size: size)
        }
        // 縦向き・正方はプレビュー全面（従来挙動を維持）
        guard size.width > size.height else {
            return CGRect(origin: .zero, size: size)
        }
        // 横向きは中央に縦構図の観測枠を配置する。
        // アスペクトは同じ画面/ペインを縦にしたときの縦横比に揃えるため、
        // 縦向き全面で撮ったコマと横向きで撮ったコマが同じ縦構図で揃う。
        let portraitAspect = size.height / size.width   // < 1（幅 / 高さ）
        let width = size.height * portraitAspect
        return CGRect(
            x: (size.width - width) / 2,
            y: 0,
            width: width,
            height: size.height
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
