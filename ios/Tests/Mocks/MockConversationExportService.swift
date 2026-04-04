@testable import sprinty
import Foundation

final class MockConversationExportService: ConversationExportServiceProtocol, @unchecked Sendable {
    var exportCallCount = 0
    var hasConversationsCallCount = 0
    var stubbedHasConversations = true
    var stubbedExportURL: URL?
    var stubbedError: Error?

    func exportConversations() async throws -> URL {
        exportCallCount += 1
        if let error = stubbedError { throw error }
        return stubbedExportURL ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-export.md")
    }

    func hasConversations() async throws -> Bool {
        hasConversationsCallCount += 1
        if let error = stubbedError { throw error }
        return stubbedHasConversations
    }
}
