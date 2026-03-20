@testable import sprinty
import Foundation

final class MockEmbeddingService: EmbeddingServiceProtocol, @unchecked Sendable {
    var stubbedEmbedding: [Float] = Array(repeating: 0.1, count: 384)
    var stubbedError: Error?
    var generateCallCount: Int = 0
    var lastText: String?

    func generateEmbedding(for text: String) throws -> [Float] {
        generateCallCount += 1
        lastText = text
        if let error = stubbedError {
            throw error
        }
        return stubbedEmbedding
    }
}
