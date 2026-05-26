import Foundation
import SwiftData

@Model
final class Plant {
    @Attribute(.unique) var id: UUID
    var userId: UUID?
    var name: String
    var species: String
    var category: String
    var acquiredAt: Date
    /// 水やり間隔（日数）。nil の場合は頻度未設定。
    var wateringIntervalDays: Int?
    var note: String = ""
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \PlantObservation.plant)
    var observations: [PlantObservation]

    @Relationship(deleteRule: .cascade, inverse: \GrowthLog.plant)
    var growthLogs: [GrowthLog]

    init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        name: String,
        species: String = "",
        category: String = PlantCategory.other.rawValue,
        acquiredAt: Date = .now,
        wateringIntervalDays: Int? = nil,
        note: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        observations: [PlantObservation] = [],
        growthLogs: [GrowthLog] = []
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.species = species
        self.category = category
        self.acquiredAt = acquiredAt
        self.wateringIntervalDays = wateringIntervalDays
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.observations = observations
        self.growthLogs = growthLogs
    }

    var dayCount: Int {
        Calendar.current.dateComponents([.day], from: acquiredAt, to: .now).day ?? 0
    }

    var observationCount: Int { observations.count }

    var latestObservation: PlantObservation? {
        observations.sorted { $0.createdAt > $1.createdAt }.first
    }

    var aggregateSyncStatus: SyncStatus {
        let statuses = observations.map(\.syncStatus) + growthLogs.map(\.syncStatus)
        if statuses.contains(.failed) { return .failed }
        if statuses.contains(.syncPausedStorageLimit) { return .syncPausedStorageLimit }
        if statuses.contains(.syncing) { return .syncing }
        if statuses.contains(.localOnly) { return .localOnly }
        return statuses.isEmpty ? .synced : .synced
    }

    var lastWateredAt: Date {
        growthLogs.filter { $0.type == .water }.map(\.createdAt).max() ?? acquiredAt
    }

    var daysSinceLastWater: Int {
        let calendar = Calendar.current
        let startOfLastWater = calendar.startOfDay(for: lastWateredAt)
        let startOfToday = calendar.startOfDay(for: .now)
        return calendar.dateComponents([.day], from: startOfLastWater, to: startOfToday).day ?? 0
    }

    var needsWatering: Bool {
        guard let interval = wateringIntervalDays, interval > 0 else { return false }
        return daysSinceLastWater >= interval
    }

    /// コレクション並び替え用。値が大きいほど水やり優先。未設定は Int.min。
    var wateringSortPriority: Int {
        guard let interval = wateringIntervalDays, interval > 0 else { return Int.min }
        return daysSinceLastWater - interval
    }

    var wateringStatusLabel: String? {
        guard needsWatering else { return nil }
        let overdue = daysSinceLastWater - (wateringIntervalDays ?? 0)
        return overdue > 0 ? "\(overdue)日遅れ" : "水やり"
    }
}

@Model
final class PlantObservation {
    @Attribute(.unique) var id: UUID
    var plantId: UUID
    var localImagePath: String
    var thumbnailPath: String
    var remoteImageURL: String?
    var note: String
    var createdAt: Date
    var syncStatusRaw: String
    var updatedAt: Date

    var plant: Plant?

    init(
        id: UUID = UUID(),
        plantId: UUID,
        localImagePath: String,
        thumbnailPath: String = "",
        remoteImageURL: String? = nil,
        note: String = "",
        createdAt: Date = .now,
        syncStatus: SyncStatus = .localOnly,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.plantId = plantId
        self.localImagePath = localImagePath
        self.thumbnailPath = thumbnailPath
        self.remoteImageURL = remoteImageURL
        self.note = note
        self.createdAt = createdAt
        self.syncStatusRaw = syncStatus.rawValue
        self.updatedAt = updatedAt
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .localOnly }
        set { syncStatusRaw = newValue.rawValue }
    }
}

@Model
final class GrowthLog {
    @Attribute(.unique) var id: UUID
    var plantId: UUID
    var typeRaw: String
    var memo: String
    var createdAt: Date
    var syncStatusRaw: String
    var updatedAt: Date

    var plant: Plant?

    init(
        id: UUID = UUID(),
        plantId: UUID,
        type: GrowthLogType,
        memo: String = "",
        createdAt: Date = .now,
        syncStatus: SyncStatus = .localOnly,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.plantId = plantId
        self.typeRaw = type.rawValue
        self.memo = memo
        self.createdAt = createdAt
        self.syncStatusRaw = syncStatus.rawValue
        self.updatedAt = updatedAt
    }

    var type: GrowthLogType {
        get { GrowthLogType(rawValue: typeRaw) ?? .note }
        set { typeRaw = newValue.rawValue }
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .localOnly }
        set { syncStatusRaw = newValue.rawValue }
    }
}
