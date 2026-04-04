import Foundation

protocol ConversationExportServiceProtocol: Sendable {
    func exportConversations() async throws -> URL
    func hasConversations() async throws -> Bool
}
