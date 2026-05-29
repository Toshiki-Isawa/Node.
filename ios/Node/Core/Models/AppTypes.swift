import Foundation

enum SyncStatus: String, Codable, CaseIterable {
    case localOnly = "local_only"
    case syncing = "syncing"
    case synced = "synced"
    case failed = "failed"
    case syncPausedStorageLimit = "sync_paused_storage_limit"

    var label: String {
        switch self {
        case .localOnly: return String(localized: "ローカル")
        case .syncing: return String(localized: "同期中")
        case .synced: return String(localized: "同期済み")
        case .failed: return String(localized: "失敗")
        case .syncPausedStorageLimit: return String(localized: "容量上限")
        }
    }
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
        case .water: return String(localized: "水やり")
        case .fertilize: return String(localized: "施肥")
        case .tonic: return String(localized: "活力剤")
        case .repot: return String(localized: "植え替え")
        case .note: return String(localized: "メモ")
        case .light: return String(localized: "ライト変更")
        }
    }

    var systemImage: String {
        switch self {
        case .water: return "drop"
        case .fertilize: return "sparkles"
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

/// 一括クイックログの起動元。初期選択のプリセットに使う。
enum BulkQuickLogContext {
    /// Collection ヘッダーの一括ボタン
    case general
    /// 「今日の水やり」バナー
    case wateringReminder
}

enum WateringInterval: Int, CaseIterable, Identifiable {
    case threeDays = 3
    case weekly = 7
    case biweekly = 14
    case threeWeeks = 21
    case monthly = 30

    var id: Int { rawValue }

    var label: String { String(localized: "\(rawValue)日") }

    static func isPreset(_ days: Int) -> Bool {
        allCases.contains { $0.rawValue == days }
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case collection
    case timeline
    case shoot

    var id: String { rawValue }

    /// タブバー表示順（観測ボタンを中央に配置）
    static var tabBarItems: [AppTab] {
        [.collection, .shoot, .timeline]
    }

    var label: String {
        switch self {
        case .collection: return String(localized: "コレクション")
        case .timeline: return String(localized: "タイムライン")
        case .shoot: return String(localized: "観測")
        }
    }

    var systemImage: String {
        switch self {
        case .collection: return "square.grid.2x2"
        case .timeline: return "clock"
        case .shoot: return "camera"
        }
    }
}

enum AppNavigationRoute: Hashable {
    case plant(UUID)
    case compare(UUID)
    case observation(UUID)
}

enum TimelapseRequirements {
    static let minimumObservations = 5
    /// 動画の長さ（秒）の下限
    static let minimumDurationSeconds: Double = 3
    /// 動画の長さ（秒）の上限
    static let maximumDurationSeconds: Double = 60
    static let defaultDurationSeconds: Double = 15
    /// Instagram / TikTok 向け縦長（9:16）
    static let aspectRatioWidth: CGFloat = 9
    static let aspectRatioHeight: CGFloat = 16
}

struct PresignedUploadResponse: Codable {
    let uploadURL: String
    let objectKey: String
}

struct PresignedDownloadResponse: Codable {
    let downloadURL: String
    let objectKey: String
    let expiresIn: Int?
}

struct RemotePlant: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let name: String
    let species: String?
    let acquiredAt: Date
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case species
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
