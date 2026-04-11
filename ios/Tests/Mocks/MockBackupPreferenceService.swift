import Foundation
@testable import sprinty

final class MockBackupPreferenceService: BackupPreferenceServiceProtocol, @unchecked Sendable {
    var lastSetValue: Bool?
    var setCallCount = 0
    var stubbedExcluded: Bool = false
    var stubbedError: Error?

    func setExcludedFromBackup(_ excluded: Bool) throws {
        setCallCount += 1
        lastSetValue = excluded
        if let stubbedError {
            throw stubbedError
        }
        stubbedExcluded = excluded
    }

    func isExcludedFromBackup() throws -> Bool {
        if let stubbedError {
            throw stubbedError
        }
        return stubbedExcluded
    }
}
