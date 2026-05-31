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

                ObservationHeroOverlayGradient()

                ObservationHeroOverlayContent(
                    plantName: plantName,
                    species: species,
                    dayNumber: dayNumber,
                    dateText: dateText,
                    note: note,
                    showsBrandMark: true
                )
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NodeColor.void)
        .clipped()
    }
}
