import SwiftUI

struct CollectionView: View {
    @ObservedObject var viewModel: CollectionViewModel
    @ObservedObject var planService: PlanService
    let imageStore: ImageStore
    let observationImageService: ObservationImageService
    var onPlantTap: (Plant) -> Void
    var onAddPlant: () -> Void
    var onBulkQuickLog: (BulkQuickLogContext) -> Void
    var onSettings: () -> Void

    @State private var isSearchActive = false
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            header
                            if ReleaseConfig.searchEnabled, isSearchActive {
                                searchBar
                                    .padding(.horizontal, NodeSpacing.sp5)
                                    .padding(.bottom, NodeSpacing.sp4)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            }
                            topBanner
                        }
                        .id(Self.topAnchorID)

                        plantGrid
                            .padding(.top, NodeSpacing.sp4)
                            .padding(.bottom, NodeTabBarMetrics.scrollBottomInset)
                    }
                }
                .background(NodeColor.graphite.ignoresSafeArea())
                .overlay(alignment: .top) {
                    NodeColor.graphite
                        .frame(maxWidth: .infinity)
                        .frame(height: proxy.safeAreaInsets.top)
                        .ignoresSafeArea(edges: .top)
                        .allowsHitTesting(false)
                }
                .toolbar(.hidden, for: .navigationBar)
                .animation(.easeOut(duration: NodeMotion.durFast), value: isSearchActive)
                .onAppear {
                    viewModel.reload()
                    Task { await planService.refresh() }
                }
                .onChange(of: viewModel.searchText) { oldValue, newValue in
                    // 検索開始 / 終了 / 文字追加のたびに該当範囲が変わるので Top に戻す。
                    // 連続入力時はアニメが自然に上書きされる。
                    guard oldValue != newValue else { return }
                    scrollToTop(scrollProxy)
                }
            }
        }
    }

    private static let topAnchorID = "collection-top"

    private func scrollToTop(_ proxy: ScrollViewProxy) {
        withAnimation(NodeMotion.enterAnimation) {
            proxy.scrollTo(Self.topAnchorID, anchor: .top)
        }
    }

    private func activateSearch() {
        withAnimation(.easeOut(duration: NodeMotion.durFast)) {
            isSearchActive = true
        }
        isSearchFieldFocused = true
    }

    private func deactivateSearch() {
        viewModel.searchText = ""
        withAnimation(.easeOut(duration: NodeMotion.durFast)) {
            isSearchActive = false
        }
        isSearchFieldFocused = false
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp3) {
            HStack(alignment: .center) {
                MetaLabel(
                    text: "\(metaLine(now: Date()))",
                    color: NodeColor.mist
                )
                Spacer()
                HStack(spacing: NodeSpacing.sp4) {
                    if ReleaseConfig.searchEnabled {
                        Button(action: isSearchActive ? deactivateSearch : activateSearch) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(isSearchActive ? NodeColor.mossSoft : NodeColor.fog)
                        }
                        .accessibilityLabel(isSearchActive ? "検索を閉じる" : "検索")
                    }
                    Button(action: { onBulkQuickLog(.general) }) {
                        Image(systemName: "drop.fill")
                            .foregroundStyle(NodeColor.mossSoft)
                            .overlay(alignment: .topTrailing) {
                                if viewModel.plantsNeedingWaterCount > 0 {
                                    Text("\(viewModel.plantsNeedingWaterCount)")
                                        .font(NodeFont.mono(8))
                                        .foregroundStyle(NodeColor.graphite)
                                        .padding(.horizontal, viewModel.plantsNeedingWaterCount >= 10 ? 3 : 0)
                                        .frame(minWidth: 14, minHeight: 14)
                                        .background(Capsule().fill(NodeColor.moss))
                                        .offset(x: 7, y: -7)
                                }
                            }
                    }
                    .accessibilityLabel("一括クイックログ")
                    Button(action: onSettings) {
                        Image(systemName: "gearshape")
                            .foregroundStyle(NodeColor.fog)
                    }
                    .accessibilityLabel("設定")
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
                .accessibilityLabel("コレクションに追加")
            }
        }
        .padding(.horizontal, NodeSpacing.sp5)
        .nodeScreenTopPadding()
        .padding(.bottom, NodeSpacing.sp4)
    }

    private func metaLine(now: Date) -> String {
        var parts: [String] = [
            now.nodeYearMonthDayWeekday(),
        ]
        if !viewModel.plants.isEmpty {
            parts.append("植物 \(viewModel.plants.count)")
            parts.append("観測 \(viewModel.totalObservations)")
        }
        return parts.joined(separator: " · ")
    }

    private var searchBar: some View {
        HStack(spacing: NodeSpacing.sp2) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(NodeColor.fog)
                .font(.system(size: 15))

            TextField("植物名、学名で検索", text: $viewModel.searchText)
                .font(NodeFont.text(NodeFont.body))
                .foregroundStyle(NodeColor.bone)
                .focused($isSearchFieldFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(NodeColor.fog)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }

            Button("キャンセル", action: deactivateSearch)
                .font(NodeFont.text(12, weight: .medium))
                .foregroundStyle(NodeColor.mossSoft)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, NodeSpacing.sp3)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: NodeRadius.lg)
                .fill(NodeColor.bark)
                .overlay(
                    RoundedRectangle(cornerRadius: NodeRadius.lg)
                        .stroke(NodeColor.hairline, lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var topBanner: some View {
        if planService.isCloudSyncPausedByStorage, let usage = planService.storageUsage {
            StorageLimitBanner(usage: usage, onUpgrade: onSettings)
                .padding(.horizontal, NodeSpacing.sp5)
                .padding(.bottom, NodeSpacing.sp4)
        } else if viewModel.plantsNeedingWaterCount > 0 {
            todayWateringBanner
                .padding(.horizontal, NodeSpacing.sp5)
                .padding(.bottom, NodeSpacing.sp4)
        }
    }

    private var todayWateringBanner: some View {
        Button(action: { onBulkQuickLog(.wateringReminder) }) {
            HStack(spacing: NodeSpacing.sp3) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(NodeColor.mossSoft)
                VStack(alignment: .leading, spacing: 2) {
                    Text("今日の水やり: \(viewModel.plantsNeedingWaterCount) 株")
                        .font(NodeFont.text(NodeFont.callout, weight: .medium))
                        .foregroundStyle(NodeColor.bone)
                    Text("タップして一括ケアログを開く")
                        .font(NodeFont.text(11))
                        .foregroundStyle(NodeColor.fog)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NodeColor.mist)
            }
            .padding(NodeSpacing.sp3)
            .background(
                RoundedRectangle(cornerRadius: NodeRadius.lg)
                    .fill(NodeColor.bark)
                    .overlay(
                        RoundedRectangle(cornerRadius: NodeRadius.lg)
                            .stroke(NodeColor.moss.opacity(0.35), lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(NodePressStyle())
    }

    private var plantGrid: some View {
        Group {
            if viewModel.filteredPlants.isEmpty {
                if viewModel.plants.isEmpty {
                    emptyCollectionState
                } else {
                    EmptyStateView(message: "該当する植物がありません。")
                        .padding(.top, NodeSpacing.sp8)
                }
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: NodeSpacing.sp3),
                        GridItem(.flexible(), spacing: NodeSpacing.sp3),
                    ],
                    spacing: NodeSpacing.sp3
                ) {
                    ForEach(viewModel.filteredPlants, id: \.id) { plant in
                        PlantGridCell(
                            plant: plant,
                            imageStore: imageStore,
                            observationImageService: observationImageService
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { onPlantTap(plant) }
                    }
                }
                .padding(.horizontal, NodeSpacing.sp4)
                .padding(.top, NodeSpacing.sp3)
            }
        }
    }

    private var emptyCollectionState: some View {
        VStack(spacing: NodeSpacing.sp5) {
            Image(systemName: "leaf")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(NodeColor.fossil)
                .frame(width: 88, height: 88)
                .background(
                    Circle()
                        .fill(NodeColor.bark)
                        .overlay(Circle().stroke(NodeColor.hairline, lineWidth: 1))
                )

            VStack(spacing: NodeSpacing.sp2) {
                Text("コレクションは空です")
                    .font(NodeFont.text(NodeFont.title3, weight: .light))
                    .foregroundStyle(NodeColor.bone)
                Text("最初の植物を追加して観測を始めましょう。\n写真とケアログで成長を時系列で残せます。")
                    .font(NodeFont.text(NodeFont.callout))
                    .foregroundStyle(NodeColor.fog)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            NodePrimaryButton("植物を追加", systemImage: "plus", action: onAddPlant)
                .padding(.horizontal, NodeSpacing.sp8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, NodeSpacing.sp5)
        .padding(.top, NodeSpacing.sp10)
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
                                if ReleaseConfig.cloudSyncEnabled {
                                    syncBadge
                                }
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
            .overlay(
                RoundedRectangle(cornerRadius: NodeRadius.sm)
                    .stroke(NodeColor.hairline, lineWidth: 1)
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
                text: "\(syncLabel)",
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
        plant.aggregateSyncStatus.label
    }
}
