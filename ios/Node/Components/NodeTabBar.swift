import SwiftUI
import UIKit

enum NodeTabBarMetrics {
    /// Floating capsule height (side tabs only; the center action protrudes above).
    static let barHeight: CGFloat = 64
    /// Scroll content inset so the last row clears the tab bar.
    static let scrollBottomInset: CGFloat = barHeight + NodeSpacing.sp4
    /// Cap the floating bar width so it stays centered on iPad / landscape.
    static let maxWidth: CGFloat = 460
    /// Diameter of the protruding center action button.
    static let shootDiameter: CGFloat = 62
    /// How far the action circle is lifted above the bar's top edge.
    static let shootLift: CGFloat = 14
    /// Fixed width per side tab — keeps the pill compact and symmetric
    /// instead of stretching tabs to the screen edges.
    static let sideTabWidth: CGFloat = 100
    /// Reserved width for the center action (circle + breathing room).
    static let centerSlot: CGFloat = 80
}

struct NodeTabBar: View {
    @Binding var selectedTab: AppTab
    var onShoot: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        bar
            .frame(maxWidth: NodeTabBarMetrics.maxWidth)
            // 観測ボタンはバーの上端をまたいで浮かせる（capsule のクリップ外に描画）。
            .overlay(alignment: .top) {
                shootButton
                    .offset(y: -NodeTabBarMetrics.shootLift)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, NodeSpacing.sp4)
    }

    private var bar: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.tabBarItems) { tab in
                if tab == .shoot {
                    // 中央は浮遊ボタンのためのスペースを確保するだけ。
                    Color.clear
                        .frame(width: NodeTabBarMetrics.centerSlot, height: 1)
                } else {
                    tabButton(tab)
                        .frame(width: NodeTabBarMetrics.sideTabWidth)
                }
            }
        }
        .padding(6)
        .background(.ultraThinMaterial)
        .background(NodeColor.void.opacity(0.65))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(NodeColor.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.7), radius: 25, y: 20)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isActive = selectedTab == tab
        return Button {
            if selectedTab != tab {
                UISelectionFeedbackGenerator().selectionChanged()
            }
            selectedTab = tab
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 18, weight: isActive ? .semibold : .regular))
                    .symbolVariant(isActive ? .fill : .none)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(height: 22)
                Text(tab.label)
                    .font(.system(.caption2, design: .monospaced))
                    .tracking(0.3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                // 選択インジケータ。非選択時も領域を確保してレイアウトシフトを防ぐ。
                Capsule()
                    .fill(isActive ? NodeColor.moss : Color.clear)
                    .frame(width: 16, height: 3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .foregroundStyle(isActive ? NodeColor.moss : NodeColor.mist)
            .contentShape(Rectangle())
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
            VStack(spacing: 1) {
                Image(systemName: AppTab.shoot.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                Text(AppTab.shoot.label)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(0.3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(NodeColor.graphite)
            .frame(width: NodeTabBarMetrics.shootDiameter, height: NodeTabBarMetrics.shootDiameter)
            .background(
                Circle()
                    .fill(NodeColor.moss)
                    .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
                    .shadow(color: NodeColor.moss.opacity(0.5), radius: 10, y: 4)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
            )
        }
        .buttonStyle(NodePressStyle())
        .accessibilityLabel(AppTab.shoot.label)
        .accessibilityAddTraits(.isButton)
    }
}
