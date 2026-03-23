import Foundation

enum AvatarState: String, Sendable, CaseIterable {
    case active
    case resting
    case celebrating
    case thinking
    case struggling

    var displayName: String {
        switch self {
        case .active: "Active"
        case .resting: "Resting"
        case .celebrating: "Celebrating"
        case .thinking: "Thinking"
        case .struggling: "Struggling"
        }
    }

    var saturationMultiplier: Double {
        switch self {
        case .active: 1.0
        case .resting: 0.65
        case .celebrating: 1.15
        case .thinking: 0.85
        case .struggling: 0.55
        }
    }

    static func derive(isPaused: Bool) -> AvatarState {
        isPaused ? .resting : .active
    }
}
