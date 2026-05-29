import SwiftUI
import UIKit

enum NodeTabBarMetrics {
    /// Floating capsule height (padding + labels).
    static let barHeight: CGFloat = 64
    /// Scroll content inset so the last row clears the tab bar.
    static let scrollBottomInset: CGFloat = barHeight + NodeSpacing.sp4
    /// Cap the floating bar width so it stays centered on iPad / landscape.
    static let maxWidth: CGFloat = 460
}

struct NodeTabBar: View {
    @Binding var selectedTab: AppTab
    var onShoot: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        .frame(maxWidth: NodeTabBarMetrics.maxWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, NodeSpacing.sp4)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isActive = selectedTab == tab
        return Button {
            if selectedTab != tab {
                UISelectionFeedbackGenerator().selectionChanged()
            }
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 18, weight: isActive ? .medium : .regular))
                    .symbolVariant(isActive ? .fill : .none)
                    .contentTransition(.symbolEffect(.replace))
                    .scaleEffect(isActive ? 1.05 : 1)
                Text(tab.label)
                    .font(.system(.caption2, design: .monospaced))
                    .tracking(0.3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(isActive ? NodeColor.bone : NodeColor.mist)
            .background {
                Capsule()
                    .fill(isActive ? NodeColor.bark : Color.clear)
            }
            .contentShape(Capsule())
            .animation(reduceMotion ? nil : NodeMotion.quietAnimation, value: isActive)
        }
        .buttonStyle(NodePressStyle())
        .accessibilityLabel(tab.label)
        .accessibilityAddTraits(isActive ? [.isSelected, .isButton] : .isButton)
    }

    private var shootButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            onShoot()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: AppTab.shoot.systemImage)
                    .font(.system(size: 20, weight: .regular))
                Text(AppTab.shoot.label)
                    .font(.system(.caption2, design: .monospaced))
                    .tracking(0.3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(NodeColor.graphite)
            .background(
                Capsule().fill(NodeColor.moss)
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(NodePressStyle())
        .accessibilityLabel(AppTab.shoot.label)
        .accessibilityAddTraits(.isButton)
    }
}
