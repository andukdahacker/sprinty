@testable import sprinty
import Foundation

final class MockChatService: ChatServiceProtocol, @unchecked Sendable {
    var stubbedEvents: [ChatEvent] = []
    var stubbedError: Error?
    var stubbedSummaryResponse: SummaryResponse?
    var stubbedSummaryError: Error?
    var lastMessages: [ChatRequestMessage]?
    var lastMode: String?
    var lastProfile: ChatProfile?
    var lastUserState: UserState?
    var lastRagContext: String?
    var lastSprintContext: SprintContext?
    var summarizeCallCount: Int = 0

    func streamChat(messages: [ChatRequestMessage], mode: String, profile: ChatProfile?, userState: UserState? = nil, ragContext: String? = nil, sprintContext: SprintContext? = nil) -> AsyncThrowingStream<ChatEvent, Error> {
        lastMessages = messages
        lastMode = mode
        lastProfile = profile
        lastUserState = userState
        lastRagContext = ragContext
        lastSprintContext = sprintContext

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

    func summarize(messages: [ChatRequestMessage]) async throws -> SummaryResponse {
        summarizeCallCount += 1
        lastMessages = messages

        if let error = stubbedSummaryError {
            throw error
        }

        return stubbedSummaryResponse ?? SummaryResponse(
            summary: "Test summary",
            keyMoments: ["key moment"],
            domainTags: ["career"],
            emotionalMarkers: nil,
            keyDecisions: nil
        )
    }
}
