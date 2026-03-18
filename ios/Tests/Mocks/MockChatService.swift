@testable import sprinty
import Foundation

final class MockChatService: ChatServiceProtocol, @unchecked Sendable {
    var stubbedEvents: [ChatEvent] = []
    var stubbedError: Error?
    var lastMessages: [ChatRequestMessage]?
    var lastMode: String?
    var lastProfile: ChatProfile?

    func streamChat(messages: [ChatRequestMessage], mode: String, profile: ChatProfile?) -> AsyncThrowingStream<ChatEvent, Error> {
        lastMessages = messages
        lastMode = mode
        lastProfile = profile

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
