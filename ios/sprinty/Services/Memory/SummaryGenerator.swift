import Foundation

final class SummaryGenerator: SummaryGeneratorProtocol, Sendable {
    private let chatService: ChatServiceProtocol

    init(chatService: ChatServiceProtocol) {
        self.chatService = chatService
    }

    func generate(messages: [ChatRequestMessage]) async throws -> SummaryResponse {
        try await chatService.summarize(messages: messages)
    }
}
