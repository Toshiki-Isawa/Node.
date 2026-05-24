import Foundation
import SwiftData
import UIKit

@MainActor
final class AddPlantViewModel: ObservableObject {
    @Published var name = ""
    @Published var species = ""
    @Published var category = PlantCategory.other.rawValue
    @Published var acquiredAt = Date.now
    @Published var note = ""

    private let modelContext: ModelContext
    private let imageStore: ImageStore
    private let syncEngine: SyncEngine
    private let supabaseService: SupabaseService

    init(
        modelContext: ModelContext,
        imageStore: ImageStore,
        syncEngine: SyncEngine,
        supabaseService: SupabaseService
    ) {
        self.modelContext = modelContext
        self.imageStore = imageStore
        self.syncEngine = syncEngine
        self.supabaseService = supabaseService
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func save(initialImage: UIImage? = nil) throws -> Plant {
        let plant = Plant(
            userId: supabaseService.userId,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            species: species.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            acquiredAt: acquiredAt
        )
        modelContext.insert(plant)

        if let initialImage {
            let observation = try createObservation(for: plant, image: initialImage)
            plant.observations.append(observation)
        }

        try modelContext.save()
        syncEngine.enqueueSync()
        return plant
    }

    func createObservation(for plant: Plant, image: UIImage) throws -> PlantObservation {
        let observationId = UUID()
        let path = try imageStore.saveOriginal(image, observationId: observationId)
        let thumbPath = try imageStore.generateThumbnail(from: image, observationId: observationId)
        let observation = PlantObservation(
            id: observationId,
            plantId: plant.id,
            localImagePath: path,
            thumbnailPath: thumbPath
        )
        observation.plant = plant
        modelContext.insert(observation)
        plant.updatedAt = .now
        return observation
    }
}
