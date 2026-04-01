@testable import sprinty
import Foundation
import GRDB

final class MockAutonomyCalculator: AutonomyCalculatorProtocol, @unchecked Sendable {
    var stubbedSnapshot = AutonomySnapshot(
        voluntarySessionRate: 0.5,
        totalSessions: 10,
        organicSessions: 5,
        notificationTriggeredSessions: 5,
        autonomyLevel: .none
    )

    var computeCallCount = 0

    func computeAutonomySnapshot(db: Database) throws -> AutonomySnapshot {
        computeCallCount += 1
        return stubbedSnapshot
    }
}
