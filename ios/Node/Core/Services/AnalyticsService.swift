import Foundation
import OSLog
import PostHog

enum AnalyticsEvent: String {
    case adRewardedPreloadStarted = "ad_rewarded_preload_started"
    case adRewardedPreloadFailed = "ad_rewarded_preload_failed"
    case adRewardedShown = "ad_rewarded_shown"
    case adRewardedCompleted = "ad_rewarded_completed"
    case adRewardedDismissed = "ad_rewarded_dismissed"
    case adRewardedRetry = "ad_rewarded_retry"
    case adRewardedFallbackUnlock = "ad_rewarded_fallback_unlock"
}

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

    func capture(_ event: AnalyticsEvent, plan: UserPlan? = nil, retryCount: Int? = nil, errorCode: Int? = nil) {
        guard isConfigured else { return }

        var properties: [String: Any] = [:]
        if let plan {
            properties["plan"] = plan.rawValue
        }
        if let retryCount {
            properties["retry_count"] = retryCount
        }
        if let errorCode {
            properties["error_code"] = errorCode
        }

        PostHogSDK.shared.capture(event.rawValue, properties: properties)
    }
}
