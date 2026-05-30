import CoreImage
import CoreVideo
import Foundation
import simd
import UIKit
import Vision

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

/// 前回の観測写真とライブフレームを Vision の画像レジストレーションで比較し、
/// 「どれだけ・どちらへ寄せるべきか」を連続値（offsetX/Y・scaleDelta）として返す。
/// UI 側で方向矢印・ターゲット点・グリーン判定に展開する。
///
/// - スレッド: 解析は内部の serial queue 上で実行する。`ingest(_:orientation:)` は
///   カメラの video data queue から呼ばれ、軽量なゲート判定のみ行ってから解析を dispatch する
///   （フレームの取りこぼし＝省電力）。
/// - 結果は `onGuidance` で main へホップして通知する。
/// - 生成 AI（Apple Intelligence）は使わず、classic VN API のみ（iOS 17 で動作）。
final class ObservationAlignmentAnalyzer: @unchecked Sendable {
    /// 解析結果の通知（main で呼ばれる）。利用開始前に main で 1 度だけ設定する。
    var onGuidance: ((AlignmentGuidance) -> Void)?

    // MARK: - チューニング定数（実機調整はここだけ触ればよい）

    enum Tuning {
        /// 解析に使う画像の長辺（px）。速度優先で十分。
        static let workingMaxDimension: CGFloat = 480
        /// フレーム解析の最小間隔（秒）。約 4fps。
        static let minInterval: TimeInterval = 0.25

        /// 平行移動: 整合（グリーン）と判定する正規化しきい値（フレーム長辺比）。緩めるとグリーンが出やすい。
        static let translationAligned: CGFloat = 0.06
        /// スケール: 整合と判定する 1 からの許容幅。緩めるとグリーンが出やすい。
        static let scaleAligned: CGFloat = 0.12
        /// 整合確定に必要な連続フレーム数。
        static let alignedStreakRequired = 2

        /// これを超える平行移動ズレは「大きくズレ」とみなし微調整ガイドを出さない。
        static let lostTranslation: CGFloat = 0.30
        /// これを超えるスケール差は「大きくズレ」とみなす。
        static let lostScale: CGFloat = 0.5
        /// レジストレーション連続失敗がこの回数に達したら searching（未捕捉）に落とす。
        static let lostFailureStreak = 3

        /// 平滑化係数（指数移動平均）。0〜1。大きいほど追従が速いがジッターも増える。
        static let smoothing: CGFloat = 0.45

        /// 「同じ場面か」判定に使うグレースケール署名の一辺（px）。小さいほど小ズレに寛容。
        static let signatureSize = 32
        /// 正規化相互相関(NCC)のしきい値。これ未満は「参照シーンが見えていない」（枠外/別被写体）とみなす。
        /// 0〜1。ライブ映像と保存写真は露出・色みが異なり相関が下がりやすいため低め。
        /// 上げると厳しく（枠外を弾きやすいが、同じ植物でも誤って弾く恐れ）。下げると寛容。
        static let minCorrelation: Float = 0.25
        /// グリーン（整合）を許可する最小相関。内容が十分一致していないと緑にしない。
        /// minCorrelation より高くする。誤グリーンが出るなら上げる。
        static let minAlignedCorrelation: Float = 0.6

        /// ズレ方向の符号補正。実機で矢印・文言の向きが逆ならこの 2 値を反転する（+1 ↔ -1）。
        /// offsetX/Y は「カメラを動かすべき方向」を意味し、UI の矢印・キャプションがこれに従う。
        static let horizontalSign: CGFloat = 1
        static let verticalSign: CGFloat = 1
    }

    // MARK: スレッド制御

    private let queue = DispatchQueue(label: "app.node.alignment", qos: .userInitiated)
    private let gate = NSLock()
    /// 解析実行中フラグ（gate 保護）。実行中はフレームを捨てる。
    private var inFlight = false
    /// 直近の取り込み時刻（gate 保護）。スロットリング用。
    private var lastIngestAt: Date = .distantPast

    // MARK: 解析状態（queue 上でのみ触る）

    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private var referencePixelBuffer: CVPixelBuffer?
    private var referenceSize: CGSize = .zero
    /// 参照画像のグレースケール署名（NCC 用、平均0・正規化前の生輝度）。
    private var referenceSignature: [Float]?
    private var alignedStreak = 0
    private var lastPublished: AlignmentGuidance = .inactive
    /// レジストレーション連続失敗カウント（searching 判定用）。
    private var failureStreak = 0
    /// 平滑化済みの連続値（EMA 状態）。初回は実測で初期化。
    private var smoothed: (x: CGFloat, y: CGFloat, scale: CGFloat)?

    // MARK: 参照画像

    /// 参照（前回写真）を設定する。`nil` で解析停止。任意スレッドから呼べる。
    func setReference(_ image: UIImage?) {
        let cgImage = image?.cgImage
        queue.async { [weak self] in
            guard let self else { return }
            self.applyReference(cgImage)
        }
    }

    private func applyReference(_ cgImage: CGImage?) {
        guard let cgImage else {
            referencePixelBuffer = nil
            referenceSize = .zero
            referenceSignature = nil
            resetState()
            publish(.inactive)
            return
        }
        let scaled = scaledPixelBuffer(from: CIImage(cgImage: cgImage))
        referencePixelBuffer = scaled?.buffer
        referenceSize = scaled?.size ?? .zero
        referenceSignature = scaled.map { grayscaleSignature(from: $0.buffer) }
        resetState()
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
        guard let reference = referencePixelBuffer, referenceSize != .zero else { return }

        let oriented = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
        guard let scaled = scaledPixelBuffer(from: oriented, matching: referenceSize) else { return }

        // 参照とフレームの正規化相互相関(NCC)。2 段階で使う:
        //  - minCorrelation 未満 → 参照シーンが見えていない（枠外/別被写体）→ searching
        //  - minAlignedCorrelation 未満 → 内容が十分一致していない → グリーンにはしない
        var correlation: Float = 1
        if let refSig = referenceSignature {
            correlation = normalizedCorrelation(refSig, grayscaleSignature(from: scaled.buffer))
        }
        if correlation < Tuning.minCorrelation {
            smoothed = nil
            alignedStreak = 0
            failureStreak = 0
            publish(AlignmentGuidance(
                state: .searching, offsetX: 0, offsetY: 0, scaleDelta: 0, isActive: true
            ))
            return
        }

        guard let metrics = registrationMetrics(reference: reference, frame: scaled.buffer) else {
            // シーンは見えているが対応点が取れない（手ブレ・低テクスチャ等）。
            // 連続失敗が続けば searching に落とすが、単発なら直近表示を維持する。
            failureStreak += 1
            if failureStreak >= Tuning.lostFailureStreak {
                smoothed = nil
                alignedStreak = 0
                publish(AlignmentGuidance(
                    state: .searching, offsetX: 0, offsetY: 0, scaleDelta: 0, isActive: true
                ))
            }
            return
        }
        failureStreak = 0
        let guidance = guidance(from: metrics, correlation: correlation)
        publish(guidance)
    }

    // MARK: Vision レジストレーション

    private struct RegistrationMetrics {
        /// フレーム長辺に対する正規化平行移動（+x = 右, +y = 下）。
        var normalizedTranslationX: CGFloat
        var normalizedTranslationY: CGFloat
        /// 拡大率（1 = 等倍, >1 = フレームが大きい=近い）。
        var scale: CGFloat
    }

    private func registrationMetrics(reference: CVPixelBuffer, frame: CVPixelBuffer) -> RegistrationMetrics? {
        let handler = VNImageRequestHandler(cvPixelBuffer: reference, options: [:])

        // 主: ホモグラフィ（平行移動＋スケール）。
        let homographic = VNHomographicImageRegistrationRequest(targetedCVPixelBuffer: frame)
        if (try? handler.perform([homographic])) != nil,
           let warp = (homographic.results?.first as? VNImageHomographicAlignmentObservation)?.warpTransform,
           let metrics = metrics(fromWarp: warp) {
            return metrics
        }

        // フォールバック: 平行移動のみ（スケールは等倍扱い）。
        let translational = VNTranslationalImageRegistrationRequest(targetedCVPixelBuffer: frame)
        if (try? handler.perform([translational])) != nil,
           let transform = (translational.results?.first as? VNImageTranslationAlignmentObservation)?.alignmentTransform {
            let longSide = max(referenceSize.width, referenceSize.height)
            guard longSide > 0 else { return nil }
            return RegistrationMetrics(
                normalizedTranslationX: CGFloat(transform.tx) / longSide,
                normalizedTranslationY: CGFloat(transform.ty) / longSide,
                scale: 1
            )
        }

        return nil
    }

    /// simd_float3x3 の warp から平行移動とスケールを抽出する。
    private func metrics(fromWarp warp: matrix_float3x3) -> RegistrationMetrics? {
        let longSide = max(referenceSize.width, referenceSize.height)
        guard longSide > 0 else { return nil }

        // 列ベクトルアクセス（column.2 が平行移動成分）。
        let tx = CGFloat(warp.columns.2.x)
        let ty = CGFloat(warp.columns.2.y)

        // 上左 2x2 の列ノルム平均をスケールとみなす。
        let col0 = hypot(CGFloat(warp.columns.0.x), CGFloat(warp.columns.0.y))
        let col1 = hypot(CGFloat(warp.columns.1.x), CGFloat(warp.columns.1.y))
        let scale = (col0 + col1) / 2

        guard tx.isFinite, ty.isFinite, scale.isFinite, scale > 0.2, scale < 5 else { return nil }

        return RegistrationMetrics(
            normalizedTranslationX: tx / longSide,
            normalizedTranslationY: ty / longSide,
            scale: scale
        )
    }

    // MARK: ズレ → ガイド

    private func guidance(from metrics: RegistrationMetrics, correlation: Float) -> AlignmentGuidance {
        // 「フレームをどちらへ寄せるべきか」を符号補正して取り出す。
        let rawX = metrics.normalizedTranslationX * Tuning.horizontalSign
        let rawY = metrics.normalizedTranslationY * Tuning.verticalSign
        let rawScale = metrics.scale - 1

        // 指数移動平均で平滑化（ジッター低減）。
        let a = Tuning.smoothing
        let prev = smoothed ?? (rawX, rawY, rawScale)
        let x = prev.x + a * (rawX - prev.x)
        let y = prev.y + a * (rawY - prev.y)
        let scale = prev.scale + a * (rawScale - prev.scale)
        smoothed = (x, y, scale)

        let translationAligned = hypot(x, y) < Tuning.translationAligned
        let scaleAligned = abs(scale) < Tuning.scaleAligned
        // グリーンには「位置・スケール一致」に加えて「内容が十分一致」も要求する。
        // これにより、背景だけ一致して被写体が違うケースの誤グリーンを防ぐ。
        let contentMatches = correlation >= Tuning.minAlignedCorrelation

        // 大きくズレ／極端なスケール差は searching（微調整ガイドを出さない）。
        // 「別の被写体／枠外」判定は process 側の NCC ゲートで済んでいる。
        let lost = hypot(x, y) > Tuning.lostTranslation || abs(scale) > Tuning.lostScale

        let state: AlignmentGuidance.State
        if lost {
            alignedStreak = 0
            state = .searching
        } else if translationAligned && scaleAligned && contentMatches {
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

    // MARK: 画像縮小

    private struct ScaledBuffer {
        let buffer: CVPixelBuffer
        let size: CGSize
    }

    /// CIImage を長辺 `workingMaxDimension` 程度（または `target` に一致）へ縮小し、CVPixelBuffer 化する。
    private func scaledPixelBuffer(from image: CIImage, matching target: CGSize? = nil) -> ScaledBuffer? {
        let extent = image.extent
        guard extent.width > 0, extent.height > 0, extent.width.isFinite, extent.height.isFinite else { return nil }

        let outputSize: CGSize
        if let target, target.width > 0, target.height > 0 {
            outputSize = target
        } else {
            let longSide = max(extent.width, extent.height)
            let factor = min(1, Tuning.workingMaxDimension / longSide)
            outputSize = CGSize(width: (extent.width * factor).rounded(),
                                height: (extent.height * factor).rounded())
        }
        guard outputSize.width >= 1, outputSize.height >= 1 else { return nil }

        let scaleX = outputSize.width / extent.width
        let scaleY = outputSize.height / extent.height
        let scaled = image
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .transformed(by: CGAffineTransform(translationX: -extent.origin.x * scaleX,
                                               y: -extent.origin.y * scaleY))

        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(outputSize.width),
            Int(outputSize.height),
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        ciContext.render(scaled, to: buffer)
        return ScaledBuffer(buffer: buffer, size: outputSize)
    }

    // MARK: 「同じ場面か」判定（NCC）

    /// BGRA の CVPixelBuffer を `signatureSize` 角のグレースケール署名（生輝度）へ落とす。
    /// CIAreaAverage 系ではなく、CIImage を小さく描いて平均輝度ベクトルを得る。
    private func grayscaleSignature(from pixelBuffer: CVPixelBuffer) -> [Float] {
        let n = Tuning.signatureSize
        let source = CIImage(cvPixelBuffer: pixelBuffer)
        let extent = source.extent
        guard extent.width > 0, extent.height > 0 else { return [] }

        // n×n へ縮小（平均化）してから描画。
        let sx = CGFloat(n) / extent.width
        let sy = CGFloat(n) / extent.height
        let small = source
            .transformed(by: CGAffineTransform(scaleX: sx, y: sy))
            .transformed(by: CGAffineTransform(translationX: -extent.origin.x * sx,
                                               y: -extent.origin.y * sy))

        var rgba = [UInt8](repeating: 0, count: n * n * 4)
        rgba.withUnsafeMutableBytes { ptr in
            guard let base = ptr.baseAddress else { return }
            ciContext.render(
                small,
                toBitmap: base,
                rowBytes: n * 4,
                bounds: CGRect(x: 0, y: 0, width: n, height: n),
                format: .RGBA8,
                colorSpace: CGColorSpaceCreateDeviceRGB()
            )
        }

        var signature = [Float](repeating: 0, count: n * n)
        for i in 0..<(n * n) {
            let r = Float(rgba[i * 4])
            let g = Float(rgba[i * 4 + 1])
            let b = Float(rgba[i * 4 + 2])
            signature[i] = 0.299 * r + 0.587 * g + 0.114 * b
        }
        return signature
    }

    /// 2 つの署名の正規化相互相関（-1〜1）。長さ不一致・無分散時は 0。
    private func normalizedCorrelation(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        let count = Float(a.count)
        let meanA = a.reduce(0, +) / count
        let meanB = b.reduce(0, +) / count

        var cov: Float = 0, varA: Float = 0, varB: Float = 0
        for i in 0..<a.count {
            let da = a[i] - meanA
            let db = b[i] - meanB
            cov += da * db
            varA += da * da
            varB += db * db
        }
        let denom = (varA * varB).squareRoot()
        guard denom > 0 else { return 0 }
        return cov / denom
    }

    // MARK: 通知

    private func resetState() {
        alignedStreak = 0
        failureStreak = 0
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
