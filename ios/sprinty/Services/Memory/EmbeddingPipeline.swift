import Foundation
import GRDB
import OSLog

// @unchecked Sendable: thread-safe via internal locking of injected dependencies
final class EmbeddingPipeline: EmbeddingPipelineProtocol, @unchecked Sendable {
    private let embeddingService: EmbeddingServiceProtocol
    private let vectorSearch: VectorSearchProtocol
    private let databaseManager: DatabaseManager

    init(embeddingService: EmbeddingServiceProtocol, vectorSearch: VectorSearchProtocol, databaseManager: DatabaseManager) {
        self.embeddingService = embeddingService
        self.vectorSearch = vectorSearch
        self.databaseManager = databaseManager
    }

    func embed(summary: ConversationSummary, rowid: Int64) async throws {
        let embedding = try embeddingService.generateEmbedding(for: summary.summary)
        let embeddingData = ConversationSummary.encodeEmbedding(embedding)

        // Insert into sqlite-vec FIRST — if this fails, GRDB embedding stays nil
        // and retryMissingEmbeddings() will pick it up on next launch (AC3)
        try vectorSearch.insert(rowid: rowid, embedding: embedding)

        var mutableSummary = summary
        mutableSummary.embedding = embeddingData
        let toSave = mutableSummary
        try await databaseManager.dbPool.write { db in
            try toSave.update(db, columns: ["embedding"])
        }
    }

    func search(query: String, limit: Int) async throws -> [ConversationSummary] {
        let queryEmbedding = try embeddingService.generateEmbedding(for: query)
        let results = try vectorSearch.query(embedding: queryEmbedding, limit: limit)

        guard !results.isEmpty else { return [] }

        let rowids = results.map { $0.rowid }
        let placeholders = rowids.map { _ in "?" }.joined(separator: ",")
        let sql = "SELECT rowid, * FROM ConversationSummary WHERE rowid IN (\(placeholders))"
        let arguments = StatementArguments(rowids.map { DatabaseValue(value: $0) })

        // Batch fetch + build rowid mapping in one query (no N+1)
        let summaryByRowid: [Int64: ConversationSummary] = try await databaseManager.dbPool.read { db in
            let rows = try Row.fetchAll(db, sql: sql, arguments: arguments)
            var mapping: [Int64: ConversationSummary] = [:]
            for row in rows {
                if let summary = try? ConversationSummary(row: row),
                   let rowid = row["rowid"] as Int64? {
                    mapping[rowid] = summary
                }
            }
            return mapping
        }

        // Preserve distance ordering from vector search
        return results.compactMap { summaryByRowid[$0.rowid] }
    }

    func deleteEmbedding(summaryRowid: Int64) async throws {
        try vectorSearch.delete(rowid: summaryRowid)
    }

    func retryMissingEmbeddings() async {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "sprinty", category: "memory")

        do {
            let rows: [(summary: ConversationSummary, rowid: Int64)] = try await databaseManager.dbPool.read { db in
                let rows = try Row.fetchAll(db, sql: "SELECT rowid, * FROM ConversationSummary WHERE embedding IS NULL")
                return rows.compactMap { row in
                    guard let summary = try? ConversationSummary(row: row),
                          let rowid = row["rowid"] as Int64? else { return nil }
                    return (summary: summary, rowid: rowid)
                }
            }

            for row in rows {
                do {
                    try await embed(summary: row.summary, rowid: row.rowid)
                } catch {
                    logger.error("Retry embedding failed for summary \(row.summary.id): \(error)")
                }
            }
        } catch {
            logger.error("Failed to query summaries without embeddings: \(error)")
        }
    }
}
