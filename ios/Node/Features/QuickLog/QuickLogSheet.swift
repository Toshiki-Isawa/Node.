import SwiftUI

struct QuickLogSheet: View {
    @ObservedObject var viewModel: QuickLogViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        sheetContent
    }

    private var sheetContent: some View {
        VStack(spacing: NodeSpacing.sp3) {
            header

            VStack(spacing: NodeSpacing.sp2) {
                logRow([.water, .fertilize, .tonic])
                logRow([.repot, .light])
            }

            dateTimeSection

            memoField

            Spacer(minLength: 0)

            NodePrimaryButton(recordButtonTitle) {
                do {
                    try viewModel.save()
                    dismiss()
                } catch {
                    // 保存失敗時はシートを開いたままにする
                }
            }
            .disabled(!viewModel.canSave)
            .opacity(viewModel.canSave ? 1 : 0.45)
        }
        .padding(.horizontal, NodeSpacing.sp5)
        .padding(.top, NodeSpacing.sp5)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                MetaLabel(text: viewModel.plant.name, size: 9)
                Text("クイックログ")
                    .font(NodeFont.display(NodeFont.title3, weight: .light))
                    .foregroundStyle(NodeColor.bone)
                MetaLabel(
                    text: selectionHint,
                    color: NodeColor.fog,
                    size: 9
                )
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(NodeColor.fog)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(NodeColor.bark))
            }
        }
    }

    private var memoField: some View {
        VStack(alignment: .leading, spacing: 4) {
            MetaLabel(text: memoFieldLabel, size: 9)
            TextField(memoPlaceholder, text: $viewModel.memo)
                .font(NodeFont.text(NodeFont.body))
                .foregroundStyle(NodeColor.bone)
                .padding(.horizontal, NodeSpacing.sp3)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: NodeRadius.lg)
                        .fill(NodeColor.bark)
                        .overlay(RoundedRectangle(cornerRadius: NodeRadius.lg).stroke(NodeColor.hairline, lineWidth: 1))
                )
        }
    }

    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                MetaLabel(text: "日時", size: 9)
                Spacer()
                if viewModel.isRecordingInPast {
                    Button("今に戻す") {
                        viewModel.resetToNow()
                    }
                    .font(NodeFont.text(12, weight: .medium))
                    .foregroundStyle(NodeColor.mossSoft)
                }
            }

            HStack(spacing: NodeSpacing.sp2) {
                DatePicker(
                    "",
                    selection: $viewModel.recordedAt,
                    in: viewModel.recordedAtRange,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(NodeColor.moss)
                .colorScheme(.dark)

                if viewModel.isRecordingInPast {
                    MetaLabel(
                        text: "過去",
                        color: NodeColor.olive,
                        size: 9
                    )
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, NodeSpacing.sp3)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: NodeRadius.lg)
                    .fill(NodeColor.bark)
                    .overlay(RoundedRectangle(cornerRadius: NodeRadius.lg).stroke(NodeColor.hairline, lineWidth: 1))
            )
        }
    }

    private var selectionHint: String {
        if !viewModel.selectedTypes.isEmpty {
            return "選択中 · \(viewModel.selectedTypes.count)"
        }
        if !viewModel.trimmedMemo.isEmpty {
            return "メモのみで記録"
        }
        return "ケアを選ぶか、メモだけでも可"
    }

    private var memoFieldLabel: String {
        viewModel.selectedTypes.isEmpty ? "メモ" : "補足 · 任意"
    }

    private var memoPlaceholder: String {
        viewModel.selectedTypes.isEmpty ? "状態や観察を記録…" : "—"
    }

    private var recordButtonTitle: String {
        let time = viewModel.recordedAt.nodeTime()
        if viewModel.isRecordingInPast {
            let date = viewModel.recordedAt.nodeMonthDay()
            return "記録する · \(date) \(time)"
        }
        return "記録する · \(time)"
    }

    private func logRow(_ types: [GrowthLogType]) -> some View {
        HStack(spacing: NodeSpacing.sp2) {
            ForEach(types) { type in
                QuickLogTypeCell(
                    type: type,
                    isSelected: viewModel.isSelected(type)
                ) {
                    viewModel.toggleType(type)
                }
            }
        }
    }
}

struct QuickLogTypeCell: View {
    let type: GrowthLogType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 6) {
                    Image(systemName: type.systemImage)
                        .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? NodeColor.moss : NodeColor.bone)
                    Text(type.label)
                        .font(NodeFont.text(12, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? NodeColor.bone : NodeColor.paper)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: NodeRadius.lg)
                        .fill(isSelected ? NodeColor.moss.opacity(0.24) : NodeColor.bark)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: NodeRadius.lg)
                        .stroke(
                            isSelected ? NodeColor.moss : NodeColor.hairline,
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                .shadow(
                    color: isSelected ? NodeColor.moss.opacity(0.25) : .clear,
                    radius: 8,
                    y: 2
                )

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(NodeColor.moss)
                        .background(Circle().fill(NodeColor.graphite).padding(2))
                        .offset(x: -6, y: 6)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(NodeMotion.quietAnimation, value: isSelected)
    }
}
