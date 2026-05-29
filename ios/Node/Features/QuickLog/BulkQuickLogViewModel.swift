import Foundation
import SwiftData

@MainActor
final class BulkQuickLogViewModel: ObservableObject {
    static let plantListCollapseThreshold = 3

    @Published var plants: [Plant] = []
    @Published var selectedPlantIDs: Set<UUID> = []
    @Published var selectedTypes: Set<GrowthLogType> = []
    @Published var memo = ""
    @Published var recordedAt = Date.now

    let context: BulkQuickLogContext

    private let modelContext: ModelContext
    private let syncEngine: SyncEngine
    private let analyticsService: AnalyticsService

    init(
        modelContext: ModelContext,
        syncEngine: SyncEngine,
        analyticsService: AnalyticsService,
        context: BulkQuickLogContext = .general
    ) {
        self.modelContext = modelContext
        self.syncEngine = syncEngine
        self.analyticsService = analyticsService
        self.context = context
        reload()
        applyContextPreset()
    }

    func reload() {
        let descriptor = FetchDescriptor<Plant>()
        let fetched = (try? modelContext.fetch(descriptor)) ?? []
        plants = fetched.sorted { lhs, rhs in
            let leftPriority = lhs.wateringSortPriority
            let rightPriority = rhs.wateringSortPriority
            if leftPriority != rightPriority { return leftPriority > rightPriority }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
        selectedPlantIDs = selectedPlantIDs.intersection(Set(plants.map(\.id)))
    }

    var selectedPlants: [Plant] {
        plants.filter { selectedPlantIDs.contains($0.id) }
    }

    var selectedCount: Int {
        selectedPlantIDs.count
    }

    var shouldCollapsePlantListByDefault: Bool {
        selectedCount > Self.plantListCollapseThreshold
    }

    var selectedPlantSummaryText: String {
        let selected = selectedPlants
        guard !selected.isEmpty else { return String(localized: "植物を選択してください") }

        let separator = String(localized: "、")
        let names = selected.prefix(2).map(\.name).joined(separator: separator)
        if selected.count <= 2 {
            return names
        }
        return String(localized: "\(names) 他 \(selected.count - 2) 株")
    }

    var trimmedMemo: String {
        memo.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var recordedAtRange: ClosedRange<Date> {
        let earliest = plants.map(\.acquiredAt).min() ?? .now
        return earliest ... Date.now
    }

    var canSave: Bool {
        !selectedPlantIDs.isEmpty
            && recordedAtRange.contains(recordedAt)
            && (!selectedTypes.isEmpty || !trimmedMemo.isEmpty)
    }

    var isRecordingInPast: Bool {
        recordedAt.timeIntervalSinceNow < -60
    }

    var plantsNeedingWater: [Plant] {
        plants.filter(\.needsWatering)
    }

    func resetToNow() {
        recordedAt = Date.now
    }

    func toggleType(_ type: GrowthLogType) {
        if selectedTypes.contains(type) {
            selectedTypes.remove(type)
        } else {
            selectedTypes.insert(type)
        }
    }

    func isSelected(_ type: GrowthLogType) -> Bool {
        selectedTypes.contains(type)
    }

    func isPlantSelected(_ plant: Plant) -> Bool {
        selectedPlantIDs.contains(plant.id)
    }

    func togglePlant(_ plant: Plant) {
        if selectedPlantIDs.contains(plant.id) {
            selectedPlantIDs.remove(plant.id)
        } else {
            selectedPlantIDs.insert(plant.id)
        }
    }

    func selectAllPlants() {
        selectedPlantIDs = Set(plants.map(\.id))
    }

    func clearPlantSelection() {
        selectedPlantIDs.removeAll()
    }

    func selectPlantsNeedingWater() {
        selectedPlantIDs = Set(plantsNeedingWater.map(\.id))
    }

    func save() throws {
        guard canSave else { return }

        let orderedTypes: [GrowthLogType]
        if selectedTypes.isEmpty {
            orderedTypes = [.note]
        } else {
            orderedTypes = GrowthLogType.quickLogActionTypes.filter { selectedTypes.contains($0) }
        }

        for plant in selectedPlants {
            for type in orderedTypes {
                let log = GrowthLog(
                    plantId: plant.id,
                    type: type,
                    memo: trimmedMemo,
                    createdAt: recordedAt,
                    updatedAt: recordedAt
                )
                log.plant = plant
                plant.growthLogs.append(log)
                modelContext.insert(log)
            }
            plant.updatedAt = .now
        }

        try modelContext.save()
        syncEngine.enqueueSync()
        analyticsService.capture(AnalyticsEvent.bulkQuickLogUsed, properties: [
            "plant_count": selectedPlants.count,
            "type_count": orderedTypes.count,
        ])
    }

    private func applyContextPreset() {
        switch context {
        case .general:
            // ヘッダーからの起動時は未選択状態で開始する
            break
        case .wateringReminder:
            selectedTypes = [.water]
            if !plantsNeedingWater.isEmpty {
                selectedPlantIDs = Set(plantsNeedingWater.map(\.id))
            }
        }
    }
}
