import SwiftUI

struct SyncDot: View {
    let state: SyncStatus
    var size: CGFloat = 6

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .opacity(state == .syncing ? pulseOpacity : 1)
            .animation(state == .syncing ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true) : .default, value: pulseOpacity)
            .onAppear {
                if state == .syncing { pulseOpacity = 0.4 }
            }
    }

    @State private var pulseOpacity: Double = 1

    private var color: Color {
        switch state {
        case .localOnly: return NodeColor.syncLocal
        case .syncing: return NodeColor.syncActive
        case .synced: return NodeColor.syncDone
        case .failed: return NodeColor.syncFail
        case .syncPausedStorageLimit: return NodeColor.syncPaused
        }
    }
}

struct MetaLabel: View {
    let text: LocalizedStringKey
    var color: Color = NodeColor.mist
    var size: CGFloat = NodeFont.micro

    var body: some View {
        Text(text)
            .textCase(.uppercase)
            .font(NodeFont.mono(size))
            .tracking(0.4)
            .foregroundStyle(color)
    }
}

struct NodeChip: View {
    let title: LocalizedStringKey
    let isSelected: Bool
    var count: Int? = nil
    var leadingSystemImage: String? = nil
    var trailingSystemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let leadingSystemImage {
                    Image(systemName: leadingSystemImage)
                        .font(.system(size: 10, weight: .medium))
                }
                Text(title)
                    .font(NodeFont.mono(NodeFont.micro))
                    .tracking(0.6)
                if let count {
                    Text("\(count)")
                        .font(NodeFont.mono(NodeFont.micro))
                        .foregroundStyle(isSelected ? NodeColor.mossSoft.opacity(0.75) : NodeColor.mist)
                }
                if let trailingSystemImage {
                    Image(systemName: trailingSystemImage)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(isSelected ? NodeColor.mossSoft.opacity(0.75) : NodeColor.mist)
                }
            }
            .padding(.horizontal, NodeSpacing.sp3)
            .padding(.vertical, 10)
            .foregroundStyle(isSelected ? NodeColor.mossSoft : NodeColor.fog)
            .background(
                Capsule()
                    .fill(isSelected ? NodeColor.moss.opacity(0.14) : .clear)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? NodeColor.moss.opacity(0.4) : NodeColor.hairline, lineWidth: 1)
            )
            .frame(minHeight: 44)
            .contentShape(Capsule())
        }
        .buttonStyle(NodePressStyle())
    }
}

struct NodePrimaryButton: View {
    let title: LocalizedStringKey
    let systemImage: String?
    let action: () -> Void

    init(_ title: LocalizedStringKey, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: NodeSpacing.sp2) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .regular))
                }
                Text(title)
                    .font(NodeFont.text(NodeFont.callout, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .foregroundStyle(NodeColor.graphite)
            .background(Capsule().fill(NodeColor.moss))
        }
        .buttonStyle(NodePressStyle())
    }
}

struct NodeSecondaryButton: View {
    let title: LocalizedStringKey
    let systemImage: String?
    let action: () -> Void

    init(_ title: LocalizedStringKey, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: NodeSpacing.sp2) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .regular))
                }
                Text(title)
                    .font(NodeFont.text(NodeFont.callout, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .foregroundStyle(NodeColor.bone)
            .background(
                Capsule()
                    .stroke(NodeColor.hairlineStrong, lineWidth: 1)
            )
        }
        .buttonStyle(NodePressStyle())
    }
}

struct NodePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: NodeMotion.durFast), value: configuration.isPressed)
    }
}

struct NodeTextField: View {
    let label: LocalizedStringKey
    var hint: LocalizedStringKey? = nil
    var isRequired: Bool = false
    @Binding var text: String
    var placeholder: LocalizedStringKey = ""

    var body: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
            HStack(spacing: NodeSpacing.sp1) {
                MetaLabel(text: label, size: 9)
                if isRequired {
                    MetaLabel(text: "必須", color: NodeColor.moss, size: 9)
                } else if let hint {
                    MetaLabel(text: hint, color: NodeColor.fog, size: 9)
                }
            }
            TextField(placeholder, text: $text)
                .font(NodeFont.text(NodeFont.body))
                .foregroundStyle(NodeColor.bone)
                .padding(NodeSpacing.sp3)
                .background(
                    RoundedRectangle(cornerRadius: NodeRadius.lg)
                        .fill(NodeColor.bark)
                        .overlay(
                            RoundedRectangle(cornerRadius: NodeRadius.lg)
                                .stroke(NodeColor.hairline, lineWidth: 1)
                        )
                )
        }
    }
}

struct PhotoCard: View {
    let imagePath: String?
    var imageStore: ImageStore
    var aspectRatio: CGFloat = 4 / 5
    var cornerRadius: CGFloat = NodeRadius.md
    var overlay: AnyView? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let imagePath, let uiImage = imageStore.loadImage(path: imagePath) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    NodeColor.bark
                    MetaLabel(text: "PLANT · NO IMAGE", color: NodeColor.fog, size: 9)
                }
                if let overlay { overlay }
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .nodePhotoShadow()
    }
}

struct ObservationThumbnail: View {
    let imagePath: String?
    let imageStore: ImageStore
    var size: CGFloat = 72

    var body: some View {
        Group {
            if let path = imagePath, let uiImage = imageStore.loadImage(path: path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                NodeColor.bark
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: NodeRadius.sm))
    }
}

struct BottomGradientOverlay: View {
    var body: some View {
        LinearGradient(
            colors: [NodeColor.void.opacity(0.9), .clear],
            startPoint: .bottom,
            endPoint: .top
        )
    }
}

struct EmptyStateView: View {
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: NodeSpacing.sp3) {
            MetaLabel(text: message, color: NodeColor.fog)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(NodeFont.text(NodeFont.callout, weight: .medium))
                        .foregroundStyle(NodeColor.mossSoft)
                        .padding(.horizontal, NodeSpacing.sp4)
                        .padding(.vertical, 8)
                        .overlay(
                            Capsule()
                                .stroke(NodeColor.moss.opacity(0.4), lineWidth: 1)
                        )
                }
                .buttonStyle(NodePressStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct StorageLimitBanner: View {
    let usage: StorageUsage
    var onUpgrade: (() -> Void)?

    var body: some View {
        Button {
            onUpgrade?()
        } label: {
            bannerContent
        }
        .buttonStyle(.plain)
        .disabled(onUpgrade == nil)
    }

    private var bannerContent: some View {
        VStack(alignment: .leading, spacing: NodeSpacing.sp2) {
            HStack(spacing: NodeSpacing.sp2) {
                SyncDot(state: .syncPausedStorageLimit, size: 6)
                MetaLabel(text: "クラウド同期", color: NodeColor.bone, size: 9)
            }

            Text("Observation がローカルのみに保存されています")
                .font(NodeFont.text(NodeFont.callout))
                .foregroundStyle(NodeColor.bone)

            Text("Archive でクラウド同期を再開")
                .font(NodeFont.text(12))
                .foregroundStyle(NodeColor.mossSoft)

            ProgressView(value: usage.usedRatio)
                .tint(NodeColor.moss)
        }
        .padding(NodeSpacing.sp4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: NodeRadius.lg)
                .fill(NodeColor.bark)
                .overlay(
                    RoundedRectangle(cornerRadius: NodeRadius.lg)
                        .stroke(NodeColor.hairline, lineWidth: 1)
                )
        )
    }
}

struct NodeRecordDateSection: View {
    @Binding var date: Date
    let range: ClosedRange<Date>
    var label: LocalizedStringKey = "日時"

    private var isRecordingInPast: Bool {
        date.timeIntervalSinceNow < -60
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                MetaLabel(text: label, size: 9)
                Spacer()
                if isRecordingInPast {
                    Button("今に戻す") {
                        date = .now
                    }
                    .font(NodeFont.text(12, weight: .medium))
                    .foregroundStyle(NodeColor.mossSoft)
                }
            }

            HStack(spacing: NodeSpacing.sp2) {
                DatePicker(
                    "",
                    selection: $date,
                    in: range,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(NodeColor.moss)
                .colorScheme(.dark)

                if isRecordingInPast {
                    MetaLabel(text: "過去", color: NodeColor.olive, size: 9)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, NodeSpacing.sp3)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: NodeRadius.lg)
                    .fill(NodeColor.bark)
                    .overlay(
                        RoundedRectangle(cornerRadius: NodeRadius.lg)
                            .stroke(NodeColor.hairline, lineWidth: 1)
                    )
            )
        }
    }
}
