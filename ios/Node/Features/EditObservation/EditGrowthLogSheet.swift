import SwiftUI

struct EditGrowthLogSheet: View {
    @ObservedObject var viewModel: EditGrowthLogViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: NodeSpacing.sp4) {
            Capsule()
                .fill(NodeColor.stone)
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
                MetaLabel(text: viewModel.plant.name, size: 9)
                Text("ログを編集")
                    .font(NodeFont.display(NodeFont.title3, weight: .light))
                    .foregroundStyle(NodeColor.bone)
                MetaLabel(
                    text: viewModel.log.type.label.uppercased() + " · " + viewModel.log.createdAt.nodeYearMonthDayTime(),
                    color: NodeColor.fog,
                    size: 9
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: NodeSpacing.sp3) {
                ZStack {
                    RoundedRectangle(cornerRadius: NodeRadius.lg)
                        .fill(NodeColor.bark)
                        .overlay(
                            RoundedRectangle(cornerRadius: NodeRadius.lg)
                                .stroke(NodeColor.hairline, lineWidth: 1)
                        )
                    Image(systemName: viewModel.log.type.systemImage)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(NodeColor.olive)
                }
                .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.log.type.label)
                        .font(NodeFont.text(NodeFont.callout, weight: .medium))
                        .foregroundStyle(NodeColor.bone)
                    MetaLabel(text: "種別は変更できません", color: NodeColor.fog, size: 9)
                }
                Spacer(minLength: 0)
            }

            NodeRecordDateSection(
                date: $viewModel.recordedAt,
                range: viewModel.recordedAtRange,
                label: "記録日時"
            )

            VStack(alignment: .leading, spacing: 4) {
                MetaLabel(text: "メモ", size: 9)
                TextField("—", text: $viewModel.memo)
                    .font(NodeFont.text(NodeFont.body))
                    .foregroundStyle(NodeColor.bone)
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

            Spacer(minLength: 0)

            VStack(spacing: NodeSpacing.sp2) {
                NodePrimaryButton(saveButtonTitle) {
                    do {
                        try viewModel.save()
                        dismiss()
                    } catch {
                        // 保存失敗時はシートを開いたままにする
                    }
                }
                .disabled(!viewModel.canSave)
                .opacity(viewModel.canSave ? 1 : 0.45)

                NodeSecondaryButton("キャンセル") {
                    dismiss()
                }
            }
        }
        .padding(.horizontal, NodeSpacing.sp5)
        .padding(.top, 10)
        .padding(.bottom, NodeSpacing.sp4)
        .background(NodeColor.charcoal)
        .clipShape(RoundedRectangle(cornerRadius: NodeRadius.xxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NodeRadius.xxl, style: .continuous)
                .stroke(NodeColor.hairline, lineWidth: 1)
        )
    }

    private var saveButtonTitle: String {
        let time = viewModel.recordedAt.nodeTime()
        if viewModel.isRecordingInPast {
            return "変更する · \(viewModel.recordedAt.nodeMonthDay()) \(time)"
        }
        return "変更する · \(time)"
    }
}
