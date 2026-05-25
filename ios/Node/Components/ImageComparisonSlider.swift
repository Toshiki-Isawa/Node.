import SwiftUI

struct ImageComparisonSlider: View {
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

    @State private var sliderPosition: CGFloat = 0.5

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let dividerX = width * sliderPosition

            ZStack(alignment: .leading) {
                comparisonImage(path: afterImagePath, width: width, height: height)

                comparisonImage(path: beforeImagePath, width: width, height: height)
                    .frame(width: dividerX, height: height, alignment: .leading)
                    .clipped()

                Rectangle()
                    .fill(NodeColor.bone)
                    .frame(width: 2, height: height)
                    .offset(x: dividerX - 1)

                sliderHandle
                    .position(x: dividerX, y: height / 2)

                label("BEFORE", alignment: .leading)
                label("AFTER", alignment: .trailing)
            }
            .contentShape(Rectangle())
            .gesture(sliderDragGesture(width: width))

            dateOverlay
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: NodeRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: NodeRadius.lg)
                .stroke(NodeColor.hairline, lineWidth: 1)
        )
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

    private var sliderHandle: some View {
        ZStack {
            Circle()
                .fill(NodeColor.bone)
                .frame(width: 36, height: 36)
                .shadow(color: NodeColor.void.opacity(0.35), radius: 6, y: 2)

            HStack(spacing: 2) {
                Image(systemName: "chevron.left")
                Image(systemName: "chevron.right")
            }
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(NodeColor.graphite)
        }
    }

    private func sliderDragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let progress = min(max(value.location.x / width, 0.04), 0.96)
                sliderPosition = progress
            }
    }

    private func label(_ text: String, alignment: HorizontalAlignment) -> some View {
        VStack {
            Text(text)
                .font(NodeFont.mono(9))
                .tracking(0.8)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
                .padding(12)
            Spacer()
        }
    }

    private var dateOverlay: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                dateButton(
                    dayNumber: beforeDayNumber,
                    dateText: beforeDateText,
                    action: onBeforeDateTap
                )
                Spacer(minLength: NodeSpacing.sp3)
                dateButton(
                    dayNumber: afterDayNumber,
                    dateText: afterDateText,
                    action: onAfterDateTap
                )
            }
            .padding(12)
        }
    }

    private func dateButton(dayNumber: Int?, dateText: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                if let dayNumber {
                    MetaLabel(text: "\(dayNumber)日目", color: NodeColor.fog, size: 9)
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
