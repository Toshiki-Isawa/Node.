import Foundation
import SwiftData
import UIKit

enum CameraCaptureMode: String, CaseIterable, Identifiable {
    case single
    case continuous

    var id: String { rawValue }

    var label: String {
        switch self {
        case .single: return String(localized: "シングル")
        case .continuous: return String(localized: "連続")
        }
    }

    var systemImage: String {
        switch self {
        case .single: return "1.circle"
        case .continuous: return "square.stack.3d.up.fill"
        }
    }
}

@MainActor
final class CameraViewModel: ObservableObject {
    @Published var selectedPlant: Plant?
    @Published var plants: [Plant] = []
    @Published var note = ""
    @Published var observedAt = Date.now
    @Published private(set) var pendingLibraryImage: UIImage?
    @Published var showFlash = false
    @Published var lastSavedAt: Date?
    @Published var errorMessage: String?
    @Published var captureMode: CameraCaptureMode = .single
    @Published private(set) var capturePhase: CameraCapturePhase = .idle
    @Published private(set) var sessionSaveCount = 0

    enum CameraCapturePhase: Equatable {
        case idle
        case capturing
        case saving

        var statusText: String {
            switch self {
            case .idle: return ""
            case .capturing: return String(localized: "撮影中...")
            case .saving: return String(localized: "保存中...")
            }
        }
    }

    var isBusy: Bool { capturePhase != .idle }

    private let modelContext: ModelContext
    private let imageStore: ImageStore
    private let observationImageService: ObservationImageService
    private let syncEngine: SyncEngine
    private let analyticsService: AnalyticsService
    private let reviewPromptService: ReviewPromptService

    init(
        modelContext: ModelContext,
        imageStore: ImageStore,
        observationImageService: ObservationImageService,
        syncEngine: SyncEngine,
        analyticsService: AnalyticsService,
        reviewPromptService: ReviewPromptService
    ) {
        self.modelContext = modelContext
        self.imageStore = imageStore
        self.observationImageService = observationImageService
        self.syncEngine = syncEngine
        self.analyticsService = analyticsService
        self.reviewPromptService = reviewPromptService
        reloadPlants()
    }

    func reloadPlants() {
        let descriptor = FetchDescriptor<Plant>(sortBy: [SortDescriptor(\.name)])
        plants = (try? modelContext.fetch(descriptor)) ?? []
        if selectedPlant == nil {
            selectedPlant = plants.first
        }
        clampObservedAt()
    }

    func selectPlant(_ plant: Plant) {
        selectedPlant = plant
        clampObservedAt()
    }

    func prepareForSession() {
        captureMode = .single
        sessionSaveCount = 0
        observedAt = .now
        pendingLibraryImage = nil
        errorMessage = nil
        resetCaptureState()
    }

    func setCapturePhase(_ phase: CameraCapturePhase) {
        capturePhase = phase
    }

    func resetCaptureState() {
        capturePhase = .idle
    }

    var captureModeHint: String {
        switch captureMode {
        case .single:
            return String(localized: "1枚で終了")
        case .continuous:
            return sessionSaveCount > 0
                ? String(localized: "連続 · \(sessionSaveCount)枚")
                : String(localized: "連続撮影")
        }
    }

    var previousObservationImagePath: String? {
        guard let plant = selectedPlant,
              let observation = plant.latestObservation else { return nil }
        if imageStore.fileExists(at: observation.localImagePath) {
            return observation.localImagePath
        }
        return observationImageService.displayThumbnailPath(for: observation)
    }

    var observedAtRange: ClosedRange<Date> {
        guard let plant = selectedPlant else {
            let now = Date.now
            return now ... now
        }
        return plant.acquiredAt ... Date.now
    }

    /// ライブラリ取り込み用。撮影日が取得日より前でも任意に選べるよう下限を緩める。
    var libraryObservedAtRange: ClosedRange<Date> {
        let floor = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? Date.distantPast
        return floor ... Date.now
    }

    var isObservingInPast: Bool {
        observedAt.timeIntervalSinceNow < -60
    }

    func resetObservedAtToNow() {
        observedAt = .now
    }

    func applyLibraryPhotoDate(_ date: Date?) {
        guard let date else { return }
        let range = libraryObservedAtRange
        observedAt = min(max(date, range.lowerBound), range.upperBound)
    }

    func stageLibraryImport(image: UIImage, creationDate: Date?) {
        pendingLibraryImage = image
        observedAt = .now
        applyLibraryPhotoDate(creationDate)
    }

    func cancelLibraryImport() {
        pendingLibraryImage = nil
        observedAt = .now
    }

    @discardableResult
    func savePendingLibraryImport() async -> Bool {
        guard let image = pendingLibraryImage else { return false }
        // 撮影日が取得日より前なら取得日を遡らせて整合性を保つ
        if let plant = selectedPlant, observedAt < plant.acquiredAt {
            plant.acquiredAt = observedAt
        }
        let saved = await saveObservation(image: image, observedAt: observedAt)
        if saved {
            pendingLibraryImage = nil
        }
        return saved
    }

    func clampObservedAt(to preferred: Date? = nil) {
        let range = observedAtRange
        guard range.lowerBound <= range.upperBound else { return }
        let candidate = preferred ?? observedAt
        observedAt = min(max(candidate, range.lowerBound), range.upperBound)
    }

    @discardableResult
    func saveObservation(
        image: UIImage,
        observedAt: Date = .now,
        preprocessForStorage: Bool = true
    ) async -> Bool {
        guard !Task.isCancelled else { return false }
        guard let plant = selectedPlant else {
            errorMessage = String(localized: "植物を選択してください。")
            return false
        }

        guard observedAtRange.contains(observedAt) else {
            errorMessage = String(localized: "観測日時が不正です。")
            return false
        }

        showFlash = true
        try? await Task.sleep(for: .milliseconds(60))
        showFlash = false

        guard !Task.isCancelled else { return false }

        let observationId = UUID()
        let preparedImage = preprocessForStorage
            ? ObservationImageProcessor.prepareImportedPhoto(
                image,
                aspectRatio: CameraFrameLayout.currentAspectRatio
            )
            : image

        do {
            let path = try await Task.detached(priority: .userInitiated) { [imageStore] in
                try imageStore.saveOriginal(preparedImage, observationId: observationId)
            }.value

            guard !Task.isCancelled else { return false }

            let thumbPath = try await Task.detached(priority: .utility) { [imageStore] in
                try imageStore.generateThumbnail(from: preparedImage, observationId: observationId)
            }.value

            guard !Task.isCancelled else { return false }

            let observation = PlantObservation(
                id: observationId,
                plantId: plant.id,
                localImagePath: path,
                thumbnailPath: thumbPath,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                createdAt: observedAt,
                updatedAt: observedAt
            )
            observation.plant = plant
            plant.observations.append(observation)
            plant.updatedAt = .now
            modelContext.insert(observation)
            try modelContext.save()

            note = ""
            lastSavedAt = observedAt
            sessionSaveCount += 1
            syncEngine.enqueueSync()
            analyticsService.capture(AnalyticsEvent.observationCaptured, properties: [
                "seq": plant.observations.count,
                "is_first_for_plant": plant.observations.count == 1,
            ])
            reviewPromptService.signalEligibleEvent(.observationCaptured)
            return true
        } catch {
            errorMessage = String(localized: "保存に失敗しました。")
            return false
        }
    }
}
