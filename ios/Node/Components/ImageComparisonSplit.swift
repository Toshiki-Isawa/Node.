import SwiftUI

struct ImageComparisonSplit: View {
    let beforeImagePath: String?
    let afterImagePath: String?
    let imageStore: ImageStore
    var beforeDayNumber: Int?
    var afterDayNumber: Int?
    var beforeDateText: String
    var afterDateText: String
    var onBeforeDateTap: () -> Void
    var onAfterDateTap: () -> Void
    var aspectRatio: CGFloat = 4 / 3

    var body: some View {
        GeometryReader { geo in
            let useHorizontalSplit = geo.size.width > geo.size.height

            Group {
                if useHorizontalSplit {
                    HStack(spacing: 0) {
                        splitPane(
                            label: "BEFORE",
                            imagePath: beforeImagePath,
                            dayNumber: beforeDayNumber,
                            dateText: beforeDateText,
                            onDateTap: onBeforeDateTap
                        )
                        splitDivider(length: geo.size.height, isVertical: true)
                        splitPane(
                            label: "AFTER",
                            imagePath: afterImagePath,
                            dayNumber: afterDayNumber,
                            dateText: afterDateText,
                            onDateTap: onAfterDateTap
                        )
                    }
                } else {
                    VStack(spacing: 0) {
                        splitPane(
                            label: "BEFORE",
                            imagePath: beforeImagePath,
                            dayNumber: beforeDayNumber,
                            dateText: beforeDateText,
                            onDateTap: onBeforeDateTap
                        )
                        splitDivider(length: geo.size.width, isVertical: false)
                        splitPane(
                            label: "AFTER",
                            imagePath: afterImagePath,
                            dayNumber: afterDayNumber,
                            dateText: afterDateText,
                            onDateTap: onAfterDateTap
                        )
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: NodeRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: NodeRadius.lg)
                .stroke(NodeColor.hairline, lineWidth: 1)
        )
    }

    private func splitPane(
        label: String,
        imagePath: String?,
        dayNumber: Int?,
        dateText: String,
        onDateTap: @escaping () -> Void
    ) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                comparisonImage(path: imagePath, width: geo.size.width, height: geo.size.height)

                paneLabel(label)
                    .padding(10)

                VStack {
                    Spacer()
                    HStack {
                        dateButton(dayNumber: dayNumber, dateText: dateText, action: onDateTap)
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func splitDivider(length: CGFloat, isVertical: Bool) -> some View {
        Group {
            if isVertical {
                Rectangle()
                    .fill(NodeColor.bone)
                    .frame(width: 2, height: length)
            } else {
                Rectangle()
                    .fill(NodeColor.bone)
                    .frame(width: length, height: 2)
            }
        }
    }

    private func comparisonImage(path: String?, width: CGFloat, height: CGFloat) -> some View {
        Group {
            if let path, let uiImage = imageStore.loadImage(path: path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                NodeColor.bark
                    .overlay {
                        MetaLabel(text: "NO IMAGE", color: NodeColor.fog, size: 9)
                    }
            }
        }
    }

    private func paneLabel(_ text: String) -> some View {
        Text(text)
            .font(NodeFont.mono(9))
            .tracking(0.8)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
    }

    private func dateButton(dayNumber: Int?, dateText: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                if let dayNumber {
                    CultivationDayLabel(
                        count: dayNumber,
                        labelFont: NodeFont.mono(9),
                        numberFont: NodeFont.mono(9, weight: .medium),
                        labelColor: NodeColor.fog,
                        numberColor: NodeColor.fog
                    )
                }
                HStack(spacing: 4) {
                    Text(dateText)
                        .font(NodeFont.text(NodeFont.callout, weight: .medium))
                        .foregroundStyle(NodeColor.bone)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(NodeColor.moss)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: NodeRadius.sm))
        }
        .buttonStyle(.plain)
    }
}
