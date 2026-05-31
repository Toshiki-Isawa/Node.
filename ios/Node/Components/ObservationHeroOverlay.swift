import SwiftUI

/// 育成日数ラベル。言語問わず `Day N` 形式。
struct CultivationDayLabel: View {
    let count: Int
    var labelFont: Font
    var numberFont: Font
    var labelColor: Color
    var numberColor: Color
    var spacing: CGFloat = 3
    var tracking: CGFloat = 0

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: spacing) {
            Text("Day")
                .font(labelFont)
                .foregroundStyle(labelColor)
            Text("\(count)")
                .font(numberFont)
                .foregroundStyle(numberColor)
        }
        .tracking(tracking)
    }
}

/// 観測写真ヒーロー／シェアカード共通の下部グラデーション。
struct ObservationHeroOverlayGradient: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.black.opacity(0),
                Color.black.opacity(0.45),
                Color.black.opacity(0.8),
            ],
            startPoint: .center,
            endPoint: .bottom
        )
    }
}

/// 観測写真ヒーロー／シェアカード共通の下部情報レイアウト。
struct ObservationHeroOverlayContent: View {
    let plantName: String
    let species: String
    let dayNumber: Int
    let dateText: String
    let note: String
    var showsBrandMark: Bool = false

    var body: some View {
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
                if showsBrandMark {
                    Spacer(minLength: 0)
                    ShareBrandMark()
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: NodeSpacing.sp2) {
                CultivationDayLabel(
                    count: dayNumber,
                    labelFont: NodeFont.mono(10),
                    numberFont: NodeFont.mono(10, weight: .medium),
                    labelColor: NodeColor.mossSoft.opacity(0.75),
                    numberColor: NodeColor.mossSoft,
                    tracking: 0.4
                )
                if !dateText.isEmpty {
                    Spacer(minLength: NodeSpacing.sp2)
                    Text(String(localized: "Shot on \(dateText)"))
                        .font(NodeFont.mono(10))
                        .tracking(0.4)
                        .foregroundStyle(NodeColor.mossSoft.opacity(0.75))
                        .multilineTextAlignment(.trailing)
                }
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
