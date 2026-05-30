import SwiftUI
import WebKit

struct LegalDocumentWebView: View {
    let url: URL
    let title: LocalizedStringKey
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            LegalDocumentWebViewRepresentable(url: url)
                .background(NodeColor.graphite)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(NodeColor.graphite, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
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

private struct LegalDocumentWebViewRepresentable: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.body.classList.add('embedded')")
        }
    }
}
