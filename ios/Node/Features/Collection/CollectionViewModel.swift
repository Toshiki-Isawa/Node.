import Foundation
import SwiftData

@MainActor
final class CollectionViewModel: ObservableObject {
    @Published var selectedCategory: String = "すべて"
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

    var categories: [String] {
        var set = Set(plants.map(\.category))
        set.insert("すべて")
        return ["すべて"] + set.filter { $0 != "すべて" }.sorted()
    }

    var filteredPlants: [Plant] {
        let base: [Plant]
        if selectedCategory == "すべて" {
            base = plants
        } else {
            base = plants.filter { $0.category == selectedCategory }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let searched: [Plant]
        if query.isEmpty {
            searched = base
        } else {
            let normalized = query.lowercased()
            searched = base.filter { plant in
                plant.name.lowercased().contains(normalized)
                    || plant.species.lowercased().contains(normalized)
                    || plant.category.lowercased().contains(normalized)
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
