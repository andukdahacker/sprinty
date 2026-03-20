import Foundation

protocol ChatServiceProtocol: Sendable {
    func streamChat(messages: [ChatRequestMessage], mode: String, profile: ChatProfile?, userState: UserState?) -> AsyncThrowingStream<ChatEvent, Error>
}
