import Foundation

protocol SafetyHandlerProtocol: Sendable {
    func classify(serverLevel: SafetyLevel?) -> SafetyLevel
    func uiState(for level: SafetyLevel) -> SafetyUIState
}
