import SwiftUI

struct CompareView: View {
    @ObservedObject var viewModel: CompareViewModel
    let imageStore: ImageStore
    var analyticsService: AnalyticsService?
    var onBack: () -> Void
    var onTimelapse: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: NodeSpacing.sp5) {
                header

                if viewModel.sortedObservations.count < 2 {
                    EmptyStateView(message: "比較には2回以上の観測が必要です。")
                } else {
                    if let error = viewModel.imageLoadError {
                        MetaLabel(text: "\(error)", color: NodeColor.syncFail)
                    }
                    comparisonBlock
                    intervalCard
                    if ReleaseConfig.timelapseEnabled {
                        timelapseSection
                    }
                }
            }
            .padding(.horizontal, NodeSpacing.sp4)
            .nodeScreenTopPadding()
            .padding(.bottom, NodeTabBarMetrics.scrollBottomInset)
        }
        .background(NodeColor.void)
        .task(id: viewModel.comparisonSelectionKey) {
            await viewModel.loadComparisonImages()
        }
        .sheet(item: $viewModel.activeCalendarSide) { side in
            calendarSheet(for: side)
        }
    }

    private var header: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .foregroundStyle(NodeColor.bone)
                    .frame(width: 36, height: 36)
                    .background(NodeColor.charcoal)
                    .overlay(Circle().stroke(NodeColor.hairline, lineWidth: 1))
                    .clipShape(Circle())
            }
            Spacer()
            VStack(spacing: 2) {
                if let plant = viewModel.plant {
                    MetaLabel(text: "\(plant.name)", size: 9)
                }
                Text("比較")
                    .font(NodeFont.text(NodeFont.callout, weight: .medium))
                    .foregroundStyle(NodeColor.bone)
            }
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
    }

    private var comparisonBlock: some View {
        VStack(alignment: .trailing, spacing: NodeSpacing.sp3) {
            compareModePicker
                .zIndex(1)
            comparisonImage
        }
    }

    private var comparisonImage: some View {
        ZStack {
            Group {
                switch viewModel.displayMode {
                case .slider:
                    ImageComparisonSlider(
                        beforeImagePath: viewModel.beforeImagePath,
                        afterImagePath: viewModel.afterImagePath,
                        imageStore: imageStore,
                        beforeDayNumber: viewModel.beforeObservation.map(viewModel.observationDayNumber),
                        afterDayNumber: viewModel.afterObservation.map(viewModel.observationDayNumber),
                        beforeDateText: viewModel.beforeObservation?.createdAt.nodeMonthDay() ?? "—",
                        afterDateText: viewModel.afterObservation?.createdAt.nodeMonthDay() ?? "—",
                        onBeforeDateTap: { viewModel.openCalendar(for: .before) },
                        onAfterDateTap: { viewModel.openCalendar(for: .after) },
                        sliderPosition: $viewModel.sliderPosition
                    )
                case .split:
                    ImageComparisonSplit(
                        beforeImagePath: viewModel.beforeImagePath,
                        afterImagePath: viewModel.afterImagePath,
                        imageStore: imageStore,
                        beforeDayNumber: viewModel.beforeObservation.map(viewModel.observationDayNumber),
                        afterDayNumber: viewModel.afterObservation.map(viewModel.observationDayNumber),
                        beforeDateText: viewModel.beforeObservation?.createdAt.nodeMonthDay() ?? "—",
                        afterDateText: viewModel.afterObservation?.createdAt.nodeMonthDay() ?? "—",
                        onBeforeDateTap: { viewModel.openCalendar(for: .before) },
                        onAfterDateTap: { viewModel.openCalendar(for: .after) }
                    )
                }
            }

            if viewModel.isLoadingImages {
                ProgressView()
                    .tint(NodeColor.moss)
            }
        }
        .aspectRatio(4 / 3, contentMode: .fit)
        .frame(maxWidth: .infinity)
    }

    private var compareModePicker: some View {
        let segmentWidth: CGFloat = 88
        let pickerHeight: CGFloat = 40

        return ZStack(alignment: .leading) {
            Capsule()
                .fill(.ultraThinMaterial)
                .allowsHitTesting(false)

            Capsule()
                .fill(NodeColor.bone)
                .frame(width: segmentWidth, height: pickerHeight)
                .offset(x: viewModel.displayMode == .slider ? 0 : segmentWidth)
                .animation(.smooth(duration: 0.2), value: viewModel.displayMode)
                .allowsHitTesting(false)

            HStack(spacing: 0) {
                modeButton(
                    mode: .slider,
                    systemImage: "slider.horizontal.below.rectangle",
                    accessibilityLabel: "スライダーで比較",
                    width: segmentWidth,
                    height: pickerHeight
                )
                modeButton(
                    mode: .split,
                    systemImage: "rectangle.split.2x1",
                    accessibilityLabel: "並列で比較",
                    width: segmentWidth,
                    height: pickerHeight
                )
            }
        }
        .frame(width: segmentWidth * 2, height: pickerHeight)
        .clipShape(Capsule())
    }

    private func modeButton(
        mode: CompareDisplayMode,
        systemImage: String,
        accessibilityLabel: String,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        let isSelected = viewModel.displayMode == mode
        return Button {
            selectMode(mode)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isSelected ? NodeColor.graphite : NodeColor.fog)
                .frame(width: width, height: height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func selectMode(_ mode: CompareDisplayMode) {
        guard viewModel.displayMode != mode else { return }
        viewModel.setDisplayMode(mode)
        analyticsService?.capture(
            AnalyticsEvent.compareModeChanged,
            properties: ["mode": mode.analyticsValue]
        )
    }

    private func calendarSheet(for side: CompareSide) -> some View {
        NavigationStack {
            CompareObservationCalendar(
                viewModel: viewModel,
                side: side,
                imageStore: imageStore,
                showsHeader: false
            )
            .navigationTitle(side == .before ? "Before を選択" : "After を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        viewModel.closeCalendar()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var intervalCard: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp3) {
            MetaLabel(text: "期間", size: 9)

            if let before = viewModel.beforeObservation, let after = viewModel.afterObservation {
                HStack(spacing: 4) {
                    Text("\(viewModel.observationDayNumber(before))日目")
                        .font(NodeFont.display(28, weight: .light))
                        .foregroundStyle(NodeColor.bone)
                    Text("→")
                        .foregroundStyle(NodeColor.moss)
                    Text("\(viewModel.observationDayNumber(after))日目")
                        .font(NodeFont.display(28, weight: .light))
                        .foregroundStyle(NodeColor.bone)
                }

                MetaLabel(
                    text: "\(before.createdAt.nodeYearMonthDay()) → \(after.createdAt.nodeYearMonthDay())",
                    color: NodeColor.fog,
                    size: 9
                )
            }

            HStack(spacing: NodeSpacing.sp3) {
                statItem(title: "経過日数", value: "\(viewModel.intervalDays)", unit: "日")
                statItem(title: "観測差", value: "\(viewModel.observationIntervalCount)", unit: "回")
                statItem(title: "水やり", value: "\(viewModel.waterLogCount)", unit: "回")
            }
        }
        .padding(18)
        .background(NodeColor.charcoal)
        .clipShape(RoundedRectangle(cornerRadius: NodeRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: NodeRadius.lg).stroke(NodeColor.hairline, lineWidth: 1))
    }

    private func statItem(title: LocalizedStringKey, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            MetaLabel(text: title, size: 9)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(NodeFont.display(18, weight: .light))
                    .foregroundStyle(NodeColor.bone)
                Text(unit)
                    .font(NodeFont.text(11))
                    .foregroundStyle(NodeColor.fog)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var timelapseSection: some View {
        if viewModel.sortedObservations.count >= TimelapseRequirements.minimumObservations {
            NodeSecondaryButton("タイムラプス", systemImage: "film", action: onTimelapse)
        } else {
            VStack(alignment: .leading, spacing: NodeSpacing.sp3) {
                HStack(spacing: 6) {
                    Image(systemName: "film")
                    Text("タイムラプス")
                        .font(NodeFont.text(NodeFont.callout, weight: .medium))
                }
                .foregroundStyle(NodeColor.fog)

                Text("タイムラプスには\(TimelapseRequirements.minimumObservations)回以上の観測が必要です。")
                    .font(NodeFont.text(NodeFont.caption))
                    .foregroundStyle(NodeColor.fog)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: NodeSpacing.sp4) {
                    timelapseStatusItem(
                        label: "現在",
                        value: "\(viewModel.sortedObservations.count)回"
                    )
                    timelapseStatusItem(
                        label: "あと",
                        value: "\(max(0, TimelapseRequirements.minimumObservations - viewModel.sortedObservations.count))回"
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(NodeColor.charcoal)
            .clipShape(RoundedRectangle(cornerRadius: NodeRadius.lg))
            .overlay(RoundedRectangle(cornerRadius: NodeRadius.lg).stroke(NodeColor.hairline, lineWidth: 1))
        }
    }

    private func timelapseStatusItem(label: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            MetaLabel(text: label, size: 9)
            Text(value)
                .font(NodeFont.text(NodeFont.title3, weight: .medium))
                .foregroundStyle(NodeColor.bone)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
