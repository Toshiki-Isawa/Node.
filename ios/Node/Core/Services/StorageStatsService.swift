import Foundation
import SwiftData

struct LocalStorageBreakdown: Sendable {
    let originalsBytes: Int64
    let thumbnailsBytes: Int64
    let cacheBytes: Int64
    let databaseBytes: Int64

    var totalBytes: Int64 {
        originalsBytes + thumbnailsBytes + cacheBytes + databaseBytes
    }

    static let empty = LocalStorageBreakdown(
        originalsBytes: 0,
        thumbnailsBytes: 0,
        cacheBytes: 0,
        databaseBytes: 0
    )
}

struct SyncStatusBreakdown: Sendable {
    let synced: Int
    let localOnly: Int
    let syncing: Int
    let failed: Int
    let syncPausedStorageLimit: Int

    var total: Int {
        synced + localOnly + syncing + failed + syncPausedStorageLimit
    }

    var pending: Int {
        localOnly + failed + syncPausedStorageLimit
    }

    static let empty = SyncStatusBreakdown(
        synced: 0,
        localOnly: 0,
        syncing: 0,
        failed: 0,
        syncPausedStorageLimit: 0
    )
}

enum StorageStatsService {
    static func localBreakdown(imageStore: ImageStore) -> LocalStorageBreakdown {
        let originals = imageStore.directoryByteSize(for: .originals)
        let thumbnails = imageStore.directoryByteSize(for: .thumbnails)
        let cache = imageStore.directoryByteSize(for: .cache)
        let database = swiftDataStoreByteSize()
        return LocalStorageBreakdown(
            originalsBytes: originals,
            thumbnailsBytes: thumbnails,
            cacheBytes: cache,
            databaseBytes: database
        )
    }

    static func syncBreakdown(modelContext: ModelContext) -> SyncStatusBreakdown {
        let descriptor = FetchDescriptor<PlantObservation>()
        guard let observations = try? modelContext.fetch(descriptor) else {
            return .empty
        }

        var synced = 0
        var localOnly = 0
        var syncing = 0
        var failed = 0
        var syncPaused = 0

        for observation in observations {
            switch observation.syncStatus {
            case .synced: synced += 1
            case .localOnly: localOnly += 1
            case .syncing: syncing += 1
            case .failed: failed += 1
            case .syncPausedStorageLimit: syncPaused += 1
            }
        }

        return SyncStatusBreakdown(
            synced: synced,
            localOnly: localOnly,
            syncing: syncing,
            failed: failed,
            syncPausedStorageLimit: syncPaused
        )
    }

    private static func swiftDataStoreByteSize() -> Int64 {
        let fileManager = FileManager.default
        guard let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return 0
        }
        let directory = base.appendingPathComponent("Node", isDirectory: true)
        let storeNames = ["Node.store", "Node.store-wal", "Node.store-shm"]
        return storeNames.reduce(Int64(0)) { total, name in
            let url = directory.appendingPathComponent(name)
            guard fileManager.fileExists(atPath: url.path),
                  let attrs = try? fileManager.attributesOfItem(atPath: url.path),
                  let size = attrs[.size] as? Int64 else {
                return total
            }
            return total + size
        }
    }
}
