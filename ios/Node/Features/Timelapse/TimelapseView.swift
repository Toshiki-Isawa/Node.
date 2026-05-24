import SwiftUI

struct TimelapseView: View {
    @ObservedObject var viewModel: PlantDetailViewModel
    @ObservedObject var timelapseService: TimelapseService
    let imageStore: ImageStore
    @Environment(\.dismiss) private var dismiss

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

                    if timelapseService.isGenerating {
                        ProgressView("生成中…")
                            .tint(NodeColor.moss)
                            .foregroundStyle(NodeColor.fog)
                    } else if let job = timelapseService.currentJob,
                              job.status == .completed,
                              let urlString = job.outputURL,
                              let url = URL(string: urlString) {
                        Link(destination: url) {
                            Text("プレビューを開く")
                                .font(NodeFont.text(NodeFont.callout, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .foregroundStyle(NodeColor.graphite)
                                .background(Capsule().fill(NodeColor.moss))
                        }
                    } else {
                        NodePrimaryButton("タイムラプスを生成") {
                            Task {
                                let ids = viewModel.sortedObservations.map(\.id).reversed()
                                await timelapseService.generate(
                                    plantId: viewModel.plant.id,
                                    observationIds: Array(ids)
                                )
                            }
                        }
                    }

                    if let error = timelapseService.errorMessage {
                        MetaLabel(text: error, color: NodeColor.syncFail)
                    }

                    MetaLabel(text: "720p · 最大60フレーム · Closed Beta", color: NodeColor.fog)
                }
                .padding(NodeSpacing.sp6)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(NodeColor.fog)
                }
            }
        }
    }

    private var previewStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: NodeSpacing.sp2) {
                ForEach(viewModel.sortedObservations.reversed(), id: \.id) { observation in
                    ObservationThumbnail(
                        imagePath: observation.thumbnailPath.isEmpty ? observation.localImagePath : observation.thumbnailPath,
                        imageStore: imageStore,
                        size: 64
                    )
                }
            }
        }
        .frame(height: 72)
    }
}
