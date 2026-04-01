import Foundation
import GRDB

enum EngagementSource: String, Codable, DatabaseValueConvertible, Sendable {
    case organic
    case checkInNotification
    case reEngagementNudge
}
