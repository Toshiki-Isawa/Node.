import Foundation
import SwiftData

enum PlantDetailTimelineItem: Identifiable {
    case observation(PlantObservation)
    case growthLog(GrowthLog)

    var id: UUID {
        switch self {
        case .observation(let observation): observation.id
        case .growthLog(let log): log.id
        }
    }

    var createdAt: Date {
        switch self {
        case .observation(let observation): observation.createdAt
        case .growthLog(let log): log.createdAt
        }
    }
}

@MainActor
final class PlantDetailViewModel: ObservableObject {
    let plant: Plant
    private let recordDeletionService: RecordDeletionService
    private let observationImageService: ObservationImageService

    @Published var displayedMonth: Date
    @Published var selectedDay: Date?
    @Published var isCalendarExpanded = false

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = NodeDateFormat.locale
        return cal
    }

    init(
        plant: Plant,
        recordDeletionService: RecordDeletionService,
        observationImageService: ObservationImageService
    ) {
        self.plant = plant
        self.recordDeletionService = recordDeletionService
        self.observationImageService = observationImageService
        self.displayedMonth = Calendar.current.startOfMonth(for: .now)
    }

    func delete(_ target: DeleteRecordTarget) throws {
        switch target {
        case .observation(let observation):
            try recordDeletionService.deleteObservation(observation, from: plant)
            if let selectedDay, logs(on: selectedDay).isEmpty, logTypes(on: selectedDay).isEmpty {
                self.selectedDay = nil
            }
        case .growthLog(let log):
            try recordDeletionService.deleteGrowthLog(log, from: plant)
            if let selectedDay, logs(on: selectedDay).isEmpty {
                self.selectedDay = nil
            }
        }
    }

    var sortedObservations: [PlantObservation] {
        plant.observations.sorted { $0.createdAt > $1.createdAt }
    }

    var timelineItems: [PlantDetailTimelineItem] {
        let observations = plant.observations.map { PlantDetailTimelineItem.observation($0) }
        let logs = plant.growthLogs.map { PlantDetailTimelineItem.growthLog($0) }
        return (observations + logs).sorted { $0.createdAt > $1.createdAt }
    }

    var heroImagePath: String? {
        guard let observation = sortedObservations.first else { return nil }
        return observationImageService.displayThumbnailPath(for: observation)
    }

    func displayThumbnailPath(for observation: PlantObservation) -> String? {
        observationImageService.displayThumbnailPath(for: observation)
    }

    var waterLogCount: Int {
        plant.growthLogs.filter { $0.type == .water }.count
    }

    // MARK: - Care Calendar

    var calendarMonthTitle: String {
        displayedMonth.nodeYearMonth()
    }

    var calendarDateRange: ClosedRange<Date> {
        calendar.startOfDay(for: plant.acquiredAt) ... calendar.startOfDay(for: .now)
    }

    var calendarPickerSeedDate: Date {
        if let selectedDay {
            return selectedDay
        }
        let today = calendar.startOfDay(for: .now)
        if calendar.isDate(today, equalTo: displayedMonth, toGranularity: .month) {
            return today
        }
        return displayedMonth
    }

    var weekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let offset = calendar.firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }

    var canGoToPreviousMonth: Bool {
        displayedMonth > calendar.startOfMonth(for: plant.acquiredAt)
    }

    var canGoToNextMonth: Bool {
        displayedMonth < calendar.startOfMonth(for: .now)
    }

    var calendarGridDays: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7
        let dayCount = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 0

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for day in 1...dayCount {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start) {
                days.append(date)
            }
        }
        return days
    }

    var lastWateredDate: Date? {
        plant.growthLogs
            .filter { $0.type == .water }
            .map(\.createdAt)
            .max()
    }

    var nextWaterDate: Date? {
        guard let interval = plant.wateringIntervalDays, interval > 0 else { return nil }
        return calendar.date(
            byAdding: .day,
            value: interval,
            to: calendar.startOfDay(for: plant.lastWateredAt)
        )
    }

    var wateringOverdueDays: Int? {
        guard let interval = plant.wateringIntervalDays, interval > 0 else { return nil }
        let overdue = plant.daysSinceLastWater - interval
        return overdue > 0 ? overdue : nil
    }

    var lastWaterPrimaryText: String {
        guard let lastWateredDate else { return "記録なし" }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: lastWateredDate),
            to: calendar.startOfDay(for: .now)
        ).day ?? 0
        switch days {
        case 0: return "今日"
        case 1: return "昨日"
        default: return "\(days)日前"
        }
    }

    var lastWaterSecondaryDateText: String? {
        lastWateredDate?.nodeMonthDay()
    }

    var nextWaterPrimaryText: String {
        guard let interval = plant.wateringIntervalDays, interval > 0 else {
            return "頻度未設定"
        }
        if let overdue = wateringOverdueDays {
            return "\(overdue)日遅れ"
        }
        let daysUntil = interval - plant.daysSinceLastWater
        switch daysUntil {
        case 0: return "今日"
        case 1: return "明日"
        default: return "あと\(daysUntil)日"
        }
    }

    var nextWaterSecondaryDateText: String? {
        nextWaterDate?.nodeMonthDay()
    }

    var isNextWaterOverdue: Bool {
        wateringOverdueDays != nil
    }

    func toggleCalendarExpanded() {
        isCalendarExpanded.toggle()
        if !isCalendarExpanded {
            selectedDay = nil
        }
    }

    func goToPreviousMonth() {
        guard canGoToPreviousMonth,
              let previous = calendar.date(byAdding: .month, value: -1, to: displayedMonth) else { return }
        displayedMonth = previous
        selectedDay = nil
    }

    func goToNextMonth() {
        guard canGoToNextMonth,
              let next = calendar.date(byAdding: .month, value: 1, to: displayedMonth) else { return }
        displayedMonth = next
        selectedDay = nil
    }

    func jumpToDate(_ date: Date) {
        let day = calendar.startOfDay(for: date)
        let clamped = min(max(day, calendarDateRange.lowerBound), calendarDateRange.upperBound)
        displayedMonth = calendar.startOfMonth(for: clamped)
        selectedDay = clamped
    }

    func selectDay(_ day: Date) {
        if calendar.isDate(day, inSameDayAs: selectedDay ?? .distantPast) {
            selectedDay = nil
        } else {
            selectedDay = day
        }
    }

    func isSelected(_ day: Date) -> Bool {
        guard let selectedDay else { return false }
        return calendar.isDate(day, inSameDayAs: selectedDay)
    }

    func isToday(_ day: Date) -> Bool {
        calendar.isDateInToday(day)
    }

    func isFuture(_ day: Date) -> Bool {
        day > calendar.startOfDay(for: .now)
    }

    func isBeforeAcquisition(_ day: Date) -> Bool {
        day < calendar.startOfDay(for: plant.acquiredAt)
    }

    func logTypes(on day: Date) -> [GrowthLogType] {
        let types = logs(on: day).map(\.type)
        return GrowthLogType.allCases.filter { types.contains($0) }
    }

    func logs(on day: Date) -> [GrowthLog] {
        plant.growthLogs
            .filter { calendar.isDate($0.createdAt, inSameDayAs: day) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func hasLogs(on day: Date) -> Bool {
        !logs(on: day).isEmpty
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        dateInterval(of: .month, for: date)?.start ?? date
    }
}
