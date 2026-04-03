import Foundation
import UserNotifications

enum NotificationType: String, Codable, Sendable {
    case checkIn
    case sprintMilestone
    case pauseSuggestion
    case reEngagement

    var priority: Int {
        switch self {
        case .checkIn: return 2
        case .sprintMilestone: return 1
        case .pauseSuggestion: return 3
        case .reEngagement: return 4
        }
    }

    var bypassesMute: Bool {
        switch self {
        case .checkIn, .sprintMilestone, .pauseSuggestion, .reEngagement:
            return false
        }
    }

    var identifier: String {
        switch self {
        case .checkIn: return "com.ducdo.sprinty.checkin"
        case .sprintMilestone: return "com.ducdo.sprinty.milestone"
        case .pauseSuggestion: return "com.ducdo.sprinty.pausesuggestion"
        case .reEngagement: return "com.ducdo.sprinty.reengagement"
        }
    }

    var content: UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = ""
        content.sound = nil

        switch self {
        case .checkIn:
            content.body = "Your coach has a thought for you."
        case .sprintMilestone:
            content.body = "You hit a milestone. Your coach noticed."
        case .pauseSuggestion:
            content.body = "Your coach thinks you might need a breather."
        case .reEngagement:
            content.body = "Your coach has a thought for you."
        }

        return content
    }
}
