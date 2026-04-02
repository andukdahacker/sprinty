import Foundation
import Security
import StoreKit

protocol AuthServiceProtocol: Sendable {
    func ensureAuthenticated() async throws
    func getToken() throws -> String
    func refreshToken() async throws
    func refreshTokenWithTransaction(_ transactionId: UInt64) async throws
}

protocol KeychainHelperProtocol: Sendable {
    func save(key: String, value: String) throws
    func read(key: String) throws -> String
    func delete(key: String)
}

final class AuthService: AuthServiceProtocol, Sendable {
    private let apiClient: APIClientProtocol
    private let keychainHelper: any KeychainHelperProtocol

    init(apiClient: APIClientProtocol, keychainHelper: any KeychainHelperProtocol = KeychainHelper()) {
        self.apiClient = apiClient
        self.keychainHelper = keychainHelper
    }

    func ensureAuthenticated() async throws {
        let deviceId = try getOrCreateDeviceUUID()

        if let token = try? keychainHelper.read(key: Constants.keychainAuthJWTKey) {
            if isTokenExpiringSoon(token) {
                try await refreshToken()
            }
            return
        }

        // Check for existing subscription entitlement (calls StoreKit 2 directly to avoid circular dependency)
        let transactionId = await currentEntitlementTransactionId()
        try await register(deviceId: deviceId, transactionId: transactionId)
    }

    func getToken() throws -> String {
        guard let token = try? keychainHelper.read(key: Constants.keychainAuthJWTKey) else {
            throw AppError.authExpired
        }
        return token
    }

    func refreshToken() async throws {
        let currentToken = try getToken()
        let response: AuthResponse = try await apiClient.request(
            method: "POST",
            path: "/v1/auth/refresh",
            bearerToken: currentToken
        )
        try keychainHelper.save(key: Constants.keychainAuthJWTKey, value: response.token)
    }

    func refreshTokenWithTransaction(_ transactionId: UInt64) async throws {
        let currentToken = try getToken()
        let body = RefreshRequest(transactionId: transactionId)
        let response: AuthResponse = try await apiClient.request(
            method: "POST",
            path: "/v1/auth/refresh",
            body: body,
            bearerToken: currentToken
        )
        try keychainHelper.save(key: Constants.keychainAuthJWTKey, value: response.token)
    }

    private func register(deviceId: String, transactionId: UInt64? = nil) async throws {
        let body = RegisterRequest(deviceId: deviceId, transactionId: transactionId)
        let response: AuthResponse = try await apiClient.request(
            method: "POST",
            path: "/v1/auth/register",
            body: body
        )
        try keychainHelper.save(key: Constants.keychainAuthJWTKey, value: response.token)
    }

    private func getOrCreateDeviceUUID() throws -> String {
        if let existing = try? keychainHelper.read(key: Constants.keychainDeviceUUIDKey) {
            return existing
        }
        let newUUID = UUID().uuidString
        try keychainHelper.save(key: Constants.keychainDeviceUUIDKey, value: newUUID)
        return newUUID
    }

    func isTokenExpiringSoon(_ token: String) -> Bool {
        guard let payload = decodeJWTPayload(token) else { return true }
        guard let exp = payload["exp"] as? TimeInterval else { return true }
        let expiryDate = Date(timeIntervalSince1970: exp)
        return expiryDate.timeIntervalSinceNow < 86400
    }

    func tierFromCurrentToken() -> String? {
        guard let token = try? keychainHelper.read(key: Constants.keychainAuthJWTKey),
              let payload = decodeJWTPayload(token) else { return nil }
        return payload["tier"] as? String
    }

    private func currentEntitlementTransactionId() async -> UInt64? {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Constants.premiumProductId {
                return transaction.id
            }
        }
        return nil
    }

    private func decodeJWTPayload(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var base64 = String(parts[1])
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        guard let data = Data(base64Encoded: base64) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}

struct RegisterRequest: Codable, Sendable {
    let deviceId: String
    var transactionId: UInt64?
}

struct RefreshRequest: Codable, Sendable {
    let transactionId: UInt64
}

struct AuthResponse: Codable, Sendable {
    let token: String
}

final class KeychainHelper: KeychainHelperProtocol, Sendable {
    private let service: String

    init(service: String = Constants.keychainService) {
        self.service = service
    }

    func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw AppError.keychainError(
                underlying: NSError(
                    domain: "KeychainHelper",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to encode value"]
                )
            )
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        SecItemDelete(query as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AppError.keychainError(
                underlying: NSError(
                    domain: "KeychainHelper",
                    code: Int(status),
                    userInfo: [NSLocalizedDescriptionKey: "Keychain save failed: \(status)"]
                )
            )
        }
    }

    func read(key: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw AppError.authExpired
        }

        return value
    }

    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
