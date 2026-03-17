import Testing
import Foundation
@testable import ai_life_coach

final class MockAPIClient: APIClientProtocol, @unchecked Sendable {
    var responses: [String: Any] = [:]
    var requestLog: [(method: String, path: String)] = []
    var shouldThrow: AppError?

    func request<T: Decodable & Sendable>(
        method: String,
        path: String,
        body: (any Encodable & Sendable)?,
        bearerToken: String?
    ) async throws -> T {
        requestLog.append((method: method, path: path))
        if let error = shouldThrow {
            throw error
        }
        guard let response = responses[path] as? T else {
            throw AppError.networkUnavailable
        }
        return response
    }
}

final class MockKeychainHelper: KeychainHelperProtocol, @unchecked Sendable {
    var store: [String: String] = [:]

    func read(key: String) throws -> String {
        guard let value = store[key] else {
            throw AppError.authExpired
        }
        return value
    }

    func save(key: String, value: String) throws {
        store[key] = value
    }

    func delete(key: String) {
        store.removeValue(forKey: key)
    }
}

@Suite("AuthService Tests")
struct AuthServiceTests {
    private func createValidJWT(expiringIn seconds: TimeInterval = 86400 * 30) -> String {
        let header = Data(#"{"alg":"HS256","typ":"JWT"}"#.utf8).base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        let exp = Int(Date().timeIntervalSince1970 + seconds)
        let payload = Data(#"{"deviceId":"test","exp":\#(exp)}"#.utf8).base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        let signature = "fake-signature"
        return "\(header).\(payload).\(signature)"
    }

    // MARK: - JWT Expiry Parsing

    @Test("Token expiring soon returns true for token expiring in less than 24h")
    func tokenExpiringSoon() {
        let mockAPI = MockAPIClient()
        let authService = AuthService(apiClient: mockAPI)
        let soonToken = createValidJWT(expiringIn: 3600)
        #expect(authService.isTokenExpiringSoon(soonToken) == true)
    }

    @Test("Token not expiring soon returns false for token with long expiry")
    func tokenNotExpiringSoon() {
        let mockAPI = MockAPIClient()
        let authService = AuthService(apiClient: mockAPI)
        let longToken = createValidJWT(expiringIn: 86400 * 15)
        #expect(authService.isTokenExpiringSoon(longToken) == false)
    }

    @Test("Invalid JWT returns expiring soon")
    func invalidJWTExpiringSoon() {
        let mockAPI = MockAPIClient()
        let authService = AuthService(apiClient: mockAPI)
        #expect(authService.isTokenExpiringSoon("not.a.jwt") == true)
        #expect(authService.isTokenExpiringSoon("") == true)
    }

    // MARK: - Wire Format

    @Test("RegisterRequest JSON has correct field name")
    func registerRequestFormat() throws {
        let req = RegisterRequest(deviceId: "abc-123")
        let data = try JSONEncoder().encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["deviceId"] as? String == "abc-123")
    }

    @Test("AuthResponse decodes token correctly")
    func authResponseFormat() throws {
        let json = #"{"token":"my-jwt-token"}"#
        let resp = try JSONDecoder().decode(AuthResponse.self, from: json.data(using: .utf8)!)
        #expect(resp.token == "my-jwt-token")
    }

    // MARK: - Mock Infrastructure

    @Test("MockAPIClient records requests")
    func mockAPIClientRecordsRequests() async throws {
        let mock = MockAPIClient()
        mock.responses["/v1/auth/register"] = AuthResponse(token: "test-token")
        let _: AuthResponse = try await mock.request(
            method: "POST",
            path: "/v1/auth/register",
            body: RegisterRequest(deviceId: "test")
        )
        #expect(mock.requestLog.count == 1)
        #expect(mock.requestLog.first?.path == "/v1/auth/register")
    }

    @Test("MockAPIClient throws when configured")
    func mockAPIClientThrows() async {
        let mock = MockAPIClient()
        mock.shouldThrow = .networkUnavailable
        do {
            let _: AuthResponse = try await mock.request(
                method: "POST",
                path: "/v1/auth/register"
            )
            #expect(Bool(false), "Should have thrown")
        } catch {
            #expect(error is AppError)
        }
    }

    // MARK: - Device UUID (getOrCreateDeviceUUID via ensureAuthenticated)

    @Test("ensureAuthenticated generates and stores device UUID on first launch")
    func ensureAuthenticatedGeneratesUUID() async throws {
        let mockAPI = MockAPIClient()
        let mockKeychain = MockKeychainHelper()
        let token = createValidJWT()
        mockAPI.responses["/v1/auth/register"] = AuthResponse(token: token)

        let authService = AuthService(apiClient: mockAPI, keychainHelper: mockKeychain)
        try await authService.ensureAuthenticated()

        let storedUUID = try mockKeychain.read(key: Constants.keychainDeviceUUIDKey)
        #expect(storedUUID.isEmpty == false)
        #expect(UUID(uuidString: storedUUID) != nil)
    }

    @Test("ensureAuthenticated reuses existing device UUID from Keychain")
    func ensureAuthenticatedReusesUUID() async throws {
        let mockAPI = MockAPIClient()
        let mockKeychain = MockKeychainHelper()
        let existingUUID = "existing-uuid-from-previous-install"
        mockKeychain.store[Constants.keychainDeviceUUIDKey] = existingUUID
        let token = createValidJWT()
        mockAPI.responses["/v1/auth/register"] = AuthResponse(token: token)

        let authService = AuthService(apiClient: mockAPI, keychainHelper: mockKeychain)
        try await authService.ensureAuthenticated()

        let storedUUID = try mockKeychain.read(key: Constants.keychainDeviceUUIDKey)
        #expect(storedUUID == existingUUID)
    }

    // MARK: - Register Flow

    @Test("ensureAuthenticated calls register when no token exists")
    func ensureAuthenticatedRegisters() async throws {
        let mockAPI = MockAPIClient()
        let mockKeychain = MockKeychainHelper()
        let token = createValidJWT()
        mockAPI.responses["/v1/auth/register"] = AuthResponse(token: token)

        let authService = AuthService(apiClient: mockAPI, keychainHelper: mockKeychain)
        try await authService.ensureAuthenticated()

        #expect(mockAPI.requestLog.count == 1)
        #expect(mockAPI.requestLog.first?.method == "POST")
        #expect(mockAPI.requestLog.first?.path == "/v1/auth/register")
        let storedToken = try mockKeychain.read(key: Constants.keychainAuthJWTKey)
        #expect(storedToken == token)
    }

    @Test("ensureAuthenticated skips register when valid token exists")
    func ensureAuthenticatedSkipsRegisterWithValidToken() async throws {
        let mockAPI = MockAPIClient()
        let mockKeychain = MockKeychainHelper()
        let validToken = createValidJWT(expiringIn: 86400 * 15)
        mockKeychain.store[Constants.keychainDeviceUUIDKey] = "existing-uuid"
        mockKeychain.store[Constants.keychainAuthJWTKey] = validToken

        let authService = AuthService(apiClient: mockAPI, keychainHelper: mockKeychain)
        try await authService.ensureAuthenticated()

        #expect(mockAPI.requestLog.isEmpty)
    }

    // MARK: - Refresh Flow

    @Test("ensureAuthenticated refreshes token when expiring soon")
    func ensureAuthenticatedRefreshesExpiring() async throws {
        let mockAPI = MockAPIClient()
        let mockKeychain = MockKeychainHelper()
        let expiringToken = createValidJWT(expiringIn: 3600)
        let freshToken = createValidJWT(expiringIn: 86400 * 30)
        mockKeychain.store[Constants.keychainDeviceUUIDKey] = "existing-uuid"
        mockKeychain.store[Constants.keychainAuthJWTKey] = expiringToken
        mockAPI.responses["/v1/auth/refresh"] = AuthResponse(token: freshToken)

        let authService = AuthService(apiClient: mockAPI, keychainHelper: mockKeychain)
        try await authService.ensureAuthenticated()

        #expect(mockAPI.requestLog.count == 1)
        #expect(mockAPI.requestLog.first?.path == "/v1/auth/refresh")
        let storedToken = try mockKeychain.read(key: Constants.keychainAuthJWTKey)
        #expect(storedToken == freshToken)
    }

    @Test("refreshToken stores new token in Keychain")
    func refreshTokenStoresNewToken() async throws {
        let mockAPI = MockAPIClient()
        let mockKeychain = MockKeychainHelper()
        let currentToken = createValidJWT(expiringIn: 3600)
        let newToken = createValidJWT(expiringIn: 86400 * 30)
        mockKeychain.store[Constants.keychainAuthJWTKey] = currentToken
        mockAPI.responses["/v1/auth/refresh"] = AuthResponse(token: newToken)

        let authService = AuthService(apiClient: mockAPI, keychainHelper: mockKeychain)
        try await authService.refreshToken()

        let storedToken = try mockKeychain.read(key: Constants.keychainAuthJWTKey)
        #expect(storedToken == newToken)
    }

    // MARK: - getToken

    @Test("getToken returns stored JWT")
    func getTokenReturnsStoredJWT() throws {
        let mockAPI = MockAPIClient()
        let mockKeychain = MockKeychainHelper()
        mockKeychain.store[Constants.keychainAuthJWTKey] = "stored-jwt"

        let authService = AuthService(apiClient: mockAPI, keychainHelper: mockKeychain)
        let token = try authService.getToken()
        #expect(token == "stored-jwt")
    }

    @Test("getToken throws authExpired when no token stored")
    func getTokenThrowsWhenEmpty() {
        let mockAPI = MockAPIClient()
        let mockKeychain = MockKeychainHelper()

        let authService = AuthService(apiClient: mockAPI, keychainHelper: mockKeychain)
        #expect(throws: AppError.self) {
            _ = try authService.getToken()
        }
    }
}
