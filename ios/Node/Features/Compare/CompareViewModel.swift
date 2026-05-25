import Foundation

enum CompareSide: String, Identifiable {
    case before
    case after

    var id: String { rawValue }
}

@MainActor
final class CompareViewModel: ObservableObject {
    @Published var plant: Plant?
    @Published var beforeIndex: Int = 0
    @Published var afterIndex: Int = 0
    @Published private(set) var beforeImagePath: String?
    @Published private(set) var afterImagePath: String?
    @Published private(set) var isLoadingImages = false
    @Published var imageLoadError: String?

    @Published var beforeDisplayedMonth = Calendar.current.startOfMonth(for: .now)
    @Published var afterDisplayedMonth = Calendar.current.startOfMonth(for: .now)
    @Published var beforePickerDay: Date?
    @Published var afterPickerDay: Date?
    @Published var activeCalendarSide: CompareSide?

    private let observationImageService: ObservationImageService

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "ja_JP")
        return cal
    }

    init(observationImageService: ObservationImageService) {
        self.observationImageService = observationImageService
    }

    var sortedObservations: [PlantObservation] {
        guard let plant else { return [] }
        return plant.observations.sorted { $0.createdAt < $1.createdAt }
    }

    var beforeObservation: PlantObservation? {
        guard !sortedObservations.isEmpty else { return nil }
        let index = min(beforeIndex, sortedObservations.count - 1)
        return sortedObservations[index]
    }

    var afterObservation: PlantObservation? {
        guard !sortedObservations.isEmpty else { return nil }
        let index = min(max(afterIndex, beforeIndex), sortedObservations.count - 1)
        return sortedObservations[index]
    }

    var comparisonSelectionKey: String {
        "\(beforeIndex)-\(afterIndex)"
    }

    func configure(plant: Plant?) {
        self.plant = plant
        let count = plant?.observations.count ?? 0
        if count >= 2 {
            beforeIndex = count - 2
            afterIndex = count - 1
        } else {
            beforeIndex = 0
            afterIndex = max(0, count - 1)
        }

        if let after = afterObservation {
            afterDisplayedMonth = calendar.startOfMonth(for: after.createdAt)
            afterPickerDay = calendar.startOfDay(for: after.createdAt)
        }
        if let before = beforeObservation {
            beforeDisplayedMonth = calendar.startOfMonth(for: before.createdAt)
            beforePickerDay = calendar.startOfDay(for: before.createdAt)
        }

        Task { await loadComparisonImages() }
    }

    func loadComparisonImages() async {
        guard let before = beforeObservation, let after = afterObservation else {
            beforeImagePath = nil
            afterImagePath = nil
            return
        }

        isLoadingImages = true
        imageLoadError = nil
        defer { isLoadingImages = false }

        do {
            async let beforePath = observationImageService.ensureOriginalPath(for: before)
            async let afterPath = observationImageService.ensureOriginalPath(for: after)
            beforeImagePath = try await beforePath
            afterImagePath = try await afterPath
        } catch {
            beforeImagePath = nil
            afterImagePath = nil
            imageLoadError = error.localizedDescription
        }
    }

    var intervalDays: Int {
        guard let before = beforeObservation, let after = afterObservation else { return 0 }
        return calendar.dateComponents([.day], from: before.createdAt, to: after.createdAt).day ?? 0
    }

    var observationIntervalCount: Int {
        max(afterIndex - beforeIndex, 0)
    }

    var waterLogCount: Int {
        plant?.growthLogs.filter { $0.type == .water }.count ?? 0
    }

    func observationDayNumber(_ observation: PlantObservation) -> Int {
        guard let plant else { return 1 }
        let days = calendar.dateComponents([.day], from: plant.acquiredAt, to: observation.createdAt).day ?? 0
        return days + 1
    }

    func setBeforeIndex(_ index: Int) {
        let count = sortedObservations.count
        guard count > 0 else { return }
        beforeIndex = min(max(index, 0), count - 1)
        if beforeIndex >= afterIndex {
            afterIndex = min(beforeIndex + 1, count - 1)
        }
        if let before = beforeObservation {
            beforeDisplayedMonth = calendar.startOfMonth(for: before.createdAt)
            beforePickerDay = calendar.startOfDay(for: before.createdAt)
        }
    }

    func setAfterIndex(_ index: Int) {
        let count = sortedObservations.count
        guard count > 0 else { return }
        afterIndex = min(max(index, 0), count - 1)
        if afterIndex <= beforeIndex {
            beforeIndex = max(afterIndex - 1, 0)
        }
        if let after = afterObservation {
            afterDisplayedMonth = calendar.startOfMonth(for: after.createdAt)
            afterPickerDay = calendar.startOfDay(for: after.createdAt)
        }
    }

    func selectObservation(_ observation: PlantObservation, for side: CompareSide) {
        guard let index = sortedObservations.firstIndex(where: { $0.id == observation.id }) else { return }
        switch side {
        case .before:
            setBeforeIndex(index)
        case .after:
            setAfterIndex(index)
        }
        closeCalendar()
    }

    func openCalendar(for side: CompareSide) {
        activeCalendarSide = side
        let observation = side == .before ? beforeObservation : afterObservation
        if let observation {
            setDisplayedMonth(calendar.startOfMonth(for: observation.createdAt), for: side)
            setPickerDay(calendar.startOfDay(for: observation.createdAt), for: side)
        }
    }

    func closeCalendar() {
        activeCalendarSide = nil
    }

    // MARK: - Calendar

    func displayedMonth(for side: CompareSide) -> Date {
        switch side {
        case .before: beforeDisplayedMonth
        case .after: afterDisplayedMonth
        }
    }

    func calendarMonthTitle(for side: CompareSide) -> String {
        displayedMonth(for: side).nodeYearMonth()
    }

    var weekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let offset = calendar.firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }

    func canGoToPreviousMonth(for side: CompareSide) -> Bool {
        guard let plant else { return false }
        return displayedMonth(for: side) > calendar.startOfMonth(for: plant.acquiredAt)
    }

    func canGoToNextMonth(for side: CompareSide) -> Bool {
        displayedMonth(for: side) < calendar.startOfMonth(for: .now)
    }

    func calendarGridDays(for side: CompareSide) -> [Date?] {
        let displayedMonth = displayedMonth(for: side)
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

    func goToPreviousMonth(for side: CompareSide) {
        guard canGoToPreviousMonth(for: side),
              let previous = calendar.date(byAdding: .month, value: -1, to: displayedMonth(for: side)) else { return }
        setDisplayedMonth(previous, for: side)
        setPickerDay(nil, for: side)
    }

    func goToNextMonth(for side: CompareSide) {
        guard canGoToNextMonth(for: side),
              let next = calendar.date(byAdding: .month, value: 1, to: displayedMonth(for: side)) else { return }
        setDisplayedMonth(next, for: side)
        setPickerDay(nil, for: side)
    }

    func setDisplayedMonth(_ date: Date, for side: CompareSide) {
        switch side {
        case .before:
            beforeDisplayedMonth = date
        case .after:
            afterDisplayedMonth = date
        }
    }

    func pickerDay(for side: CompareSide) -> Date? {
        switch side {
        case .before: beforePickerDay
        case .after: afterPickerDay
        }
    }

    func setPickerDay(_ day: Date?, for side: CompareSide) {
        switch side {
        case .before:
            beforePickerDay = day
        case .after:
            afterPickerDay = day
        }
    }

    func selectDay(_ day: Date, for side: CompareSide) {
        guard hasObservations(on: day) else { return }
        let observations = observations(on: day)
        if observations.count == 1, let observation = observations.first {
            selectObservation(observation, for: side)
            setPickerDay(day, for: side)
            return
        }

        if let current = pickerDay(for: side), calendar.isDate(day, inSameDayAs: current) {
            setPickerDay(nil, for: side)
        } else {
            setPickerDay(day, for: side)
        }
    }

    func isSelected(_ day: Date, for side: CompareSide) -> Bool {
        guard let pickerDay = pickerDay(for: side) else { return false }
        return calendar.isDate(day, inSameDayAs: pickerDay)
    }

    func isActiveObservationDay(_ day: Date, for side: CompareSide) -> Bool {
        let observation = side == .before ? beforeObservation : afterObservation
        guard let observation else { return false }
        return calendar.isDate(observation.createdAt, inSameDayAs: day)
    }

    func isToday(_ day: Date) -> Bool {
        calendar.isDateInToday(day)
    }

    func isFuture(_ day: Date) -> Bool {
        day > calendar.startOfDay(for: .now)
    }

    func isBeforeAcquisition(_ day: Date) -> Bool {
        guard let plant else { return true }
        return day < calendar.startOfDay(for: plant.acquiredAt)
    }

    func observations(on day: Date) -> [PlantObservation] {
        sortedObservations
            .filter { calendar.isDate($0.createdAt, inSameDayAs: day) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func hasObservations(on day: Date) -> Bool {
        !observations(on: day).isEmpty
    }

    func isSelectedObservation(_ observation: PlantObservation, for side: CompareSide) -> Bool {
        switch side {
        case .before:
            beforeObservation?.id == observation.id
        case .after:
            afterObservation?.id == observation.id
        }
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        dateInterval(of: .month, for: date)?.start ?? date
    }
}
