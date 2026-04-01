@testable import sprinty
import Foundation

final class MockDriftDetectionService: DriftDetectionServiceProtocol, @unchecked Sendable {
    var evaluateAndScheduleCallCount = 0
    var lastAutonomyLevel: AutonomyLevel?
    var cancelCallCount = 0

    func evaluateAndSchedule() async {
        evaluateAndScheduleCallCount += 1
    }

    func evaluateAndSchedule(autonomyLevel: AutonomyLevel) async {
        evaluateAndScheduleCallCount += 1
        lastAutonomyLevel = autonomyLevel
    }

    func cancelReEngagementNudge() async {
        cancelCallCount += 1
    }
}
