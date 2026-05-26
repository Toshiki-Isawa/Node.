import Foundation
import StoreKit

struct StorageUsage: Sendable {
    let usedBytes: Int64
    let limitBytes: Int64
    let plan: UserPlan

    init(usedBytes: Int64, plan: UserPlan) {
        self.usedBytes = usedBytes
        self.plan = plan
        self.limitBytes = plan.storageLimitBytes
    }

    var isAtLimit: Bool {
        usedBytes >= limitBytes
    }

    var remainingBytes: Int64 {
        max(0, limitBytes - usedBytes)
    }

    var usedRatio: Double {
        guard limitBytes > 0 else { return 0 }
        return min(1, Double(usedBytes) / Double(limitBytes))
    }
}

@MainActor
final class PlanService: ObservableObject {
    @Published private(set) var serverPlan: UserPlan = .seed
    @Published private(set) var storageUsage: StorageUsage?

    private let supabaseService: SupabaseService
    private let subscriptionService: SubscriptionService
    weak var syncEngine: SyncEngine?

    var plan: UserPlan {
        UserPlan.highest([serverPlan, subscriptionService.activePlan])
    }

    var allowsOriginalSync: Bool {
        plan.allowsOriginalSync
    }

    var isPaid: Bool {
        plan.isPaid
    }

    init(
        supabaseService: SupabaseService,
        subscriptionService: SubscriptionService
    ) {
        self.supabaseService = supabaseService
        self.subscriptionService = subscriptionService

        subscriptionService.setEntitlementChangedHandler { [weak self] in
            Task { @MainActor in
                await self?.handleEntitlementChanged()
            }
        }
    }

    func refresh() async {
        guard ReleaseConfig.cloudSyncEnabled else {
            serverPlan = .seed
            storageUsage = nil
            return
        }

        await subscriptionService.refreshEntitlements()

        guard supabaseService.isAuthenticated else {
            serverPlan = .seed
            storageUsage = nil
            return
        }

        do {
            if subscriptionService.activePlan.isPaid,
               let transaction = await subscriptionService.latestVerifiedTransaction() {
                try? await syncSubscriptionToServer(transaction: transaction)
            }

            let fetchedPlan = try await supabaseService.fetchUserPlan()
            let usedBytes = try await supabaseService.fetchStorageUsageBytes()
            serverPlan = fetchedPlan
            storageUsage = StorageUsage(usedBytes: usedBytes, plan: plan)
        } catch {
            storageUsage = StorageUsage(
                usedBytes: storageUsage?.usedBytes ?? 0,
                plan: plan
            )
        }
    }

    var isCloudSyncPausedByStorage: Bool {
        storageUsage?.isAtLimit ?? false
    }

    func purchaseArchive() async throws {
        guard ReleaseConfig.subscriptionsEnabled else {
            throw SubscriptionError.purchasesUnavailable
        }
        guard supabaseService.isAuthenticated else {
            throw SubscriptionError.notAuthenticated
        }

        let transaction = try await subscriptionService.purchaseArchive()
        try await syncSubscriptionToServer(transaction: transaction)
        await refresh()
        syncEngine?.enqueueSync()
    }

    func purchaseConservatory() async throws {
        guard ReleaseConfig.subscriptionsEnabled else {
            throw SubscriptionError.purchasesUnavailable
        }
        guard supabaseService.isAuthenticated else {
            throw SubscriptionError.notAuthenticated
        }

        let transaction = try await subscriptionService.purchaseConservatory()
        try await syncSubscriptionToServer(transaction: transaction)
        await refresh()
        syncEngine?.enqueueSync()
    }

    func restoreSubscriptions() async throws {
        guard ReleaseConfig.subscriptionsEnabled else {
            throw SubscriptionError.purchasesUnavailable
        }
        guard supabaseService.isAuthenticated else {
            throw SubscriptionError.notAuthenticated
        }

        try await subscriptionService.restorePurchases()

        if let transaction = await subscriptionService.latestVerifiedTransaction() {
            try await syncSubscriptionToServer(transaction: transaction)
        }

        await refresh()
        syncEngine?.enqueueSync()
    }

    private func handleEntitlementChanged() async {
        guard supabaseService.isAuthenticated,
              let transaction = await subscriptionService.latestVerifiedTransaction() else {
            await refresh()
            return
        }

        try? await syncSubscriptionToServer(transaction: transaction)
        await refresh()
        syncEngine?.enqueueSync()
    }

    private func syncSubscriptionToServer(transaction: Transaction) async throws {
        try await supabaseService.syncPremiumSubscription(
            productId: transaction.productID,
            transactionId: String(transaction.id),
            originalTransactionId: String(transaction.originalID),
            expiresAt: transaction.expirationDate,
            environment: transactionEnvironment(transaction)
        )
    }

    private func transactionEnvironment(_ transaction: Transaction) -> String {
        switch transaction.environment {
        case .sandbox: return "sandbox"
        case .production: return "production"
        default: return "xcode"
        }
    }
}
