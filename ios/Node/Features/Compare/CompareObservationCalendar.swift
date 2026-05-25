import SwiftUI

struct CompareObservationCalendar: View {
    @ObservedObject var viewModel: CompareViewModel
    let side: CompareSide
    let imageStore: ImageStore
    var showsHeader = true

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private var title: String {
        side == .before ? "Before" : "After"
    }

    private var selectedObservation: PlantObservation? {
        side == .before ? viewModel.beforeObservation : viewModel.afterObservation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp4) {
            if showsHeader {
                header
            }
            monthNavigator
            weekdayHeader
            dayGrid

            if let pickerDay = viewModel.pickerDay(for: side) {
                observationList(for: pickerDay)
            }
        }
        .padding(18)
        .background(showsHeader ? NodeColor.charcoal : NodeColor.void)
        .clipShape(RoundedRectangle(cornerRadius: showsHeader ? NodeRadius.lg : 0))
        .overlay {
            if showsHeader {
                RoundedRectangle(cornerRadius: NodeRadius.lg)
                    .stroke(NodeColor.hairline, lineWidth: 1)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
            MetaLabel(text: title, size: 9)

            if let observation = selectedObservation {
                HStack(spacing: NodeSpacing.sp3) {
                    ObservationThumbnail(
                        imagePath: side == .before ? viewModel.beforeImagePath : viewModel.afterImagePath,
                        imageStore: imageStore,
                        size: 44
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(viewModel.observationDayNumber(observation))日目")
                            .font(NodeFont.display(18, weight: .light))
                            .foregroundStyle(NodeColor.bone)
                        MetaLabel(
                            text: observation.createdAt.nodeYearMonthDayTime(),
                            color: NodeColor.fog,
                            size: 9
                        )
                    }
                }
            }
        }
    }

    private var monthNavigator: some View {
        HStack {
            Button {
                viewModel.goToPreviousMonth(for: side)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(viewModel.canGoToPreviousMonth(for: side) ? NodeColor.bone : NodeColor.stone)
                    .frame(width: 32, height: 32)
            }
            .disabled(!viewModel.canGoToPreviousMonth(for: side))

            Spacer()

            Text(viewModel.calendarMonthTitle(for: side))
                .font(NodeFont.text(NodeFont.callout, weight: .medium))
                .foregroundStyle(NodeColor.bone)

            Spacer()

            Button {
                viewModel.goToNextMonth(for: side)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(viewModel.canGoToNextMonth(for: side) ? NodeColor.bone : NodeColor.stone)
                    .frame(width: 32, height: 32)
            }
            .disabled(!viewModel.canGoToNextMonth(for: side))
        }
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
            ForEach(Array(viewModel.calendarGridDays(for: side).enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(for: day)
                } else {
                    Color.clear
                        .frame(height: 40)
                }
            }
        }
    }

    private func dayCell(for day: Date) -> some View {
        let isDisabled = viewModel.isFuture(day) || viewModel.isBeforeAcquisition(day)
        let hasObservations = viewModel.hasObservations(on: day)
        let isSelected = viewModel.isSelected(day, for: side)
        let isActive = viewModel.isActiveObservationDay(day, for: side)
        let isToday = viewModel.isToday(day)

        return Button {
            guard !isDisabled, hasObservations else { return }
            viewModel.selectDay(day, for: side)
        } label: {
            VStack(spacing: 3) {
                Text("\(Calendar.current.component(.day, from: day))")
                    .font(NodeFont.text(NodeFont.caption, weight: isToday ? .semibold : .regular))
                    .foregroundStyle(
                        isDisabled ? NodeColor.stone :
                            hasObservations ? NodeColor.bone : NodeColor.mist
                    )

                Circle()
                    .fill(hasObservations ? NodeColor.moss : .clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: NodeRadius.sm)
                    .fill(
                        isActive ? NodeColor.moss.opacity(0.22) :
                            isSelected ? NodeColor.moss.opacity(0.12) : .clear
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: NodeRadius.sm)
                    .stroke(
                        isActive ? NodeColor.moss :
                            isToday ? NodeColor.moss.opacity(0.45) : .clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || !hasObservations)
    }

    @ViewBuilder
    private func observationList(for day: Date) -> some View {
        let observations = viewModel.observations(on: day)
        if observations.count > 1 {
            VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
                MetaLabel(text: day.nodeMonthDayWeekday(), color: NodeColor.fog, size: 9)

                ForEach(observations, id: \.id) { observation in
                    Button {
                        viewModel.selectObservation(observation, for: side)
                    } label: {
                        HStack(spacing: NodeSpacing.sp3) {
                            ObservationThumbnail(
                                imagePath: observation.thumbnailPath.isEmpty
                                    ? observation.localImagePath
                                    : observation.thumbnailPath,
                                imageStore: imageStore,
                                size: 36
                            )

                            Text(observation.createdAt.nodeTime())
                                .font(NodeFont.text(NodeFont.caption, weight: .medium))
                                .foregroundStyle(NodeColor.bone)

                            Spacer()

                            if viewModel.isSelectedObservation(observation, for: side) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(NodeColor.moss)
                            }
                        }
                        .padding(.vertical, NodeSpacing.sp1)
                    }
                    .buttonStyle(.plain)
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
}
