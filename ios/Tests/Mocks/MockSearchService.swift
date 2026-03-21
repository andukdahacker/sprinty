import Foundation
@testable import sprinty

final class MockSearchService: SearchServiceProtocol, @unchecked Sendable {
    var stubbedResults: [SearchResult] = []
    var stubbedError: Error?
    var lastQuery: String?
    var lastLimit: Int?
    var searchCallCount: Int = 0

    func search(query: String, limit: Int = 50) async throws -> [SearchResult] {
        lastQuery = query
        lastLimit = limit
        searchCallCount += 1
        if let error = stubbedError {
            throw error
        }
        return stubbedResults
    }
}
