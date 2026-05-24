import Foundation
import SwiftData

@MainActor
final class CollectionViewModel: ObservableObject {
    @Published var selectedCategory: String = "すべて"
    @Published var plants: [Plant] = []

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        reload()
    }

    func reload() {
        let descriptor = FetchDescriptor<Plant>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        plants = (try? modelContext.fetch(descriptor)) ?? []
    }

    var categories: [String] {
        var set = Set(plants.map(\.category))
        set.insert("すべて")
        return ["すべて"] + set.filter { $0 != "すべて" }.sorted()
    }

    var filteredPlants: [Plant] {
        guard selectedCategory != "すべて" else { return plants }
        return plants.filter { $0.category == selectedCategory }
    }

    var totalObservations: Int {
        plants.reduce(0) { $0 + $1.observationCount }
    }

    func deletePlant(_ plant: Plant) {
        modelContext.delete(plant)
        try? modelContext.save()
        reload()
    }
}
