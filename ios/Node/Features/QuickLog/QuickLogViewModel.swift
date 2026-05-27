import Foundation
import SwiftData

@MainActor
final class QuickLogViewModel: ObservableObject {
    @Published var selectedTypes: Set<GrowthLogType> = []
    @Published var memo = ""
    @Published var recordedAt = Date.now

    let plant: Plant
    private let modelContext: ModelContext
    private let syncEngine: SyncEngine
    private let analyticsService: AnalyticsService

    init(
        plant: Plant,
        modelContext: ModelContext,
        syncEngine: SyncEngine,
        analyticsService: AnalyticsService
    ) {
        self.plant = plant
        self.modelContext = modelContext
        self.syncEngine = syncEngine
        self.analyticsService = analyticsService
    }

    var recordedAtRange: ClosedRange<Date> {
        plant.acquiredAt ... Date.now
    }

    var trimmedMemo: String {
        memo.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSave: Bool {
        recordedAtRange.contains(recordedAt) && (!selectedTypes.isEmpty || !trimmedMemo.isEmpty)
    }

    var isMemoOnly: Bool {
        selectedTypes.isEmpty && !trimmedMemo.isEmpty
    }

    var isRecordingInPast: Bool {
        recordedAt.timeIntervalSinceNow < -60
    }

    func resetToNow() {
        recordedAt = Date.now
    }

    func toggleType(_ type: GrowthLogType) {
        if selectedTypes.contains(type) {
            selectedTypes.remove(type)
        } else {
            selectedTypes.insert(type)
        }
    }

    func isSelected(_ type: GrowthLogType) -> Bool {
        selectedTypes.contains(type)
    }

    func save() throws {
        guard canSave else { return }

        let orderedTypes: [GrowthLogType]
        if selectedTypes.isEmpty {
            orderedTypes = [.note]
        } else {
            orderedTypes = GrowthLogType.quickLogActionTypes.filter { selectedTypes.contains($0) }
        }

        for type in orderedTypes {
            let log = GrowthLog(
                plantId: plant.id,
                type: type,
                memo: trimmedMemo,
                createdAt: recordedAt,
                updatedAt: recordedAt
            )
            log.plant = plant
            plant.growthLogs.append(log)
            modelContext.insert(log)
        }

        plant.updatedAt = .now
        try modelContext.save()
        syncEngine.enqueueSync()
        for type in orderedTypes {
            analyticsService.capture(AnalyticsEvent.quickLogAdded, properties: [
                "type": type.rawValue,
            ])
        }
    }
}
