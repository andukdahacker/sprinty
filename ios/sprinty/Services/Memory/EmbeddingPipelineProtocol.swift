import Foundation

protocol EmbeddingPipelineProtocol: Sendable {
    func embed(summary: ConversationSummary, rowid: Int64) async throws
    func search(query: String, limit: Int) async throws -> [ConversationSummary]
    func retryMissingEmbeddings() async
    func deleteEmbedding(summaryRowid: Int64) async throws
}
