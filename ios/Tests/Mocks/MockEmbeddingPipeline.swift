@testable import sprinty
import Foundation

final class MockEmbeddingPipeline: EmbeddingPipelineProtocol, @unchecked Sendable {
    var embedCallCount: Int = 0
    var lastEmbedSummary: ConversationSummary?
    var lastEmbedRowid: Int64?
    var stubbedEmbedError: Error?

    var searchCallCount: Int = 0
    var lastSearchQuery: String?
    var lastSearchLimit: Int?
    var stubbedSearchResults: [ConversationSummary] = []
    var stubbedSearchError: Error?

    var retryCallCount: Int = 0

    var deleteEmbeddingCallCount: Int = 0
    var lastDeletedRowid: Int64?
    var stubbedDeleteError: Error?

    func embed(summary: ConversationSummary, rowid: Int64) async throws {
        embedCallCount += 1
        lastEmbedSummary = summary
        lastEmbedRowid = rowid
        if let error = stubbedEmbedError {
            throw error
        }
    }

    func search(query: String, limit: Int) async throws -> [ConversationSummary] {
        searchCallCount += 1
        lastSearchQuery = query
        lastSearchLimit = limit
        if let error = stubbedSearchError {
            throw error
        }
        return stubbedSearchResults
    }

    func retryMissingEmbeddings() async {
        retryCallCount += 1
    }

    func deleteEmbedding(summaryRowid: Int64) async throws {
        deleteEmbeddingCallCount += 1
        lastDeletedRowid = summaryRowid
        if let error = stubbedDeleteError {
            throw error
        }
    }
}
