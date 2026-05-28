import SwiftUI

struct EditPlantView: View {
    @ObservedObject var viewModel: EditPlantViewModel
    @Environment(\.dismiss) private var dismiss
    var onDeleted: (() -> Void)?

    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: NodeSpacing.sp4) {
                topBar
                formFields
                deleteSection
            }
            .padding(.bottom, 40)
        }
        .background(NodeColor.graphite)
        .confirmationDialog(
            "植物を削除しますか？",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                deletePlant()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text(deleteConfirmationMessage)
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(NodeColor.fog)
            }
            Spacer()
            Text("植物を編集")
                .font(NodeFont.text(NodeFont.title3, weight: .medium))
                .foregroundStyle(NodeColor.bone)
            Spacer()
            Button("保存") { savePlant() }
                .font(NodeFont.text(NodeFont.body, weight: .medium))
                .foregroundStyle(viewModel.canSave ? NodeColor.moss : NodeColor.fossil)
                .disabled(!viewModel.canSave)
        }
        .padding(.horizontal, NodeSpacing.sp4)
        .padding(.top, 20)
    }

    private var formFields: some View {
        VStack(spacing: NodeSpacing.sp4) {
            NodeTextField(
                label: "植物名",
                isRequired: true,
                text: $viewModel.name,
                placeholder: "例: アガベ チタノタ"
            )

            NodeTextField(
                label: "学名 · クローン",
                hint: "任意",
                text: $viewModel.species,
                placeholder: "例: Agave titanota 'FO-076'"
            )

            WateringIntervalSection(intervalDays: $viewModel.wateringIntervalDays)

            acquiredAtSection

            NodeTextField(
                label: "メモ",
                hint: "任意",
                text: $viewModel.note,
                placeholder: "—"
            )

            NodePrimaryButton("変更を保存") {
                savePlant()
            }
            .disabled(!viewModel.canSave)
            .opacity(viewModel.canSave ? 1 : 0.45)
            .padding(.top, NodeSpacing.sp3)
        }
        .padding(.horizontal, NodeSpacing.sp4)
    }

    private var deleteSection: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
            MetaLabel(text: "危険な操作", size: 9)
            Button {
                showDeleteConfirmation = true
            } label: {
                HStack(spacing: NodeSpacing.sp2) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                    Text("植物を削除")
                        .font(NodeFont.text(NodeFont.callout, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .foregroundStyle(NodeColor.syncFail)
                .background(
                    Capsule()
                        .stroke(NodeColor.syncFail.opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(NodePressStyle())
            MetaLabel(
                text: "観測記録・ログ・端末内の写真もすべて削除されます",
                color: NodeColor.fog,
                size: 9
            )
        }
        .padding(.horizontal, NodeSpacing.sp4)
        .padding(.top, NodeSpacing.sp6)
    }

    private var deleteConfirmationMessage: String {
        var message = String(localized: "「\(viewModel.plant.name)」と、すべての観測記録・ログを削除します。端末内の写真も削除され、元に戻せません。")
        if ReleaseConfig.cloudSyncEnabled {
            message += String(localized: "クラウドに同期済みのデータも削除されます。")
        }
        return message
    }

    private var acquiredAtSection: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
            MetaLabel(text: "育成開始日", size: 9)
            HStack(spacing: NodeSpacing.sp3) {
                DatePicker(
                    "",
                    selection: $viewModel.acquiredAt,
                    in: viewModel.acquiredAtRange,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(NodeColor.moss)
                .colorScheme(.dark)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, NodeSpacing.sp3)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: NodeRadius.lg)
                    .fill(NodeColor.bark)
                    .overlay(RoundedRectangle(cornerRadius: NodeRadius.lg).stroke(NodeColor.hairline, lineWidth: 1))
            )
            MetaLabel(text: "日数カウントの起点", color: NodeColor.fog, size: 9)
        }
    }

    private func savePlant() {
        do {
            try viewModel.save()
            dismiss()
        } catch {
            // 保存失敗時はシートを開いたままにする
        }
    }

    private func deletePlant() {
        do {
            try viewModel.delete()
            dismiss()
            onDeleted?()
        } catch {
            // 削除失敗時はシートを開いたままにする
        }
    }
}
