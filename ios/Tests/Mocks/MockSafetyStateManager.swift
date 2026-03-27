@testable import sprinty
import Foundation

@MainActor
final class MockSafetyStateManager: SafetyStateManagerProtocol, @unchecked Sendable {
    var currentLevel: SafetyLevel = .green

    var processClassificationCallCount: Int = 0
    var lastProcessedLevel: SafetyLevel?
    var lastProcessedSource: SafetyClassificationSource?
    var stubbedProcessResult: SafetyLevel = .green

    var resetSessionCallCount: Int = 0

    func processClassification(_ level: SafetyLevel, source: SafetyClassificationSource) -> SafetyLevel {
        processClassificationCallCount += 1
        lastProcessedLevel = level
        lastProcessedSource = source
        currentLevel = stubbedProcessResult
        return stubbedProcessResult
    }

    func resetSession() {
        resetSessionCallCount += 1
        currentLevel = .green
    }
}
