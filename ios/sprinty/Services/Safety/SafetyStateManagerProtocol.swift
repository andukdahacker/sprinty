import Foundation

@MainActor
protocol SafetyStateManagerProtocol: AnyObject {
    var currentLevel: SafetyLevel { get }
    func processClassification(_ level: SafetyLevel, source: SafetyClassificationSource) -> SafetyLevel
    func resetSession()
}
