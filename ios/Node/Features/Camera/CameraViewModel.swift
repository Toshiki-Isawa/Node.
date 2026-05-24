import Foundation
import SwiftData
import UIKit

@MainActor
final class CameraViewModel: ObservableObject {
    @Published var selectedPlant: Plant?
    @Published var plants: [Plant] = []
    @Published var note = ""
    @Published var showFlash = false
    @Published var lastSavedAt: Date?
    @Published var errorMessage: String?

    private let modelContext: ModelContext
    private let imageStore: ImageStore
    private let syncEngine: SyncEngine

    init(modelContext: ModelContext, imageStore: ImageStore, syncEngine: SyncEngine) {
        self.modelContext = modelContext
        self.imageStore = imageStore
        self.syncEngine = syncEngine
        reloadPlants()
    }

    func reloadPlants() {
        let descriptor = FetchDescriptor<Plant>(sortBy: [SortDescriptor(\.name)])
        plants = (try? modelContext.fetch(descriptor)) ?? []
        if selectedPlant == nil {
            selectedPlant = plants.first
        }
    }

    func selectPlant(_ plant: Plant) {
        selectedPlant = plant
    }

    var previousObservationImagePath: String? {
        guard let plant = selectedPlant else { return nil }
        return plant.latestObservation?.localImagePath
    }

    func saveObservation(image: UIImage) async {
        guard let plant = selectedPlant else {
            errorMessage = "植物を選択してください。"
            return
        }

        showFlash = true
        try? await Task.sleep(for: .milliseconds(60))
        showFlash = false

        let observationId = UUID()

        do {
            let path = try await Task.detached(priority: .userInitiated) { [imageStore] in
                try imageStore.saveOriginal(image, observationId: observationId)
            }.value

            let thumbPath = try await Task.detached(priority: .utility) { [imageStore] in
                try imageStore.generateThumbnail(from: image, observationId: observationId)
            }.value

            let observation = PlantObservation(
                id: observationId,
                plantId: plant.id,
                localImagePath: path,
                thumbnailPath: thumbPath,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            observation.plant = plant
            plant.observations.append(observation)
            plant.updatedAt = .now
            modelContext.insert(observation)
            try modelContext.save()

            note = ""
            lastSavedAt = .now
            syncEngine.enqueueSync()
        } catch {
            errorMessage = "保存に失敗しました。"
        }
    }
}
