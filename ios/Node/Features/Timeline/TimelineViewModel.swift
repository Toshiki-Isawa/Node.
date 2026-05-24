import Foundation
import SwiftData

enum TimelineContentFilter: String, CaseIterable, Identifiable {
    case all
    case observations
    case logs

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "すべて"
        case .observations: return "観測"
        case .logs: return "ログ"
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
    }

    @Published var filter: TimelineContentFilter = .all
    @Published private(set) var allItems: [TimelineEntry] = []

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        reload()
    }

    var items: [TimelineEntry] {
        switch filter {
        case .all:
            return allItems
        case .observations:
            return allItems.filter {
                if case .observation = $0 { return true }
                return false
            }
        case .logs:
            return allItems.filter {
                if case .growthLog = $0 { return true }
                return false
            }
        }
    }

    var emptyMessage: String {
        switch filter {
        case .all:
            return "まだ記録がありません。"
        case .observations:
            return "観測がまだありません。"
        case .logs:
            return "ログがまだありません。"
        }
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
    }
}
