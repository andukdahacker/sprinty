import StoreKit

protocol SubscriptionServiceProtocol {
    func purchase() async throws -> Transaction?
    func checkCurrentEntitlement() async -> UInt64?
    func listenForTransactionUpdates() async
}
