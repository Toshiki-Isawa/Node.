import SwiftUI

struct CareCalendarView: View {
    @ObservedObject var viewModel: PlantDetailViewModel

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            accordionHeader

            expandedContent
                .padding(.top, viewModel.isCalendarExpanded ? NodeSpacing.sp4 : 0)
                .calendarAccordionReveal(isExpanded: viewModel.isCalendarExpanded)
        }
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

    private var accordionHeader: some View {
        Button {
            withAnimation(NodeMotion.quietAnimation) {
                viewModel.toggleCalendarExpanded()
            }
        } label: {
            VStack(alignment: .leading, spacing: NodeSpacing.sp3) {
                HStack {
                    MetaLabel(text: "ケアカレンダー", size: 9)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(NodeColor.fog)
                        .rotationEffect(.degrees(viewModel.isCalendarExpanded ? 180 : 0))
                }

                summaryRow
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var summaryRow: some View {
        HStack(spacing: NodeSpacing.sp6) {
            summaryItem(
                label: "前回",
                primaryText: viewModel.lastWaterPrimaryText,
                secondaryDateText: viewModel.lastWaterSecondaryDateText,
                icon: "drop.fill",
                iconColor: CareLogColor.water,
                primaryColor: NodeColor.paper
            )

            summaryItem(
                label: "次回",
                primaryText: viewModel.nextWaterPrimaryText,
                secondaryDateText: viewModel.nextWaterSecondaryDateText,
                icon: "calendar",
                iconColor: NodeColor.mossSoft,
                primaryColor: viewModel.isNextWaterOverdue ? NodeColor.syncFail : NodeColor.paper
            )
        }
    }

    private func summaryItem(
        label: String,
        primaryText: String,
        secondaryDateText: String?,
        icon: String,
        iconColor: Color,
        primaryColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp1) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(iconColor)
                MetaLabel(text: label, color: NodeColor.mist, size: 9)
            }
            Text(primaryText)
                .font(NodeFont.text(NodeFont.callout, weight: .medium))
                .foregroundStyle(primaryColor)
            if let secondaryDateText {
                Text(secondaryDateText)
                    .font(NodeFont.text(11))
                    .foregroundStyle(NodeColor.fog)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp4) {
            monthNavigator
            weekdayHeader
            dayGrid
            legend
            if let selectedDay = viewModel.selectedDay {
                selectedDayDetail(for: selectedDay)
            }
        }
    }

    private var monthNavigator: some View {
        NodeCalendarMonthNavigator(
            monthTitle: viewModel.calendarMonthTitle,
            canGoToPreviousMonth: viewModel.canGoToPreviousMonth,
            canGoToNextMonth: viewModel.canGoToNextMonth,
            dateRange: viewModel.calendarDateRange,
            initialPickerDate: viewModel.calendarPickerSeedDate,
            onPreviousMonth: viewModel.goToPreviousMonth,
            onNextMonth: viewModel.goToNextMonth,
            onJumpToDate: viewModel.jumpToDate
        )
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(viewModel.weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(NodeFont.mono(NodeFont.micro))
                    .foregroundStyle(NodeColor.mist)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, NodeSpacing.sp1)
            }
        }
    }

    private var dayGrid: some View {
        LazyVGrid(columns: columns, spacing: NodeSpacing.sp1) {
            ForEach(Array(viewModel.calendarGridDays.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(for: day)
                } else {
                    Color.clear
                        .frame(height: 44)
                }
            }
        }
    }

    private func dayCell(for day: Date) -> some View {
        let isDisabled = viewModel.isFuture(day) || viewModel.isBeforeAcquisition(day)
        let types = viewModel.logTypes(on: day)
        let isSelected = viewModel.isSelected(day)
        let isToday = viewModel.isToday(day)

        return Button {
            guard !isDisabled else { return }
            viewModel.selectDay(day)
        } label: {
            VStack(spacing: 3) {
                Text("\(Calendar.current.component(.day, from: day))")
                    .font(NodeFont.text(NodeFont.caption, weight: isToday ? .semibold : .regular))
                    .foregroundStyle(isDisabled ? NodeColor.stone : NodeColor.bone)

                HStack(spacing: 2) {
                    ForEach(types.prefix(3)) { type in
                        Circle()
                            .fill(CareLogColor.forType(type))
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: NodeRadius.sm)
                    .fill(isSelected ? NodeColor.moss.opacity(0.18) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: NodeRadius.sm)
                    .stroke(isToday ? NodeColor.moss.opacity(0.5) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private var legend: some View {
        let usedTypes = GrowthLogType.allCases.filter { type in
            viewModel.plant.growthLogs.contains { $0.type == type }
        }

        return Group {
            if usedTypes.isEmpty {
                Text("クイックログで水やり等を記録すると、ここに表示されます。")
                    .font(NodeFont.text(NodeFont.caption))
                    .foregroundStyle(NodeColor.fog)
            } else {
                FlowLayout(spacing: NodeSpacing.sp3) {
                    ForEach(usedTypes) { type in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(CareLogColor.forType(type))
                                .frame(width: 6, height: 6)
                            Text(type.label)
                                .font(NodeFont.text(NodeFont.micro))
                                .foregroundStyle(NodeColor.fog)
                        }
                    }
                }
            }
        }
    }

    private func selectedDayDetail(for day: Date) -> some View {
        let logs = viewModel.logs(on: day)
        let dateLabel = day.nodeMonthDayWeekday()

        return VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
            MetaLabel(text: dateLabel, color: NodeColor.fog, size: 9)

            ForEach(logs, id: \.id) { log in
                HStack(spacing: NodeSpacing.sp3) {
                    ZStack {
                        Circle()
                            .fill(CareLogColor.forType(log.type).opacity(0.15))
                            .frame(width: 28, height: 28)
                        Image(systemName: log.type.systemImage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(CareLogColor.forType(log.type))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(log.type.label)
                            .font(NodeFont.text(NodeFont.caption, weight: .medium))
                            .foregroundStyle(NodeColor.bone)
                        if !log.memo.isEmpty {
                            Text(log.memo)
                                .font(NodeFont.text(NodeFont.caption))
                                .foregroundStyle(NodeColor.fog)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    Text(log.createdAt.nodeTime())
                        .font(NodeFont.mono(NodeFont.micro))
                        .foregroundStyle(NodeColor.mist)
                }
                .padding(.vertical, NodeSpacing.sp1)
            }
        }
        .padding(.top, NodeSpacing.sp2)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(NodeColor.hairline)
                .frame(height: 1)
                .offset(y: -NodeSpacing.sp2)
        }
    }
}

// MARK: - Accordion reveal

private struct CalendarAccordionHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct CalendarAccordionRevealModifier: ViewModifier {
    let isExpanded: Bool
    @State private var contentHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: CalendarAccordionHeightKey.self, value: proxy.size.height)
                }
            }
            .onPreferenceChange(CalendarAccordionHeightKey.self) { height in
                guard height > 0, abs(height - contentHeight) > 0.5 else { return }
                contentHeight = height
            }
            .frame(height: isExpanded ? contentHeight : 0, alignment: .top)
            .clipped()
            .opacity(isExpanded ? 1 : 0)
            .allowsHitTesting(isExpanded)
            .accessibilityHidden(!isExpanded)
    }
}

private extension View {
    func calendarAccordionReveal(isExpanded: Bool) -> some View {
        modifier(CalendarAccordionRevealModifier(isExpanded: isExpanded))
    }
}

private enum CareLogColor {
    static let water = NodeColor.syncActive

    static func forType(_ type: GrowthLogType) -> Color {
        switch type {
        case .water: return NodeColor.syncActive
        case .fertilize: return NodeColor.moss
        case .tonic: return NodeColor.olive
        case .repot: return NodeColor.sage
        case .note: return NodeColor.fog
        case .light: return NodeColor.mossSoft
        }
    }
}

/// 凡例用の横並びレイアウト
private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
