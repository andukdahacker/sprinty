import Foundation

protocol ChatServiceProtocol: Sendable {
    func streamChat(messages: [ChatRequestMessage], mode: String) -> AsyncThrowingStream<ChatEvent, Error>
}
