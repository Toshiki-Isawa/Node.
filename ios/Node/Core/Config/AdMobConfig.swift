import Foundation

enum AdMobConfig {
    static let testAppID = "ca-app-pub-3940256099942544~1458002511"
    static let testRewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313"

    static var appID: String {
        #if DEBUG
        return testAppID
        #else
        guard let raw = Bundle.main.infoDictionary?["GAD_APP_ID"] as? String,
              !raw.isEmpty,
              !raw.contains("your-"),
              raw.contains("~") else {
            return testAppID
        }
        return raw
        #endif
    }

    static var rewardedAdUnitID: String {
        #if DEBUG
        return testRewardedAdUnitID
        #else
        guard let raw = Bundle.main.infoDictionary?["GAD_REWARDED_AD_UNIT_ID"] as? String,
              !raw.isEmpty,
              !raw.contains("your-"),
              raw.contains("/") else {
            return testRewardedAdUnitID
        }
        return raw
        #endif
    }
}
