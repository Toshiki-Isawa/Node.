import CoreImage
import CoreVideo
import Foundation
import simd
import UIKit
import Vision

/// 観測撮影時のガイド状態。前回写真と現在フレームのズレを連続値で保持し、
/// UI 側で大きな方向矢印・ターゲット点・グリーン判定に展開する。
struct AlignmentGuidance: Equatable {
    /// 正規化水平オフセット（フレーム長辺比）= カメラを動かすべき方向。+ = 右。
    var offsetX: CGFloat
    /// 正規化垂直オフセット = カメラを動かすべき方向。+ = 下。
    var offsetY: CGFloat
    /// スケール差（0 = 等倍, + = 近すぎ／引くべき, − = 遠すぎ／寄るべき）。
    var scaleDelta: CGFloat
    /// おおよそ位置が合った状態。グリーンマーク表示の条件。
    var isAligned: Bool
    /// 参照画像があり解析中。`false` のときはガイド非表示。
    var isActive: Bool

    static let inactive = AlignmentGuidance(
        offsetX: 0, offsetY: 0, scaleDelta: 0, isAligned: false, isActive: false
    )

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

        /// 平滑化係数（指数移動平均）。0〜1。大きいほど追従が速いがジッターも増える。
        static let smoothing: CGFloat = 0.45

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
    private var alignedStreak = 0
    private var lastPublished: AlignmentGuidance = .inactive
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
            resetState()
            publish(.inactive)
            return
        }
        let scaled = scaledPixelBuffer(from: CIImage(cgImage: cgImage))
        referencePixelBuffer = scaled?.buffer
        referenceSize = scaled?.size ?? .zero
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

        guard let metrics = registrationMetrics(reference: reference, frame: scaled.buffer) else {
            // 低テクスチャ等で失敗。判定保留（直近表示は維持）。
            return
        }
        let guidance = guidance(from: metrics)
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

    private func guidance(from metrics: RegistrationMetrics) -> AlignmentGuidance {
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

        var isAligned = false
        if translationAligned && scaleAligned {
            alignedStreak += 1
            isAligned = alignedStreak >= Tuning.alignedStreakRequired
        } else {
            alignedStreak = 0
        }

        return AlignmentGuidance(
            offsetX: x,
            offsetY: y,
            scaleDelta: scale,
            isAligned: isAligned,
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

    // MARK: 通知

    private func resetState() {
        alignedStreak = 0
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
