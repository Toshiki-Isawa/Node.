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

    /// App Store Connect で確定後に差し替える。nil の間は Settings の「評価する」ボタンを非表示。
    static let appStoreId: String? = nil

    static var writeReviewURL: URL? {
        guard let id = appStoreId else { return nil }
        return URL(string: "itms-apps://itunes.apple.com/app/id\(id)?action=write-review")
    }
}
