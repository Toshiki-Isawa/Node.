import Foundation
import SwiftData

@MainActor
final class CollectionViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var plants: [Plant] = []

    private let modelContext: ModelContext
    private let recordDeletionService: RecordDeletionService
    private let analyticsService: AnalyticsService

    init(
        modelContext: ModelContext,
        recordDeletionService: RecordDeletionService,
        analyticsService: AnalyticsService
    ) {
        self.modelContext = modelContext
        self.recordDeletionService = recordDeletionService
        self.analyticsService = analyticsService
        reload()
    }

    func reload() {
        let descriptor = FetchDescriptor<Plant>()
        plants = (try? modelContext.fetch(descriptor)) ?? []
    }

    var filteredPlants: [Plant] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let searched: [Plant]
        if query.isEmpty {
            searched = plants
        } else {
            let normalized = query.lowercased()
            searched = plants.filter { plant in
                plant.name.lowercased().contains(normalized)
                    || plant.species.lowercased().contains(normalized)
            }
        }

        return searched.sorted { lhs, rhs in
            let leftPriority = lhs.wateringSortPriority
            let rightPriority = rhs.wateringSortPriority
            if leftPriority != rightPriority { return leftPriority > rightPriority }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    var totalObservations: Int {
        plants.reduce(0) { $0 + $1.observationCount }
    }

    var plantsNeedingWaterCount: Int {
        plants.filter(\.needsWatering).count
    }

    func deletePlant(_ plant: Plant) throws {
        let observationCount = plant.observations.count
        try recordDeletionService.deletePlant(plant)
        analyticsService.capture(AnalyticsEvent.plantDeleted, properties: [
            "observation_count": observationCount,
        ])
        reload()
    }
}
