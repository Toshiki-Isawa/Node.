import Foundation
import SwiftData
import UIKit

@MainActor
final class AddPlantViewModel: ObservableObject {
    @Published var name = ""
    @Published var species = ""
    @Published var category = PlantCategory.other.rawValue
    @Published var acquiredAt = Date.now
    @Published var initialObservationAt = Date.now
    @Published var wateringIntervalDays: Int? = nil
    @Published var note = ""

    private let modelContext: ModelContext
    private let imageStore: ImageStore
    private let syncEngine: SyncEngine
    private let supabaseService: SupabaseService
    private let analyticsService: AnalyticsService

    init(
        modelContext: ModelContext,
        imageStore: ImageStore,
        syncEngine: SyncEngine,
        supabaseService: SupabaseService,
        analyticsService: AnalyticsService
    ) {
        self.modelContext = modelContext
        self.imageStore = imageStore
        self.syncEngine = syncEngine
        self.supabaseService = supabaseService
        self.analyticsService = analyticsService
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var initialObservationAtRange: ClosedRange<Date> {
        Date.distantPast ... Date.now
    }

    var acquiredAtRange: ClosedRange<Date> {
        Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1))! ... Date.now
    }

    func applyLibraryPhotoDate(_ date: Date?) {
        guard let date else { return }
        initialObservationAt = min(max(date, initialObservationAtRange.lowerBound), initialObservationAtRange.upperBound)
    }

    func save(initialImage: UIImage? = nil, useCustomObservationDate: Bool = false) throws -> Plant {
        let observationDate: Date
        if initialImage != nil, useCustomObservationDate {
            observationDate = min(
                max(initialObservationAt, initialObservationAtRange.lowerBound),
                initialObservationAtRange.upperBound
            )
        } else {
            observationDate = .now
        }

        var plantAcquiredAt = acquiredAt
        if initialImage != nil, observationDate < plantAcquiredAt {
            plantAcquiredAt = observationDate
        }

        let plant = Plant(
            userId: supabaseService.userId,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            species: species.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            acquiredAt: plantAcquiredAt,
            wateringIntervalDays: wateringIntervalDays,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        modelContext.insert(plant)

        if let initialImage {
            let observation = try createObservation(
                for: plant,
                image: initialImage,
                createdAt: observationDate
            )
            plant.observations.append(observation)
        }

        try modelContext.save()
        syncEngine.enqueueSync()
        analyticsService.capture(AnalyticsEvent.plantAdded, properties: [
            "has_initial_image": initialImage != nil,
            "has_watering_interval": wateringIntervalDays != nil,
        ])
        return plant
    }

    func createObservation(for plant: Plant, image: UIImage, createdAt: Date = .now) throws -> PlantObservation {
        let observationId = UUID()
        let path = try imageStore.saveOriginal(image, observationId: observationId)
        let thumbPath = try imageStore.generateThumbnail(from: image, observationId: observationId)
        let observation = PlantObservation(
            id: observationId,
            plantId: plant.id,
            localImagePath: path,
            thumbnailPath: thumbPath,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        observation.plant = plant
        modelContext.insert(observation)
        plant.updatedAt = .now
        return observation
    }
}
