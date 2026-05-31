import SwiftUI

/// Before / After の比較を 1:1 でまとめた SNS 共有用カード。
/// `ShareCardRenderer.renderCard` で画像化される前提で、ブラー（material）を使わず
/// 不透明な色だけで構成している。
/// 植物名などのテキストは画像の上にグラデーションで重ねて表示する。
struct ComparisonShareCard: View {
    let plantName: String
    let species: String
    let beforeImage: UIImage?
    let afterImage: UIImage?
    let beforeDayNumber: Int
    let afterDayNumber: Int
    let beforeDateText: String
    let afterDateText: String

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                HStack(spacing: 2) {
                    pane(
                        image: beforeImage,
                        label: "BEFORE",
                        dayNumber: beforeDayNumber,
                        dateText: beforeDateText
                    )
                    pane(
                        image: afterImage,
                        label: "AFTER",
                        dayNumber: afterDayNumber,
                        dateText: afterDateText
                    )
                }
                .frame(width: geo.size.width, height: geo.size.height)

                header
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NodeColor.void)
        .clipped()
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: NodeSpacing.sp3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(plantName)
                    .font(NodeFont.display(18, weight: .light))
                    .foregroundStyle(NodeColor.bone)
                    .lineLimit(1)
                if !species.isEmpty {
                    Text(species)
                        .font(NodeFont.display(11, weight: .light))
                        .italic()
                        .foregroundStyle(NodeColor.paper)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            ShareBrandMark()
        }
        .padding(.horizontal, NodeSpacing.sp4)
        .padding(.top, NodeSpacing.sp4)
        .padding(.bottom, NodeSpacing.sp5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.7), Color.black.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func pane(
        image: UIImage?,
        label: String,
        dayNumber: Int,
        dateText: String
    ) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    NodeColor.bark
                }

                LinearGradient(
                    colors: [Color.black.opacity(0), Color.black.opacity(0.55)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 4) {
                    paneLabel(label)
                    VStack(alignment: .leading, spacing: 1) {
                        CultivationDayLabel(
                            count: dayNumber,
                            labelFont: NodeFont.mono(9),
                            numberFont: NodeFont.mono(9, weight: .medium),
                            labelColor: NodeColor.mossSoft.opacity(0.75),
                            numberColor: NodeColor.mossSoft,
                            tracking: 0.4
                        )
                        Text(dateText)
                            .font(NodeFont.mono(9))
                            .tracking(0.4)
                            .foregroundStyle(NodeColor.mossSoft.opacity(0.75))
                    }
                }
                .padding(10)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .clipped()
    }

    private func paneLabel(_ text: String) -> some View {
        Text(text)
            .font(NodeFont.mono(9))
            .tracking(0.8)
            .foregroundStyle(NodeColor.bone)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(NodeColor.void.opacity(0.55)))
    }
}
