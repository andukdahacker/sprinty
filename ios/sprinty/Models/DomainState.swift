import Foundation

struct DomainState: Codable, Sendable {
    let status: String?
    let conversationCount: Int?
    let lastUpdated: String?
}
