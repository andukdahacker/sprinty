@testable import ai_life_coach
import Foundation

final class MockChatService: ChatServiceProtocol, @unchecked Sendable {
    var stubbedEvents: [ChatEvent] = []
    var stubbedError: Error?
    var lastMessages: [ChatRequestMessage]?
    var lastMode: String?

    func streamChat(messages: [ChatRequestMessage], mode: String) -> AsyncThrowingStream<ChatEvent, Error> {
        lastMessages = messages
        lastMode = mode

        let events = stubbedEvents
        let error = stubbedError

        return AsyncThrowingStream { continuation in
            Task {
                if let error {
                    continuation.finish(throwing: error)
                    return
                }

                for event in events {
                    continuation.yield(event)
                }
                continuation.finish()
            }
        }
    }
}
