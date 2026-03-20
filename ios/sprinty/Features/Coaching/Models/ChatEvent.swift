import Foundation

enum ChatEvent: Sendable {
    case token(text: String)
    case done(safetyLevel: String, domainTags: [String], mood: String?, mode: String?, challengerUsed: Bool?, usage: ChatUsage, promptVersion: String?)
}

struct ChatUsage: Codable, Sendable {
    let inputTokens: Int
    let outputTokens: Int
}

extension ChatEvent {
    static func from(sseEvent: SSEEvent) throws -> ChatEvent {
        guard let data = sseEvent.data.data(using: .utf8) else {
            throw ChatEventParseError.invalidData
        }

        switch sseEvent.type {
        case "token":
            let parsed = try JSONDecoder().decode(TokenEventData.self, from: data)
            return .token(text: parsed.text)
        case "done":
            let parsed = try JSONDecoder().decode(DoneEventData.self, from: data)
            return .done(
                safetyLevel: parsed.safetyLevel,
                domainTags: parsed.domainTags,
                mood: parsed.mood,
                mode: parsed.mode,
                challengerUsed: parsed.challengerUsed,
                usage: parsed.usage,
                promptVersion: parsed.promptVersion
            )
        default:
            throw ChatEventParseError.unknownEventType(sseEvent.type)
        }
    }
}

enum ChatEventParseError: Error, Sendable {
    case invalidData
    case unknownEventType(String)
}

private struct TokenEventData: Codable {
    let text: String
}

private struct DoneEventData: Codable {
    let safetyLevel: String
    let domainTags: [String]
    let mood: String?
    let mode: String?
    let challengerUsed: Bool?
    let usage: ChatUsage
    let promptVersion: String?
}
