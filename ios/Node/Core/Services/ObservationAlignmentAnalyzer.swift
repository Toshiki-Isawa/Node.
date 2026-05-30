import CoreImage
import CoreVideo
import Foundation
import UIKit

/// 観測撮影時のガイド状態。前回写真と現在フレームのズレを連続値で保持し、
/// UI 側で方向矢印・リングサイズ・グリーン判定に展開する。
struct AlignmentGuidance: Equatable {
    enum State: Equatable {
        /// 大きくズレ／未捕捉。微調整ガイドは出さず「フレームに収めてください」を促す。
        case searching
        /// 微調整ガイド中（矢印・リング表示）。
        case guiding
        /// おおよそ整合（グリーン）。
        case aligned
    }

    var state: State
    /// 正規化水平オフセット（フレーム長辺比）= カメラを動かすべき方向。+ = 右。
    var offsetX: CGFloat
    /// 正規化垂直オフセット = カメラを動かすべき方向。+ = 下。
    var offsetY: CGFloat
    /// スケール差（0 = 等倍, + = 近すぎ／引くべき, − = 遠すぎ／寄るべき）。
    var scaleDelta: CGFloat
    /// 参照画像があり解析中。`false` のときはガイド非表示。
    var isActive: Bool

    static let inactive = AlignmentGuidance(
        state: .searching, offsetX: 0, offsetY: 0, scaleDelta: 0, isActive: false
    )

    /// おおよそ位置が合った状態。グリーンマーク表示の条件。
    var isAligned: Bool { state == .aligned }

    /// 平行移動ズレの大きさ（正規化）。
    var translationMagnitude: CGFloat { hypot(offsetX, offsetY) }
}

/// 前回の観測写真とライブフレームを比較し、「どれだけ・どちらへ寄せるべきか」を
/// 連続値（offsetX/Y・scaleDelta）として返す。
///
/// ## アルゴリズム
/// Vision の画像レジストレーションは同一カメラの連写向けで、保存写真 vs ライブ映像の
/// ようなクロスドメイン（露出・WB・色みが違う）では失敗や near-identity を返しやすい。
/// そこで古典 CV パイプラインに置き換えている:
///  1. **観測枠クロップ**: ライブフレームを参照写真と同じアスペクトへセンタークロップし、
///     視野（FOV）を揃える（保存写真は観測枠にクロップ済みのため）。
///  2. **勾配エッジ化**: グレースケール→Sobel 勾配強度。照明・露出差に不変にする。
///  3. **多スケール ZNCC テンプレートマッチング**: 参照中央のテンプレートを、複数スケール×
///     平行移動の探索空間でフレームに重ね、ゼロ平均正規化相互相関(ZNCC)のピークを探す
///     （coarse-to-fine）。ピーク位置→平行移動、最良スケール→遠近、ピーク値→信頼度。
///
/// - スレッド: 解析は内部の serial queue 上で実行する。結果は `onGuidance` で main へ通知。
/// - 生成 AI（Apple Intelligence）は使わない。iOS 17 で動作。
final class ObservationAlignmentAnalyzer: @unchecked Sendable {
    /// 解析結果の通知（main で呼ばれる）。利用開始前に main で 1 度だけ設定する。
    var onGuidance: ((AlignmentGuidance) -> Void)?

    // MARK: - チューニング定数（実機調整はここだけ触ればよい）

    enum Tuning {
        /// エッジ画像の長辺（px）。大きいほど精度が上がるが重い。
        static let workingLongSide: CGFloat = 200
        /// フレーム解析の最小間隔（秒）。約 4fps。
        static let minInterval: TimeInterval = 0.25

        /// テンプレート格子の一辺（サンプル数）。中央領域を G×G に等間隔サンプル。
        static let templateGrid = 40
        /// テンプレートが覆う参照中央領域の割合（0〜1）。
        static let templateCenterFraction: CGFloat = 0.6

        /// 探索するスケール候補（フレーム上で参照内容が何倍に見えるか）。
        static let scales: [CGFloat] = [0.72, 0.82, 0.9, 1.0, 1.1, 1.22, 1.38]
        /// 平行移動の探索範囲（長辺比）。±この割合。
        static let searchRangeFraction: CGFloat = 0.24
        /// coarse 探索のステップ（px）。
        static let coarseStep = 4
        /// fine 探索の片側範囲（px, coarseStep 近傍）。
        static let fineSpan = 4

        /// 「参照シーンが見えている」とみなす最小スコア（ZNCC ピーク）。未満は searching。
        /// 上げると枠外を弾きやすいが、同じ植物でも誤って弾く恐れ。下げると寛容。
        static let minSceneScore: Float = 0.18
        /// グリーン（整合）を許可する最小スコア。内容が十分一致していないと緑にしない。
        /// minSceneScore より高くする。誤グリーンが出るなら上げる。
        static let minAlignedScore: Float = 0.45

        /// 平行移動: 整合（グリーン）と判定する正規化しきい値（長辺比）。緩めるとグリーンが出やすい。
        static let translationAligned: CGFloat = 0.05
        /// スケール: 整合と判定する 1 からの許容幅。緩めるとグリーンが出やすい。
        static let scaleAligned: CGFloat = 0.1
        /// 整合確定に必要な連続フレーム数。
        static let alignedStreakRequired = 2

        /// 平滑化係数（指数移動平均）。0〜1。大きいほど追従が速いがジッターも増える。
        static let smoothing: CGFloat = 0.5
        /// シーン未検出（low score）が続いて searching に落とす連続回数。
        static let lostScoreStreak = 2

        /// ズレ方向の符号補正。実機で矢印・文言の向きが逆ならこの 2 値を反転する（+1 ↔ -1）。
        /// offsetX/Y は「カメラを動かすべき方向」を意味し、UI の矢印・キャプションがこれに従う。
        static let horizontalSign: CGFloat = 1
        static let verticalSign: CGFloat = 1
    }

    // MARK: スレッド制御

    private let queue = DispatchQueue(label: "app.node.alignment", qos: .userInitiated)
    private let gate = NSLock()
    private var inFlight = false
    private var lastIngestAt: Date = .distantPast

    // MARK: 解析状態（queue 上でのみ触る）

    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    /// 参照（前回写真）のエッジ画像。
    private var referenceEdge: EdgeImage?
    /// 参照中央から作ったテンプレート。
    private var template: Template?
    private var alignedStreak = 0
    private var lowScoreStreak = 0
    private var lastPublished: AlignmentGuidance = .inactive
    /// 平滑化済みの連続値（EMA 状態）。
    private var smoothed: (x: CGFloat, y: CGFloat, scale: CGFloat)?

    // MARK: 参照画像

    /// 参照（前回写真）を設定する。`nil` で解析停止。任意スレッドから呼べる。
    func setReference(_ image: UIImage?) {
        let cgImage = image?.cgImage
        queue.async { [weak self] in
            self?.applyReference(cgImage)
        }
    }

    private func applyReference(_ cgImage: CGImage?) {
        resetState()
        guard let cgImage else {
            referenceEdge = nil
            template = nil
            publish(.inactive)
            return
        }
        // 参照はアスペクトを保ったまま長辺 workingLongSide のエッジ画像に。
        let aspect = CGFloat(cgImage.width) / CGFloat(max(1, cgImage.height))
        let (w, h) = workingDimensions(aspect: aspect)
        referenceEdge = edgeImage(from: CIImage(cgImage: cgImage), width: w, height: h, cropAspect: nil)
        template = referenceEdge.flatMap(makeTemplate)
    }

    // MARK: フレーム取り込み

    /// video data queue から呼ばれる。スロットリング＋実行中ドロップしてから解析へ回す。
    func ingest(_ pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) {
        gate.lock()
        let now = Date()
        if inFlight || now.timeIntervalSince(lastIngestAt) < Tuning.minInterval {
            gate.unlock()
            return
        }
        lastIngestAt = now
        inFlight = true
        gate.unlock()

        queue.async { [weak self] in
            guard let self else { return }
            self.process(pixelBuffer, orientation: orientation)
            self.gate.lock()
            self.inFlight = false
            self.gate.unlock()
        }
    }

    private func process(_ pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) {
        guard let reference = referenceEdge, let template else { return }

        // フレームを参照と同じアスペクト・同じ寸法のエッジ画像に（センタークロップで FOV を揃える）。
        let aspect = CGFloat(reference.w) / CGFloat(reference.h)
        let oriented = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
        guard let frame = edgeImage(from: oriented, width: reference.w, height: reference.h, cropAspect: aspect) else {
            return
        }

        guard let match = bestMatch(template: template, in: frame) else {
            handleLowScore()
            return
        }

        // スコアが低い＝参照シーンが見えていない（枠外/別被写体）。
        if match.score < Tuning.minSceneScore {
            handleLowScore()
            return
        }
        lowScoreStreak = 0

        let longSide = CGFloat(max(frame.w, frame.h))
        let rawX = (match.dx / longSide) * Tuning.horizontalSign
        let rawY = (match.dy / longSide) * Tuning.verticalSign
        let rawScale = match.scale - 1

        publish(guidance(rawX: rawX, rawY: rawY, rawScale: rawScale, score: match.score))
    }

    private func handleLowScore() {
        lowScoreStreak += 1
        if lowScoreStreak >= Tuning.lostScoreStreak {
            smoothed = nil
            alignedStreak = 0
            publish(AlignmentGuidance(
                state: .searching, offsetX: 0, offsetY: 0, scaleDelta: 0, isActive: true
            ))
        }
    }

    // MARK: ズレ → ガイド

    private func guidance(rawX: CGFloat, rawY: CGFloat, rawScale: CGFloat, score: Float) -> AlignmentGuidance {
        // 指数移動平均で平滑化（ジッター低減）。
        let a = Tuning.smoothing
        let prev = smoothed ?? (rawX, rawY, rawScale)
        let x = prev.x + a * (rawX - prev.x)
        let y = prev.y + a * (rawY - prev.y)
        let scale = prev.scale + a * (rawScale - prev.scale)
        smoothed = (x, y, scale)

        let translationAligned = hypot(x, y) < Tuning.translationAligned
        let scaleAligned = abs(scale) < Tuning.scaleAligned
        let contentMatches = score >= Tuning.minAlignedScore

        let state: AlignmentGuidance.State
        if translationAligned && scaleAligned && contentMatches {
            alignedStreak += 1
            state = alignedStreak >= Tuning.alignedStreakRequired ? .aligned : .guiding
        } else {
            alignedStreak = 0
            state = .guiding
        }

        return AlignmentGuidance(
            state: state,
            offsetX: x,
            offsetY: y,
            scaleDelta: scale,
            isActive: true
        )
    }

    // MARK: - エッジ画像

    /// グレースケール Sobel 勾配強度の画像。
    private struct EdgeImage {
        let w: Int
        let h: Int
        var px: [Float]
    }

    private func workingDimensions(aspect: CGFloat) -> (Int, Int) {
        let long = Tuning.workingLongSide
        if aspect >= 1 {
            return (Int(long.rounded()), Int((long / aspect).rounded()))
        } else {
            return (Int((long * aspect).rounded()), Int(long.rounded()))
        }
    }

    /// CIImage を必要なら `cropAspect` でセンタークロップ→ w×h へ縮小→輝度→Sobel 勾配。
    private func edgeImage(from image: CIImage, width: Int, height: Int, cropAspect: CGFloat?) -> EdgeImage? {
        guard width > 2, height > 2 else { return nil }
        var src = image
        let extent = src.extent
        guard extent.width > 0, extent.height > 0, extent.width.isFinite, extent.height.isFinite else { return nil }

        // センタークロップ（FOV を参照に合わせる）。
        var cropRect = extent
        if let cropAspect {
            let srcAspect = extent.width / extent.height
            if srcAspect > cropAspect {
                let cw = extent.height * cropAspect
                cropRect = CGRect(x: extent.midX - cw / 2, y: extent.minY, width: cw, height: extent.height)
            } else {
                let ch = extent.width / cropAspect
                cropRect = CGRect(x: extent.minX, y: extent.midY - ch / 2, width: extent.width, height: ch)
            }
            src = src.cropped(to: cropRect)
        }

        let sx = CGFloat(width) / cropRect.width
        let sy = CGFloat(height) / cropRect.height
        let scaled = src
            .transformed(by: CGAffineTransform(scaleX: sx, y: sy))
            .transformed(by: CGAffineTransform(translationX: -cropRect.origin.x * sx,
                                               y: -cropRect.origin.y * sy))

        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        rgba.withUnsafeMutableBytes { ptr in
            guard let base = ptr.baseAddress else { return }
            ciContext.render(
                scaled,
                toBitmap: base,
                rowBytes: width * 4,
                bounds: CGRect(x: 0, y: 0, width: width, height: height),
                format: .RGBA8,
                colorSpace: CGColorSpaceCreateDeviceRGB()
            )
        }

        // 輝度。
        var lum = [Float](repeating: 0, count: width * height)
        for i in 0..<(width * height) {
            let r = Float(rgba[i * 4])
            let g = Float(rgba[i * 4 + 1])
            let b = Float(rgba[i * 4 + 2])
            lum[i] = 0.299 * r + 0.587 * g + 0.114 * b
        }

        // Sobel 勾配強度（照明不変）。
        var edge = [Float](repeating: 0, count: width * height)
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let i = y * width + x
                let tl = lum[i - width - 1], tc = lum[i - width], tr = lum[i - width + 1]
                let ml = lum[i - 1], mr = lum[i + 1]
                let bl = lum[i + width - 1], bc = lum[i + width], br = lum[i + width + 1]
                let gx = (tr + 2 * mr + br) - (tl + 2 * ml + bl)
                let gy = (bl + 2 * bc + br) - (tl + 2 * tc + tr)
                edge[i] = (gx * gx + gy * gy).squareRoot()
            }
        }
        return EdgeImage(w: width, h: height, px: edge)
    }

    // MARK: - テンプレートマッチング

    /// 参照中央から等間隔サンプルしたテンプレート（ZNCC 用に平均0化済み）。
    private struct Template {
        let count: Int
        /// 参照中心からの相対座標（px）。
        let relX: [CGFloat]
        let relY: [CGFloat]
        /// 平均を引いたテンプレート値。
        let centered: [Float]
        /// Σ centered²（ZNCC 分母用）。
        let sumSq: Float
        let refCenterX: CGFloat
        let refCenterY: CGFloat
    }

    private func makeTemplate(from edge: EdgeImage) -> Template? {
        let g = Tuning.templateGrid
        guard edge.w > g, edge.h > g else { return nil }

        let cx = CGFloat(edge.w) / 2
        let cy = CGFloat(edge.h) / 2
        let halfW = CGFloat(edge.w) * Tuning.templateCenterFraction / 2
        let halfH = CGFloat(edge.h) * Tuning.templateCenterFraction / 2

        var relX = [CGFloat](); relX.reserveCapacity(g * g)
        var relY = [CGFloat](); relY.reserveCapacity(g * g)
        var values = [Float](); values.reserveCapacity(g * g)

        for b in 0..<g {
            let fy = CGFloat(b) / CGFloat(g - 1) - 0.5   // -0.5...0.5
            let ry = fy * 2 * halfH
            for a in 0..<g {
                let fx = CGFloat(a) / CGFloat(g - 1) - 0.5
                let rx = fx * 2 * halfW
                relX.append(rx)
                relY.append(ry)
                values.append(sampleBilinear(edge, x: cx + rx, y: cy + ry))
            }
        }

        let n = Float(values.count)
        let mean = values.reduce(0, +) / n
        var centered = [Float](repeating: 0, count: values.count)
        var sumSq: Float = 0
        for i in 0..<values.count {
            let c = values[i] - mean
            centered[i] = c
            sumSq += c * c
        }
        guard sumSq > 0 else { return nil }

        return Template(
            count: values.count,
            relX: relX, relY: relY,
            centered: centered, sumSq: sumSq,
            refCenterX: cx, refCenterY: cy
        )
    }

    private struct Match {
        let score: Float
        let dx: CGFloat
        let dy: CGFloat
        let scale: CGFloat
    }

    /// 多スケール×平行移動でテンプレートをフレームに重ね、ZNCC ピークを探す（coarse-to-fine）。
    private func bestMatch(template t: Template, in frame: EdgeImage) -> Match? {
        let fcx = CGFloat(frame.w) / 2
        let fcy = CGFloat(frame.h) / 2
        let range = CGFloat(max(frame.w, frame.h)) * Tuning.searchRangeFraction
        let coarse = Tuning.coarseStep

        var best: Match?

        func evaluate(scale: CGFloat, dx: CGFloat, dy: CGFloat) -> Float {
            zncc(template: t, frame: frame, fcx: fcx + dx, fcy: fcy + dy, scale: scale)
        }

        // coarse: 各スケール×粗いグリッド。
        let steps = Int((range / CGFloat(coarse)).rounded())
        for scale in Tuning.scales {
            var iy = -steps
            while iy <= steps {
                let dy = CGFloat(iy * coarse)
                var ix = -steps
                while ix <= steps {
                    let dx = CGFloat(ix * coarse)
                    let s = evaluate(scale: scale, dx: dx, dy: dy)
                    if best == nil || s > best!.score {
                        best = Match(score: s, dx: dx, dy: dy, scale: scale)
                    }
                    ix += 1
                }
                iy += 1
            }
        }

        guard var refined = best else { return nil }

        // fine: 最良の近傍を 1px ステップで精緻化（平行移動のみ）。
        let span = Tuning.fineSpan
        var dy = refined.dy - CGFloat(span)
        while dy <= refined.dy + CGFloat(span) {
            var dx = refined.dx - CGFloat(span)
            while dx <= refined.dx + CGFloat(span) {
                let s = evaluate(scale: refined.scale, dx: dx, dy: dy)
                if s > refined.score {
                    refined = Match(score: s, dx: dx, dy: dy, scale: refined.scale)
                }
                dx += 1
            }
            dy += 1
        }
        return refined
    }

    /// テンプレートをフレーム上の (fcx,fcy) 中心・倍率 scale で重ねたときの ZNCC（-1〜1）。
    private func zncc(template t: Template, frame: EdgeImage, fcx: CGFloat, fcy: CGFloat, scale: CGFloat) -> Float {
        let n = t.count
        var samples = [Float](repeating: 0, count: n)
        var sum: Float = 0
        for i in 0..<n {
            let fx = fcx + t.relX[i] * scale
            let fy = fcy + t.relY[i] * scale
            let v = sampleBilinear(frame, x: fx, y: fy)
            samples[i] = v
            sum += v
        }
        let mean = sum / Float(n)

        var num: Float = 0
        var frameSS: Float = 0
        for i in 0..<n {
            let fc = samples[i] - mean
            num += t.centered[i] * fc
            frameSS += fc * fc
        }
        let denom = (t.sumSq * frameSS).squareRoot()
        guard denom > 0 else { return 0 }
        return num / denom
    }

    /// エッジ画像をバイリニア補間でサンプル（範囲外はエッジクランプ）。
    private func sampleBilinear(_ img: EdgeImage, x: CGFloat, y: CGFloat) -> Float {
        let cx = min(max(x, 0), CGFloat(img.w - 1))
        let cy = min(max(y, 0), CGFloat(img.h - 1))
        let x0 = Int(cx), y0 = Int(cy)
        let x1 = min(x0 + 1, img.w - 1)
        let y1 = min(y0 + 1, img.h - 1)
        let fx = Float(cx - CGFloat(x0))
        let fy = Float(cy - CGFloat(y0))
        let p00 = img.px[y0 * img.w + x0]
        let p10 = img.px[y0 * img.w + x1]
        let p01 = img.px[y1 * img.w + x0]
        let p11 = img.px[y1 * img.w + x1]
        let top = p00 + (p10 - p00) * fx
        let bottom = p01 + (p11 - p01) * fx
        return top + (bottom - top) * fy
    }

    // MARK: 通知

    private func resetState() {
        alignedStreak = 0
        lowScoreStreak = 0
        lastPublished = .inactive
        smoothed = nil
    }

    private func publish(_ guidance: AlignmentGuidance) {
        guard guidance != lastPublished else { return }
        lastPublished = guidance
        let callback = onGuidance
        DispatchQueue.main.async {
            callback?(guidance)
        }
    }
}
