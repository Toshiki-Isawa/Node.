import SwiftUI

enum NodeTabBarMetrics {
    /// Floating capsule height (padding + labels).
    static let barHeight: CGFloat = 64
    /// Scroll content inset so the last row clears the tab bar.
    static let scrollBottomInset: CGFloat = barHeight + NodeSpacing.sp4
}

struct NodeTabBar: View {
    @Binding var selectedTab: AppTab
    var onShoot: () -> Void

    var body: some View {
        HStack(spacing: NodeSpacing.sp1) {
            ForEach(AppTab.tabBarItems) { tab in
                if tab == .shoot {
                    shootButton
                } else {
                    tabButton(tab)
                }
            }
        }
        .padding(6)
        .background(.ultraThinMaterial)
        .background(NodeColor.void.opacity(0.65))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(NodeColor.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.7), radius: 25, y: 20)
        .padding(.horizontal, NodeSpacing.sp4)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isActive = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 18, weight: isActive ? .medium : .regular))
                    .symbolVariant(isActive ? .fill : .none)
                Text(tab.label)
                    .font(NodeFont.mono(8))
                    .tracking(0.3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(isActive ? NodeColor.bone : NodeColor.mist)
            .background {
                Capsule()
                    .fill(isActive ? NodeColor.bark : Color.clear)
            }
            .contentShape(Capsule())
            .animation(NodeMotion.quietAnimation, value: isActive)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private var shootButton: some View {
        Button(action: onShoot) {
            VStack(spacing: 4) {
                Image(systemName: AppTab.shoot.systemImage)
                    .font(.system(size: 20, weight: .regular))
                Text(AppTab.shoot.label)
                    .font(NodeFont.mono(8))
                    .tracking(0.3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(NodeColor.graphite)
            .background(Capsule().fill(NodeColor.moss))
        }
        .buttonStyle(NodePressStyle())
    }
}
