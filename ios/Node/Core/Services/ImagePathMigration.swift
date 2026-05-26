import Foundation
import SwiftData

enum ImagePathMigration {
    /// 旧データの絶対パスを Application Support からの相対パスへ正規化する。
    static func migrateStoredPathsIfNeeded(modelContext: ModelContext, imageStore: ImageStore) {
        guard let observations = try? modelContext.fetch(FetchDescriptor<PlantObservation>()) else {
            return
        }

        var didChange = false
        for observation in observations {
            if let normalized = imageStore.normalizeStoredPath(observation.localImagePath),
               normalized != observation.localImagePath {
                observation.localImagePath = normalized
                didChange = true
            }
            if let normalized = imageStore.normalizeStoredPath(observation.thumbnailPath),
               normalized != observation.thumbnailPath {
                observation.thumbnailPath = normalized
                didChange = true
            }
        }

        if didChange {
            try? modelContext.save()
        }
    }
}
