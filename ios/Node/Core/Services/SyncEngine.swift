import Foundation
import Network
import OSLog
import SwiftData

enum SyncError: LocalizedError {
    case notAuthenticated
    case storageLimitExceeded

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return String(localized: "サインインセッションがありません。")
        case .storageLimitExceeded:
            return String(localized: "クラウド容量の上限に達しました。")
        }
    }
}

@MainActor
final class SyncEngine: ObservableObject {
    private static let logger = Logger(subsystem: "app.node.ios", category: "SyncEngine")

    private let modelContext: ModelContext
    private let imageStore: ImageStore
    private let observationImageService: ObservationImageService
    private let supabaseService: SupabaseService
    private let planService: PlanService
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "app.node.sync.monitor")
    private var isProcessing = false
    private var isOnline = true
    private var retryDelay: TimeInterval = 2

    init(
        modelContext: ModelContext,
        imageStore: ImageStore,
        observationImageService: ObservationImageService,
        supabaseService: SupabaseService,
        planService: PlanService
    ) {
        self.modelContext = modelContext
        self.imageStore = imageStore
        self.observationImageService = observationImageService
        self.supabaseService = supabaseService
        self.planService = planService
    }

    func start() {
        guard ReleaseConfig.cloudSyncEnabled else { return }
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
        guard ReleaseConfig.cloudSyncEnabled else { return }
        Task { await processQueue() }
    }

    func processQueue() async {
        guard ReleaseConfig.cloudSyncEnabled else { return }
        guard isOnline, !isProcessing else { return }

        isProcessing = true
        defer { isProcessing = false }

        await supabaseService.refreshSession()
        guard supabaseService.isAuthenticated else { return }

        resetStaleSyncingRecords()
        evictSyncedOriginalBackfill()

        await planService.refresh()
        guard planService.isPaid else { return }

        await syncPlants()
        await syncObservations()
        await syncGrowthLogs()
    }

    /// アプリ再起動などで `.syncing` のまま残ったレコードを再試行可能にする
    private func resetStaleSyncingRecords() {
        let observationDescriptor = FetchDescriptor<PlantObservation>()
        let logDescriptor = FetchDescriptor<GrowthLog>()
        guard
            let observations = try? modelContext.fetch(observationDescriptor),
            let logs = try? modelContext.fetch(logDescriptor)
        else { return }

        var didChange = false
        for observation in observations where observation.syncStatus == .syncing {
            observation.syncStatus = .failed
            didChange = true
        }
        for log in logs where log.syncStatus == .syncing {
            log.syncStatus = .failed
            didChange = true
        }
        if didChange {
            try? modelContext.save()
        }
    }

    private func syncPlants() async {
        let descriptor = FetchDescriptor<Plant>()
        guard let plants = try? modelContext.fetch(descriptor) else { return }
        for plant in plants {
            do {
                try await supabaseService.upsertPlant(plant)
            } catch {
                Self.logger.error("Plant sync failed (\(plant.id.uuidString)): \(error.localizedDescription)")
            }
        }
    }

    private func syncObservations() async {
        let descriptor = FetchDescriptor<PlantObservation>()
        guard let observations = try? modelContext.fetch(descriptor) else { return }

        if planService.isCloudSyncPausedByStorage {
            pauseObservationsForStorageLimit(observations)
            return
        }

        let pending = observations.filter {
            switch $0.syncStatus {
            case .localOnly, .failed, .syncPausedStorageLimit:
                return true
            case .syncing, .synced:
                return false
            }
        }

        for observation in pending {
            observation.syncStatus = .syncing
            try? modelContext.save()

            do {
                try await uploadObservationImageIfNeeded(observation)
                try await supabaseService.upsertObservation(observation)
                observation.syncStatus = .synced
                observation.updatedAt = .now
                try modelContext.save()
                if observationImageService.evictLocalOriginalIfSynced(observation) {
                    try? modelContext.save()
                }
                await planService.refresh()
                retryDelay = 2
            } catch let error as SyncError {
                if case .storageLimitExceeded = error {
                    observation.syncStatus = .syncPausedStorageLimit
                    try? modelContext.save()
                    await planService.refresh()
                    Self.logger.warning(
                        "Observation sync paused by storage limit (\(observation.id.uuidString))"
                    )
                    break
                }
                observation.syncStatus = .failed
                try? modelContext.save()
                Self.logger.error(
                    "Observation sync failed (\(observation.id.uuidString)): \(error.localizedDescription)"
                )
                retryDelay = min(retryDelay * 2, 60)
                try? await Task.sleep(for: .seconds(retryDelay))
            } catch {
                observation.syncStatus = .failed
                try? modelContext.save()
                Self.logger.error(
                    "Observation sync failed (\(observation.id.uuidString)): \(error.localizedDescription)"
                )
                retryDelay = min(retryDelay * 2, 60)
                try? await Task.sleep(for: .seconds(retryDelay))
            }
        }
    }

    private func pauseObservationsForStorageLimit(_ observations: [PlantObservation]) {
        var didChange = false
        for observation in observations {
            switch observation.syncStatus {
            case .localOnly, .failed:
                observation.syncStatus = .syncPausedStorageLimit
                didChange = true
            case .syncing, .synced, .syncPausedStorageLimit:
                break
            }
        }
        if didChange {
            try? modelContext.save()
        }
    }

    private func uploadObservationImageIfNeeded(_ observation: PlantObservation) async throws {
        guard observation.remoteImageURL == nil else { return }

        if let existingKey = try await supabaseService.fetchStorageObjectKey(observationId: observation.id) {
            observation.remoteImageURL = existingKey
            return
        }

        guard let uploadPath = imageStore.resolveUploadPath(
            localImagePath: observation.localImagePath,
            thumbnailPath: observation.thumbnailPath
        ) else {
            throw ImageStoreError.imageNotFound
        }

        let uploadPayload = try imageStore.uploadPayload(
            for: uploadPath,
            premium: planService.allowsOriginalSync
        )
        let presigned = try await supabaseService.requestPresignedUpload(
            observationId: observation.id,
            contentType: uploadPayload.contentType,
            byteSize: uploadPayload.data.count
        )
        try await supabaseService.uploadToPresignedURL(
            uploadPayload.data,
            uploadURL: presigned.uploadURL,
            contentType: uploadPayload.contentType
        )
        try await supabaseService.registerStorageObject(
            observationId: observation.id,
            objectKey: presigned.objectKey,
            byteSize: uploadPayload.data.count,
            contentType: uploadPayload.contentType
        )
        observation.remoteImageURL = presigned.objectKey
    }

    private func evictSyncedOriginalBackfill() {
        let descriptor = FetchDescriptor<PlantObservation>()
        guard let observations = try? modelContext.fetch(descriptor) else { return }

        for observation in observations where observation.syncStatus == .synced {
            if observationImageService.evictLocalOriginalIfSynced(observation) {
                try? modelContext.save()
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
                Self.logger.error("Growth log sync failed (\(log.id.uuidString)): \(error.localizedDescription)")
            }
        }
    }
}