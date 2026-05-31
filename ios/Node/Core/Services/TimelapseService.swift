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

    func generate(
        observations: [PlantObservation],
        firstIndex: Int,
        lastIndex: Int,
        excludedObservationIDs: Set<UUID> = [],
        durationSeconds: Double,
        maxLongEdge: CGFloat,
        overlay: TimelapseVideoOverlayInfo
    ) async {
        let chronological = observations.sorted { $0.createdAt < $1.createdAt }
        guard firstIndex >= 0, lastIndex < chronological.count, firstIndex <= lastIndex else {
            errorMessage = String(localized: "観測範囲が不正です。")
            return
        }

        let ranged = Array(chronological[firstIndex...lastIndex])
            .filter { !excludedObservationIDs.contains($0.id) }
        let sampled = Self.sampleObservations(ranged, maxFrames: TimelapseVideoGenerator.maxFrames)

        guard sampled.count >= TimelapseRequirements.minimumObservations else {
            errorMessage = String(localized: "選択範囲には\(TimelapseRequirements.minimumObservations)回以上の観測が必要です。")
            return
        }

        let clampedDuration = min(
            max(durationSeconds, TimelapseRequirements.minimumDurationSeconds),
            TimelapseRequirements.maximumDurationSeconds
        )
        let secondsPerFrame = clampedDuration / Double(sampled.count)

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
            errorMessage = String(localized: "観測画像が端末上に見つかりません。")
            return
        }

        do {
            let outputSize = TimelapseVideoGenerator.outputSize(maxLongEdge: maxLongEdge)
            let overlayImage = TimelapseShareOverlayRenderer.render(info: overlay, size: outputSize)

            let url = try await TimelapseVideoGenerator.generate(
                imagePaths: imagePaths,
                imageStore: imageStore,
                maxLongEdge: maxLongEdge,
                secondsPerFrame: secondsPerFrame,
                overlay: overlayImage
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
