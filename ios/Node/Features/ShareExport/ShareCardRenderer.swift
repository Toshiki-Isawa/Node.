import Photos
import SwiftUI

/// SNS（Instagram 等）向けに SwiftUI のカードビューを 4:5 の画像へ書き出すためのヘルパー。
/// `ImageRenderer` で端末内レンダリングし、共有用の一時 JPEG ファイルや写真ライブラリ保存を提供する。
///
/// 比率を 4:5（縦長）にしているのは、Instagram フィードが 4:5 を基準にトリミングするため。
/// 1:1 のまま投稿するとフィードで上下が見切れ、画像に重ねたテキストが切れてしまう。
@MainActor
enum ShareCardRenderer {
    /// カードの基準幅（pt）。`outputScale` を掛けた解像度で書き出される。
    static let canvasPointWidth: CGFloat = 360
    /// カードの基準高さ（pt）。4:5 比率（Instagram フィード推奨の縦長）。
    static let canvasPointHeight: CGFloat = 450
    /// 出力スケール。360×450 pt × 3 = 1080×1350px（Instagram 推奨の縦長サイズ）。
    static let outputScale: CGFloat = 3

    enum RenderError: LocalizedError {
        case renderFailed
        case notAuthorized

        var errorDescription: String? {
            switch self {
            case .renderFailed:
                return String(localized: "画像の生成に失敗しました。")
            case .notAuthorized:
                return String(localized: "写真ライブラリへのアクセスが許可されていません。")
            }
        }
    }

    /// 与えたカードビューを 4:5 の `UIImage` にレンダリングする。
    static func renderCard<Content: View>(@ViewBuilder content: () -> Content) -> UIImage? {
        let renderer = ImageRenderer(
            content: content()
                .frame(width: canvasPointWidth, height: canvasPointHeight)
                .environment(\.colorScheme, .dark)
        )
        renderer.scale = outputScale
        renderer.isOpaque = true
        return renderer.uiImage
    }

    /// 共有シート（ShareLink）で渡せるよう一時ディレクトリに JPEG を書き出す。
    static func writeTemporaryJPEG(_ image: UIImage, name: String) -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.95) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).jpg")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    /// 画像を写真ライブラリに保存する。
    static func saveToPhotos(_ image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw RenderError.notAuthorized
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }
}
