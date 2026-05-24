import SwiftUI

struct CollectionView: View {
    @ObservedObject var viewModel: CollectionViewModel
    let imageStore: ImageStore
    var onPlantTap: (Plant) -> Void
    var onAddPlant: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                categoryChips
                plantGrid
            }
            .padding(.bottom, 120)
        }
        .background(NodeColor.graphite)
        .onAppear { viewModel.reload() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp3) {
            HStack {
                MetaLabel(
                    text: Date.now.formatted(.dateTime.year().month().day().weekday(.abbreviated)) + " · " + Date.now.formatted(date: .omitted, time: .shortened),
                    color: NodeColor.mist
                )
                Spacer()
                HStack(spacing: NodeSpacing.sp4) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(NodeColor.fog)
                    Button(action: onAddPlant) {
                        Image(systemName: "plus")
                            .foregroundStyle(NodeColor.bone)
                    }
                    Image(systemName: "gearshape")
                        .foregroundStyle(NodeColor.fog)
                }
                .font(.system(size: 20, weight: .regular))
            }

            HStack(spacing: 0) {
                Text("Node")
                    .font(NodeFont.display(NodeFont.display, weight: .light))
                    .tracking(-1)
                    .foregroundStyle(NodeColor.bone)
                Text(".")
                    .font(NodeFont.display(NodeFont.display, weight: .light))
                    .foregroundStyle(NodeColor.moss)
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
                EmptyStateView(message: "No observations yet.")
                    .padding(.top, NodeSpacing.sp16)
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(viewModel.filteredPlants, id: \.id) { plant in
                        PlantGridCell(plant: plant, imageStore: imageStore)
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

    var body: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
            PhotoCard(
                imagePath: plant.latestObservation?.thumbnailPath ?? plant.latestObservation?.localImagePath,
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
                Text(plant.name)
                    .font(NodeFont.text(13, weight: .medium))
                    .foregroundStyle(NodeColor.bone)
                if !plant.species.isEmpty {
                    Text(plant.species)
                        .font(NodeFont.text(12))
                        .italic()
                        .foregroundStyle(NodeColor.fog)
                }
            }
            .padding(.leading, 2)
        }
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
        }
    }
}
