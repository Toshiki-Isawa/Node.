import AVKit
import Photos
import SwiftUI

struct TimelapseView: View {
    @ObservedObject var viewModel: PlantDetailViewModel
    @ObservedObject var timelapseService: TimelapseService
    @ObservedObject var planService: PlanService
    @StateObject private var rangePicker: CompareViewModel
    let imageStore: ImageStore
    @Environment(\.dismiss) private var dismiss

    @State private var durationSeconds = TimelapseRequirements.defaultDurationSeconds
    @State private var isSavingToPhotos = false
    @State private var saveMessage: String?
    @State private var excludedObservationIDs: Set<UUID> = []

    init(
        viewModel: PlantDetailViewModel,
        timelapseService: TimelapseService,
        planService: PlanService,
        observationImageService: ObservationImageService,
        imageStore: ImageStore
    ) {
        self.viewModel = viewModel
        self.timelapseService = timelapseService
        self.planService = planService
        self.imageStore = imageStore
        _rangePicker = StateObject(
            wrappedValue: CompareViewModel(observationImageService: observationImageService)
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NodeColor.graphite.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: NodeSpacing.sp6) {
                        MetaLabel(text: "\(viewModel.plant.name)", size: 9)
                        Text("タイムラプス")
                            .font(NodeFont.display(NodeFont.title1, weight: .light))
                            .foregroundStyle(NodeColor.bone)

                        if !timelapseService.isGenerating && timelapseService.outputURL == nil {
                            frameSelectionSection
                        }

                        content

                        if let error = timelapseService.errorMessage {
                            MetaLabel(text: "\(error)", color: NodeColor.syncFail)
                        }

                        if let saveMessage {
                            MetaLabel(text: "\(saveMessage)", color: NodeColor.mossSoft)
                        }

                        MetaLabel(
                            text: "\(planService.plan.timelapseQualityLabel) · 9:16 · 端末内生成 · 最大\(TimelapseVideoGenerator.maxFrames)フレーム",
                            color: NodeColor.fog
                        )
                    }
                    .padding(NodeSpacing.sp6)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        timelapseService.reset()
                        dismiss()
                    }
                    .foregroundStyle(NodeColor.fog)
                }
            }
        }
        .onAppear {
            rangePicker.configureForTimelapse(plant: viewModel.plant)
        }
        .onChange(of: rangePicker.comparisonSelectionKey) { _, _ in
            pruneExcludedObservations()
        }
        .onDisappear { timelapseService.discardOutput() }
        .sheet(item: $rangePicker.activeCalendarSide) { side in
            calendarSheet(for: side)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.plant.observations.count < TimelapseRequirements.minimumObservations {
            requirementCard
        } else if timelapseService.isGenerating {
            generatingCard
        } else if let url = timelapseService.outputURL {
            completedCard(url: url)
        } else {
            configurationCard
        }
    }

    private var configurationCard: some View {
        VStack(spacing: NodeSpacing.sp4) {
            rangeSelectionCard
            durationCard

            if includedObservationCount < TimelapseRequirements.minimumObservations {
                MetaLabel(
                    text: "選択範囲には\(TimelapseRequirements.minimumObservations)回以上の観測が必要です。",
                    color: NodeColor.syncFail
                )
            }

            NodePrimaryButton("タイムラプスを生成") {
                Task { await generateTimelapse() }
            }
            .disabled(includedObservationCount < TimelapseRequirements.minimumObservations)
        }
    }

    private var rangeSelectionCard: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp3) {
            MetaLabel(text: "観測範囲", size: 9)

            HStack(spacing: NodeSpacing.sp3) {
                rangeEndpointButton(side: .before, label: "開始")
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NodeColor.moss)
                rangeEndpointButton(side: .after, label: "終了")
            }

            if let before = rangePicker.beforeObservation, let after = rangePicker.afterObservation {
                HStack(spacing: 4) {
                    CultivationDayLabel(
                        count: rangePicker.observationDayNumber(before),
                        labelFont: NodeFont.mono(9.5),
                        numberFont: NodeFont.display(22, weight: .light),
                        labelColor: NodeColor.mist,
                        numberColor: NodeColor.bone,
                        spacing: 4
                    )
                    Text("→")
                        .foregroundStyle(NodeColor.moss)
                    CultivationDayLabel(
                        count: rangePicker.observationDayNumber(after),
                        labelFont: NodeFont.mono(9.5),
                        numberFont: NodeFont.display(22, weight: .light),
                        labelColor: NodeColor.mist,
                        numberColor: NodeColor.bone,
                        spacing: 4
                    )
                }

                MetaLabel(
                    text: rangeSummaryText,
                    color: NodeColor.fog,
                    size: 9
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(NodeSpacing.sp4)
        .background(NodeColor.charcoal)
        .clipShape(RoundedRectangle(cornerRadius: NodeRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: NodeRadius.lg)
                .stroke(NodeColor.hairline, lineWidth: 1)
        )
    }

    private func rangeEndpointButton(side: CompareSide, label: LocalizedStringKey) -> some View {
        Button {
            rangePicker.openCalendar(for: side)
        } label: {
            VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
                MetaLabel(text: label, size: 9)

                if let observation = side == .before ? rangePicker.beforeObservation : rangePicker.afterObservation {
                    ObservationThumbnail(
                        imagePath: viewModel.displayThumbnailPath(for: observation),
                        imageStore: imageStore,
                        size: 52
                    )

                    Text(observation.createdAt.nodeMonthDay())
                        .font(NodeFont.text(NodeFont.caption, weight: .medium))
                        .foregroundStyle(NodeColor.bone)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(NodeSpacing.sp3)
            .background(NodeColor.void)
            .clipShape(RoundedRectangle(cornerRadius: NodeRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: NodeRadius.md)
                    .stroke(NodeColor.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var durationCard: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp3) {
            HStack {
                MetaLabel(text: "動画の長さ", size: 9)
                Spacer()
                Text("\(Int(durationSeconds))秒")
                    .font(NodeFont.text(NodeFont.callout, weight: .medium))
                    .foregroundStyle(NodeColor.bone)
            }

            Slider(
                value: $durationSeconds,
                in: TimelapseRequirements.minimumDurationSeconds...TimelapseRequirements.maximumDurationSeconds,
                step: 1
            )
            .tint(NodeColor.moss)

            HStack {
                MetaLabel(
                    text: "\(Int(TimelapseRequirements.minimumDurationSeconds))秒",
                    color: NodeColor.fog,
                    size: 9
                )
                Spacer()
                MetaLabel(
                    text: "\(Int(TimelapseRequirements.maximumDurationSeconds))秒",
                    color: NodeColor.fog,
                    size: 9
                )
            }

            MetaLabel(
                text: durationSummaryText,
                color: NodeColor.fog,
                size: 9
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(NodeSpacing.sp4)
        .background(NodeColor.charcoal)
        .clipShape(RoundedRectangle(cornerRadius: NodeRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: NodeRadius.lg)
                .stroke(NodeColor.hairline, lineWidth: 1)
        )
    }

    private var durationSummaryText: LocalizedStringKey {
        let frameCount = max(estimatedFrameCount, 1)
        let secondsPerFrame = durationSeconds / Double(frameCount)
        let formatted = secondsPerFrame >= 0.1
            ? String(format: "%.1f", secondsPerFrame)
            : String(format: "%.2f", secondsPerFrame)

        if includedObservationCount > TimelapseVideoGenerator.maxFrames {
            return "\(frameCount)フレーム(\(includedObservationCount)枚から間引き) · 1枚あたり\(formatted)秒"
        }
        return "\(frameCount)フレーム · 1枚あたり\(formatted)秒"
    }

    private var includedObservations: [PlantObservation] {
        rangePicker.selectedObservations.filter { !excludedObservationIDs.contains($0.id) }
    }

    private var includedObservationCount: Int {
        includedObservations.count
    }

    private var estimatedFrameCount: Int {
        min(TimelapseVideoGenerator.maxFrames, includedObservationCount)
    }

    private var canExcludeObservations: Bool {
        includedObservationCount > TimelapseRequirements.minimumObservations
    }

    private var rangeSummaryText: LocalizedStringKey {
        if excludedObservationIDs.isEmpty {
            return "\(rangePicker.selectedObservationCount)枚 · \(rangePicker.intervalDays)日間"
        }
        return "\(includedObservationCount)枚（\(rangePicker.selectedObservationCount)枚中） · \(rangePicker.intervalDays)日間"
    }

    private var frameSelectionSection: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
            HStack {
                MetaLabel(text: "含める画像", size: 9)
                Spacer()
                if !excludedObservationIDs.isEmpty {
                    MetaLabel(
                        text: "\(excludedObservationIDs.count)枚除外",
                        color: NodeColor.mossSoft,
                        size: 9
                    )
                } else if canExcludeObservations {
                    MetaLabel(text: "タップで除外", color: NodeColor.fog, size: 9)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: NodeSpacing.sp2) {
                    ForEach(rangePicker.selectedObservations, id: \.id) { observation in
                        frameSelectionThumbnail(for: observation)
                    }
                }
            }
            .frame(height: 72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func frameSelectionThumbnail(for observation: PlantObservation) -> some View {
        let isExcluded = excludedObservationIDs.contains(observation.id)

        return Button {
            toggleExclusion(for: observation)
        } label: {
            ZStack {
                ObservationThumbnail(
                    imagePath: viewModel.displayThumbnailPath(for: observation),
                    imageStore: imageStore,
                    size: 64
                )
                .opacity(isExcluded ? 0.35 : 1)

                if isExcluded {
                    RoundedRectangle(cornerRadius: NodeRadius.sm)
                        .stroke(NodeColor.syncFail.opacity(0.8), lineWidth: 1.5)

                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(NodeColor.bone)
                        .padding(6)
                        .background(Circle().fill(NodeColor.void.opacity(0.75)))
                } else {
                    RoundedRectangle(cornerRadius: NodeRadius.sm)
                        .stroke(NodeColor.hairline, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExcluded ? String(localized: "動画から除外中") : String(localized: "動画に含める"))
        .accessibilityValue(observation.createdAt.nodeMonthDay())
    }

    private func toggleExclusion(for observation: PlantObservation) {
        if excludedObservationIDs.contains(observation.id) {
            excludedObservationIDs.remove(observation.id)
            return
        }

        guard includedObservationCount > TimelapseRequirements.minimumObservations else { return }
        excludedObservationIDs.insert(observation.id)
    }

    private func pruneExcludedObservations() {
        let selectedIDs = Set(rangePicker.selectedObservations.map(\.id))
        excludedObservationIDs = excludedObservationIDs.intersection(selectedIDs)
    }

    private func calendarSheet(for side: CompareSide) -> some View {
        CompareObservationPickerSheet(
            viewModel: rangePicker,
            side: side,
            imageStore: imageStore,
            navigationTitle: side == .before ? "開始を選択" : "終了を選択"
        )
    }

    private var requirementCard: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
            Text("タイムラプスには\(TimelapseRequirements.minimumObservations)回以上の観測が必要です。")
                .font(NodeFont.text(NodeFont.caption))
                .foregroundStyle(NodeColor.fog)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(NodeSpacing.sp4)
        .background(NodeColor.charcoal)
        .clipShape(RoundedRectangle(cornerRadius: NodeRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: NodeRadius.lg)
                .stroke(NodeColor.hairline, lineWidth: 1)
        )
    }

    private var generatingCard: some View {
        VStack(spacing: NodeSpacing.sp3) {
            ProgressView(value: timelapseService.generationProgress)
                .tint(NodeColor.moss)
            Text(generatingStatusText)
                .font(NodeFont.text(NodeFont.caption))
                .foregroundStyle(NodeColor.fog)
        }
        .padding(NodeSpacing.sp4)
        .frame(maxWidth: .infinity)
        .background(NodeColor.charcoal)
        .clipShape(RoundedRectangle(cornerRadius: NodeRadius.lg))
    }

    private var generatingStatusText: LocalizedStringKey {
        if timelapseService.generationProgress < 0.2 {
            return "画像を取得中… \(Int(timelapseService.generationProgress / 0.2 * 100))%"
        }
        let encodeProgress = (timelapseService.generationProgress - 0.2) / 0.8
        return "端末内で生成中… \(Int(encodeProgress * 100))%"
    }

    private func completedCard(url: URL) -> some View {
        VStack(spacing: NodeSpacing.sp4) {
            VideoPlayer(player: AVPlayer(url: url))
                .aspectRatio(
                    TimelapseRequirements.aspectRatioWidth / TimelapseRequirements.aspectRatioHeight,
                    contentMode: .fit
                )
                .frame(maxWidth: 220)
                .clipShape(RoundedRectangle(cornerRadius: NodeRadius.lg))

            exportActions(url: url)

            NodeSecondaryButton("もう一度生成", systemImage: "arrow.clockwise") {
                timelapseService.discardOutput()
            }
        }
    }

    @ViewBuilder
    private func exportActions(url: URL) -> some View {
        HStack(spacing: NodeSpacing.sp3) {
            ShareLink(item: url) {
                Label("共有", systemImage: "square.and.arrow.up")
                    .font(NodeFont.text(NodeFont.callout, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .foregroundStyle(NodeColor.graphite)
                    .background(Capsule().fill(NodeColor.moss))
            }

            Button {
                Task { await saveToPhotoLibrary(url: url) }
            } label: {
                Label(isSavingToPhotos ? "保存中…" : "写真に保存", systemImage: "photo.badge.plus")
                    .font(NodeFont.text(NodeFont.callout, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .foregroundStyle(NodeColor.bone)
                    .background(
                        Capsule()
                            .stroke(NodeColor.moss.opacity(0.5), lineWidth: 1)
                    )
            }
            .disabled(isSavingToPhotos)
        }
    }

    private func generateTimelapse() async {
        await timelapseService.generate(
            observations: viewModel.plant.observations,
            firstIndex: rangePicker.beforeIndex,
            lastIndex: rangePicker.afterIndex,
            excludedObservationIDs: excludedObservationIDs,
            durationSeconds: durationSeconds,
            maxLongEdge: planService.plan.timelapseMaxLongEdge
        )
    }

    private func saveToPhotoLibrary(url: URL) async {
        isSavingToPhotos = true
        saveMessage = nil
        defer { isSavingToPhotos = false }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            saveMessage = "写真ライブラリへのアクセスが許可されていません。"
            return
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }
            saveMessage = "写真ライブラリに保存しました。"
        } catch {
            saveMessage = error.localizedDescription
        }
    }
}
