import Foundation

@MainActor
final class TimelapseService: ObservableObject {
    @Published private(set) var outputURL: URL?
    @Published private(set) var generationProgress: Double = 0
    @Published private(set) var isGenerating = false
    @Published var errorMessage: String?

    private let imageStore: ImageStore
    private let observationImageService: ObservationImageService

    init(imageStore: ImageStore, observationImageService: ObservationImageService) {
        self.imageStore = imageStore
        self.observationImageService = observationImageService
    }

    func generate(observations: [PlantObservation], maxLongEdge: CGFloat) async {
        let chronological = observations.sorted { $0.createdAt < $1.createdAt }
        let sampled = Self.sampleObservations(chronological, maxFrames: TimelapseVideoGenerator.maxFrames)

        guard sampled.count >= TimelapseRequirements.minimumObservations else {
            errorMessage = "タイムラプスには\(TimelapseRequirements.minimumObservations)回以上の観測が必要です。"
            return
        }

        discardOutput()
        isGenerating = true
        generationProgress = 0
        errorMessage = nil
        defer { isGenerating = false }

        var imagePaths: [String] = []
        imagePaths.reserveCapacity(sampled.count)

        do {
            for (index, observation) in sampled.enumerated() {
                let path = try await observationImageService.ensureOriginalPath(for: observation)
                imagePaths.append(path)
                generationProgress = Double(index + 1) / Double(sampled.count) * 0.2
            }
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        guard imagePaths.count >= TimelapseRequirements.minimumObservations else {
            errorMessage = "観測画像が端末上に見つかりません。"
            return
        }

        do {
            let url = try await TimelapseVideoGenerator.generate(
                imagePaths: imagePaths,
                imageStore: imageStore,
                maxLongEdge: maxLongEdge
            ) { [weak self] value in
                Task { @MainActor in
                    self?.generationProgress = 0.2 + value * 0.8
                }
            }
            outputURL = url
            generationProgress = 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func discardOutput() {
        if let url = outputURL {
            try? FileManager.default.removeItem(at: url)
        }
        outputURL = nil
        generationProgress = 0
    }

    func reset() {
        discardOutput()
        errorMessage = nil
    }

    // MARK: - Helpers

    private static func sampleObservations(
        _ observations: [PlantObservation],
        maxFrames: Int
    ) -> [PlantObservation] {
        guard observations.count > maxFrames else { return observations }
        guard maxFrames > 1 else { return [observations[0]] }

        return (0 ..< maxFrames).map { index in
            let position = Double(index) * Double(observations.count - 1) / Double(maxFrames - 1)
            return observations[Int(position.rounded())]
        }
    }
}
