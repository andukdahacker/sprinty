import Foundation

enum AvatarOptions {
    static let avatarOptions: [(id: String, name: String)] = [
        ("avatar_classic", "Classic"),
        ("avatar_minimal", "Minimal"),
        ("avatar_zen", "Zen"),
    ]

    static let coachOptions: [(id: String, name: String, hint: String)] = [
        ("coach_sage", "Sage", "Warm and encouraging"),
        ("coach_mentor", "Mentor", "Focused and direct"),
        ("coach_guide", "Guide", "Calm and grounding"),
    ]

    static let defaultCoachNames = ["Sage", "Mentor", "Guide"]

    /// Builds the state-specific asset name for an avatar ID + state combination.
    /// e.g., "avatar_classic" + .active → "avatar_classic_active"
    static func assetName(for avatarId: String, state: AvatarState) -> String {
        "\(avatarId)_\(state.rawValue)"
    }
}
