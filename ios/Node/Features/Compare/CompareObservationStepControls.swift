import SwiftUI

struct CompareObservationStepControls: View {
    @ObservedObject var viewModel: CompareViewModel
    let side: CompareSide
    var showsBoundaryButtons = true

    var body: some View {
        HStack(spacing: NodeSpacing.sp2) {
            if showsBoundaryButtons {
                boundaryButton(title: "最初", boundary: .earliest)
            }

            stepButton(
                systemName: "chevron.left",
                accessibilityLabel: "前の観測",
                isEnabled: viewModel.canStepObservation(delta: -1, for: side)
            ) {
                viewModel.stepObservation(delta: -1, for: side)
            }

            stepButton(
                systemName: "chevron.right",
                accessibilityLabel: "次の観測",
                isEnabled: viewModel.canStepObservation(delta: 1, for: side)
            ) {
                viewModel.stepObservation(delta: 1, for: side)
            }

            if showsBoundaryButtons {
                boundaryButton(title: "最新", boundary: .latest)
            }
        }
    }

    private func stepButton(
        systemName: String,
        accessibilityLabel: LocalizedStringKey,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isEnabled ? NodeColor.bone : NodeColor.stone)
                .frame(width: 32, height: 32)
                .background(NodeColor.charcoal)
                .clipShape(Circle())
                .overlay(Circle().stroke(NodeColor.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }

    private func boundaryButton(title: LocalizedStringKey, boundary: CompareObservationBoundary) -> some View {
        Button {
            viewModel.jumpToBoundaryObservation(for: side, boundary: boundary)
        } label: {
            Text(title)
                .font(NodeFont.mono(NodeFont.micro))
                .tracking(0.4)
                .foregroundStyle(NodeColor.fog)
                .padding(.horizontal, NodeSpacing.sp2)
                .padding(.vertical, 8)
                .background(NodeColor.charcoal)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(NodeColor.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct CompareObservationDualStepControls: View {
    @ObservedObject var viewModel: CompareViewModel

    var body: some View {
        HStack(spacing: NodeSpacing.sp4) {
            stepGroup(side: .before, label: "Before")
            stepGroup(side: .after, label: "After")
        }
    }

    private func stepGroup(side: CompareSide, label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
            MetaLabel(text: label, size: 9)
            CompareObservationStepControls(
                viewModel: viewModel,
                side: side,
                showsBoundaryButtons: false
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
