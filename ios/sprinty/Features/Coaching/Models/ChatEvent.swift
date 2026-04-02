import Foundation

enum ChatEvent: Sendable {
    case token(text: String)
    case sprintProposal(SprintProposalData)
    case done(safetyLevel: String, domainTags: [String], mood: String?, mode: String?, memoryReferenced: Bool?, challengerUsed: Bool?, usage: ChatUsage, promptVersion: String?, profileUpdate: ProfileUpdate?, guardrail: Bool?)
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
        case "sprint_proposal":
            let parsed = try JSONDecoder().decode(SprintProposalData.self, from: data)
            guard !parsed.name.isEmpty, !parsed.steps.isEmpty, parsed.durationWeeks > 0 else {
                throw ChatEventParseError.invalidData
            }
            return .sprintProposal(parsed)
        case "done":
            let parsed = try JSONDecoder().decode(DoneEventData.self, from: data)
            return .done(
                safetyLevel: parsed.safetyLevel,
                domainTags: parsed.domainTags,
                mood: parsed.mood,
                mode: parsed.mode,
                memoryReferenced: parsed.memoryReferenced,
                challengerUsed: parsed.challengerUsed,
                usage: parsed.usage,
                promptVersion: parsed.promptVersion,
                profileUpdate: parsed.profileUpdate,
                guardrail: parsed.guardrail
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
    let memoryReferenced: Bool?
    let challengerUsed: Bool?
    let usage: ChatUsage
    let promptVersion: String?
    let profileUpdate: ProfileUpdate?
    let guardrail: Bool?
}
