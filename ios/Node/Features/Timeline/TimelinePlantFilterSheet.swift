import SwiftUI

struct TimelinePlantFilterSheet: View {
    let plants: [Plant]
    let selectedPlantId: UUID?
    let imageStore: ImageStore
    let observationImageService: ObservationImageService
    var onSelect: (Plant?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(spacing: NodeSpacing.sp2) {
                    allPlantsRow
                    ForEach(plants, id: \.id) { plant in
                        plantRow(plant)
                    }
                }
                .padding(.horizontal, NodeSpacing.sp4)
                .padding(.bottom, NodeSpacing.sp6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NodeColor.charcoal)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
            MetaLabel(text: "フィルター", size: NodeFont.caption)
            Text("植物で絞り込む")
                .font(NodeFont.display(NodeFont.title3, weight: .light))
                .foregroundStyle(NodeColor.bone)
        }
        .padding(.horizontal, NodeSpacing.sp4)
        .padding(.top, NodeSpacing.sp5)
        .padding(.bottom, NodeSpacing.sp4)
    }

    private var allPlantsRow: some View {
        Button {
            onSelect(nil)
            dismiss()
        } label: {
            HStack(spacing: NodeSpacing.sp3) {
                ZStack {
                    RoundedRectangle(cornerRadius: NodeRadius.sm)
                        .fill(NodeColor.bark)
                        .overlay(
                            RoundedRectangle(cornerRadius: NodeRadius.sm)
                                .stroke(NodeColor.hairline, lineWidth: 1)
                        )
                    Image(systemName: "leaf")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(NodeColor.fog)
                }
                .frame(width: 56, height: 56)

                Text("すべての植物")
                    .font(NodeFont.text(NodeFont.body))
                    .foregroundStyle(NodeColor.bone)

                Spacer(minLength: 0)

                if selectedPlantId == nil {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(NodeColor.mossSoft)
                }
            }
            .padding(NodeSpacing.sp3)
            .background(rowBackground(isSelected: selectedPlantId == nil))
            .contentShape(Rectangle())
        }
        .buttonStyle(NodePressStyle())
    }

    private func plantRow(_ plant: Plant) -> some View {
        let isSelected = selectedPlantId == plant.id
        return Button {
            onSelect(plant)
            dismiss()
        } label: {
            HStack(spacing: NodeSpacing.sp3) {
                ObservationThumbnail(
                    imagePath: plant.latestObservation.flatMap {
                        observationImageService.displayThumbnailPath(for: $0)
                    },
                    imageStore: imageStore,
                    size: 56
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(plant.name)
                        .font(NodeFont.text(NodeFont.body))
                        .foregroundStyle(NodeColor.bone)
                        .lineLimit(1)
                    if !plant.species.isEmpty {
                        Text(plant.species)
                            .font(NodeFont.text(12))
                            .foregroundStyle(NodeColor.fog)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(NodeColor.mossSoft)
                }
            }
            .padding(NodeSpacing.sp3)
            .background(rowBackground(isSelected: isSelected))
            .contentShape(Rectangle())
        }
        .buttonStyle(NodePressStyle())
    }

    private func rowBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: NodeRadius.lg)
            .fill(isSelected ? NodeColor.moss.opacity(0.10) : NodeColor.bark)
            .overlay(
                RoundedRectangle(cornerRadius: NodeRadius.lg)
                    .stroke(
                        isSelected ? NodeColor.moss.opacity(0.4) : NodeColor.hairline,
                        lineWidth: 1
                    )
            )
    }
}
