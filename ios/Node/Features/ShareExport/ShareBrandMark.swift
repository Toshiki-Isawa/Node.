import SwiftUI

/// エクスポート画像に載せる控えめな「Node.」ワードマーク。
struct ShareBrandMark: View {
    var body: some View {
        Text("Node.")
            .font(NodeFont.display(15, weight: .regular))
            .foregroundStyle(NodeColor.moss)
            .accessibilityHidden(true)
    }
}
