import SwiftUI

struct CollectionView: View {
    @ObservedObject var viewModel: CollectionViewModel
    @ObservedObject var planService: PlanService
    let imageStore: ImageStore
    let observationImageService: ObservationImageService
    var onPlantTap: (Plant) -> Void
    var onAddPlant: () -> Void
    var onBulkQuickLog: () -> Void
    var onSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                if planService.isCloudSyncPausedByStorage, let usage = planService.storageUsage {
                    StorageLimitBanner(usage: usage, onUpgrade: onSettings)
                        .padding(.horizontal, NodeSpacing.sp5)
                        .padding(.bottom, NodeSpacing.sp4)
                }
                categoryChips
                plantGrid
            }
            .padding(.bottom, 120)
        }
        .background(NodeColor.graphite)
        .onAppear {
            viewModel.reload()
            Task { await planService.refresh() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp3) {
            HStack {
                MetaLabel(
                    text: Date.now.nodeYearMonthDayWeekday() + " · " + Date.now.nodeTime(),
                    color: NodeColor.mist
                )
                Spacer()
                HStack(spacing: NodeSpacing.sp4) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(NodeColor.fog)
                    Button(action: onBulkQuickLog) {
                        Image(systemName: "drop.fill")
                            .foregroundStyle(NodeColor.mossSoft)
                    }
                    Button(action: onSettings) {
                        Image(systemName: "gearshape")
                            .foregroundStyle(NodeColor.fog)
                    }
                }
                .font(.system(size: 20, weight: .regular))
            }

            HStack(alignment: .center, spacing: NodeSpacing.sp3) {
                HStack(spacing: 0) {
                    Text("Node")
                        .font(NodeFont.display(NodeFont.display, weight: .light))
                        .tracking(-1)
                        .foregroundStyle(NodeColor.bone)
                    Text(".")
                        .font(NodeFont.display(NodeFont.display, weight: .light))
                        .foregroundStyle(NodeColor.moss)
                }

                Spacer(minLength: NodeSpacing.sp2)

                Button(action: onAddPlant) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                        Text("コレクションに追加")
                            .font(NodeFont.text(12, weight: .medium))
                    }
                    .foregroundStyle(NodeColor.graphite)
                    .padding(.horizontal, NodeSpacing.sp3)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(NodeColor.moss))
                }
                .buttonStyle(NodePressStyle())
            }

            HStack(spacing: NodeSpacing.sp2) {
                MetaLabel(text: "コレクション")
                MetaLabel(text: "· 植物 \(viewModel.plants.count) · 観測 \(viewModel.totalObservations)", color: NodeColor.fog)
            }
        }
        .padding(.horizontal, NodeSpacing.sp5)
        .padding(.top, 62)
        .padding(.bottom, NodeSpacing.sp4)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: NodeSpacing.sp2) {
                ForEach(viewModel.categories, id: \.self) { category in
                    NodeChip(
                        title: category,
                        isSelected: viewModel.selectedCategory == category
                    ) {
                        viewModel.selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, NodeSpacing.sp5)
        }
        .padding(.bottom, NodeSpacing.sp4)
    }

    private var plantGrid: some View {
        Group {
            if viewModel.filteredPlants.isEmpty {
                EmptyStateView(message: "まだ植物がありません。")
                    .padding(.top, NodeSpacing.sp8)
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(viewModel.filteredPlants, id: \.id) { plant in
                        PlantGridCell(
                            plant: plant,
                            imageStore: imageStore,
                            observationImageService: observationImageService
                        )
                            .onTapGesture { onPlantTap(plant) }
                    }
                }
                .padding(.horizontal, NodeSpacing.sp4)
            }
        }
    }
}

private struct PlantGridCell: View {
    let plant: Plant
    let imageStore: ImageStore
    let observationImageService: ObservationImageService

    var body: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
            PhotoCard(
                imagePath: plant.latestObservation.flatMap {
                    observationImageService.displayThumbnailPath(for: $0)
                },
                imageStore: imageStore,
                overlay: AnyView(
                    ZStack(alignment: .topTrailing) {
                        VStack {
                            HStack {
                                Spacer()
                                syncBadge
                            }
                            Spacer()
                            HStack {
                                MetaLabel(text: "\(plant.dayCount)日目", color: NodeColor.fog, size: 9)
                                Spacer()
                            }
                            .padding(12)
                        }
                        BottomGradientOverlay()
                    }
                )
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(plant.name)
                        .font(NodeFont.text(13, weight: .medium))
                        .foregroundStyle(NodeColor.bone)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(-1)

                    if let label = plant.wateringStatusLabel {
                        HStack(spacing: 3) {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 9))
                            Text(label)
                                .font(NodeFont.mono(9))
                        }
                        .foregroundStyle(NodeColor.mossSoft)
                        .fixedSize()
                    }
                }

                Text(plant.species.isEmpty ? " " : plant.species)
                    .font(NodeFont.text(12))
                    .italic()
                    .foregroundStyle(plant.species.isEmpty ? .clear : NodeColor.fog)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .topLeading)
            .padding(.leading, 2)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var syncBadge: some View {
        HStack(spacing: 5) {
            SyncDot(state: plant.aggregateSyncStatus, size: 5)
            MetaLabel(
                text: syncLabel,
                color: NodeColor.bone,
                size: 9
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(NodeColor.void.opacity(0.65))
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(10)
    }

    private var syncLabel: String {
        switch plant.aggregateSyncStatus {
        case .synced: return "\(plant.observationCount)"
        case .localOnly: return "ローカル"
        case .syncing: return "同期中"
        case .failed: return "失敗"
        case .syncPausedStorageLimit: return "容量上限"
        }
    }
}
