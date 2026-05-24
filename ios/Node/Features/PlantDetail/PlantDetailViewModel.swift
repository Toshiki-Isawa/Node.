import Foundation
import SwiftData

enum PlantDetailTimelineItem: Identifiable {
    case observation(PlantObservation)
    case growthLog(GrowthLog)

    var id: UUID {
        switch self {
        case .observation(let observation): observation.id
        case .growthLog(let log): log.id
        }
    }

    var createdAt: Date {
        switch self {
        case .observation(let observation): observation.createdAt
        case .growthLog(let log): log.createdAt
        }
    }
}

@MainActor
final class PlantDetailViewModel: ObservableObject {
    let plant: Plant

    init(plant: Plant) {
        self.plant = plant
    }

    var sortedObservations: [PlantObservation] {
        plant.observations.sorted { $0.createdAt > $1.createdAt }
    }

    var timelineItems: [PlantDetailTimelineItem] {
        let observations = plant.observations.map { PlantDetailTimelineItem.observation($0) }
        let logs = plant.growthLogs.map { PlantDetailTimelineItem.growthLog($0) }
        return (observations + logs).sorted { $0.createdAt > $1.createdAt }
    }

    var heroImagePath: String? {
        sortedObservations.first?.localImagePath
    }

    var waterLogCount: Int {
        plant.growthLogs.filter { $0.type == .water }.count
    }
}
