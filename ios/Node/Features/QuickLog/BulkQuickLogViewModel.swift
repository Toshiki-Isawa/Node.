import Foundation
import SwiftData

@MainActor
final class BulkQuickLogViewModel: ObservableObject {
    @Published var plants: [Plant] = []
    @Published var selectedPlantIDs: Set<UUID> = []
    @Published var selectedTypes: Set<GrowthLogType> = []
    @Published var memo = ""
    @Published var recordedAt = Date.now

    private let modelContext: ModelContext
    private let syncEngine: SyncEngine

    init(modelContext: ModelContext, syncEngine: SyncEngine) {
        self.modelContext = modelContext
        self.syncEngine = syncEngine
        reload()
        if !plantsNeedingWater.isEmpty {
            selectedPlantIDs = Set(plantsNeedingWater.map(\.id))
        }
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
    }
}
