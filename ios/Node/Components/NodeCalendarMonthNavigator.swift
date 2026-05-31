import SwiftUI

struct NodeCalendarMonthNavigator: View {
    let monthTitle: String
    let canGoToPreviousMonth: Bool
    let canGoToNextMonth: Bool
    let dateRange: ClosedRange<Date>
    let initialPickerDate: Date
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onJumpToDate: (Date) -> Void

    @State private var showsDatePicker = false
    @State private var pickerDate: Date

    init(
        monthTitle: String,
        canGoToPreviousMonth: Bool,
        canGoToNextMonth: Bool,
        dateRange: ClosedRange<Date>,
        initialPickerDate: Date,
        onPreviousMonth: @escaping () -> Void,
        onNextMonth: @escaping () -> Void,
        onJumpToDate: @escaping (Date) -> Void
    ) {
        self.monthTitle = monthTitle
        self.canGoToPreviousMonth = canGoToPreviousMonth
        self.canGoToNextMonth = canGoToNextMonth
        self.dateRange = dateRange
        self.initialPickerDate = initialPickerDate
        self.onPreviousMonth = onPreviousMonth
        self.onNextMonth = onNextMonth
        self.onJumpToDate = onJumpToDate
        _pickerDate = State(initialValue: initialPickerDate)
    }

    var body: some View {
        HStack {
            monthStepButton(
                systemName: "chevron.left",
                accessibilityLabel: "前の月",
                isEnabled: canGoToPreviousMonth,
                action: onPreviousMonth
            )

            Spacer()

            Button {
                pickerDate = initialPickerDate
                showsDatePicker = true
            } label: {
                HStack(spacing: 4) {
                    Text(monthTitle)
                        .font(NodeFont.text(NodeFont.callout, weight: .medium))
                        .foregroundStyle(NodeColor.bone)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(NodeColor.fog)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("年月日を選択")

            Spacer()

            monthStepButton(
                systemName: "chevron.right",
                accessibilityLabel: "次の月",
                isEnabled: canGoToNextMonth,
                action: onNextMonth
            )
        }
        .sheet(isPresented: $showsDatePicker) {
            datePickerSheet
        }
    }

    private func monthStepButton(
        systemName: String,
        accessibilityLabel: LocalizedStringKey,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isEnabled ? NodeColor.bone : NodeColor.stone)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }

    private var datePickerSheet: some View {
        NavigationStack {
            VStack(spacing: NodeSpacing.sp4) {
                DatePicker(
                    "",
                    selection: $pickerDate,
                    in: dateRange,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .tint(NodeColor.moss)
                .colorScheme(.dark)

                NodePrimaryButton("この日へ移動") {
                    onJumpToDate(pickerDate)
                    showsDatePicker = false
                }
            }
            .padding(NodeSpacing.sp4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(NodeColor.void)
            .navigationTitle("日付を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        showsDatePicker = false
                    }
                    .foregroundStyle(NodeColor.fog)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
