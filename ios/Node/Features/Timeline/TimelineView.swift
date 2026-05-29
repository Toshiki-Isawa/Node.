import SwiftData
import SwiftUI

struct TimelineView: View {
    @ObservedObject var viewModel: TimelineViewModel
    let imageStore: ImageStore
    let observationImageService: ObservationImageService
    let modelContext: ModelContext
    let syncEngine: SyncEngine
    var onBack: () -> Void
    var onPlantTap: (Plant) -> Void
    var onObservationTap: (Plant, PlantObservation) -> Void

    @State private var deleteTarget: DeleteRecordTarget?
    @State private var pendingDeleteEntry: TimelineViewModel.TimelineEntry?
    @State private var editObservationTarget: TimelineObservationEditTarget?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NodeSpacing.sp4) {
                header
                filterChips
                if viewModel.items.isEmpty {
                    EmptyStateView(message: "\(viewModel.emptyMessage)")
                        .padding(.top, NodeSpacing.sp16)
                } else {
                    ForEach(viewModel.items) { item in
                        timelineCard(item)
                            .contentShape(Rectangle())
                            .onTapGesture { handleTap(item) }
                            .contextMenu {
                                if case .observation(let plant, let observation) = item {
                                    Button("日時を変更") {
                                        editObservationTarget = TimelineObservationEditTarget(
                                            plant: plant,
                                            observation: observation
                                        )
                                    }
                                }
                                Button("削除", role: .destructive) {
                                    pendingDeleteEntry = item
                                    deleteTarget = viewModel.deleteTarget(for: item)
                                }
                            }
                    }
                }
            }
            .padding(.horizontal, NodeSpacing.sp4)
            .nodeScreenTopPadding()
            .padding(.bottom, NodeTabBarMetrics.scrollBottomInset)
        }
        .background(NodeColor.graphite)
        .onAppear { viewModel.reload() }
        .confirmationDialog(
            deleteTarget?.title ?? "",
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 {
                    deleteTarget = nil
                    pendingDeleteEntry = nil
                } }
            ),
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                if let pendingDeleteEntry {
                    try? viewModel.delete(pendingDeleteEntry)
                }
                deleteTarget = nil
                pendingDeleteEntry = nil
            }
            Button("キャンセル", role: .cancel) {
                deleteTarget = nil
                pendingDeleteEntry = nil
            }
        } message: {
            if let deleteTarget {
                Text(deleteTarget.message)
            }
        }
        .sheet(item: $editObservationTarget) { target in
            EditObservationSheet(
                viewModel: EditObservationViewModel(
                    plant: target.plant,
                    observation: target.observation,
                    modelContext: modelContext,
                    syncEngine: syncEngine
                ),
                imageStore: imageStore,
                observationImageService: observationImageService
            )
            .presentationDetents([.fraction(0.58), .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(NodeColor.charcoal)
            .onDisappear {
                viewModel.reload()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp3) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .foregroundStyle(NodeColor.bone)
                    .frame(width: 36, height: 36)
                    .background(NodeColor.charcoal)
                    .overlay(Circle().stroke(NodeColor.hairline, lineWidth: 1))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
                MetaLabel(text: "タイムライン", size: NodeFont.caption)
                Text("観測の記録をたどる")
                    .font(NodeFont.display(NodeFont.title2, weight: .light))
                    .foregroundStyle(NodeColor.bone)
            }
        }
        .padding(.bottom, NodeSpacing.sp2)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: NodeSpacing.sp2) {
                ForEach(TimelineContentFilter.allCases) { filter in
                    NodeChip(title: "\(filter.label)", isSelected: viewModel.filter == filter) {
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
                imagePath: observationImageService.displayThumbnailPath(for: observation),
                imageStore: imageStore,
                aspectRatio: 16 / 10,
                overlay: AnyView(
                    VStack {
                        Spacer()
                        HStack {
                            MetaLabel(
                                text: "\(formattedDateTime(observation.createdAt))",
                                color: NodeColor.bone,
                                size: 9
                            )
                            .padding(.horizontal, NodeSpacing.sp2)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(NodeColor.surfaceOverlay)
                            )
                            .overlay(
                                Capsule().stroke(NodeColor.hairline, lineWidth: 1)
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
            cardHeader(plantName: plant.name, syncStatus: log.syncStatus, badge: "\(log.type.label)")

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
                        text: "\(formattedDateTime(log.createdAt))",
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

    private func cardHeader(plantName: String, syncStatus: SyncStatus, badge: LocalizedStringKey) -> some View {
        HStack {
            MetaLabel(text: "\(plantName)", size: 9)
            MetaLabel(text: badge, color: NodeColor.fog, size: 9)
            Spacer()
            if ReleaseConfig.cloudSyncEnabled {
                SyncDot(state: syncStatus, size: 5)
            }
        }
    }

    private func formattedDateTime(_ date: Date) -> String {
        date.nodeYearMonthDayTime()
    }

    private func plant(for item: TimelineViewModel.TimelineEntry) -> Plant {
        switch item {
        case .observation(let plant, _): plant
        case .growthLog(let plant, _): plant
        }
    }

    private func handleTap(_ item: TimelineViewModel.TimelineEntry) {
        switch item {
        case .observation(let plant, let observation):
            onObservationTap(plant, observation)
        case .growthLog(let plant, _):
            onPlantTap(plant)
        }
    }
}

private struct TimelineObservationEditTarget: Identifiable {
    let id: UUID
    let plant: Plant
    let observation: PlantObservation

    init(plant: Plant, observation: PlantObservation) {
        self.id = observation.id
        self.plant = plant
        self.observation = observation
    }
}
