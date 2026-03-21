import Foundation

protocol ProfileEnricherProtocol: Sendable {
    func enrich(from summary: ConversationSummary) async throws
}
