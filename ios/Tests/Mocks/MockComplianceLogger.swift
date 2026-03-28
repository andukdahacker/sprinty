@testable import sprinty
import Foundation

final class MockComplianceLogger: ComplianceLoggerProtocol, @unchecked Sendable {
    var logCallCount = 0
    var lastSessionId: UUID?
    var lastLevel: SafetyLevel?
    var lastSource: SafetyClassificationSource?
    var lastPreviousLevel: SafetyLevel?

    func logSafetyBoundary(sessionId: UUID, level: SafetyLevel, source: SafetyClassificationSource, previousLevel: SafetyLevel?) async {
        logCallCount += 1
        lastSessionId = sessionId
        lastLevel = level
        lastSource = source
        lastPreviousLevel = previousLevel
    }
}
