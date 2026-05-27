import Foundation
import OSLog
import PostHog

@MainActor
final class AnalyticsService {
    private static let logger = Logger(subsystem: "app.node.ios", category: "AnalyticsService")

    private(set) var isConfigured = false

    func configure() {
        if isConfigured {
            Self.logger.debug("PostHog is already configured; skipping setup")
            return
        }

        guard let apiKey = AnalyticsConfig.apiKey else {
            Self.logger.warning("PostHog API key is missing or placeholder; analytics disabled")
            return
        }

        let host = AnalyticsConfig.host
        let config = PostHogConfig(apiKey: apiKey, host: host)
        PostHogSDK.shared.setup(config)
        isConfigured = true
        Self.logger.info("PostHog configured (host: \(host, privacy: .public))")
    }
}
