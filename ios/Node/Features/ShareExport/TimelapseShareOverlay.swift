import SwiftUI

struct TimelapseVideoOverlayInfo: Sendable {
    let plantName: String
    let species: String
    let beforeDayNumber: Int
    let afterDayNumber: Int
}

/// タイムラプス動画の下部に重ねる SNS 共有向けオーバーレイ。
struct TimelapseShareOverlay: View {
    let plantName: String
    let species: String
    let beforeDayNumber: Int
    let afterDayNumber: Int

    /// 720p 縦動画（幅 720pt）を基準に各要素をスケールする。
    private static let referenceWidth: CGFloat = 720

    private enum Metrics {
        static let nameSize: CGFloat = 56
        static let speciesSize: CGFloat = 30
        static let metaSize: CGFloat = 26
        static let brandSize: CGFloat = 38
        static let accentBarWidth: CGFloat = 60
        static let accentBarHeight: CGFloat = 4
    }

    var body: some View {
        GeometryReader { geo in
            let unit = geo.size.width / Self.referenceWidth

            ZStack(alignment: .bottomLeading) {
                ObservationHeroOverlayGradient()

                VStack(alignment: .leading, spacing: NodeSpacing.sp3 * unit) {
                    Rectangle()
                        .fill(NodeColor.moss)
                        .frame(
                            width: Metrics.accentBarWidth * unit,
                            height: Metrics.accentBarHeight * unit
                        )

                    HStack(alignment: .firstTextBaseline, spacing: NodeSpacing.sp3 * unit) {
                        VStack(alignment: .leading, spacing: 4 * unit) {
                            Text(plantName)
                                .font(NodeFont.display(Metrics.nameSize * unit, weight: .light))
                                .foregroundStyle(NodeColor.bone)
                                .lineLimit(2)
                            if !species.isEmpty {
                                Text(species)
                                    .font(NodeFont.display(Metrics.speciesSize * unit, weight: .light))
                                    .italic()
                                    .foregroundStyle(NodeColor.paper)
                                    .lineLimit(2)
                            }
                        }
                        Spacer(minLength: 0)
                        Text("Node.")
                            .font(NodeFont.display(Metrics.brandSize * unit, weight: .regular))
                            .foregroundStyle(NodeColor.moss)
                            .accessibilityHidden(true)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: NodeSpacing.sp3 * unit) {
                        CultivationDayLabel(
                            count: beforeDayNumber,
                            labelFont: NodeFont.mono(Metrics.metaSize * unit),
                            numberFont: NodeFont.display(Metrics.metaSize * unit, weight: .light),
                            labelColor: NodeColor.mossSoft.opacity(0.75),
                            numberColor: NodeColor.mossSoft,
                            spacing: 5 * unit,
                            tracking: 0.4
                        )
                        Text("→")
                            .font(NodeFont.mono(Metrics.metaSize * unit, weight: .medium))
                            .foregroundStyle(NodeColor.moss)
                        CultivationDayLabel(
                            count: afterDayNumber,
                            labelFont: NodeFont.mono(Metrics.metaSize * unit),
                            numberFont: NodeFont.display(Metrics.metaSize * unit, weight: .light),
                            labelColor: NodeColor.mossSoft.opacity(0.75),
                            numberColor: NodeColor.mossSoft,
                            spacing: 5 * unit,
                            tracking: 0.4
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, NodeSpacing.sp6 * unit)
                .padding(.bottom, NodeSpacing.sp6 * unit)
                .padding(.top, NodeSpacing.sp5 * unit)
            }
        }
    }
}

enum TimelapseShareOverlayRenderer {
    @MainActor
    static func render(info: TimelapseVideoOverlayInfo, size: CGSize) -> UIImage? {
        let content = TimelapseShareOverlay(
            plantName: info.plantName,
            species: info.species,
            beforeDayNumber: info.beforeDayNumber,
            afterDayNumber: info.afterDayNumber
        )
        .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        renderer.isOpaque = false
        return renderer.uiImage
    }
}
