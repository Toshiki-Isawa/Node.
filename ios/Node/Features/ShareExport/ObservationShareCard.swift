import SwiftUI

/// 単一の観測写真を 1:1 でまとめた SNS 共有用カード。
struct ObservationShareCard: View {
    let plantName: String
    let species: String
    let image: UIImage?
    let dateText: String
    let dayNumber: Int
    let note: String

    var body: some View {
        VStack(spacing: 0) {
            imageArea
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NodeColor.void)
    }

    private var imageArea: some View {
        GeometryReader { geo in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    NodeColor.bark
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(NodeColor.moss)
                .frame(height: 2)

            VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
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

                HStack(spacing: NodeSpacing.sp2) {
                    Text("\(dayNumber)日目")
                        .font(NodeFont.mono(10))
                        .tracking(0.4)
                        .foregroundStyle(NodeColor.mossSoft)
                    Text(dateText)
                        .font(NodeFont.text(NodeFont.caption, weight: .medium))
                        .foregroundStyle(NodeColor.fog)
                }

                if !note.isEmpty {
                    Text(note)
                        .font(NodeFont.text(NodeFont.caption))
                        .foregroundStyle(NodeColor.paper)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, NodeSpacing.sp4)
            .padding(.vertical, NodeSpacing.sp3)
        }
        .background(NodeColor.void)
    }
}
