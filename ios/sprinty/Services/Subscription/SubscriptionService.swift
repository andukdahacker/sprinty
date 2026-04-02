import StoreKit

final class SubscriptionService: SubscriptionServiceProtocol {
    private let authService: AuthServiceProtocol
    private let onSubscriptionChange: (@Sendable () async -> Void)?

    init(authService: AuthServiceProtocol, onSubscriptionChange: (@Sendable () async -> Void)? = nil) {
        self.authService = authService
        self.onSubscriptionChange = onSubscriptionChange
    }

    // MARK: - Purchase Flow

    func purchase() async throws -> Transaction? {
        let products = try await Product.products(for: [Constants.premiumProductId])
        guard let product = products.first else { return nil }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { return nil }
            try await authService.refreshTokenWithTransaction(transaction.id)
            await onSubscriptionChange?()
            await transaction.finish()
            return transaction
        case .pending:
            return nil
        case .userCancelled:
            return nil
        @unknown default:
            return nil
        }
    }

    // MARK: - Entitlement Checking

    func checkCurrentEntitlement() async -> UInt64? {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Constants.premiumProductId {
                return transaction.id
            }
        }
        return nil
    }

    // MARK: - Transaction Updates Listener

    func listenForTransactionUpdates() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            await handleVerifiedTransaction(transaction)
            await transaction.finish()
        }
    }

    private func handleVerifiedTransaction(_ transaction: Transaction) async {
        if transaction.productID == Constants.premiumProductId {
            if transaction.revocationDate != nil {
                // Subscription revoked — refresh to get free tier
                try? await authService.refreshToken()
                await onSubscriptionChange?()
            } else if let expirationDate = transaction.expirationDate, expirationDate < Date() {
                // Subscription expired — refresh to get free tier
                try? await authService.refreshToken()
                await onSubscriptionChange?()
            } else {
                // Active subscription — refresh with transaction ID for premium tier
                try? await authService.refreshTokenWithTransaction(transaction.id)
                await onSubscriptionChange?()
            }
        }
    }
}
