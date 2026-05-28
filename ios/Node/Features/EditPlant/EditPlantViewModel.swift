import Foundation
import SwiftData

@MainActor
final class EditPlantViewModel: ObservableObject {
    @Published var name: String
    @Published var species: String
    @Published var acquiredAt: Date
    @Published var wateringIntervalDays: Int?
    @Published var note: String

    let plant: Plant

    private let modelContext: ModelContext
    private let syncEngine: SyncEngine
    private let recordDeletionService: RecordDeletionService
    private let analyticsService: AnalyticsService

    init(
        plant: Plant,
        modelContext: ModelContext,
        syncEngine: SyncEngine,
        recordDeletionService: RecordDeletionService,
        analyticsService: AnalyticsService
    ) {
        self.plant = plant
        self.modelContext = modelContext
        self.syncEngine = syncEngine
        self.recordDeletionService = recordDeletionService
        self.analyticsService = analyticsService
        self.name = plant.name
        self.species = plant.species
        self.acquiredAt = plant.acquiredAt
        self.wateringIntervalDays = plant.wateringIntervalDays
        self.note = plant.note
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
        plant.acquiredAt = acquiredAt
        plant.wateringIntervalDays = wateringIntervalDays
        plant.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        plant.updatedAt = .now
        try modelContext.save()
        syncEngine.enqueueSync()
        analyticsService.capture(AnalyticsEvent.plantEdited)
    }

    func delete() throws {
        let observationCount = plant.observations.count
        try recordDeletionService.deletePlant(plant)
        analyticsService.capture(AnalyticsEvent.plantDeleted, properties: [
            "observation_count": observationCount,
        ])
    }
}
