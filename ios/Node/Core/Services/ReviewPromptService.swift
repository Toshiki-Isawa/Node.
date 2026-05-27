import Foundation
import OSLog
import SwiftData

/// レビュー促進ダイアログの発火元種別。アナリティクスの property としても利用。
enum ReviewPromptTrigger: String {
    case observationCaptured = "observation_captured"
    case compareCompleted = "compare_completed"
}

/// `RequestReviewAction` を呼ぶ条件を集中管理する。
///
/// 発火条件（AND）:
///   - 累計観測 ≥ 10
///   - 直近 7 日のうち 5 日以上で観測あり
///   - 過去 90 日以内に未発火（独自タイマー。Apple 側でも年 3 回まで自動制限）
@MainActor
final class ReviewPromptService: ObservableObject {
    static let cooldownDays = 90
    static let requiredObservationCount = 10
    static let requiredStreakDays = 5
    static let streakWindowDays = 7

    private static let logger = Logger(subsystem: "app.node.ios", category: "ReviewPrompt")
    private static let lastPromptKey = "reviewPrompt.lastShownAt.v1"
    private static let totalCountKey = "reviewPrompt.totalCount.v1"

    /// SwiftUI 側で `.onChange` 経由で `requestReview()` を呼ぶためのトークン。
    @Published private(set) var pendingPromptToken: UUID?

    private let modelContext: ModelContext
    private let analyticsService: AnalyticsService
    private let defaults: UserDefaults

    init(
        modelContext: ModelContext,
        analyticsService: AnalyticsService,
        defaults: UserDefaults = .standard
    ) {
        self.modelContext = modelContext
        self.analyticsService = analyticsService
        self.defaults = defaults
    }

    /// 観測完了 / Compare 終了などの達成イベント発火点から呼ぶ。条件を満たさなければ no-op。
    func signalEligibleEvent(_ trigger: ReviewPromptTrigger) {
        guard meetsConditions() else { return }
        pendingPromptToken = UUID()
        markPromptScheduled()
        analyticsService.capture(AnalyticsEvent.reviewPromptShown, properties: [
            "trigger": trigger.rawValue,
        ])
    }

    /// `.onChange` ハンドラ側で `requestReview()` を呼んだ後にトークンを消費する。
    func consumeToken() {
        pendingPromptToken = nil
    }

    private func meetsConditions() -> Bool {
        if let last = defaults.object(forKey: Self.lastPromptKey) as? Date {
            let cooldown = TimeInterval(Self.cooldownDays * 86400)
            if Date().timeIntervalSince(last) < cooldown {
                return false
            }
        }

        let descriptor = FetchDescriptor<PlantObservation>()
        guard let observations = try? modelContext.fetch(descriptor) else { return false }
        guard observations.count >= Self.requiredObservationCount else { return false }

        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .day, value: -Self.streakWindowDays, to: Date()) else {
            return false
        }
        let recentDays = Set(observations
            .filter { $0.createdAt >= cutoff }
            .map { calendar.startOfDay(for: $0.createdAt) })
        return recentDays.count >= Self.requiredStreakDays
    }

    private func markPromptScheduled() {
        defaults.set(Date(), forKey: Self.lastPromptKey)
        let previous = defaults.integer(forKey: Self.totalCountKey)
        defaults.set(previous + 1, forKey: Self.totalCountKey)
        Self.logger.info("Review prompt scheduled (total: \(previous + 1, privacy: .public))")
    }
}
