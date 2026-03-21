@testable import sprinty
import Foundation

final class MockProfileUpdateService: ProfileUpdateServiceProtocol, @unchecked Sendable {
    var applyUpdateCallCount = 0
    var lastUpdate: ProfileUpdate?
    var lastProfileId: UUID?
    var stubbedError: Error?

    func applyUpdate(_ update: ProfileUpdate, to profileId: UUID) async throws {
        applyUpdateCallCount += 1
        lastUpdate = update
        lastProfileId = profileId
        if let error = stubbedError {
            throw error
        }
    }
}
