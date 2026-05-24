import Foundation

enum SyncStatus: String, Codable, CaseIterable {
    case localOnly = "local_only"
    case syncing = "syncing"
    case synced = "synced"
    case failed = "failed"
}

enum GrowthLogType: String, Codable, CaseIterable, Identifiable {
    case water
    case fertilize
    case tonic
    case repot
    case note
    case light

    var id: String { rawValue }

    var label: String {
        switch self {
        case .water: return "水やり"
        case .fertilize: return "施肥"
        case .tonic: return "活力剤"
        case .repot: return "植え替え"
        case .note: return "メモ"
        case .light: return "ライト変更"
        }
    }

    var systemImage: String {
        switch self {
        case .water: return "drop"
        case .fertilize: return "leaf"
        case .tonic: return "flask"
        case .repot: return "arrow.up.bin"
        case .note: return "doc.text"
        case .light: return "lightbulb"
        }
    }

    /// Quick Log シートのケア種別ボタン（メモのみは下の入力欄で記録）
    static let quickLogActionTypes: [GrowthLogType] = [
        .water, .fertilize, .tonic, .repot, .light
    ]
}

enum PlantCategory: String, Codable, CaseIterable, Identifiable {
    case agave = "アガベ"
    case caudex = "塊根"
    case platycerium = "ビカクシダ"
    case aroid = "アロイド"
    case other = "その他"

    var id: String { rawValue }
}

enum AppTab: String, CaseIterable, Identifiable {
    case collection
    case timeline
    case shoot
    case compare

    var id: String { rawValue }

    var label: String {
        switch self {
        case .collection: return "コレクション"
        case .timeline: return "タイムライン"
        case .shoot: return "観測"
        case .compare: return "比較"
        }
    }

    var systemImage: String {
        switch self {
        case .collection: return "square.grid.2x2"
        case .timeline: return "clock"
        case .shoot: return "camera"
        case .compare: return "square.split.2x1"
        }
    }
}

enum TimelapseJobStatus: String, Codable {
    case pending
    case processing
    case completed
    case failed
}

struct TimelapseJob: Codable, Identifiable {
    let id: String
    let status: TimelapseJobStatus
    let outputURL: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case outputURL = "outputURL"
        case error
    }
}

struct TimelapseCreateResponse: Codable {
    let jobId: String
}

struct PresignedUploadResponse: Codable {
    let uploadURL: String
    let objectKey: String
}

struct RemotePlant: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let name: String
    let species: String?
    let category: String?
    let acquiredAt: Date
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case species
        case category
        case acquiredAt = "acquired_at"
        case createdAt = "created_at"
    }
}

struct RemoteObservation: Codable, Identifiable {
    let id: UUID
    let plantId: UUID
    let imageUrl: String?
    let note: String?
    let createdAt: Date
    let syncStatus: String

    enum CodingKeys: String, CodingKey {
        case id
        case plantId = "plant_id"
        case imageUrl = "image_url"
        case note
        case createdAt = "created_at"
        case syncStatus = "sync_status"
    }
}

struct RemoteGrowthLog: Codable, Identifiable {
    let id: UUID
    let plantId: UUID
    let type: String
    let memo: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case plantId = "plant_id"
        case type
        case memo
        case createdAt = "created_at"
    }
}
