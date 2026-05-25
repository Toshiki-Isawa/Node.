import Foundation

enum AnalyticsConfig {
    static var apiKey: String? {
        guard let raw = Bundle.main.infoDictionary?["POSTHOG_API_KEY"] as? String,
              !raw.isEmpty,
              !raw.contains("your-posthog-key") else {
            return nil
        }
        return raw
    }

    static var host: String {
        guard let raw = Bundle.main.infoDictionary?["POSTHOG_HOST"] as? String,
              !raw.isEmpty,
              let url = URL(string: raw),
              url.scheme != nil else {
            return "https://us.i.posthog.com"
        }
        return raw
    }
}
