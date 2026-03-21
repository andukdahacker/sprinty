import Foundation
import GRDB
import OSLog

struct SearchResult: Sendable, Equatable, Identifiable {
    var id: UUID { messageId }
    let messageId: UUID
    let sessionId: UUID
    let content: String
    let timestamp: Date
}

enum SearchNavigationDirection: Sendable {
    case next
    case previous
}

protocol SearchServiceProtocol: Sendable {
    func search(query: String, limit: Int) async throws -> [SearchResult]
}

extension SearchServiceProtocol {
    func search(query: String) async throws -> [SearchResult] {
        try await search(query: query, limit: 50)
    }
}

final class SearchService: SearchServiceProtocol, Sendable {
    private let dbPool: DatabasePool
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "sprinty", category: "search")

    init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    func search(query: String, limit: Int = 50) async throws -> [SearchResult] {
        guard let sanitized = SearchService.sanitizeFTSQuery(query) else {
            return []
        }

        do {
            return try await dbPool.read { db in
                let rows = try Row.fetchAll(db, sql: """
                    SELECT m.id, m.sessionId, m.content, m.timestamp
                    FROM Message m
                    INNER JOIN MessageFTS fts ON fts.rowid = m.rowid
                    WHERE MessageFTS MATCH ?
                    ORDER BY fts.rank
                    LIMIT ?
                    """, arguments: [sanitized, limit])

                return rows.map { row in
                    let messageId: UUID = row["id"]
                    let sessionId: UUID = row["sessionId"]
                    let content: String = row["content"]
                    let timestamp: Date = row["timestamp"]
                    return SearchResult(
                        messageId: messageId,
                        sessionId: sessionId,
                        content: content,
                        timestamp: timestamp
                    )
                }
            }
        } catch {
            logger.error("FTS5 search failed: \(error)")
            throw error
        }
    }

    static func sanitizeFTSQuery(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return nil }
        let words = trimmed.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .filter { !["AND", "OR", "NOT", "NEAR"].contains($0.uppercased()) }
        guard !words.isEmpty else { return nil }
        return words.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
            .joined(separator: " ")
    }
}
