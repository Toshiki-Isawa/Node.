import SwiftUI

private enum CompareObservationPickerMode: String, CaseIterable, Identifiable {
    case list
    case calendar

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .list: "一覧"
        case .calendar: "カレンダー"
        }
    }
}

struct CompareObservationPickerSheet: View {
    @ObservedObject var viewModel: CompareViewModel
    let side: CompareSide
    let imageStore: ImageStore
    let navigationTitle: LocalizedStringKey

    @State private var mode: CompareObservationPickerMode = .list

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                modePicker
                    .padding(.horizontal, NodeSpacing.sp4)
                    .padding(.vertical, NodeSpacing.sp3)

                Rectangle()
                    .fill(NodeColor.hairline)
                    .frame(height: 1)

                pickerContent

                Rectangle()
                    .fill(NodeColor.hairline)
                    .frame(height: 1)

                CompareObservationStepControls(viewModel: viewModel, side: side)
                    .padding(.horizontal, NodeSpacing.sp4)
                    .padding(.vertical, NodeSpacing.sp3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NodeColor.graphite)
            }
            .background(NodeColor.void)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        viewModel.closeCalendar()
                    }
                    .foregroundStyle(NodeColor.fog)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var modePicker: some View {
        let segmentWidth: CGFloat = 96
        let pickerHeight: CGFloat = 36

        return ZStack(alignment: .leading) {
            Capsule()
                .fill(NodeColor.charcoal)
                .overlay(Capsule().stroke(NodeColor.hairline, lineWidth: 1))

            Capsule()
                .fill(NodeColor.bone)
                .frame(width: segmentWidth, height: pickerHeight)
                .offset(x: mode == .list ? 0 : segmentWidth)
                .animation(.smooth(duration: 0.2), value: mode)

            HStack(spacing: 0) {
                ForEach(CompareObservationPickerMode.allCases) { pickerMode in
                    Button {
                        mode = pickerMode
                    } label: {
                        Text(pickerMode.title)
                            .font(NodeFont.text(NodeFont.caption, weight: .medium))
                            .foregroundStyle(mode == pickerMode ? NodeColor.graphite : NodeColor.fog)
                            .frame(width: segmentWidth, height: pickerHeight)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(mode == pickerMode ? .isSelected : [])
                }
            }
        }
        .frame(width: segmentWidth * 2, height: pickerHeight)
        .clipShape(Capsule())
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var pickerContent: some View {
        switch mode {
        case .list:
            CompareObservationList(
                viewModel: viewModel,
                side: side,
                imageStore: imageStore
            )
        case .calendar:
            ScrollView {
                CompareObservationCalendar(
                    viewModel: viewModel,
                    side: side,
                    imageStore: imageStore,
                    showsHeader: false
                )
                .padding(.horizontal, NodeSpacing.sp4)
                .padding(.vertical, NodeSpacing.sp3)
            }
            .background(NodeColor.void)
        }
    }
}
