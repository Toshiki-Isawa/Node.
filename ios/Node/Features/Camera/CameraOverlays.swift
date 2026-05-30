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

/// 前回写真との位置合わせガイド（観測枠の中央に描く照準型 UI）。
/// - 中央の固定ターゲットリング（合わせるべき位置）
/// - 現在位置を示す可動リング（offset ぶんずれ、scaleDelta で径が変わる＝遠近）
/// - 中央へ向かう大きな方向矢印（複合方向をベクトルで表現）
/// - おおよそ重なると moss 色＋チェックに切り替わる
struct AlignmentGuideOverlay: View {
    let guidance: AlignmentGuidance
    /// 観測枠の矩形（オーバーレイ座標系）。中央と移動量スケールの基準。
    let frame: CGRect

    /// 正規化オフセットを画面ポイントへ変換する係数（枠長辺基準・誇張ゲイン込み）。
    private var displayGain: CGFloat {
        max(frame.width, frame.height) * 1.1
    }

    /// 可動リングの中心（現在の被写体位置）。
    /// offset は「カメラをどちらへ動かすべきか」のベクトル。被写体はその逆側にあるので符号を反転。
    private var currentCenter: CGPoint {
        CGPoint(
            x: frame.midX - guidance.offsetX * displayGain,
            y: frame.midY - guidance.offsetY * displayGain
        )
    }

    /// 可動リングの径（scaleDelta>0=近い=大きく）。
    private var currentRingDiameter: CGFloat {
        let base: CGFloat = 84
        return max(40, min(160, base * (1 + guidance.scaleDelta)))
    }

    private var accent: Color {
        guidance.isAligned ? NodeColor.moss : NodeColor.bone
    }

    /// 方向矢印の表示判定（ほぼ合っていれば出さない）。
    private var showsArrow: Bool {
        !guidance.isAligned && guidance.translationMagnitude > 0.02
    }

    var body: some View {
        ZStack {
            // 固定ターゲット（合わせるべき位置）。十字つきリング。
            Circle()
                .stroke(accent.opacity(0.9), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                .frame(width: 84, height: 84)
                .position(x: frame.midX, y: frame.midY)

            crosshair
                .stroke(accent.opacity(0.9), lineWidth: 1.5)

            // 現在位置リング（実映像のズレ）。
            Circle()
                .stroke(NodeColor.bone.opacity(0.55), lineWidth: 2)
                .frame(width: currentRingDiameter, height: currentRingDiameter)
                .position(currentCenter)

            // 中央へ導く大きな方向矢印（複合方向はベクトルで）。
            if showsArrow {
                directionArrow
            }

            // 整合チェック。
            if guidance.isAligned {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(NodeColor.moss)
                    .position(x: frame.midX, y: frame.midY)
                    .transition(.scale.combined(with: .opacity))
            }

            // 枠下の文言キャプション（補助）。
            caption
                .position(x: frame.midX, y: frame.maxY + 28)
        }
        .animation(.easeOut(duration: 0.16), value: guidance)
        .allowsHitTesting(false)
    }

    private var caption: some View {
        Text(captionText)
            .font(NodeFont.text(13, weight: .semibold))
            .foregroundStyle(accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background { Capsule().fill(.ultraThinMaterial) }
    }

    /// 連続値から主要なズレ方向を 1 つ選び、文言キーへ変換する（補助表示）。
    private var captionText: LocalizedStringKey {
        if guidance.isAligned { return "位置が合いました" }

        let horizontal = abs(guidance.offsetX)
        let vertical = abs(guidance.offsetY)
        // スケールを平行移動と同尺度へ換算して比較。
        let scaleComparable = abs(guidance.scaleDelta) * 0.5
        let maxMag = max(horizontal, vertical, scaleComparable)

        guard maxMag > 0.02 else { return "前回の位置に合わせています" }

        if maxMag == scaleComparable {
            // scaleDelta>0 = 近すぎ → 引く（遠ざける）。
            return guidance.scaleDelta > 0 ? "前回より少し近いようです" : "前回より少し遠いようです"
        }
        if maxMag == horizontal {
            // offsetX = カメラを動かすべき方向。
            return guidance.offsetX > 0 ? "もう少し右です" : "もう少し左です"
        }
        return guidance.offsetY > 0 ? "もう少し下です" : "もう少し上です"
    }

    private var crosshair: Path {
        Path { p in
            let c = CGPoint(x: frame.midX, y: frame.midY)
            p.move(to: CGPoint(x: c.x - 10, y: c.y))
            p.addLine(to: CGPoint(x: c.x + 10, y: c.y))
            p.move(to: CGPoint(x: c.x, y: c.y - 10))
            p.addLine(to: CGPoint(x: c.x, y: c.y + 10))
        }
    }

    /// 中央から、合わせるべき方向（offset の向き）へ伸びる矢印。
    private var directionArrow: some View {
        let angle = atan2(guidance.offsetY, guidance.offsetX)
        let length = min(frame.width, frame.height) * 0.34
        return Image(systemName: "arrow.right")
            .font(.system(size: 34, weight: .bold))
            .foregroundStyle(NodeColor.bone)
            .shadow(color: .black.opacity(0.4), radius: 3)
            .rotationEffect(.radians(angle))
            .position(
                x: frame.midX + cos(angle) * length,
                y: frame.midY + sin(angle) * length
            )
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
