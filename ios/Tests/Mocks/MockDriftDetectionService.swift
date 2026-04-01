@testable import sprinty
import Foundation

final class MockDriftDetectionService: DriftDetectionServiceProtocol, @unchecked Sendable {
    var evaluateAndScheduleCallCount = 0
    var cancelCallCount = 0

    func evaluateAndSchedule() async {
        evaluateAndScheduleCallCount += 1
    }

    func cancelReEngagementNudge() async {
        cancelCallCount += 1
    }
}
