import Foundation

struct ChatRequestMessage: Codable, Sendable {
    let role: String
    let content: String
}

struct ChatProfile: Codable, Sendable {
    let coachName: String
}

struct ChatRequest: Codable, Sendable {
    let messages: [ChatRequestMessage]
    let mode: String
    let promptVersion: String
    let profile: ChatProfile?

    enum CodingKeys: String, CodingKey {
        case messages
        case mode
        case promptVersion
        case profile
    }
}
