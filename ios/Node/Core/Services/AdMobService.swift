import AppTrackingTransparency
import Foundation
import GoogleMobileAds
import Network
import UIKit
import UserMessagingPlatform

enum AdMobLoadState: Equatable {
    case idle
    case loading
    case ready
    case failed
    case presenting
}

enum AdMobRewardResult: Equatable {
    case completed
    case dismissed
    case failed
    case offline
    case fallbackUnlock
}

@MainActor
final class AdMobService: ObservableObject {
    static let maxLoadRetries = 3

    @Published private(set) var state: AdMobLoadState = .idle
    @Published private(set) var loadRetryCount = 0

    private let analyticsService: AnalyticsService
    private var rewardedAd: GADRewardedAd?
    private var isSDKStarted = false
    private var isConsentRequested = false

    init(analyticsService: AnalyticsService) {
        self.analyticsService = analyticsService
    }

    var hasReachedRetryLimit: Bool {
        loadRetryCount >= Self.maxLoadRetries
    }

    func resetForNewExport() {
        rewardedAd = nil
        state = .idle
        loadRetryCount = 0
    }

    func preloadRewardedAd(plan: UserPlan, isRetry: Bool = false) async {
        guard plan.showsExportAds else { return }

        guard NetworkMonitor.shared.isConnected else {
            state = .failed
            return
        }

        if isRetry {
            loadRetryCount += 1
            analyticsService.capture(.adRewardedRetry, plan: plan, retryCount: loadRetryCount)
        }

        if hasReachedRetryLimit {
            state = .failed
            analyticsService.capture(.adRewardedFallbackUnlock, plan: plan, retryCount: loadRetryCount)
            return
        }

        await startSDKIfNeeded()
        state = .loading
        analyticsService.capture(.adRewardedPreloadStarted, plan: plan, retryCount: loadRetryCount)

        do {
            let ad = try await loadRewardedAd()
            rewardedAd = ad
            state = .ready
        } catch {
            rewardedAd = nil
            state = .failed
            analyticsService.capture(
                .adRewardedPreloadFailed,
                plan: plan,
                retryCount: loadRetryCount,
                errorCode: (error as NSError).code
            )
        }
    }

    func showRewardedAd(plan: UserPlan) async -> AdMobRewardResult {
        guard plan.showsExportAds else { return .completed }

        if hasReachedRetryLimit {
            analyticsService.capture(.adRewardedFallbackUnlock, plan: plan, retryCount: loadRetryCount)
            return .fallbackUnlock
        }

        guard NetworkMonitor.shared.isConnected else {
            return .offline
        }

        if rewardedAd == nil || state != .ready {
            await preloadRewardedAd(plan: plan)
        }

        guard let ad = rewardedAd, state == .ready else {
            return .failed
        }

        guard let viewController = Self.topViewController() else {
            return .failed
        }

        await requestTrackingAuthorizationIfNeeded()
        state = .presenting
        analyticsService.capture(.adRewardedShown, plan: plan, retryCount: loadRetryCount)

        return await withCheckedContinuation { continuation in
            var hasResumed = false
            var didEarnReward = false

            ad.fullScreenContentDelegate = RewardedAdDelegate {
                guard !hasResumed, !didEarnReward else { return }
                hasResumed = true
                self.analyticsService.capture(.adRewardedDismissed, plan: plan, retryCount: self.loadRetryCount)
                self.rewardedAd = nil
                self.state = .idle
                continuation.resume(returning: .dismissed)
            }

            ad.present(fromRootViewController: viewController) { [weak self] in
                guard let self, !hasResumed else { return }
                didEarnReward = true
                hasResumed = true
                self.analyticsService.capture(.adRewardedCompleted, plan: plan, retryCount: self.loadRetryCount)
                self.rewardedAd = nil
                self.state = .idle
                continuation.resume(returning: .completed)
            }
        }
    }

    private func loadRewardedAd() async throws -> GADRewardedAd {
        try await withCheckedThrowingContinuation { continuation in
            GADRewardedAd.load(withAdUnitID: AdMobConfig.rewardedAdUnitID, request: GADRequest()) { ad, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let ad {
                    continuation.resume(returning: ad)
                } else {
                    continuation.resume(throwing: AdMobLoadError.unknown)
                }
            }
        }
    }

    private func startSDKIfNeeded() async {
        guard !isSDKStarted else { return }

        await requestConsentIfNeeded()

        await withCheckedContinuation { continuation in
            GADMobileAds.sharedInstance().start { _ in
                continuation.resume()
            }
        }

        isSDKStarted = true
    }

    private func requestConsentIfNeeded() async {
        guard !isConsentRequested else { return }
        isConsentRequested = true

        let parameters = UMPRequestParameters()
        parameters.tagForUnderAgeOfConsent = false

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: parameters) { _ in
                Task { @MainActor in
                    if UMPConsentInformation.sharedInstance.formStatus == .available,
                       let viewController = Self.topViewController() {
                        UMPConsentForm.loadAndPresentIfRequired(from: viewController) { _ in
                            continuation.resume()
                        }
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }

    private func requestTrackingAuthorizationIfNeeded() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ATTrackingManager.requestTrackingAuthorization { _ in
                continuation.resume()
            }
        }
    }

    private static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController else {
            return nil
        }

        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}

private enum AdMobLoadError: Error {
    case unknown
}

private final class RewardedAdDelegate: NSObject, GADFullScreenContentDelegate {
    private let onDismissWithoutReward: () -> Void

    init(onDismissWithoutReward: @escaping () -> Void) {
        self.onDismissWithoutReward = onDismissWithoutReward
    }

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        onDismissWithoutReward()
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        onDismissWithoutReward()
    }
}

@MainActor
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private(set) var isConnected = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "app.node.network-monitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
}
