import SwiftUI

/// 中央誘導ガイド：中央クロスヘア。
/// 「植物を中央に」撮るための位置ガイド。
struct SubjectZoneOverlay: View {
    let frame: CGRect
    var crossLength: CGFloat = 18

    var body: some View {
        let cx = frame.midX
        let cy = frame.midY

        ZStack {
            Path { path in
                path.move(to: CGPoint(x: cx - crossLength, y: cy))
                path.addLine(to: CGPoint(x: cx + crossLength, y: cy))
                path.move(to: CGPoint(x: cx, y: cy - crossLength))
                path.addLine(to: CGPoint(x: cx, y: cy + crossLength))
            }
            .stroke(Color.white.opacity(0.75), lineWidth: 1.5)
        }
        .allowsHitTesting(false)
    }
}

/// 観測枠用の三分割グリッド。`frame` 内に縦横 2 本ずつのラインを描く。
struct GridOverlay: View {
    let frame: CGRect

    var body: some View {
        Path { path in
            let thirdW = frame.width / 3
            let thirdH = frame.height / 3
            path.move(to: CGPoint(x: frame.minX + thirdW, y: frame.minY))
            path.addLine(to: CGPoint(x: frame.minX + thirdW, y: frame.maxY))
            path.move(to: CGPoint(x: frame.minX + thirdW * 2, y: frame.minY))
            path.addLine(to: CGPoint(x: frame.minX + thirdW * 2, y: frame.maxY))
            path.move(to: CGPoint(x: frame.minX, y: frame.minY + thirdH))
            path.addLine(to: CGPoint(x: frame.maxX, y: frame.minY + thirdH))
            path.move(to: CGPoint(x: frame.minX, y: frame.minY + thirdH * 2))
            path.addLine(to: CGPoint(x: frame.maxX, y: frame.minY + thirdH * 2))
        }
        .stroke(Color.white.opacity(0.22), lineWidth: 1)
    }
}

/// 観測枠の四隅と中心を示すレティクル。
struct ReticleOverlay: View {
    let frame: CGRect
    private let bracketSize: CGFloat = 22

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                bracket(at: index)
            }
            Circle()
                .stroke(NodeColor.moss, lineWidth: 1)
                .frame(width: 5, height: 5)
                .position(x: frame.midX, y: frame.midY)
        }
    }

    @ViewBuilder
    private func bracket(at index: Int) -> some View {
        let isLeft = index % 2 == 0
        let isTop = index < 2
        Path { path in
            let x = isLeft ? frame.minX : frame.maxX
            let y = isTop ? frame.minY : frame.maxY
            if isLeft && isTop {
                path.move(to: CGPoint(x: x, y: y + bracketSize))
                path.addLine(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x + bracketSize, y: y))
            } else if !isLeft && isTop {
                path.move(to: CGPoint(x: x - bracketSize, y: y))
                path.addLine(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x, y: y + bracketSize))
            } else if isLeft && !isTop {
                path.move(to: CGPoint(x: x, y: y - bracketSize))
                path.addLine(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x + bracketSize, y: y))
            } else {
                path.move(to: CGPoint(x: x - bracketSize, y: y))
                path.addLine(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x, y: y - bracketSize))
            }
        }
        .stroke(NodeColor.bone.opacity(0.85), lineWidth: 1)
    }
}

/// 前回写真との位置合わせガイド。`LevelIndicator` のスタイルを踏襲し、
/// 方向ヒント or 整合（グリーンチェック）を 1 行で提示する。
struct AlignmentGuideOverlay: View {
    let guidance: AlignmentGuidance

    private var symbol: String {
        if guidance.isAligned { return "checkmark.circle.fill" }
        switch guidance.primaryHint {
        case .moveLeft: return "arrow.left"
        case .moveRight: return "arrow.right"
        case .moveUp: return "arrow.up"
        case .moveDown: return "arrow.down"
        case .moveCloser: return "plus.magnifyingglass"
        case .moveFarther: return "minus.magnifyingglass"
        case nil: return "viewfinder"
        }
    }

    private var message: LocalizedStringKey {
        if guidance.isAligned { return "位置が合いました" }
        switch guidance.primaryHint {
        case .moveLeft: return "もう少し左です"
        case .moveRight: return "もう少し右です"
        case .moveUp: return "もう少し上です"
        case .moveDown: return "もう少し下です"
        case .moveCloser: return "前回より少し近いようです"
        case .moveFarther: return "前回より少し遠いようです"
        case nil: return "前回の位置に合わせています"
        }
    }

    private var accentColor: Color {
        guidance.isAligned ? NodeColor.moss : NodeColor.bone
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accentColor)

            Text(message)
                .font(NodeFont.text(12, weight: .semibold))
                .foregroundStyle(accentColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            Capsule().fill(.ultraThinMaterial)
        }
        .overlay {
            if guidance.isAligned {
                Capsule().stroke(NodeColor.moss.opacity(0.6), lineWidth: 1)
            }
        }
        .animation(.easeOut(duration: 0.12), value: guidance)
    }
}

/// 端末の傾き（ロール）を視覚化する水平インジケーター。
/// 水平から ±1° 以内で moss カラーに切り替わるフィードバック付き。
struct LevelIndicator: View {
    let roll: Double

    private var normalizedRoll: Double {
        // -180...180 → 水平からのズレ角度（-90...90）に正規化
        var value = roll.truncatingRemainder(dividingBy: 180)
        if value > 90 { value -= 180 }
        if value < -90 { value += 180 }
        return value
    }

    private var isLevel: Bool { abs(normalizedRoll) < 1.0 }

    private var accentColor: Color {
        isLevel ? NodeColor.moss : NodeColor.bone
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(String(format: "%+.0f°", normalizedRoll))
                .font(NodeFont.text(12, weight: .semibold))
                .foregroundStyle(accentColor)
                .monospacedDigit()
                .frame(width: 36, alignment: .trailing)

            ZStack {
                Capsule()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: 140, height: 2)

                Capsule()
                    .fill(accentColor)
                    .frame(width: 56, height: 3)
                    .rotationEffect(.degrees(normalizedRoll))
                    .shadow(color: accentColor.opacity(0.65), radius: 3)

                Circle()
                    .fill(accentColor)
                    .frame(width: 6, height: 6)
                    .shadow(color: accentColor.opacity(0.7), radius: 2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            Capsule().fill(.ultraThinMaterial)
        }
        .animation(.easeOut(duration: 0.12), value: isLevel)
    }
}
