@testable import sprinty
import Foundation

final class MockOnDeviceSafetyClassifier: OnDeviceSafetyClassifierProtocol, @unchecked Sendable {
    var stubbedLevel: SafetyLevel?
    var lastClassifiedText: String?
    var classifyCallCount: Int = 0

    func classify(_ text: String) async -> SafetyLevel? {
        classifyCallCount += 1
        lastClassifiedText = text
        return stubbedLevel
    }
}
