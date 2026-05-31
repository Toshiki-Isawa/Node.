import SwiftUI

struct CompareObservationList: View {
    @ObservedObject var viewModel: CompareViewModel
    let side: CompareSide
    let imageStore: ImageStore

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: NodeSpacing.sp4) {
                    ForEach(viewModel.observationSectionsByYear) { section in
                        sectionView(section)
                    }
                }
                .padding(.horizontal, NodeSpacing.sp4)
                .padding(.vertical, NodeSpacing.sp3)
            }
            .background(NodeColor.void)
            .onAppear {
                scrollToSelection(using: proxy)
            }
            .onChange(of: selectedObservationID) { _, _ in
                scrollToSelection(using: proxy)
            }
        }
    }

    private var selectedObservationID: UUID? {
        switch side {
        case .before:
            viewModel.beforeObservation?.id
        case .after:
            viewModel.afterObservation?.id
        }
    }

    private func sectionView(_ section: CompareObservationYearSection) -> some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
            MetaLabel(text: "\(section.year)年", color: NodeColor.fog, size: 9)
                .padding(.top, NodeSpacing.sp1)

            ForEach(section.observations, id: \.id) { observation in
                observationRow(observation)
                    .id(observation.id)
            }
        }
    }

    private func observationRow(_ observation: PlantObservation) -> some View {
        let isSelectable = viewModel.isObservationSelectable(observation, for: side)
        let isSelected = viewModel.isSelectedObservation(observation, for: side)

        return Button {
            viewModel.selectObservation(observation, for: side)
        } label: {
            HStack(spacing: NodeSpacing.sp3) {
                ObservationThumbnail(
                    imagePath: observation.thumbnailPath.isEmpty
                        ? observation.localImagePath
                        : observation.thumbnailPath,
                    imageStore: imageStore,
                    size: 52
                )

                VStack(alignment: .leading, spacing: 4) {
                    CultivationDayLabel(
                        count: viewModel.observationDayNumber(observation),
                        labelFont: NodeFont.mono(10),
                        numberFont: NodeFont.display(18, weight: .light),
                        labelColor: NodeColor.mist,
                        numberColor: NodeColor.bone,
                        spacing: 4
                    )

                    Text(observation.createdAt.nodeDotYearMonthDay())
                        .font(NodeFont.mono(10))
                        .foregroundStyle(NodeColor.fog)

                    Text(observation.createdAt.nodeTime())
                        .font(NodeFont.text(NodeFont.caption))
                        .foregroundStyle(NodeColor.mist)
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(NodeColor.moss)
                }
            }
            .padding(NodeSpacing.sp3)
            .background(isSelected ? NodeColor.moss.opacity(0.12) : NodeColor.charcoal)
            .clipShape(RoundedRectangle(cornerRadius: NodeRadius.md))
            .overlay {
                RoundedRectangle(cornerRadius: NodeRadius.md)
                    .stroke(isSelected ? NodeColor.moss.opacity(0.45) : NodeColor.hairline, lineWidth: 1)
            }
            .opacity(isSelectable ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .disabled(!isSelectable)
    }

    private func scrollToSelection(using proxy: ScrollViewProxy) {
        guard let selectedObservationID else { return }
        withAnimation(.smooth(duration: 0.25)) {
            proxy.scrollTo(selectedObservationID, anchor: .center)
        }
    }
}
