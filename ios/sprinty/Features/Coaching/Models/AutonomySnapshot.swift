import Foundation

struct AutonomySnapshot: Codable, Sendable {
    let voluntarySessionRate: Float
    let totalSessions: Int
    let organicSessions: Int
    let notificationTriggeredSessions: Int
    let autonomyLevel: AutonomyLevel
}
