import SwiftUI

struct EditPlantView: View {
    @ObservedObject var viewModel: EditPlantViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: NodeSpacing.sp4) {
                topBar
                formFields
            }
            .padding(.bottom, 40)
        }
        .background(NodeColor.graphite)
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

            VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
                MetaLabel(text: "カテゴリ", size: 9)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: NodeSpacing.sp2) {
                        ForEach(PlantCategory.allCases) { cat in
                            NodeChip(title: cat.rawValue, isSelected: viewModel.category == cat.rawValue) {
                                viewModel.category = cat.rawValue
                            }
                        }
                    }
                }
            }

            acquiredAtSection

            NodePrimaryButton("変更を保存") {
                savePlant()
            }
            .disabled(!viewModel.canSave)
            .opacity(viewModel.canSave ? 1 : 0.45)
            .padding(.top, NodeSpacing.sp3)
        }
        .padding(.horizontal, NodeSpacing.sp4)
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
}
