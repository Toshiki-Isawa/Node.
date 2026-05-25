import Foundation
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
    private(set) var isConfigured = false

    func configure() {
        guard !isConfigured, let apiKey = AnalyticsConfig.apiKey else { return }
        let config = PostHogConfig(apiKey: apiKey, host: AnalyticsConfig.host)
        PostHogSDK.shared.setup(config)
        isConfigured = true
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
