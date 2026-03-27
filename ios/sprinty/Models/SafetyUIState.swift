import Foundation

enum HiddenElement: String, Sendable, CaseIterable {
    case gamification
    case sprintProgress
    case avatarActivity
    case celebrations
}

enum NotificationBehavior: String, Sendable {
    case normal
    case safetyOnly
    case suppressed
}

struct SafetyUIState: Sendable {
    let level: SafetyLevel
    let hiddenElements: Set<HiddenElement>
    let coachExpression: CoachExpression
    let notificationBehavior: NotificationBehavior
    let showCrisisResources: Bool

    static let green = SafetyUIState(
        level: .green,
        hiddenElements: [],
        coachExpression: .welcoming,
        notificationBehavior: .normal,
        showCrisisResources: false
    )
}
