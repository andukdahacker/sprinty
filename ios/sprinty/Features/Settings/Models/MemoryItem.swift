import Foundation

struct MemoryItem: Identifiable, Sendable {
    let id: UUID            // ConversationSummary.id
    let rowid: Int64        // GRDB rowid for vector deletion
    let summary: String     // Natural language summary text
    let keyMoments: [String]
    let date: Date          // createdAt for display
    let domainTags: [String]
}
