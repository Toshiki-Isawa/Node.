import SwiftUI
import SwiftData

struct PlantDetailView: View {
    @Bindable var plant: Plant
    @ObservedObject var viewModel: PlantDetailViewModel
    let imageStore: ImageStore
    var onBack: () -> Void
    var onEdit: () -> Void
    var onObserve: () -> Void
    var onCompare: () -> Void
    var onQuickLog: () -> Void
    var onTimelapse: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection
                actionRow
                timelineSection
            }
            .padding(.bottom, 130)
        }
        .background(NodeColor.graphite)
    }

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            PhotoCard(
                imagePath: viewModel.heroImagePath,
                imageStore: imageStore,
                aspectRatio: 390 / 380,
                cornerRadius: 0,
                overlay: AnyView(
                    LinearGradient(
                        colors: [NodeColor.void.opacity(0.5), .clear, NodeColor.void.opacity(0.9)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            )
            .frame(height: 380)

            VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(NodeColor.bone)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    Spacer()
                    Button(action: onEdit) {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(NodeColor.bone)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, NodeSpacing.sp4)
                .padding(.top, 62)

                Spacer()

                VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
                    MetaLabel(text: "\(plant.dayCount)日目 · 観測 \(plant.observationCount)回")
                    Text(plant.name)
                        .font(NodeFont.display(32, weight: .light))
                        .tracking(-0.5)
                        .foregroundStyle(NodeColor.bone)
                    if !plant.species.isEmpty {
                        Text(plant.species)
                            .font(NodeFont.display(15, weight: .light))
                            .italic()
                            .foregroundStyle(NodeColor.fog)
                    }
                }
                .padding(.horizontal, NodeSpacing.sp5)
                .padding(.bottom, NodeSpacing.sp5)
            }
            .frame(height: 380)
        }
    }

    private var actionRow: some View {
        VStack(spacing: NodeSpacing.sp2) {
            NodePrimaryButton("観測する", systemImage: "camera", action: onObserve)
            HStack(spacing: NodeSpacing.sp2) {
                NodeSecondaryButton("比較する", systemImage: "square.split.2x1", action: onCompare)
                NodeSecondaryButton("クイックログ", systemImage: "doc.text", action: onQuickLog)
            }
        }
        .padding(.horizontal, NodeSpacing.sp4)
        .padding(.vertical, NodeSpacing.sp4)
    }

    private var timelineSection: some View {
        let items = timelineItems

        return VStack(alignment: .leading, spacing: NodeSpacing.sp4) {
            HStack {
                MetaLabel(text: timelineHeaderLabel)
                Spacer()
                MetaLabel(text: "新しい順", color: NodeColor.fog)
            }

            if items.isEmpty {
                EmptyStateView(message: "まだ記録がありません。")
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    switch item {
                    case .observation(let observation):
                        ObservationTimelineRow(
                            observation: observation,
                            imageStore: imageStore,
                            isLast: index == items.count - 1
                        )
                    case .growthLog(let log):
                        GrowthLogTimelineRow(
                            log: log,
                            isLast: index == items.count - 1
                        )
                    }
                }

                if plant.observationCount >= 2 {
                    Button(action: onTimelapse) {
                        HStack {
                            Image(systemName: "film")
                            Text("タイムラプス")
                                .font(NodeFont.text(NodeFont.callout, weight: .medium))
                        }
                        .foregroundStyle(NodeColor.mossSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, NodeSpacing.sp3)
                        .overlay(
                            RoundedRectangle(cornerRadius: NodeRadius.lg)
                                .stroke(NodeColor.hairline, lineWidth: 1)
                        )
                    }
                    .padding(.top, NodeSpacing.sp2)
                }
            }
        }
        .padding(.horizontal, NodeSpacing.sp4)
    }

    private var timelineHeaderLabel: String {
        let logCount = plant.growthLogs.count
        if logCount > 0 {
            return "履歴 · 観測 \(plant.observationCount) · ログ \(logCount)"
        }
        return "観測 · \(plant.observationCount)回"
    }

    private var timelineItems: [PlantDetailTimelineItem] {
        let observations = plant.observations.map { PlantDetailTimelineItem.observation($0) }
        let logs = plant.growthLogs.map { PlantDetailTimelineItem.growthLog($0) }
        return (observations + logs).sorted { $0.createdAt > $1.createdAt }
    }
}

struct GrowthLogTimelineRow: View {
    let log: GrowthLog
    var isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: NodeSpacing.sp4) {
            VStack(spacing: 4) {
                SyncDot(state: log.syncStatus, size: 6)
                if !isLast {
                    Rectangle()
                        .fill(NodeColor.hairline)
                        .frame(width: 1)
                        .frame(minHeight: 60)
                }
            }
            .frame(width: 36)

            HStack(spacing: NodeSpacing.sp3) {
                ZStack {
                    RoundedRectangle(cornerRadius: NodeRadius.md)
                        .fill(NodeColor.bark)
                        .overlay(
                            RoundedRectangle(cornerRadius: NodeRadius.md)
                                .stroke(NodeColor.hairline, lineWidth: 1)
                        )
                    Image(systemName: log.type.systemImage)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(NodeColor.olive)
                }
                .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 4) {
                    MetaLabel(
                        text: log.type.label.uppercased() + " · " + log.createdAt.formatted(.dateTime.month().day()) + " · " + log.createdAt.formatted(date: .omitted, time: .shortened),
                        color: NodeColor.olive,
                        size: 9
                    )
                    if !log.memo.isEmpty {
                        Text(log.memo)
                            .font(NodeFont.text(NodeFont.callout))
                            .foregroundStyle(NodeColor.paper)
                    } else {
                        Text(log.type.label)
                            .font(NodeFont.text(NodeFont.callout))
                            .foregroundStyle(NodeColor.paper)
                    }
                }
                Spacer()
            }
        }
    }
}

struct ObservationTimelineRow: View {
    let observation: PlantObservation
    let imageStore: ImageStore
    var isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: NodeSpacing.sp4) {
            VStack(spacing: 4) {
                SyncDot(state: observation.syncStatus, size: 6)
                if !isLast {
                    Rectangle()
                        .fill(NodeColor.hairline)
                        .frame(width: 1)
                        .frame(minHeight: 60)
                }
            }
            .frame(width: 36)

            HStack(spacing: NodeSpacing.sp3) {
                ObservationThumbnail(
                    imagePath: observation.thumbnailPath.isEmpty ? observation.localImagePath : observation.thumbnailPath,
                    imageStore: imageStore,
                    size: 72
                )

                VStack(alignment: .leading, spacing: 4) {
                    MetaLabel(
                        text: observation.createdAt.formatted(.dateTime.month().day()) + " · " + observation.createdAt.formatted(date: .omitted, time: .shortened),
                        color: NodeColor.fog,
                        size: 9
                    )
                    if !observation.note.isEmpty {
                        Text(observation.note)
                            .font(NodeFont.text(NodeFont.callout))
                            .foregroundStyle(NodeColor.paper)
                    }
                }
                Spacer()
            }
        }
    }
}
