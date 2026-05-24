import Foundation
import SwiftData

@MainActor
final class EditPlantViewModel: ObservableObject {
    @Published var name: String
    @Published var species: String
    @Published var category: String
    @Published var acquiredAt: Date

    let plant: Plant

    private let modelContext: ModelContext
    private let syncEngine: SyncEngine

    init(plant: Plant, modelContext: ModelContext, syncEngine: SyncEngine) {
        self.plant = plant
        self.modelContext = modelContext
        self.syncEngine = syncEngine
        self.name = plant.name
        self.species = plant.species
        self.category = plant.category
        self.acquiredAt = plant.acquiredAt
    }

    var acquiredAtRange: ClosedRange<Date> {
        Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1))! ... Date.now
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && acquiredAtRange.contains(acquiredAt)
    }

    func save() throws {
        guard canSave else { return }

        plant.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        plant.species = species.trimmingCharacters(in: .whitespacesAndNewlines)
        plant.category = category
        plant.acquiredAt = acquiredAt
        plant.updatedAt = .now
        try modelContext.save()
        syncEngine.enqueueSync()
    }
}
