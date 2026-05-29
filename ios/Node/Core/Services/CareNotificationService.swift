import Combine
import Foundation
import OSLog
import SwiftData
import UIKit
import UserNotifications

@MainActor
final class CareNotificationService: NSObject, ObservableObject {
    static let categoryIdentifier = "WATERING_REMINDER"
    static let actionDoneIdentifier = "WATERING_DONE"
    static let actionOpenIdentifier = "OPEN_APP"
    static let openCollectionNotification = Notification.Name("CareNotificationService.openCollection")

    private static let logger = Logger(subsystem: "app.node.ios", category: "CareNotification")
    private static let preferencesDefaultsKey = "careNotification.preferences.v1"
    private static let scheduleHorizonDays = 7

    @Published private(set) var preferences: CarePreferences
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let modelContext: ModelContext
    private let defaults: UserDefaults
    private let center: UNUserNotificationCenter
    private let analyticsService: AnalyticsService
    private var isBootstrapped = false

    init(
        modelContext: ModelContext,
        analyticsService: AnalyticsService,
        defaults: UserDefaults = .standard,
        center: UNUserNotificationCenter = .current()
    ) {
        self.modelContext = modelContext
        self.analyticsService = analyticsService
        self.defaults = defaults
        self.center = center
        self.preferences = Self.loadPreferences(from: defaults)
        super.init()
    }

    func bootstrap() async {
        guard !isBootstrapped else { return }
        isBootstrapped = true
        center.delegate = self
        registerCategory()
        await refreshAuthorizationStatus()
        await rescheduleIfNeeded()
        await updateBadge()
    }

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            analyticsService.capture(AnalyticsEvent.notificationPermissionRequested, properties: [
                "granted": granted,
            ])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            Self.logger.error("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
            analyticsService.capture(AnalyticsEvent.notificationPermissionRequested, properties: [
                "granted": false,
            ])
            await refreshAuthorizationStatus()
            return false
        }
    }

    func updatePreferences(_ new: CarePreferences) async {
        let sanitized = CarePreferences(
            isWateringRemindersEnabled: new.isWateringRemindersEnabled,
            hour: new.hour,
            minute: new.minute
        )
        preferences = sanitized
        savePreferences()

        if sanitized.isWateringRemindersEnabled {
            if authorizationStatus == .notDetermined {
                _ = await requestAuthorizationIfNeeded()
            }
        }
        await rescheduleIfNeeded()
        await updateBadge()
    }

    /// 観測・QuickLog・植物編集など、対象株が変わり得るイベント後に呼ぶ。
    func rescheduleIfNeeded() async {
        center.removePendingNotificationRequests(
            withIdentifiers: pendingIdentifiers()
        )

        guard isCareReminderActive else { return }

        for offset in 0..<Self.scheduleHorizonDays {
            await scheduleNotification(dayOffset: offset)
        }
    }

    /// アプリアイコンのバッジを「今日時点の水やり待ち株数」に合わせる。
    /// ゲート (リマインダー ON + 認可済み) を通らない場合は 0 (クリア) にする。
    /// アプリ生存中の更新経路。未起動時は scheduleNotification の content.badge が担う。
    func updateBadge() async {
        let count = isCareReminderActive ? overduePlants(on: Date()).count : 0
        do {
            try await center.setBadgeCount(count)
        } catch {
            Self.logger.error("Failed to set badge count: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 通知・バッジを出す条件 (リマインダー ON かつ通知認可済み)。
    private var isCareReminderActive: Bool {
        preferences.isWateringRemindersEnabled
            && (authorizationStatus == .authorized || authorizationStatus == .provisional)
    }

    private func registerCategory() {
        let done = UNNotificationAction(
            identifier: Self.actionDoneIdentifier,
            title: String(localized: "水やり完了"),
            options: []
        )
        let open = UNNotificationAction(
            identifier: Self.actionOpenIdentifier,
            title: String(localized: "アプリで確認"),
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [done, open],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    private func scheduleNotification(dayOffset: Int) async {
        let calendar = Calendar.current
        guard let baseDate = calendar.date(byAdding: .day, value: dayOffset, to: Date()) else { return }
        var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
        components.hour = preferences.hour
        components.minute = preferences.minute
        guard let fireDate = calendar.date(from: components), fireDate > Date() else { return }

        let targets = overduePlants(on: fireDate)
        guard !targets.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "今日の水やり")
        content.body = makeBody(for: targets)
        content.categoryIdentifier = Self.categoryIdentifier
        content.sound = .default
        // アプリ未起動でも発火時刻にバッジがその日の水やり待ち株数へ更新される。
        content.badge = NSNumber(value: targets.count)

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: identifier(for: dayOffset),
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            Self.logger.error("Failed to add notification: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func overduePlants(on referenceDate: Date) -> [Plant] {
        let calendar = Calendar.current
        let descriptor = FetchDescriptor<Plant>()
        guard let plants = try? modelContext.fetch(descriptor) else { return [] }

        let referenceDay = calendar.startOfDay(for: referenceDate)
        return plants.filter { plant in
            guard let interval = plant.wateringIntervalDays, interval > 0 else { return false }
            let lastWaterDay = calendar.startOfDay(for: plant.lastWateredAt)
            let days = calendar.dateComponents([.day], from: lastWaterDay, to: referenceDay).day ?? 0
            return days >= interval
        }
    }

    private func makeBody(for plants: [Plant]) -> String {
        let listSeparator = String(localized: "、")
        let names = plants.prefix(3).map(\.name)
        let leadingNames = names.joined(separator: listSeparator)
        if plants.count <= 3 {
            return String(localized: "\(plants.count) 株が水やり待ちです: \(leadingNames)")
        }
        let remaining = plants.count - 3
        return String(localized: "\(plants.count) 株が水やり待ちです: \(leadingNames) 他 \(remaining) 株")
    }

    private func identifier(for dayOffset: Int) -> String {
        "watering.reminder.day\(dayOffset)"
    }

    private func pendingIdentifiers() -> [String] {
        (0..<Self.scheduleHorizonDays).map(identifier(for:))
    }

    private static func loadPreferences(from defaults: UserDefaults) -> CarePreferences {
        guard let data = defaults.data(forKey: preferencesDefaultsKey),
              let decoded = try? JSONDecoder().decode(CarePreferences.self, from: data) else {
            return CarePreferences()
        }
        return decoded
    }

    private func savePreferences() {
        guard let encoded = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(encoded, forKey: Self.preferencesDefaultsKey)
    }
}

extension CareNotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        switch response.actionIdentifier {
        case Self.actionDoneIdentifier:
            await applyWateringDone()
        case Self.actionOpenIdentifier, UNNotificationDefaultActionIdentifier:
            analyticsService.capture(AnalyticsEvent.notificationOpenAppAction)
            NotificationCenter.default.post(name: Self.openCollectionNotification, object: nil)
        default:
            break
        }
        await rescheduleIfNeeded()
        await updateBadge()
    }

    private func applyWateringDone() async {
        let targets = overduePlants(on: Date())
        guard !targets.isEmpty else { return }

        let now = Date()
        for plant in targets {
            let log = GrowthLog(
                plantId: plant.id,
                type: .water,
                createdAt: now,
                syncStatus: .localOnly,
                updatedAt: now
            )
            modelContext.insert(log)
            plant.growthLogs.append(log)
            plant.updatedAt = now
        }
        do {
            try modelContext.save()
            analyticsService.capture(AnalyticsEvent.notificationWateringDoneAction, properties: [
                "plant_count": targets.count,
            ])
        } catch {
            Self.logger.error("Failed to save bulk water logs: \(error.localizedDescription, privacy: .public)")
        }
    }
}
