import Foundation
import Security

protocol AuthServiceProtocol: Sendable {
    func ensureAuthenticated() async throws
    func getToken() throws -> String
    func refreshToken() async throws
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

        try await register(deviceId: deviceId)
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

    private func register(deviceId: String) async throws {
        let body = RegisterRequest(deviceId: deviceId)
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
