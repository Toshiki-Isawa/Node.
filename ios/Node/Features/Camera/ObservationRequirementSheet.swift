import SwiftUI

struct ObservationRequirementSheet: View {
    var onAddPlant: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: NodeSpacing.sp4) {
            VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
                MetaLabel(text: "OBSERVATION", size: 9)
                Text("観測")
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
                        Image(systemName: "camera")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(NodeColor.olive)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: NodeRadius.lg)
                            .stroke(NodeColor.hairline, lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("植物の登録が必要です")
                            .font(NodeFont.text(NodeFont.callout, weight: .medium))
                            .foregroundStyle(NodeColor.bone)
                        Text("観測記録は植物ごとに蓄積されます。まずコレクションに植物を追加してください。")
                            .font(NodeFont.text(NodeFont.caption))
                            .foregroundStyle(NodeColor.fog)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Text("登録後、いつでも観測を記録できます。最初の写真は登録時に撮影することもできます。")
                    .font(NodeFont.text(NodeFont.caption))
                    .foregroundStyle(NodeColor.fog)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(NodeSpacing.sp3)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                NodePrimaryButton("植物を追加", systemImage: "plus") {
                    dismiss()
                    onAddPlant()
                }
                NodeSecondaryButton("閉じる") {
                    dismiss()
                }
            }
        }
        .padding(.horizontal, NodeSpacing.sp5)
        .padding(.top, NodeSpacing.sp5)
    }
}
