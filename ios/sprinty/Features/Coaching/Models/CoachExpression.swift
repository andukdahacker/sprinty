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

    /// Builds the asset catalog name for this expression + coach variant.
    /// e.g., .thinking + "coach_sage" → "coach_sage_thinking"
    func assetName(for coachAppearanceId: String) -> String {
        "\(coachAppearanceId)_\(rawValue)"
    }

    var statusText: String {
        switch self {
        case .thinking: "Thinking about what you said..."
        case .welcoming, .warm, .focused, .gentle: ""
        }
    }
}
