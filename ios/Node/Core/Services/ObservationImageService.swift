import Foundation

enum ObservationImageError: LocalizedError {
    case remoteImageUnavailable
    case downloadFailed
    case notAuthenticated
    case networkRequired

    var errorDescription: String? {
        switch self {
        case .remoteImageUnavailable:
            return "クラウド上の画像が見つかりません。"
        case .downloadFailed:
            return "画像の取得に失敗しました。"
        case .notAuthenticated:
            return "サインインが必要です。"
        case .networkRequired:
            return "ネットワーク接続が必要です。"
        }
    }
}

@MainActor
final class ObservationImageService {
    private let imageStore: ImageStore
    private let supabaseService: SupabaseService

    init(imageStore: ImageStore, supabaseService: SupabaseService) {
        self.imageStore = imageStore
        self.supabaseService = supabaseService
    }

    func displayThumbnailPath(for observation: PlantObservation) -> String? {
        if imageStore.fileExists(at: observation.thumbnailPath) {
            return observation.thumbnailPath
        }
        if imageStore.fileExists(at: observation.localImagePath) {
            return observation.localImagePath
        }
        return nil
    }

    @discardableResult
    func evictLocalOriginalIfSynced(_ observation: PlantObservation) -> Bool {
        guard observation.syncStatus == .synced,
              observation.remoteImageURL != nil,
              !observation.localImagePath.isEmpty,
              imageStore.fileExists(at: observation.localImagePath)
        else {
            return false
        }

        imageStore.deleteOriginal(at: observation.localImagePath)
        observation.localImagePath = ""
        return true
    }

    func ensureOriginalPath(for observation: PlantObservation) async throws -> String {
        if imageStore.fileExists(at: observation.localImagePath) {
            return observation.localImagePath
        }

        let cachedPath = imageStore.cachePath(for: observation.id)
        if imageStore.fileExists(at: cachedPath) {
            return cachedPath
        }

        guard supabaseService.isAuthenticated else {
            throw ObservationImageError.notAuthenticated
        }
        guard observation.remoteImageURL != nil else {
            throw ObservationImageError.remoteImageUnavailable
        }

        let presigned = try await supabaseService.requestPresignedDownload(observationId: observation.id)
        let data = try await supabaseService.downloadFromPresignedURL(presigned.downloadURL)
        return try imageStore.saveCachedOriginal(data, observationId: observation.id)
    }

    func deleteCache(for observationId: UUID) {
        imageStore.deleteCachedOriginal(for: observationId)
    }
}
