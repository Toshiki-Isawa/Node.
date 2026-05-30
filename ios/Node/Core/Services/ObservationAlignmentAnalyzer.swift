import CoreImage
import CoreVideo
import Foundation
import simd
import UIKit
import Vision

/// 観測撮影時のガイド状態。前回写真と現在フレームのズレを 1 軸の指示にまとめる。
struct AlignmentGuidance: Equatable {
    enum Hint: Equatable {
        case moveLeft
        case moveRight
        case moveUp
        case moveDown
        case moveCloser
        case moveFarther
    }

    /// 提示する指示（ズレが最大の 1 軸のみ）。`nil` かつ `isAligned == false` は判定保留。
    var primaryHint: Hint?
    /// おおよそ位置が合った状態。グリーンマーク表示の条件。
    var isAligned: Bool
    /// 参照画像があり解析中。`false` のときはガイド非表示。
    var isActive: Bool

    static let inactive = AlignmentGuidance(primaryHint: nil, isAligned: false, isActive: false)
}

/// 前回の観測写真とライブフレームを Vision の画像レジストレーションで比較し、
/// 「もう少し右/左/上/下」「少し遠い/近い」といったガイドへ変換する。
///
/// - スレッド: 解析は内部の serial queue 上で実行する。`ingest(_:orientation:)` は
///   カメラの video data queue から呼ばれ、軽量なゲート判定のみ行ってから解析を dispatch する
///   （フレームの取りこぼし＝省電力）。
/// - 結果は `onGuidance` で main へホップして通知する。
/// - 生成 AI（Apple Intelligence）は使わず、classic VN API のみ（iOS 17 で動作）。
final class ObservationAlignmentAnalyzer: @unchecked Sendable {
    /// 解析結果の通知（main で呼ばれる）。利用開始前に main で 1 度だけ設定する。
    var onGuidance: ((AlignmentGuidance) -> Void)?

    // MARK: チューニング定数

    /// 解析に使う画像の長辺（px）。速度優先で十分。
    private let workingMaxDimension: CGFloat = 480
    /// フレーム解析の最小間隔（秒）。約 4fps。
    private let minInterval: TimeInterval = 0.25
    /// 平行移動: ズレと判定する正規化しきい値（フレーム長辺比）。
    private let translationEnter: CGFloat = 0.06
    /// 平行移動: 整合と判定する正規化しきい値。
    private let translationExit: CGFloat = 0.03
    /// スケール: 整合と判定する 1 からの許容幅。
    private let scaleTolerance: CGFloat = 0.08
    /// 整合確定に必要な連続フレーム数。
    private let alignedStreakRequired = 2
    /// 同一ヒントを保持する最小時間（秒）。ちらつき防止。
    private let hintMinHold: TimeInterval = 0.5

    /// ズレ方向 → ヒントの符号補正。実機キャリブレーションはこの 2 値だけ反転すれば直る。
    /// `tx > 0`（参照に対しフレームが右へずれている）のとき、ユーザーは左へ寄せるべき → moveLeft。
    private let horizontalSign: CGFloat = 1
    private let verticalSign: CGFloat = 1

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
    private var lastHintChangedAt: Date = .distantPast

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
        if inFlight || now.timeIntervalSince(lastIngestAt) < minInterval {
            gate.unlock()
            return
        }
        lastIngestAt = now
        inFlight = true
        gate.unlock()

        queue.async { [weak self] in
            guard let self else { return }
            self.process(pixelBuffer, orientation: orientation, now: now)
            self.gate.lock()
            self.inFlight = false
            self.gate.unlock()
        }
    }

    private func process(_ pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, now: Date) {
        guard let reference = referencePixelBuffer, referenceSize != .zero else { return }

        let oriented = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
        guard let scaled = scaledPixelBuffer(from: oriented, matching: referenceSize) else { return }

        guard let metrics = registrationMetrics(reference: reference, frame: scaled.buffer) else {
            // 低テクスチャ等で失敗。判定保留（直近表示は維持）。
            return
        }
        let guidance = guidance(from: metrics, now: now)
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

    private func guidance(from metrics: RegistrationMetrics, now: Date) -> AlignmentGuidance {
        let dx = metrics.normalizedTranslationX
        let dy = metrics.normalizedTranslationY
        let scaleDelta = metrics.scale - 1

        let translationAligned = abs(dx) < translationExit && abs(dy) < translationExit
        let scaleAligned = abs(scaleDelta) < scaleTolerance

        if translationAligned && scaleAligned {
            alignedStreak += 1
            if alignedStreak >= alignedStreakRequired {
                return AlignmentGuidance(primaryHint: nil, isAligned: true, isActive: true)
            }
            // 整合確定前は直近のヒントを維持（ちらつき防止）。
            return lastPublished.isActive
                ? lastPublished
                : AlignmentGuidance(primaryHint: nil, isAligned: false, isActive: true)
        }

        alignedStreak = 0

        // ズレ最大の 1 軸を選ぶ。スケールは平行移動と同尺度に換算して比較する。
        let horizontalMag = abs(dx)
        let verticalMag = abs(dy)
        let scaleMag = abs(scaleDelta) >= scaleTolerance ? abs(scaleDelta) : 0
        let scaleComparable = scaleMag * (translationEnter / scaleTolerance)

        var candidate: AlignmentGuidance.Hint?
        let maxMag = max(horizontalMag, verticalMag, scaleComparable)

        if maxMag == scaleComparable && scaleMag > 0 {
            candidate = scaleDelta > 0 ? .moveFarther : .moveCloser
        } else if maxMag == horizontalMag && horizontalMag >= translationEnter {
            candidate = (dx * horizontalSign) > 0 ? .moveLeft : .moveRight
        } else if verticalMag >= translationEnter {
            candidate = (dy * verticalSign) > 0 ? .moveUp : .moveDown
        }

        guard let hint = candidate else {
            // しきい値の谷間（enter 未満・exit 超）。直近表示を維持。
            return lastPublished.isActive
                ? lastPublished
                : AlignmentGuidance(primaryHint: nil, isAligned: false, isActive: true)
        }

        // 最小表示時間: 別ヒントへ切り替えるには hintMinHold 経過が必要。
        if let previous = lastPublished.primaryHint,
           previous != hint,
           now.timeIntervalSince(lastHintChangedAt) < hintMinHold {
            return lastPublished
        }

        if lastPublished.primaryHint != hint {
            lastHintChangedAt = now
        }
        return AlignmentGuidance(primaryHint: hint, isAligned: false, isActive: true)
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
            let factor = min(1, workingMaxDimension / longSide)
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
        lastHintChangedAt = .distantPast
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
