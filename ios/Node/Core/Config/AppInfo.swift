import Foundation

enum AppInfo {
    static var marketingVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    static var versionLabel: String {
        "バージョン \(marketingVersion) (\(buildNumber))"
    }
}
