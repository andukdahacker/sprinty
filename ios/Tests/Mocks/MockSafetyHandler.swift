@testable import sprinty
import Foundation

final class MockSafetyHandler: SafetyHandlerProtocol, @unchecked Sendable {
    var lastClassifyServerLevel: SafetyLevel?
    var classifyCallCount: Int = 0
    var stubbedClassifyResult: SafetyLevel = .green

    var lastUIStateLevel: SafetyLevel?
    var uiStateCallCount: Int = 0
    var stubbedUIState: SafetyUIState = .green

    func classify(serverLevel: SafetyLevel?) -> SafetyLevel {
        lastClassifyServerLevel = serverLevel
        classifyCallCount += 1
        return stubbedClassifyResult
    }

    func uiState(for level: SafetyLevel) -> SafetyUIState {
        lastUIStateLevel = level
        uiStateCallCount += 1
        return stubbedUIState
    }
}
