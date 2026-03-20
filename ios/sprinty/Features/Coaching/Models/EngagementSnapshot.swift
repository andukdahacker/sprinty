import Foundation

enum EngagementLevel: String, Codable, Sendable {
    case high
    case medium
    case low
}

enum MessageLength: String, Codable, Sendable {
    case short
    case medium
    case long
}

enum SessionIntensity: String, Codable, Sendable {
    case light
    case moderate
    case deep
}

struct EngagementSnapshot: Codable, Sendable {
    let engagementLevel: EngagementLevel
    let recentMoods: [String]
    let avgMessageLength: MessageLength
    let sessionCount: Int
    let lastSessionGapHours: Int?
    let recentSessionIntensity: SessionIntensity
}
