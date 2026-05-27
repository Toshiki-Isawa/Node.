import Foundation

/// ケア通知のユーザー設定。受信窓は 04:00–23:59 に制限する。
struct CarePreferences: Codable, Equatable {
    static let earliestHour = 4
    static let latestHour = 24

    var isWateringRemindersEnabled: Bool
    var hour: Int
    var minute: Int

    init(
        isWateringRemindersEnabled: Bool = false,
        hour: Int = 8,
        minute: Int = 0
    ) {
        self.isWateringRemindersEnabled = isWateringRemindersEnabled
        self.hour = Self.clampHour(hour)
        self.minute = Self.clampMinute(minute)
    }

    var firingTimeComponents: DateComponents {
        DateComponents(hour: hour, minute: minute)
    }

    var displayTime: String {
        String(format: "%02d:%02d", hour, minute)
    }

    static func clampHour(_ raw: Int) -> Int {
        min(max(raw, earliestHour), latestHour - 1)
    }

    static func clampMinute(_ raw: Int) -> Int {
        min(max(raw, 0), 59)
    }
}
