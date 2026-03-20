import Foundation
import Testing
@testable import sprinty

@Suite("SummaryGenerator Tests")
struct SummaryGeneratorTests {

    @Test("generate returns summary from chat service")
    func test_generate_success() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedSummaryResponse = SummaryResponse(
            summary: "User explored career concerns.",
            keyMoments: ["realized pattern", "made commitment"],
            domainTags: ["career", "personal-growth"],
            emotionalMarkers: ["anxious", "determined"],
            keyDecisions: ["will schedule meeting"]
        )

        let generator = SummaryGenerator(chatService: mockChat)
        let messages = [
            ChatRequestMessage(role: "user", content: "I'm stressed about work"),
            ChatRequestMessage(role: "assistant", content: "What's driving that stress?")
        ]

        let result = try await generator.generate(messages: messages)

        #expect(result.summary == "User explored career concerns.")
        #expect(result.keyMoments.count == 2)
        #expect(result.domainTags == ["career", "personal-growth"])
        #expect(result.emotionalMarkers == ["anxious", "determined"])
        #expect(result.keyDecisions == ["will schedule meeting"])
        #expect(mockChat.summarizeCallCount == 1)
    }

    @Test("generate propagates network error")
    func test_generate_networkError() async throws {
        let mockChat = MockChatService()
        mockChat.stubbedSummaryError = AppError.networkUnavailable

        let generator = SummaryGenerator(chatService: mockChat)
        let messages = [
            ChatRequestMessage(role: "user", content: "Hello"),
            ChatRequestMessage(role: "assistant", content: "Hi there")
        ]

        do {
            _ = try await generator.generate(messages: messages)
            #expect(Bool(false), "Expected error to be thrown")
        } catch {
            #expect(error is AppError)
        }
    }

    @Test("generate passes messages to chat service")
    func test_generate_passesMessages() async throws {
        let mockChat = MockChatService()
        let generator = SummaryGenerator(chatService: mockChat)

        let messages = [
            ChatRequestMessage(role: "user", content: "Test message"),
            ChatRequestMessage(role: "assistant", content: "Test response")
        ]

        _ = try await generator.generate(messages: messages)

        #expect(mockChat.lastMessages?.count == 2)
        #expect(mockChat.lastMessages?[0].content == "Test message")
    }
}
