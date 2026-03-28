import Foundation

protocol ComplianceLoggerProtocol: Sendable {
    func logSafetyBoundary(
        sessionId: UUID,
        level: SafetyLevel,
        source: SafetyClassificationSource,
        previousLevel: SafetyLevel?
    ) async
}
