import Foundation

enum CoachExpression: String, Sendable, CaseIterable {
    case welcoming
    case thinking
    case warm
    case focused
    case gentle

    init(mood: String?) {
        guard let mood, let expression = CoachExpression(rawValue: mood) else {
            self = .welcoming
            return
        }
        self = expression
    }

    var sfSymbolName: String {
        switch self {
        case .welcoming: "person.circle.fill"
        case .thinking: "brain.head.profile"
        case .warm: "heart.circle.fill"
        case .focused: "eye.circle.fill"
        case .gentle: "leaf.circle.fill"
        }
    }

    var statusText: String {
        switch self {
        case .thinking: "Thinking about what you said..."
        case .welcoming, .warm, .focused, .gentle: ""
        }
    }
}
