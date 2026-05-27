import Foundation
import OSLog
import PostHog
import UIKit

/// v1.0 で送信するイベント名の定数集。文字列は PostHog 側でそのまま使われる。
enum AnalyticsEvent {
    static let appLaunch = "app_launch"
    static let appForeground = "app_foreground"

    static let plantAdded = "plant_added"
    static let plantEdited = "plant_edited"
    static let plantDeleted = "plant_deleted"

    static let observationCaptured = "observation_captured"

    static let quickLogAdded = "quicklog_added"
    static let bulkQuickLogUsed = "bulk_quicklog_used"

    static let timelineViewed = "timeline_viewed"
    static let compareOpened = "compare_opened"
    static let settingsOpened = "settings_opened"

    static let feedbackMailtoOpened = "feedback_mailto_opened"
    static let reviewPromptShown = "review_prompt_shown"

    static let notificationPermissionRequested = "notification_permission_requested"
    static let notificationWateringDoneAction = "notification_watering_done_action"
    static let notificationOpenAppAction = "notification_open_app_action"
}

@MainActor
final class AnalyticsService: ObservableObject {
    private static let logger = Logger(subsystem: "app.node.ios", category: "AnalyticsService")
    private static let optOutDefaultsKey = "analytics.optOut.v1"

    @Published private(set) var isOptedOut: Bool

    private let defaults: UserDefaults
    private(set) var isConfigured = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isOptedOut = defaults.bool(forKey: Self.optOutDefaultsKey)
    }

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
        config.optOut = isOptedOut
        PostHogSDK.shared.setup(config)
        isConfigured = true
        Self.logger.info("PostHog configured (host: \(host, privacy: .public))")

        registerSuperProperties()
    }

    func capture(_ event: String, properties: [String: Any]? = nil) {
        guard isConfigured else { return }
        if let properties {
            PostHogSDK.shared.capture(event, properties: properties)
        } else {
            PostHogSDK.shared.capture(event)
        }
    }

    func setOptedOut(_ optedOut: Bool) {
        isOptedOut = optedOut
        defaults.set(optedOut, forKey: Self.optOutDefaultsKey)
        guard isConfigured else { return }
        if optedOut {
            PostHogSDK.shared.optOut()
        } else {
            PostHogSDK.shared.optIn()
        }
    }

    private func registerSuperProperties() {
        let props: [String: Any] = [
            "app_version": AppInfo.marketingVersion,
            "build_number": AppInfo.buildNumber,
            "os_version": UIDevice.current.systemVersion,
            "device_model": Self.deviceModelIdentifier(),
            "release_train": "v1.0",
        ]
        PostHogSDK.shared.register(props)
    }

    private static func deviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let identifier = withUnsafePointer(to: &systemInfo.machine) { ptr -> String in
            ptr.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        return identifier.isEmpty ? UIDevice.current.model : identifier
    }
}
