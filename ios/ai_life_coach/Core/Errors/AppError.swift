import Foundation

enum AppError: Error, Sendable {
    case networkUnavailable
    case authExpired
    case providerError(message: String, retryAfter: Int?)
    case degraded
    case databaseError(underlying: any Error)
    case keychainError(underlying: any Error)
}
