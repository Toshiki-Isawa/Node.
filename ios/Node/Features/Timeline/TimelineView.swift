import SwiftUI

struct TimelineView: View {
    @ObservedObject var viewModel: TimelineViewModel
    let imageStore: ImageStore
    var onPlantTap: (Plant) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NodeSpacing.sp4) {
                header
                filterChips
                if viewModel.items.isEmpty {
                    EmptyStateView(message: viewModel.emptyMessage)
                        .padding(.top, NodeSpacing.sp16)
                } else {
                    ForEach(viewModel.items) { item in
                        Button {
                            onPlantTap(plant(for: item))
                        } label: {
                            timelineCard(item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, NodeSpacing.sp4)
            .padding(.top, 62)
            .padding(.bottom, 120)
        }
        .background(NodeColor.graphite)
        .onAppear { viewModel.reload() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
            MetaLabel(text: "タイムライン")
            Text("植物の時間を見る")
                .font(NodeFont.display(NodeFont.title1, weight: .light))
                .foregroundStyle(NodeColor.bone)
        }
        .padding(.bottom, NodeSpacing.sp2)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: NodeSpacing.sp2) {
                ForEach(TimelineContentFilter.allCases) { filter in
                    NodeChip(title: filter.label, isSelected: viewModel.filter == filter) {
                        viewModel.filter = filter
                    }
                }
            }
        }
        .padding(.bottom, NodeSpacing.sp2)
    }

    @ViewBuilder
    private func timelineCard(_ item: TimelineViewModel.TimelineEntry) -> some View {
        switch item {
        case .observation(let plant, let observation):
            observationCard(plant: plant, observation: observation)
        case .growthLog(let plant, let log):
            growthLogCard(plant: plant, log: log)
        }
    }

    private func observationCard(plant: Plant, observation: PlantObservation) -> some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp3) {
            cardHeader(plantName: plant.name, syncStatus: observation.syncStatus, badge: "観測")

            PhotoCard(
                imagePath: observation.thumbnailPath.isEmpty ? observation.localImagePath : observation.thumbnailPath,
                imageStore: imageStore,
                aspectRatio: 16 / 10,
                overlay: AnyView(
                    VStack {
                        Spacer()
                        HStack {
                            MetaLabel(
                                text: formattedDateTime(observation.createdAt),
                                color: NodeColor.fog,
                                size: 9
                            )
                            Spacer()
                        }
                        .padding(12)
                        BottomGradientOverlay()
                    }
                )
            )

            if !observation.note.isEmpty {
                Text(observation.note)
                    .font(NodeFont.text(NodeFont.callout))
                    .foregroundStyle(NodeColor.paper)
            }
        }
        .padding(.bottom, NodeSpacing.sp4)
    }

    private func growthLogCard(plant: Plant, log: GrowthLog) -> some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp3) {
            cardHeader(plantName: plant.name, syncStatus: log.syncStatus, badge: log.type.label)

            HStack(spacing: NodeSpacing.sp3) {
                ZStack {
                    RoundedRectangle(cornerRadius: NodeRadius.lg)
                        .fill(NodeColor.bark)
                        .overlay(
                            RoundedRectangle(cornerRadius: NodeRadius.lg)
                                .stroke(NodeColor.hairline, lineWidth: 1)
                        )
                    Image(systemName: log.type.systemImage)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(NodeColor.olive)
                }
                .frame(width: 88, height: 88)

                VStack(alignment: .leading, spacing: 6) {
                    MetaLabel(
                        text: formattedDateTime(log.createdAt),
                        color: NodeColor.olive,
                        size: 9
                    )
                    if !log.memo.isEmpty {
                        Text(log.memo)
                            .font(NodeFont.text(NodeFont.callout))
                            .foregroundStyle(NodeColor.paper)
                            .lineLimit(3)
                    } else {
                        Text(log.type.label)
                            .font(NodeFont.text(NodeFont.callout))
                            .foregroundStyle(NodeColor.paper)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(NodeSpacing.sp3)
            .background(
                RoundedRectangle(cornerRadius: NodeRadius.lg)
                    .fill(NodeColor.charcoal)
                    .overlay(RoundedRectangle(cornerRadius: NodeRadius.lg).stroke(NodeColor.hairline, lineWidth: 1))
            )
        }
        .padding(.bottom, NodeSpacing.sp4)
    }

    private func cardHeader(plantName: String, syncStatus: SyncStatus, badge: String) -> some View {
        HStack {
            MetaLabel(text: plantName.uppercased(), size: 9)
            MetaLabel(text: badge, color: NodeColor.fog, size: 9)
            Spacer()
            SyncDot(state: syncStatus, size: 5)
        }
    }

    private func formattedDateTime(_ date: Date) -> String {
        date.formatted(.dateTime.year().month().day()) + " · " + date.formatted(date: .omitted, time: .shortened)
    }

    private func plant(for item: TimelineViewModel.TimelineEntry) -> Plant {
        switch item {
        case .observation(let plant, _): plant
        case .growthLog(let plant, _): plant
        }
    }
}
