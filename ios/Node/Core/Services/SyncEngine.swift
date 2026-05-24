import Foundation
import Network
import SwiftData

@MainActor
final class SyncEngine: ObservableObject {
    private let modelContext: ModelContext
    private let imageStore: ImageStore
    private let supabaseService: SupabaseService
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "app.node.sync.monitor")
    private var isProcessing = false
    private var isOnline = true
    private var retryDelay: TimeInterval = 2

    init(
        modelContext: ModelContext,
        imageStore: ImageStore,
        supabaseService: SupabaseService
    ) {
        self.modelContext = modelContext
        self.imageStore = imageStore
        self.supabaseService = supabaseService
    }

    func start() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let online = path.status == .satisfied
                self?.isOnline = online
                if online {
                    await self?.processQueue()
                }
            }
        }
        pathMonitor.start(queue: monitorQueue)
        Task { await processQueue() }
    }

    func enqueueSync() {
        Task { await processQueue() }
    }

    func processQueue() async {
        guard isOnline, supabaseService.isAuthenticated, !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        await syncPlants()
        await syncObservations()
        await syncGrowthLogs()
    }

    private func syncPlants() async {
        let descriptor = FetchDescriptor<Plant>()
        guard let plants = try? modelContext.fetch(descriptor) else { return }
        for plant in plants {
            do {
                try await supabaseService.upsertPlant(plant)
            } catch {
                continue
            }
        }
    }

    private func syncObservations() async {
        let descriptor = FetchDescriptor<PlantObservation>()
        guard let observations = try? modelContext.fetch(descriptor) else { return }
        let pending = observations.filter {
            $0.syncStatus == .localOnly || $0.syncStatus == .failed
        }

        for observation in pending {
            observation.syncStatus = .syncing
            try? modelContext.save()

            do {
                if observation.remoteImageURL == nil {
                    let data = try imageStore.compressedData(for: observation.localImagePath)
                    let presigned = try await supabaseService.requestPresignedUpload(
                        observationId: observation.id
                    )
                    try await supabaseService.uploadToPresignedURL(data, uploadURL: presigned.uploadURL)
                    observation.remoteImageURL = presigned.objectKey
                }
                try await supabaseService.upsertObservation(observation)
                observation.syncStatus = .synced
                observation.updatedAt = .now
                try? modelContext.save()
                retryDelay = 2
            } catch {
                observation.syncStatus = .failed
                try? modelContext.save()
                retryDelay = min(retryDelay * 2, 60)
                try? await Task.sleep(for: .seconds(retryDelay))
            }
        }
    }

    private func syncGrowthLogs() async {
        let descriptor = FetchDescriptor<GrowthLog>()
        guard let logs = try? modelContext.fetch(descriptor) else { return }
        let pending = logs.filter {
            $0.syncStatus == .localOnly || $0.syncStatus == .failed
        }

        for log in pending {
            log.syncStatus = .syncing
            try? modelContext.save()
            do {
                try await supabaseService.upsertGrowthLog(log)
                log.syncStatus = .synced
                log.updatedAt = .now
                try? modelContext.save()
            } catch {
                log.syncStatus = .failed
                try? modelContext.save()
            }
        }
    }
}
