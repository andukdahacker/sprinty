@testable import sprinty
import Foundation

final class MockDataDeletionService: DataDeletionServiceProtocol, @unchecked Sendable {
    var callCount = 0
    var stubbedError: Error?

    func deleteAllData() async throws {
        callCount += 1
        if let stubbedError {
            throw stubbedError
        }
    }
}
