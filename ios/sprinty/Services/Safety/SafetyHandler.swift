import Foundation

struct SafetyHandler: SafetyHandlerProtocol {
    func classify(serverLevel: SafetyLevel?) -> SafetyLevel {
        // UX-DR71: fail-safe to yellow when server level missing or nil
        serverLevel ?? .yellow
    }

    func uiState(for level: SafetyLevel) -> SafetyUIState {
        switch level {
        case .green:
            SafetyUIState(
                level: .green,
                hiddenElements: [],
                coachExpression: .welcoming,
                notificationBehavior: .normal,
                showCrisisResources: false
            )
        case .yellow:
            SafetyUIState(
                level: .yellow,
                hiddenElements: [],
                coachExpression: .gentle,
                notificationBehavior: .normal,
                showCrisisResources: false
            )
        case .orange:
            SafetyUIState(
                level: .orange,
                hiddenElements: [.gamification, .celebrations, .sprintProgress],
                coachExpression: .gentle,
                notificationBehavior: .safetyOnly,
                showCrisisResources: true
            )
        case .red:
            SafetyUIState(
                level: .red,
                hiddenElements: Set(HiddenElement.allCases),
                coachExpression: .gentle,
                notificationBehavior: .suppressed,
                showCrisisResources: true
            )
        }
    }
}
