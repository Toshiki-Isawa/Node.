import SwiftUI
import WebKit

struct PrivacyPolicyWebView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PrivacyPolicyWebViewRepresentable(url: url)
                .background(NodeColor.graphite)
                .navigationTitle("プライバシーポリシー")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("閉じる") { dismiss() }
                            .foregroundStyle(NodeColor.fog)
                    }
                }
        }
        .preferredColorScheme(.dark)
    }
}

private struct PrivacyPolicyWebViewRepresentable: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
