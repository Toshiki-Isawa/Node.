import Foundation
import SwiftData

enum TimelineContentFilter: String, CaseIterable, Identifiable {
    case all
    case observations
    case logs

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return String(localized: "すべて")
        case .observations: return String(localized: "観測")
        case .logs: return String(localized: "ログ")
        }
    }
}

@MainActor
final class TimelineViewModel: ObservableObject {
    enum TimelineEntry: Identifiable {
        case observation(plant: Plant, observation: PlantObservation)
        case growthLog(plant: Plant, log: GrowthLog)

        var id: UUID {
            switch self {
            case .observation(_, let observation): observation.id
            case .growthLog(_, let log): log.id
            }
        }

        var createdAt: Date {
            switch self {
            case .observation(_, let observation): observation.createdAt
            case .growthLog(_, let log): log.createdAt
            }
        }

        var plantId: UUID {
            switch self {
            case .observation(let plant, _): plant.id
            case .growthLog(let plant, _): plant.id
            }
        }
    }

    @Published var filter: TimelineContentFilter = .all
    @Published var plantFilter: Plant? = nil
    @Published private(set) var allItems: [TimelineEntry] = []
    @Published private(set) var availablePlants: [Plant] = []

    private let modelContext: ModelContext
    private let recordDeletionService: RecordDeletionService

    init(modelContext: ModelContext, recordDeletionService: RecordDeletionService) {
        self.modelContext = modelContext
        self.recordDeletionService = recordDeletionService
        reload()
    }

    var items: [TimelineEntry] {
        allItems.filter { entry in
            if let plantFilter, entry.plantId != plantFilter.id { return false }
            switch filter {
            case .all:
                return true
            case .observations:
                if case .observation = entry { return true }
                return false
            case .logs:
                if case .growthLog = entry { return true }
                return false
            }
        }
    }

    var isAnyFilterActive: Bool {
        filter != .all || plantFilter != nil
    }

    var emptyMessage: String {
        if isAnyFilterActive {
            return String(localized: "条件に合う記録がありません。")
        }
        return String(localized: "まだ記録がありません。")
    }

    func resetFilters() {
        filter = .all
        plantFilter = nil
    }

    func reload() {
        let descriptor = FetchDescriptor<Plant>()
        let plants = (try? modelContext.fetch(descriptor)) ?? []

        let observations = plants.flatMap { plant in
            plant.observations.map { TimelineEntry.observation(plant: plant, observation: $0) }
        }
        let logs = plants.flatMap { plant in
            plant.growthLogs.map { TimelineEntry.growthLog(plant: plant, log: $0) }
        }

        allItems = (observations + logs).sorted { $0.createdAt > $1.createdAt }

        // sheet 用: 最終記録日時の新しい順。記録ゼロの株は plant.createdAt にフォールバックして末尾寄りに置く。
        availablePlants = plants.sorted { lhs, rhs in
            let l = lastActivity(for: lhs)
            let r = lastActivity(for: rhs)
            return l > r
        }

        // 削除等で現在の plantFilter 対象が消えた場合は解除
        if let current = plantFilter, !plants.contains(where: { $0.id == current.id }) {
            plantFilter = nil
        }
    }

    private func lastActivity(for plant: Plant) -> Date {
        let dates = plant.observations.map(\.createdAt) + plant.growthLogs.map(\.createdAt)
        return dates.max() ?? plant.createdAt
    }

    func delete(_ entry: TimelineEntry) throws {
        switch entry {
        case .observation(let plant, let observation):
            try recordDeletionService.deleteObservation(observation, from: plant)
        case .growthLog(let plant, let log):
            try recordDeletionService.deleteGrowthLog(log, from: plant)
        }
        reload()
    }

    func deleteTarget(for entry: TimelineEntry) -> DeleteRecordTarget {
        switch entry {
        case .observation(_, let observation):
            return .observation(observation)
        case .growthLog(_, let log):
            return .growthLog(log)
        }
    }
}
