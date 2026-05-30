import SwiftUI

/// 単一の観測写真を 1:1 でまとめた SNS 共有用カード。
/// テキスト情報は画像の下部にグラデーションで重ねて表示する。
struct ObservationShareCard: View {
    let plantName: String
    let species: String
    let image: UIImage?
    let dateText: String
    let dayNumber: Int
    let note: String

    var body: some View {
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
                    colors: [
                        Color.black.opacity(0),
                        Color.black.opacity(0.45),
                        Color.black.opacity(0.8)
                    ],
                    startPoint: .center,
                    endPoint: .bottom
                )

                overlayInfo
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NodeColor.void)
        .clipped()
    }

    private var overlayInfo: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
            Rectangle()
                .fill(NodeColor.moss)
                .frame(width: 28, height: 2)

            HStack(alignment: .firstTextBaseline, spacing: NodeSpacing.sp3) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plantName)
                        .font(NodeFont.display(20, weight: .light))
                        .foregroundStyle(NodeColor.bone)
                        .lineLimit(1)
                    if !species.isEmpty {
                        Text(species)
                            .font(NodeFont.display(12, weight: .light))
                            .italic()
                            .foregroundStyle(NodeColor.paper)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                ShareBrandMark()
            }

            HStack(spacing: NodeSpacing.sp2) {
                Text("\(dayNumber)日目")
                    .font(NodeFont.mono(10))
                    .tracking(0.4)
                    .foregroundStyle(NodeColor.mossSoft)
                Text(dateText)
                    .font(NodeFont.text(NodeFont.caption, weight: .medium))
                    .foregroundStyle(NodeColor.paper)
            }

            if !note.isEmpty {
                Text(note)
                    .font(NodeFont.text(NodeFont.caption))
                    .foregroundStyle(NodeColor.bone)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, NodeSpacing.sp5)
        .padding(.bottom, NodeSpacing.sp5)
        .padding(.top, NodeSpacing.sp4)
    }
}
