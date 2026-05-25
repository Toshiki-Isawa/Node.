import Foundation
import SwiftData

@MainActor
final class CollectionViewModel: ObservableObject {
    @Published var selectedCategory: String = "すべて"
    @Published var searchText: String = ""
    @Published var plants: [Plant] = []

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
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

    func deletePlant(_ plant: Plant) {
        modelContext.delete(plant)
        try? modelContext.save()
        reload()
    }
}
