import Foundation
import SwiftData

@MainActor
final class EditGrowthLogViewModel: ObservableObject {
    let plant: Plant
    let log: GrowthLog

    @Published var recordedAt: Date
    @Published var memo: String

    private let modelContext: ModelContext
    private let syncEngine: SyncEngine

    init(
        plant: Plant,
        log: GrowthLog,
        modelContext: ModelContext,
        syncEngine: SyncEngine
    ) {
        self.plant = plant
        self.log = log
        self.recordedAt = log.createdAt
        self.memo = log.memo
        self.modelContext = modelContext
        self.syncEngine = syncEngine
    }

    var recordedAtRange: ClosedRange<Date> {
        plant.acquiredAt ... Date.now
    }

    var trimmedMemo: String {
        memo.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSave: Bool {
        recordedAtRange.contains(recordedAt)
            && (recordedAt != log.createdAt || trimmedMemo != log.memo)
    }

    var isRecordingInPast: Bool {
        recordedAt.timeIntervalSinceNow < -60
    }

    func save() throws {
        guard recordedAtRange.contains(recordedAt) else { return }

        log.createdAt = recordedAt
        log.memo = trimmedMemo
        log.updatedAt = .now
        plant.updatedAt = .now
        try modelContext.save()
        syncEngine.enqueueSync()
    }
}
