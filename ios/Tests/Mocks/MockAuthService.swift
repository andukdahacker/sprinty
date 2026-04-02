@testable import sprinty
import Foundation

final class MockAuthService: AuthServiceProtocol, @unchecked Sendable {
    var ensureAuthenticatedCallCount = 0
    var stubbedEnsureAuthenticatedError: Error?

    var getTokenCallCount = 0
    var stubbedToken: String = "mock-jwt-token"
    var stubbedGetTokenError: Error?

    var refreshTokenCallCount = 0
    var stubbedRefreshTokenError: Error?

    var refreshTokenWithTransactionCallCount = 0
    var lastTransactionId: UInt64?
    var stubbedRefreshTokenWithTransactionError: Error?

    func ensureAuthenticated() async throws {
        ensureAuthenticatedCallCount += 1
        if let error = stubbedEnsureAuthenticatedError {
            throw error
        }
    }

    func getToken() throws -> String {
        getTokenCallCount += 1
        if let error = stubbedGetTokenError {
            throw error
        }
        return stubbedToken
    }

    func refreshToken() async throws {
        refreshTokenCallCount += 1
        if let error = stubbedRefreshTokenError {
            throw error
        }
    }

    func refreshTokenWithTransaction(_ transactionId: UInt64) async throws {
        refreshTokenWithTransactionCallCount += 1
        lastTransactionId = transactionId
        if let error = stubbedRefreshTokenWithTransactionError {
            throw error
        }
    }
}
