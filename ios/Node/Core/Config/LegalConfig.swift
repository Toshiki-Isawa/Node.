import Foundation

enum LegalConfig {
    /// App Store Connect 等で公開したプライバシーポリシー URL。未設定時は同梱 HTML を使用。
    static var privacyPolicyURL: URL? {
        guard let raw = Bundle.main.infoDictionary?["PRIVACY_POLICY_URL"] as? String,
              !raw.isEmpty,
              !raw.contains("$("),
              !raw.contains("example.com"),
              !raw.contains("your-"),
              let url = URL(string: raw),
              url.scheme?.hasPrefix("http") == true else {
            return nil
        }
        return url
    }

    static var bundledPrivacyPolicyURL: URL? {
        Bundle.main.url(forResource: "privacy", withExtension: "html")
    }

    /// 外部 URL が設定されていればそちら、なければ同梱 HTML。
    static var effectivePrivacyPolicyURL: URL? {
        privacyPolicyURL ?? bundledPrivacyPolicyURL
    }

    /// フィードバック / お問い合わせ受信用メールアドレス。privacy-policy.md と一致。
    static let feedbackEmail = "support@node-app.jp"
}
