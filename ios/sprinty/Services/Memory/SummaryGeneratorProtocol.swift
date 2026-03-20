import Foundation

protocol SummaryGeneratorProtocol: Sendable {
    func generate(messages: [ChatRequestMessage]) async throws -> SummaryResponse
}
