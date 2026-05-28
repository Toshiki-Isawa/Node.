import Foundation
import SwiftData

enum DeleteRecordTarget: Identifiable {
    case observation(PlantObservation)
    case growthLog(GrowthLog)

    var id: UUID {
        switch self {
        case .observation(let observation): observation.id
        case .growthLog(let log): log.id
        }
    }

    var title: String {
        switch self {
        case .observation: return String(localized: "観測を削除")
        case .growthLog: return String(localized: "ログを削除")
        }
    }

    var message: String {
        switch self {
        case .observation:
            return String(localized: "この観測記録を削除します。写真も端末から削除され、元に戻せません。")
        case .growthLog:
            return String(localized: "このログを削除します。元に戻せません。")
        }
    }
}

@MainActor
final class RecordDeletionService {
    private let modelContext: ModelContext
    private let imageStore: ImageStore
    private let observationImageService: ObservationImageService
    private let supabaseService: SupabaseService

    init(
        modelContext: ModelContext,
        imageStore: ImageStore,
        observationImageService: ObservationImageService,
        supabaseService: SupabaseService
    ) {
        self.modelContext = modelContext
        self.imageStore = imageStore
        self.observationImageService = observationImageService
        self.supabaseService = supabaseService
    }

    func deleteObservation(_ observation: PlantObservation, from plant: Plant) throws {
        let observationId = observation.id
        let shouldDeleteRemote = observation.syncStatus == .synced

        imageStore.deleteObservationFiles(observation)
        plant.observations.removeAll { $0.id == observation.id }
        modelContext.delete(observation)
        plant.updatedAt = .now
        try modelContext.save()

        if shouldDeleteRemote {
            Task { try? await supabaseService.deleteObservation(id: observationId) }
        }
    }

    func deleteGrowthLog(_ log: GrowthLog, from plant: Plant) throws {
        let logId = log.id
        let shouldDeleteRemote = log.syncStatus == .synced

        plant.growthLogs.removeAll { $0.id == log.id }
        modelContext.delete(log)
        plant.updatedAt = .now
        try modelContext.save()

        if shouldDeleteRemote {
            Task { try? await supabaseService.deleteGrowthLog(id: logId) }
        }
    }

    func deletePlant(_ plant: Plant) throws {
        let plantId = plant.id
        let shouldDeleteRemote = ReleaseConfig.cloudSyncEnabled && supabaseService.isAuthenticated

        for observation in plant.observations {
            imageStore.deleteObservationFiles(observation)
        }

        modelContext.delete(plant)
        try modelContext.save()

        if shouldDeleteRemote {
            Task { try? await supabaseService.deletePlant(id: plantId) }
        }
    }
}
