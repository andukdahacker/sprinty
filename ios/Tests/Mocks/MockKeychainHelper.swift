@testable import sprinty
import Foundation

final class MockKeychainHelper: KeychainHelperProtocol, @unchecked Sendable {
    var store: [String: String] = [:]
    var deletedKeys: [String] = []

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
        deletedKeys.append(key)
        store.removeValue(forKey: key)
    }
}
