import Foundation
import SwiftData

@MainActor
final class EditObservationViewModel: ObservableObject {
    let plant: Plant
    let observation: PlantObservation

    @Published var observedAt: Date

    private let modelContext: ModelContext
    private let syncEngine: SyncEngine

    init(
        plant: Plant,
        observation: PlantObservation,
        modelContext: ModelContext,
        syncEngine: SyncEngine
    ) {
        self.plant = plant
        self.observation = observation
        self.observedAt = observation.createdAt
        self.modelContext = modelContext
        self.syncEngine = syncEngine
    }

    var observedAtRange: ClosedRange<Date> {
        plant.acquiredAt ... Date.now
    }

    var canSave: Bool {
        observedAtRange.contains(observedAt) && observedAt != observation.createdAt
    }

    var isObservingInPast: Bool {
        observedAt.timeIntervalSinceNow < -60
    }

    func save() throws {
        guard observedAtRange.contains(observedAt) else { return }

        observation.createdAt = observedAt
        observation.updatedAt = .now
        plant.updatedAt = .now
        try modelContext.save()
        syncEngine.enqueueSync()
    }
}
