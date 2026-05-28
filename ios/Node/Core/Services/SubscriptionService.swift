import Foundation
import StoreKit

enum SubscriptionError: LocalizedError {
    case productUnavailable
    case userCancelled
    case pending
    case unverified
    case notAuthenticated
    case purchasesUnavailable

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return String(localized: "プラン情報を取得できませんでした。")
        case .userCancelled:
            return nil
        case .pending:
            return String(localized: "購入が保留中です。承認後にプランが有効になります。")
        case .unverified:
            return String(localized: "購入の確認に失敗しました。")
        case .notAuthenticated:
            return String(localized: "プランを有効にするにはサインインが必要です。")
        case .purchasesUnavailable:
            return String(localized: "有料プランは近日公開予定です。")
        }
    }
}

@MainActor
final class SubscriptionService: ObservableObject {
    @Published private(set) var archiveProduct: Product?
    @Published private(set) var conservatoryProduct: Product?
    @Published private(set) var activePlan: UserPlan = .seed
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published var errorMessage: String?

    private var updatesTask: Task<Void, Never>?
    private var onEntitlementChanged: (() -> Void)?

    init() {
        updatesTask = Task { await listenForTransactions() }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func setEntitlementChangedHandler(_ handler: @escaping () -> Void) {
        onEntitlementChanged = handler
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let products = try await Product.products(for: SubscriptionProducts.all)
            archiveProduct = products.first { $0.id == SubscriptionProducts.archiveMonthly }
            conservatoryProduct = products.first { $0.id == SubscriptionProducts.conservatoryMonthly }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        var plans: [UserPlan] = []

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard let plan = SubscriptionProducts.plan(for: transaction.productID) else { continue }
            if let expiration = transaction.expirationDate, expiration <= .now { continue }
            if transaction.revocationDate != nil { continue }
            plans.append(plan)
        }

        activePlan = UserPlan.highest(plans)
    }

    @discardableResult
    func purchase(_ product: Product) async throws -> Transaction {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try verifiedTransaction(from: verification)
            await transaction.finish()
            await refreshEntitlements()
            onEntitlementChanged?()
            return transaction
        case .userCancelled:
            throw SubscriptionError.userCancelled
        case .pending:
            throw SubscriptionError.pending
        @unknown default:
            throw SubscriptionError.unverified
        }
    }

    func purchaseArchive() async throws -> Transaction {
        guard let archiveProduct else { throw SubscriptionError.productUnavailable }
        return try await purchase(archiveProduct)
    }

    func purchaseConservatory() async throws -> Transaction {
        guard let conservatoryProduct else { throw SubscriptionError.productUnavailable }
        return try await purchase(conservatoryProduct)
    }

    func restorePurchases() async throws {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        try await AppStore.sync()
        await refreshEntitlements()

        guard activePlan.isPaid else {
            errorMessage = String(localized: "復元できる有料プランが見つかりませんでした。")
            return
        }

        onEntitlementChanged?()
    }

    func latestVerifiedTransaction(for plan: UserPlan) async -> Transaction? {
        var latest: Transaction?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard SubscriptionProducts.plan(for: transaction.productID) == plan else { continue }
            if let expiration = transaction.expirationDate, expiration <= .now { continue }
            if transaction.revocationDate != nil { continue }

            if let current = latest {
                if transaction.purchaseDate > current.purchaseDate {
                    latest = transaction
                }
            } else {
                latest = transaction
            }
        }

        return latest
    }

    func latestVerifiedTransaction() async -> Transaction? {
        for plan in [UserPlan.conservatory, .archive] {
            if let transaction = await latestVerifiedTransaction(for: plan) {
                return transaction
            }
        }
        return nil
    }

    func priceLabel(for product: Product?, fallbackPlan: UserPlan) -> String? {
        let price: String?
        if let product {
            price = Self.formattedYenPrice(product)
        } else {
            price = fallbackPlan.marketingMonthlyPrice
        }
        guard let price else { return nil }

        guard let product,
              let period = product.subscription?.subscriptionPeriod
        else {
            return product == nil ? "\(price)/月" : price
        }

        switch period.unit {
        case .month: return "\(price)/月"
        case .year: return "\(price)/年"
        default: return price
        }
    }

    /// 日本向けアプリのため、storefront が US でも UI は円表記に統一する。
    private static func formattedYenPrice(_ product: Product) -> String {
        product.price.formatted(
            .currency(code: "JPY")
                .locale(Locale(identifier: "ja_JP"))
                .precision(.fractionLength(0...0))
        )
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            guard SubscriptionProducts.plan(for: transaction.productID) != nil else { continue }

            await refreshEntitlements()
            onEntitlementChanged?()
            await transaction.finish()
        }
    }

    private func verifiedTransaction(from result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified:
            throw SubscriptionError.unverified
        }
    }
}
