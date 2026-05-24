import SwiftUI

struct CompareView: View {
    @ObservedObject var viewModel: CompareViewModel
    let imageStore: ImageStore
    var onBack: () -> Void
    var onSelectPlant: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: NodeSpacing.sp5) {
                header

                if viewModel.plant == nil {
                    EmptyStateView(message: "植物を選択してください。")
                    Button("植物を選ぶ", action: onSelectPlant)
                        .font(NodeFont.text(NodeFont.callout))
                        .foregroundStyle(NodeColor.moss)
                } else if viewModel.sortedObservations.count < 2 {
                    EmptyStateView(message: "比較には2回以上の観測が必要です。")
                } else {
                    comparisonStack
                    intervalCard
                    scrubberCard
                }
            }
            .padding(.horizontal, NodeSpacing.sp4)
            .padding(.top, 62)
            .padding(.bottom, 120)
        }
        .background(NodeColor.void)
    }

    private var header: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .foregroundStyle(NodeColor.bone)
                    .frame(width: 36, height: 36)
                    .background(NodeColor.charcoal)
                    .overlay(Circle().stroke(NodeColor.hairline, lineWidth: 1))
                    .clipShape(Circle())
            }
            Spacer()
            VStack(spacing: 2) {
                if let plant = viewModel.plant {
                    MetaLabel(text: plant.name, size: 9)
                }
                Text("比較")
                    .font(NodeFont.text(NodeFont.callout, weight: .medium))
                    .foregroundStyle(NodeColor.bone)
            }
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
    }

    private var comparisonStack: some View {
        VStack(spacing: 0) {
            comparePanel(
                label: "BEFORE",
                observation: viewModel.beforeObservation,
                subtitle: "入手日"
            )
            Rectangle().fill(NodeColor.stone).frame(height: 1)
            comparePanel(
                label: "AFTER",
                observation: viewModel.afterObservation,
                subtitle: "今日"
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: NodeRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: NodeRadius.lg).stroke(NodeColor.hairline, lineWidth: 1))
    }

    private func comparePanel(label: String, observation: PlantObservation?, subtitle: String) -> some View {
        ZStack(alignment: .topLeading) {
            PhotoCard(
                imagePath: observation?.localImagePath,
                imageStore: imageStore,
                aspectRatio: 4 / 3,
                cornerRadius: 0
            )

            VStack(alignment: .leading) {
                Text(label)
                    .font(NodeFont.mono(9))
                    .tracking(0.8)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(12)

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    if let observation {
                        MetaLabel(
                            text: observation.createdAt.formatted(.dateTime.year().month().day()),
                            color: NodeColor.fog,
                            size: 9
                        )
                    }
                    Text(subtitle)
                        .font(NodeFont.display(22, weight: .light))
                        .foregroundStyle(NodeColor.bone)
                }
                .padding(14)
            }
        }
    }

    private var intervalCard: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp3) {
            MetaLabel(text: "期間", size: 9)
            HStack(spacing: 4) {
                Text("1日目")
                    .font(NodeFont.display(28, weight: .light))
                    .foregroundStyle(NodeColor.bone)
                Text("→")
                    .foregroundStyle(NodeColor.moss)
                Text("\(viewModel.plant?.dayCount ?? 0)日目")
                    .font(NodeFont.display(28, weight: .light))
                    .foregroundStyle(NodeColor.bone)
            }

            HStack(spacing: NodeSpacing.sp3) {
                statItem(title: "経過日数", value: "\(viewModel.intervalDays)", unit: "日")
                statItem(title: "観測", value: "\(viewModel.plant?.observationCount ?? 0)", unit: "回")
                statItem(title: "水やり", value: "\(viewModel.waterLogCount)", unit: "回")
            }
        }
        .padding(18)
        .background(NodeColor.charcoal)
        .clipShape(RoundedRectangle(cornerRadius: NodeRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: NodeRadius.lg).stroke(NodeColor.hairline, lineWidth: 1))
    }

    private func statItem(title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            MetaLabel(text: title, size: 9)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(NodeFont.display(18, weight: .light))
                    .foregroundStyle(NodeColor.bone)
                Text(unit)
                    .font(NodeFont.text(11))
                    .foregroundStyle(NodeColor.fog)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scrubberCard: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp4) {
            HStack {
                MetaLabel(text: "スクラブ", size: 9)
                Spacer()
                MetaLabel(text: "\(viewModel.sortedObservations.count)点", color: NodeColor.fog, size: 9)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(NodeColor.stone)
                        .frame(height: 1)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)

                    ForEach(Array(viewModel.sortedObservations.enumerated()), id: \.offset) { index, _ in
                        Circle()
                            .fill(index == viewModel.afterIndex ? NodeColor.moss : NodeColor.stone)
                            .frame(width: index == viewModel.afterIndex ? 10 : 4, height: index == viewModel.afterIndex ? 10 : 4)
                            .position(
                                x: geo.size.width * CGFloat(index) / CGFloat(max(viewModel.sortedObservations.count - 1, 1)),
                                y: geo.size.height / 2
                            )
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let progress = min(max(value.location.x / geo.size.width, 0), 1)
                            viewModel.setScrubProgress(progress)
                        }
                )
            }
            .frame(height: 28)

            Slider(value: Binding(
                get: { viewModel.scrubProgress },
                set: { viewModel.setScrubProgress($0) }
            ))
            .tint(NodeColor.moss)
        }
        .padding(18)
        .background(NodeColor.charcoal)
        .clipShape(RoundedRectangle(cornerRadius: NodeRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: NodeRadius.lg).stroke(NodeColor.hairline, lineWidth: 1))
    }
}
