import Foundation

protocol ChatServiceProtocol: Sendable {
    func streamChat(messages: [ChatRequestMessage], mode: String, profile: ChatProfile?, userState: UserState?, ragContext: String?, sprintContext: SprintContext?) -> AsyncThrowingStream<ChatEvent, Error>
    func summarize(messages: [ChatRequestMessage]) async throws -> SummaryResponse
}
