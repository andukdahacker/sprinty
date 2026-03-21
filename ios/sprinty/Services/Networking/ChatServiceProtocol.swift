import Foundation

protocol ChatServiceProtocol: Sendable {
    func streamChat(messages: [ChatRequestMessage], mode: String, profile: ChatProfile?, userState: UserState?, ragContext: String?) -> AsyncThrowingStream<ChatEvent, Error>
    func summarize(messages: [ChatRequestMessage]) async throws -> SummaryResponse
}
