import AVKit
import Photos
import SwiftUI

struct TimelapseView: View {
    @ObservedObject var viewModel: PlantDetailViewModel
    @ObservedObject var timelapseService: TimelapseService
    @ObservedObject var planService: PlanService
    let imageStore: ImageStore
    @Environment(\.dismiss) private var dismiss

    @State private var isSavingToPhotos = false
    @State private var saveMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                NodeColor.graphite.ignoresSafeArea()

                VStack(spacing: NodeSpacing.sp6) {
                    MetaLabel(text: viewModel.plant.name.uppercased(), size: 9)
                    Text("タイムラプス")
                        .font(NodeFont.display(NodeFont.title1, weight: .light))
                        .foregroundStyle(NodeColor.bone)

                    previewStrip

                    content

                    if let error = timelapseService.errorMessage {
                        MetaLabel(text: error, color: NodeColor.syncFail)
                    }

                    if let saveMessage {
                        MetaLabel(text: saveMessage, color: NodeColor.mossSoft)
                    }

                    MetaLabel(
                        text: "\(planService.plan.timelapseQualityLabel) · 端末内生成 · 最大\(TimelapseVideoGenerator.maxFrames)フレーム",
                        color: NodeColor.fog
                    )
                }
                .padding(NodeSpacing.sp6)
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
        .onDisappear { timelapseService.discardOutput() }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.sortedObservations.count < TimelapseRequirements.minimumObservations {
            requirementCard
        } else if timelapseService.isGenerating {
            generatingCard
        } else if let url = timelapseService.outputURL {
            completedCard(url: url)
        } else {
            NodePrimaryButton("タイムラプスを生成") {
                Task {
                    await timelapseService.generate(
                        observations: viewModel.plant.observations,
                        maxLongEdge: planService.plan.timelapseMaxLongEdge
                    )
                }
            }
        }
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

    private var generatingStatusText: String {
        if timelapseService.generationProgress < 0.2 {
            return "画像を取得中… \(Int(timelapseService.generationProgress / 0.2 * 100))%"
        }
        let encodeProgress = (timelapseService.generationProgress - 0.2) / 0.8
        return "端末内で生成中… \(Int(encodeProgress * 100))%"
    }

    private func completedCard(url: URL) -> some View {
        VStack(spacing: NodeSpacing.sp4) {
            VideoPlayer(player: AVPlayer(url: url))
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: NodeRadius.lg))

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

            NodeSecondaryButton("もう一度生成", systemImage: "arrow.clockwise") {
                timelapseService.discardOutput()
            }
        }
    }

    private var previewStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: NodeSpacing.sp2) {
                ForEach(viewModel.sortedObservations.reversed(), id: \.id) { observation in
                    ObservationThumbnail(
                        imagePath: viewModel.displayThumbnailPath(for: observation),
                        imageStore: imageStore,
                        size: 64
                    )
                }
            }
        }
        .frame(height: 72)
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
