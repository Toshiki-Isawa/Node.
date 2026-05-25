import Foundation

@MainActor
final class CompareViewModel: ObservableObject {
    @Published var plant: Plant?
    @Published var beforeIndex: Int = 0
    @Published var afterIndex: Int = 0
    @Published private(set) var beforeImagePath: String?
    @Published private(set) var afterImagePath: String?
    @Published private(set) var isLoadingImages = false
    @Published var imageLoadError: String?

    private let observationImageService: ObservationImageService

    init(observationImageService: ObservationImageService) {
        self.observationImageService = observationImageService
    }

    var sortedObservations: [PlantObservation] {
        guard let plant else { return [] }
        return plant.observations.sorted { $0.createdAt < $1.createdAt }
    }

    var beforeObservation: PlantObservation? {
        guard !sortedObservations.isEmpty else { return nil }
        let index = min(beforeIndex, sortedObservations.count - 1)
        return sortedObservations[index]
    }

    var afterObservation: PlantObservation? {
        guard !sortedObservations.isEmpty else { return nil }
        let index = min(max(afterIndex, beforeIndex), sortedObservations.count - 1)
        return sortedObservations[index]
    }

    func configure(plant: Plant?) {
        self.plant = plant
        let count = plant?.observations.count ?? 0
        beforeIndex = 0
        afterIndex = max(0, count - 1)
        Task { await loadComparisonImages() }
    }

    func loadComparisonImages() async {
        guard let before = beforeObservation, let after = afterObservation else {
            beforeImagePath = nil
            afterImagePath = nil
            return
        }

        isLoadingImages = true
        imageLoadError = nil
        defer { isLoadingImages = false }

        do {
            async let beforePath = observationImageService.ensureOriginalPath(for: before)
            async let afterPath = observationImageService.ensureOriginalPath(for: after)
            beforeImagePath = try await beforePath
            afterImagePath = try await afterPath
        } catch {
            beforeImagePath = nil
            afterImagePath = nil
            imageLoadError = error.localizedDescription
        }
    }

    var intervalDays: Int {
        guard let before = beforeObservation, let after = afterObservation else { return 0 }
        return Calendar.current.dateComponents([.day], from: before.createdAt, to: after.createdAt).day ?? 0
    }

    var waterLogCount: Int {
        plant?.growthLogs.filter { $0.type == .water }.count ?? 0
    }

    func setScrubProgress(_ progress: Double) {
        let count = sortedObservations.count
        guard count > 1 else { return }
        afterIndex = Int(round(progress * Double(count - 1)))
        if afterIndex <= beforeIndex {
            afterIndex = min(beforeIndex + 1, count - 1)
        }
    }

    var scrubProgress: Double {
        let count = sortedObservations.count
        guard count > 1 else { return 1 }
        return Double(afterIndex) / Double(count - 1)
    }
}
