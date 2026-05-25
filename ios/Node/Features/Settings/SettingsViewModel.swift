import Foundation
import StoreKit
import SwiftData
import UIKit

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var localBreakdown = LocalStorageBreakdown.empty
    @Published private(set) var syncBreakdown = SyncStatusBreakdown.empty
    @Published private(set) var isRefreshing = false
    @Published private(set) var isPurchasing = false
    @Published var purchaseMessage: String?
    @Published var accountActionMessage: String?

    private let modelContext: ModelContext
    private let imageStore: ImageStore
    private let planService: PlanService
    private let subscriptionService: SubscriptionService
    private let syncEngine: SyncEngine
    private let authViewModel: AuthViewModel
    private let supabaseService: SupabaseService

    init(
        modelContext: ModelContext,
        imageStore: ImageStore,
        planService: PlanService,
        subscriptionService: SubscriptionService,
        syncEngine: SyncEngine,
        authViewModel: AuthViewModel,
        supabaseService: SupabaseService
    ) {
        self.modelContext = modelContext
        self.imageStore = imageStore
        self.planService = planService
        self.subscriptionService = subscriptionService
        self.syncEngine = syncEngine
        self.authViewModel = authViewModel
        self.supabaseService = supabaseService
    }

    var plan: UserPlan { planService.plan }
    var isAuthenticated: Bool { supabaseService.isAuthenticated }
    var cloudUsage: StorageUsage? { planService.storageUsage }
    var isCloudSyncPaused: Bool { planService.isCloudSyncPausedByStorage }
    var archivePriceLabel: String? {
        subscriptionService.priceLabel(
            for: subscriptionService.archiveProduct,
            fallbackPlan: .archive
        )
    }
    var conservatoryPriceLabel: String? {
        subscriptionService.priceLabel(
            for: subscriptionService.conservatoryProduct,
            fallbackPlan: .conservatory
        )
    }

    func reload() async {
        isRefreshing = true
        defer { isRefreshing = false }

        localBreakdown = StorageStatsService.localBreakdown(imageStore: imageStore)
        syncBreakdown = StorageStatsService.syncBreakdown(modelContext: modelContext)
        await subscriptionService.loadProducts()
        await planService.refresh()
    }

    func retrySync() {
        syncEngine.enqueueSync()
        Task { await reload() }
    }

    func purchaseArchive() async {
        await purchase(planName: "Archive") {
            try await planService.purchaseArchive()
        }
    }

    func purchaseConservatory() async {
        await purchase(planName: "Conservatory") {
            try await planService.purchaseConservatory()
        }
    }

    func restoreSubscriptions() async {
        isPurchasing = true
        purchaseMessage = nil
        defer { isPurchasing = false }

        do {
            try await planService.restoreSubscriptions()
            purchaseMessage = planService.plan.isPaid
                ? "\(planService.plan.displayName) を復元しました。"
                : nil
            await reload()
        } catch SubscriptionError.userCancelled {
            return
        } catch {
            purchaseMessage = error.localizedDescription
        }
    }

    func manageSubscriptions() async {
        guard let scene = Self.activeWindowScene() else { return }
        try? await AppStore.showManageSubscriptions(in: scene)
        await reload()
    }

    func signOut() async {
        accountActionMessage = nil
        await authViewModel.signOut()
        if let errorMessage = authViewModel.errorMessage {
            accountActionMessage = errorMessage
        }
    }

    @discardableResult
    func deleteAccount() async -> Bool {
        isRefreshing = true
        accountActionMessage = nil
        defer { isRefreshing = false }

        await authViewModel.deleteAccount()
        if let errorMessage = authViewModel.errorMessage {
            accountActionMessage = errorMessage
            return false
        }
        return true
    }

    private func purchase(planName: String, action: () async throws -> Void) async {
        isPurchasing = true
        purchaseMessage = nil
        defer { isPurchasing = false }

        do {
            try await action()
            purchaseMessage = "\(planName) が有効になりました。"
            await reload()
        } catch SubscriptionError.userCancelled {
            return
        } catch {
            purchaseMessage = error.localizedDescription
        }
    }

    private static func activeWindowScene() -> UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }
}
