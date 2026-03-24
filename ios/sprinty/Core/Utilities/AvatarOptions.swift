import Foundation

enum AvatarOptions {
    static let avatarOptions: [(id: String, name: String)] = [
        ("person.circle.fill", "Classic"),
        ("person.circle", "Minimal"),
        ("figure.mind.and.body", "Zen"),
    ]

    static let coachOptions: [(id: String, name: String, hint: String)] = [
        ("person.circle.fill", "Sage", "Warm and encouraging"),
        ("brain.head.profile", "Mentor", "Focused and direct"),
        ("leaf.circle.fill", "Guide", "Calm and grounding"),
    ]

    static let defaultCoachNames = ["Sage", "Mentor", "Guide"]
}
