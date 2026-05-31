import SwiftUI
import SwiftData

struct PlantDetailView: View {
    @Bindable var plant: Plant
    @ObservedObject var viewModel: PlantDetailViewModel
    let imageStore: ImageStore
    let observationImageService: ObservationImageService
    let modelContext: ModelContext
    let syncEngine: SyncEngine
    var onBack: () -> Void
    var onEdit: () -> Void
    var onObserve: () -> Void
    var onCompare: () -> Void
    var onQuickLog: () -> Void
    var onObservationTap: (PlantObservation) -> Void

    @State private var showCompareRequirement = false
    @State private var showShareSheet = false
    @State private var deleteTarget: DeleteRecordTarget?
    @State private var editObservationTarget: ObservationEditTarget?
    @State private var editGrowthLogTarget: GrowthLogEditTarget?

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                    actionRow
                    if !plant.note.isEmpty {
                        noteSection
                    }
                    careCalendarSection
                    timelineSection
                }
                .padding(.bottom, NodeTabBarMetrics.scrollBottomInset + NodeSpacing.sp4)
            }
            .background(NodeColor.graphite)
            .ignoresSafeArea(edges: .top)

            topBar
        }
        .background(NodeColor.graphite)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showCompareRequirement) {
            CompareRequirementSheet(
                plantName: plant.name,
                observationCount: plant.observationCount,
                onObserve: onObserve
            )
            .presentationDetents([.fraction(0.52)])
            .presentationDragIndicator(.visible)
            .presentationBackground(NodeColor.charcoal)
        }
        .confirmationDialog(
            deleteTarget?.title ?? "",
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                guard let deleteTarget else { return }
                try? viewModel.delete(deleteTarget)
                self.deleteTarget = nil
            }
            Button("キャンセル", role: .cancel) {
                deleteTarget = nil
            }
        } message: {
            if let deleteTarget {
                Text(deleteTarget.message)
            }
        }
        .sheet(item: $editObservationTarget) { target in
            EditObservationSheet(
                viewModel: EditObservationViewModel(
                    plant: plant,
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
        }
        .sheet(item: $editGrowthLogTarget) { target in
            EditGrowthLogSheet(
                viewModel: EditGrowthLogViewModel(
                    plant: plant,
                    log: target.log,
                    modelContext: modelContext,
                    syncEngine: syncEngine
                )
            )
            .presentationDetents([.fraction(0.62), .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(NodeColor.charcoal)
        }
        .sheet(isPresented: $showShareSheet) {
            shareSheet
        }
    }

    private var shareSheet: some View {
        ShareExportSheet(
            fileName: "Node-observation",
            analyticsKind: "observation",
            analyticsService: nil
        ) {
            if let observation = viewModel.heroObservation {
                ObservationShareCard(
                    plantName: plant.name,
                    species: plant.species,
                    image: heroShareImage(for: observation),
                    dateText: observation.createdAt.nodeDotYearMonthDay(),
                    dayNumber: viewModel.observationDayNumber(for: observation),
                    note: observation.note
                )
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(NodeColor.graphite)
    }

    private func heroShareImage(for observation: PlantObservation) -> UIImage? {
        imageStore.loadImage(path: observation.localImagePath)
            ?? observationImageService.displayThumbnailPath(for: observation)
                .flatMap { imageStore.loadImage(path: $0) }
    }

    private var topBar: some View {
        HStack {
            Button(action: onBack) {
                topBarIcon("chevron.left")
            }
            .buttonStyle(NodePressStyle())
            .accessibilityLabel("戻る")
            Spacer()
            // 視覚円は 36pt のまま、ヒット領域は 44pt を確保するため間隔は 0。
            HStack(spacing: 0) {
                Button {
                    showShareSheet = true
                } label: {
                    topBarIcon("square.and.arrow.up")
                }
                .buttonStyle(NodePressStyle())
                .disabled(viewModel.heroObservation == nil)
                .accessibilityLabel("画像をシェア")

                Button(action: onEdit) {
                    topBarIcon("square.and.pencil")
                }
                .buttonStyle(NodePressStyle())
                .accessibilityLabel("植物を編集")
            }
        }
        .padding(.horizontal, NodeSpacing.sp4)
        .nodeScreenTopPadding()
        .padding(.bottom, NodeSpacing.sp2)
    }

    /// 視覚 36pt の円形アイコン + 44pt のタップ領域。
    private func topBarIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .foregroundStyle(NodeColor.bone)
            .frame(width: 36, height: 36)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .frame(width: 44, height: 44)
            .contentShape(Circle())
    }

    private var heroSection: some View {
        PhotoCard(
            imagePath: viewModel.heroImagePath,
            imageStore: imageStore,
            aspectRatio: 390 / 380,
            cornerRadius: 0,
            overlay: AnyView(
                ZStack(alignment: .bottomLeading) {
                    ObservationHeroOverlayGradient()
                    ObservationHeroOverlayContent(
                        plantName: plant.name,
                        species: plant.species,
                        dayNumber: viewModel.heroDayNumber,
                        dateText: viewModel.heroDateText,
                        note: viewModel.heroNote,
                        showsBrandMark: false
                    )
                }
                .accessibilityElement(children: .combine)
            )
        )
        .frame(height: 380)
    }

    private var actionRow: some View {
        VStack(spacing: NodeSpacing.sp2) {
            NodePrimaryButton("観測する", systemImage: "camera", action: onObserve)
            HStack(spacing: NodeSpacing.sp2) {
                NodeSecondaryButton("比較する", systemImage: "square.split.2x1") {
                    if plant.observationCount >= 2 {
                        onCompare()
                    } else {
                        showCompareRequirement = true
                    }
                }
                NodeSecondaryButton("クイックログ", systemImage: "doc.text", action: onQuickLog)
            }
        }
        .padding(.horizontal, NodeSpacing.sp4)
        .padding(.vertical, NodeSpacing.sp4)
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
            MetaLabel(text: "メモ", size: 9)
            Text(plant.note)
                .font(NodeFont.text(NodeFont.callout))
                .foregroundStyle(NodeColor.paper)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(NodeSpacing.sp4)
                .background(
                    RoundedRectangle(cornerRadius: NodeRadius.lg)
                        .fill(NodeColor.charcoal)
                        .overlay(
                            RoundedRectangle(cornerRadius: NodeRadius.lg)
                                .stroke(NodeColor.hairline, lineWidth: 1)
                        )
                )
        }
        .padding(.horizontal, NodeSpacing.sp4)
        .padding(.bottom, NodeSpacing.sp4)
    }

    private var careCalendarSection: some View {
        CareCalendarView(viewModel: viewModel)
            .padding(.horizontal, NodeSpacing.sp4)
            .padding(.bottom, NodeSpacing.sp4)
    }

    private var timelineSection: some View {
        let items = viewModel.timelineItems

        return VStack(alignment: .leading, spacing: NodeSpacing.sp4) {
            HStack {
                MetaLabel(text: timelineHeaderLabel)
                Spacer()
                MetaLabel(text: "新しい順", color: NodeColor.fog)
            }

            if items.isEmpty {
                EmptyStateView(message: "まだ記録がありません。")
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    switch item {
                    case .observation(let observation):
                        ObservationTimelineRow(
                            observation: observation,
                            imageStore: imageStore,
                            observationImageService: observationImageService,
                            isLast: index == items.count - 1,
                            onTap: { onObservationTap(observation) },
                            onEditDate: {
                                editObservationTarget = ObservationEditTarget(observation: observation)
                            },
                            onDelete: { deleteTarget = .observation(observation) }
                        )
                    case .growthLog(let log):
                        GrowthLogTimelineRow(
                            log: log,
                            isLast: index == items.count - 1,
                            onEdit: {
                                editGrowthLogTarget = GrowthLogEditTarget(log: log)
                            },
                            onDelete: { deleteTarget = .growthLog(log) }
                        )
                    }
                }
            }
        }
        .padding(.horizontal, NodeSpacing.sp4)
    }

    private var timelineHeaderLabel: LocalizedStringKey {
        let logCount = plant.growthLogs.count
        if logCount > 0 {
            return "履歴 · 観測 \(plant.observationCount) · ログ \(logCount)"
        }
        return "観測 · \(plant.observationCount)回"
    }
}

struct GrowthLogTimelineRow: View {
    let log: GrowthLog
    var isLast: Bool
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: NodeSpacing.sp4) {
            VStack(spacing: 4) {
                SyncDot(state: log.syncStatus, size: 6)
                if !isLast {
                    Rectangle()
                        .fill(NodeColor.hairline)
                        .frame(width: 1)
                        .frame(minHeight: 60)
                }
            }
            .frame(width: 36)

            HStack(spacing: NodeSpacing.sp3) {
                ZStack {
                    RoundedRectangle(cornerRadius: NodeRadius.md)
                        .fill(NodeColor.bark)
                        .overlay(
                            RoundedRectangle(cornerRadius: NodeRadius.md)
                                .stroke(NodeColor.hairline, lineWidth: 1)
                        )
                    Image(systemName: log.type.systemImage)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(NodeColor.olive)
                }
                .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 4) {
                    MetaLabel(
                        text: "\(log.type.label) · \(log.createdAt.nodeMonthDayTime())",
                        color: NodeColor.olive,
                        size: 9
                    )
                    if !log.memo.isEmpty {
                        Text(log.memo)
                            .font(NodeFont.text(NodeFont.callout))
                            .foregroundStyle(NodeColor.paper)
                    } else {
                        Text(log.type.label)
                            .font(NodeFont.text(NodeFont.callout))
                            .foregroundStyle(NodeColor.paper)
                    }
                }

                Spacer(minLength: 0)

                TimelineRowActionsMenu(
                    editLabel: "編集",
                    onEdit: onEdit,
                    onDelete: onDelete
                )
            }
        }
    }
}

struct ObservationTimelineRow: View {
    let observation: PlantObservation
    let imageStore: ImageStore
    let observationImageService: ObservationImageService
    var isLast: Bool
    var onTap: () -> Void
    var onEditDate: () -> Void
    var onDelete: () -> Void

    private var accessibilityLabel: String {
        var parts = [observation.createdAt.nodeMonthDayTime()]
        if !observation.note.isEmpty { parts.append(observation.note) }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: NodeSpacing.sp4) {
            VStack(spacing: 4) {
                SyncDot(state: observation.syncStatus, size: 6)
                if !isLast {
                    Rectangle()
                        .fill(NodeColor.hairline)
                        .frame(width: 1)
                        .frame(minHeight: 60)
                }
            }
            .frame(width: 36)

            HStack(spacing: NodeSpacing.sp3) {
                Button(action: onTap) {
                    HStack(spacing: NodeSpacing.sp3) {
                        ObservationThumbnail(
                            imagePath: observationImageService.displayThumbnailPath(for: observation),
                            imageStore: imageStore,
                            size: 72
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            MetaLabel(
                                text: "\(observation.createdAt.nodeMonthDayTime())",
                                color: NodeColor.fog,
                                size: 9
                            )
                            if !observation.note.isEmpty {
                                Text(observation.note)
                                    .font(NodeFont.text(NodeFont.callout))
                                    .foregroundStyle(NodeColor.paper)
                            }
                        }

                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(NodePressStyle())
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(accessibilityLabel)

                TimelineRowActionsMenu(
                    editLabel: "日時を変更",
                    onEdit: onEditDate,
                    onDelete: onDelete
                )
            }
        }
    }
}

private struct TimelineRowActionsMenu: View {
    let editLabel: LocalizedStringKey
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Menu {
            Button(editLabel, action: onEdit)
            Button("削除", role: .destructive, action: onDelete)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(NodeColor.fog)
                .frame(width: 32, height: 32)
                .background(Circle().fill(NodeColor.bark))
                .overlay(Circle().stroke(NodeColor.hairline, lineWidth: 1))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("その他の操作")
    }
}

private struct ObservationEditTarget: Identifiable {
    let id: UUID
    let observation: PlantObservation

    init(observation: PlantObservation) {
        self.id = observation.id
        self.observation = observation
    }
}

private struct GrowthLogEditTarget: Identifiable {
    let id: UUID
    let log: GrowthLog

    init(log: GrowthLog) {
        self.id = log.id
        self.log = log
    }
}
