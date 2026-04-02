@testable import sprinty
import StoreKit

final class MockSubscriptionService: SubscriptionServiceProtocol, @unchecked Sendable {
    var purchaseCallCount = 0
    var stubbedPurchaseError: Error?
    var checkEntitlementCallCount = 0
    var stubbedEntitlementTransactionId: UInt64?
    var listenCallCount = 0

    func purchase() async throws -> Transaction? {
        purchaseCallCount += 1
        if let error = stubbedPurchaseError {
            throw error
        }
        return nil
    }

    func checkCurrentEntitlement() async -> UInt64? {
        checkEntitlementCallCount += 1
        return stubbedEntitlementTransactionId
    }

    func listenForTransactionUpdates() async {
        listenCallCount += 1
    }
}
