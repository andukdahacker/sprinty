@testable import sprinty
import Foundation

final class MockProfileEnricher: ProfileEnricherProtocol, @unchecked Sendable {
    var enrichCallCount = 0
    var lastSummary: ConversationSummary?
    var stubbedError: Error?

    func enrich(from summary: ConversationSummary) async throws {
        enrichCallCount += 1
        lastSummary = summary
        if let error = stubbedError {
            throw error
        }
    }
}
