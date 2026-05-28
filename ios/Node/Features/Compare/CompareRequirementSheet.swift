import SwiftUI

struct CompareRequirementSheet: View {
    let plantName: String
    let observationCount: Int
    var onObserve: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var remainingCount: Int {
        max(0, 2 - observationCount)
    }

    var body: some View {
        VStack(spacing: NodeSpacing.sp4) {
            VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
                MetaLabel(text: "\(plantName)", size: 9)
                Text("比較")
                    .font(NodeFont.display(NodeFont.title3, weight: .light))
                    .foregroundStyle(NodeColor.bone)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: NodeSpacing.sp3) {
                HStack(spacing: NodeSpacing.sp3) {
                    ZStack {
                        RoundedRectangle(cornerRadius: NodeRadius.lg)
                            .fill(NodeColor.bark)
                            .frame(width: 56, height: 56)
                        Image(systemName: "square.split.2x1")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(NodeColor.olive)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: NodeRadius.lg)
                            .stroke(NodeColor.hairline, lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("2回以上の観測が必要です")
                            .font(NodeFont.text(NodeFont.callout, weight: .medium))
                            .foregroundStyle(NodeColor.bone)
                        Text("異なる時点の写真を2枚以上記録すると、Before / After で比較できます。")
                            .font(NodeFont.text(NodeFont.caption))
                            .foregroundStyle(NodeColor.fog)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: NodeSpacing.sp4) {
                    statusItem(label: "現在", value: "\(observationCount)回")
                    statusItem(label: "あと", value: "\(remainingCount)回")
                }
                .padding(NodeSpacing.sp3)
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
                NodePrimaryButton("観測する", systemImage: "camera") {
                    dismiss()
                    onObserve()
                }
                NodeSecondaryButton("閉じる") {
                    dismiss()
                }
            }
        }
        .padding(.horizontal, NodeSpacing.sp5)
        .padding(.top, NodeSpacing.sp5)
    }

    private func statusItem(label: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            MetaLabel(text: label, size: 9)
            Text(value)
                .font(NodeFont.text(NodeFont.title3, weight: .medium))
                .foregroundStyle(NodeColor.bone)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
