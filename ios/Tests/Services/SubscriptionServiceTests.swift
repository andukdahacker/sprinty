import Testing
import Foundation
@testable import sprinty

// --- Story 8.1 Tests ---

@Suite("SubscriptionService Tests")
struct SubscriptionServiceTests {

    // MARK: - MockAuthService Integration

    @Test("SubscriptionService initializes with AuthService dependency")
    func initWithAuthService() {
        let mockAuth = MockAuthService()
        let service = SubscriptionService(authService: mockAuth)
        #expect(service != nil)
    }

    @Test("checkCurrentEntitlement returns nil when no entitlements exist")
    func checkEntitlementNoEntitlements() async {
        let mockAuth = MockAuthService()
        let service = SubscriptionService(authService: mockAuth)
        let transactionId = await service.checkCurrentEntitlement()
        #expect(transactionId == nil)
    }

    // MARK: - MockSubscriptionService

    @Test("MockSubscriptionService records purchase calls")
    func mockRecordsPurchase() async throws {
        let mock = MockSubscriptionService()
        let result = try await mock.purchase()
        #expect(mock.purchaseCallCount == 1)
        #expect(result == nil)
    }

    @Test("MockSubscriptionService returns stubbed entitlement")
    func mockReturnsEntitlement() async {
        let mock = MockSubscriptionService()
        mock.stubbedEntitlementTransactionId = 12345
        let result = await mock.checkCurrentEntitlement()
        #expect(result == 12345)
        #expect(mock.checkEntitlementCallCount == 1)
    }

    @Test("MockSubscriptionService throws stubbed error on purchase")
    func mockThrowsOnPurchase() async {
        let mock = MockSubscriptionService()
        mock.stubbedPurchaseError = AppError.networkUnavailable
        do {
            _ = try await mock.purchase()
            #expect(Bool(false), "Should have thrown")
        } catch {
            #expect(error is AppError)
        }
    }

    @Test("MockSubscriptionService records listen calls")
    func mockRecordsListen() async {
        let mock = MockSubscriptionService()
        await mock.listenForTransactionUpdates()
        #expect(mock.listenCallCount == 1)
    }
}

@Suite("AuthService Story 8.1 Tests")
struct AuthServiceSubscriptionTests {
    private func createValidJWT(tier: String = "free", expiringIn seconds: TimeInterval = 86400 * 30) -> String {
        let header = Data(#"{"alg":"HS256","typ":"JWT"}"#.utf8).base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        let exp = Int(Date().timeIntervalSince1970 + seconds)
        let payload = Data(#"{"deviceId":"test","tier":"\#(tier)","exp":\#(exp)}"#.utf8).base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        let signature = "fake-signature"
        return "\(header).\(payload).\(signature)"
    }

    // MARK: - RegisterRequest with transactionId

    @Test("RegisterRequest encodes transactionId when present")
    func registerRequestWithTransactionId() throws {
        let req = RegisterRequest(deviceId: "test-device", transactionId: 12345)
        let data = try JSONEncoder().encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["deviceId"] as? String == "test-device")
        #expect(json?["transactionId"] as? UInt64 == 12345)
    }

    @Test("RegisterRequest omits transactionId when nil")
    func registerRequestWithoutTransactionId() throws {
        let req = RegisterRequest(deviceId: "test-device")
        let data = try JSONEncoder().encode(req)
        let jsonStr = String(data: data, encoding: .utf8)!
        #expect(!jsonStr.contains("transactionId"))
    }

    // MARK: - RefreshRequest

    @Test("RefreshRequest encodes transactionId")
    func refreshRequestEncoding() throws {
        let req = RefreshRequest(transactionId: 67890)
        let data = try JSONEncoder().encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["transactionId"] as? UInt64 == 67890)
    }

    // MARK: - refreshTokenWithTransaction

    @Test("refreshTokenWithTransaction calls refresh endpoint with body")
    func refreshTokenWithTransaction() async throws {
        let mockAPI = MockAPIClient()
        let mockKeychain = MockKeychainHelper()
        let currentToken = createValidJWT()
        let newToken = createValidJWT(tier: "premium")
        mockKeychain.store[Constants.keychainAuthJWTKey] = currentToken
        mockAPI.responses["/v1/auth/refresh"] = AuthResponse(token: newToken)

        let authService = AuthService(apiClient: mockAPI, keychainHelper: mockKeychain)
        try await authService.refreshTokenWithTransaction(12345)

        #expect(mockAPI.requestLog.count == 1)
        #expect(mockAPI.requestLog.first?.path == "/v1/auth/refresh")
        let storedToken = try mockKeychain.read(key: Constants.keychainAuthJWTKey)
        #expect(storedToken == newToken)
    }

    @Test("refreshTokenWithTransaction throws when no token stored")
    func refreshTokenWithTransactionNoToken() async {
        let mockAPI = MockAPIClient()
        let mockKeychain = MockKeychainHelper()
        let authService = AuthService(apiClient: mockAPI, keychainHelper: mockKeychain)

        do {
            try await authService.refreshTokenWithTransaction(12345)
            #expect(Bool(false), "Should have thrown")
        } catch {
            #expect(error is AppError)
        }
    }

    // MARK: - Tier Parsing

    @Test("tierFromCurrentToken returns tier from stored JWT")
    func tierFromCurrentToken() {
        let mockAPI = MockAPIClient()
        let mockKeychain = MockKeychainHelper()
        mockKeychain.store[Constants.keychainAuthJWTKey] = createValidJWT(tier: "premium")

        let authService = AuthService(apiClient: mockAPI, keychainHelper: mockKeychain)
        #expect(authService.tierFromCurrentToken() == "premium")
    }

    @Test("tierFromCurrentToken returns free for free-tier JWT")
    func tierFromCurrentTokenFree() {
        let mockAPI = MockAPIClient()
        let mockKeychain = MockKeychainHelper()
        mockKeychain.store[Constants.keychainAuthJWTKey] = createValidJWT(tier: "free")

        let authService = AuthService(apiClient: mockAPI, keychainHelper: mockKeychain)
        #expect(authService.tierFromCurrentToken() == "free")
    }

    @Test("tierFromCurrentToken returns nil when no token stored")
    func tierFromCurrentTokenNoToken() {
        let mockAPI = MockAPIClient()
        let mockKeychain = MockKeychainHelper()
        let authService = AuthService(apiClient: mockAPI, keychainHelper: mockKeychain)
        #expect(authService.tierFromCurrentToken() == nil)
    }

    // MARK: - MockAuthService

    @Test("MockAuthService records refreshTokenWithTransaction calls")
    func mockAuthServiceRecordsTransactionRefresh() async throws {
        let mock = MockAuthService()
        try await mock.refreshTokenWithTransaction(99999)
        #expect(mock.refreshTokenWithTransactionCallCount == 1)
        #expect(mock.lastTransactionId == 99999)
    }

    @Test("MockAuthService throws stubbed error for refreshTokenWithTransaction")
    func mockAuthServiceThrowsOnTransactionRefresh() async {
        let mock = MockAuthService()
        mock.stubbedRefreshTokenWithTransactionError = AppError.networkUnavailable
        do {
            try await mock.refreshTokenWithTransaction(99999)
            #expect(Bool(false), "Should have thrown")
        } catch {
            #expect(error is AppError)
        }
    }

    // MARK: - Tier Enum

    @Test("Tier enum raw values match API contract")
    func tierRawValues() {
        #expect(Tier.free.rawValue == "free")
        #expect(Tier.premium.rawValue == "premium")
    }

    @Test("Tier decodes from JSON string")
    func tierDecoding() throws {
        let json = #""premium""#.data(using: .utf8)!
        let tier = try JSONDecoder().decode(Tier.self, from: json)
        #expect(tier == .premium)
    }

    @Test("Tier encodes to JSON string")
    func tierEncoding() throws {
        let data = try JSONEncoder().encode(Tier.premium)
        let str = String(data: data, encoding: .utf8)
        #expect(str == #""premium""#)
    }
}
