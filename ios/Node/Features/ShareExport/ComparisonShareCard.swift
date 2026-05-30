import SwiftUI

/// Before / After の比較を 1:1 でまとめた SNS 共有用カード。
/// `ShareCardRenderer.renderSquare` で画像化される前提で、ブラー（material）を使わず
/// 不透明な色だけで構成している。
struct ComparisonShareCard: View {
    let plantName: String
    let species: String
    let beforeImage: UIImage?
    let afterImage: UIImage?
    let beforeDayNumber: Int
    let afterDayNumber: Int
    let beforeDateText: String
    let afterDateText: String
    let intervalDays: Int
    let observationDiffCount: Int
    let waterCount: Int

    var body: some View {
        VStack(spacing: 0) {
            header
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NodeColor.void)
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
                        .foregroundStyle(NodeColor.fog)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            ShareBrandMark()
        }
        .padding(.horizontal, NodeSpacing.sp4)
        .padding(.vertical, NodeSpacing.sp3)
    }

    private func pane(
        image: UIImage?,
        label: String,
        dayNumber: Int,
        dateText: String
    ) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
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
                    colors: [Color.black.opacity(0), Color.black.opacity(0.5)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 0) {
                    paneLabel(label)
                    Spacer(minLength: 0)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(dayNumber)日目")
                            .font(NodeFont.mono(9))
                            .tracking(0.4)
                            .foregroundStyle(NodeColor.mossSoft)
                        Text(dateText)
                            .font(NodeFont.text(NodeFont.callout, weight: .medium))
                            .foregroundStyle(NodeColor.bone)
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

    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(NodeColor.moss)
                .frame(height: 2)

            HStack(spacing: 0) {
                stat(title: "経過日数", value: "\(intervalDays)日")
                stat(title: "観測差", value: "\(observationDiffCount)回")
                stat(title: "水やり", value: "\(waterCount)回")
            }
            .padding(.horizontal, NodeSpacing.sp4)
            .padding(.vertical, NodeSpacing.sp3)
        }
        .background(NodeColor.void)
    }

    private func stat(title: LocalizedStringKey, value: LocalizedStringKey) -> some View {
        VStack(spacing: 3) {
            MetaLabel(text: title, size: 8)
            Text(value)
                .font(NodeFont.display(16, weight: .light))
                .foregroundStyle(NodeColor.bone)
        }
        .frame(maxWidth: .infinity)
    }
}
