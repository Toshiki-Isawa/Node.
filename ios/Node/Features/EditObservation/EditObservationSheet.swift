import SwiftUI

struct EditObservationSheet: View {
    @ObservedObject var viewModel: EditObservationViewModel
    let imageStore: ImageStore
    let observationImageService: ObservationImageService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: NodeSpacing.sp4) {
            Capsule()
                .fill(NodeColor.stone)
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
                MetaLabel(text: viewModel.plant.name, size: 9)
                Text("観測日時を変更")
                    .font(NodeFont.display(NodeFont.title3, weight: .light))
                    .foregroundStyle(NodeColor.bone)
                MetaLabel(
                    text: "現在 · \(viewModel.observation.createdAt.nodeYearMonthDayTime())",
                    color: NodeColor.fog,
                    size: 9
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ObservationThumbnail(
                imagePath: observationImageService.displayThumbnailPath(for: viewModel.observation),
                imageStore: imageStore,
                size: 88
            )
            .frame(maxWidth: .infinity)

            NodeRecordDateSection(
                date: $viewModel.observedAt,
                range: viewModel.observedAtRange,
                label: "観測日時"
            )

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
        let time = viewModel.observedAt.nodeTime()
        if viewModel.isObservingInPast {
            return "変更する · \(viewModel.observedAt.nodeMonthDay()) \(time)"
        }
        return "変更する · \(time)"
    }
}
