import Testing
import Foundation
@testable import ai_life_coach

@Suite("ChatEvent Codable")
struct ChatEventCodableTests {
    @Test("Decodes token SSE event")
    func test_fromSSE_tokenEvent_parsesText() throws {
        let sseEvent = SSEEvent(type: "token", data: "{\"text\": \"I hear you. \"}")
        let chatEvent = try ChatEvent.from(sseEvent: sseEvent)

        if case .token(let text) = chatEvent {
            #expect(text == "I hear you. ")
        } else {
            Issue.record("Expected token event")
        }
    }

    @Test("Decodes done SSE event with all fields")
    func test_fromSSE_doneEvent_parsesAllFields() throws {
        let json = """
        {"safetyLevel": "green", "domainTags": ["work"], "mood": "welcoming", "usage": {"inputTokens": 50, "outputTokens": 12}}
        """
        let sseEvent = SSEEvent(type: "done", data: json)
        let chatEvent = try ChatEvent.from(sseEvent: sseEvent)

        if case .done(let safetyLevel, let domainTags, let mood, let usage) = chatEvent {
            #expect(safetyLevel == "green")
            #expect(domainTags == ["work"])
            #expect(mood == "welcoming")
            #expect(usage.inputTokens == 50)
            #expect(usage.outputTokens == 12)
        } else {
            Issue.record("Expected done event")
        }
    }

    @Test("Decodes done event with empty domainTags array")
    func test_fromSSE_doneEvent_emptyDomainTags() throws {
        let json = """
        {"safetyLevel": "green", "domainTags": [], "mood": "welcoming", "usage": {"inputTokens": 10, "outputTokens": 5}}
        """
        let sseEvent = SSEEvent(type: "done", data: json)
        let chatEvent = try ChatEvent.from(sseEvent: sseEvent)

        if case .done(_, let domainTags, _, _) = chatEvent {
            #expect(domainTags.isEmpty)
        } else {
            Issue.record("Expected done event")
        }
    }

    @Test("Decodes done event with nil mood")
    func test_fromSSE_doneEvent_nilMood() throws {
        let json = """
        {"safetyLevel": "green", "domainTags": [], "usage": {"inputTokens": 10, "outputTokens": 5}}
        """
        let sseEvent = SSEEvent(type: "done", data: json)
        let chatEvent = try ChatEvent.from(sseEvent: sseEvent)

        if case .done(_, _, let mood, _) = chatEvent {
            #expect(mood == nil)
        } else {
            Issue.record("Expected done event")
        }
    }

    @Test("Throws on unknown event type")
    func test_fromSSE_unknownType_throws() throws {
        let sseEvent = SSEEvent(type: "unknown", data: "{}")
        #expect(throws: ChatEventParseError.self) {
            try ChatEvent.from(sseEvent: sseEvent)
        }
    }

    @Test("ChatRequest encodes with correct keys")
    func test_chatRequest_encodesCorrectly() throws {
        let request = ChatRequest(
            messages: [ChatRequestMessage(role: "user", content: "hello")],
            mode: "discovery",
            promptVersion: "1.0"
        )
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(decoded?["mode"] as? String == "discovery")
        #expect(decoded?["promptVersion"] as? String == "1.0")
        let messages = decoded?["messages"] as? [[String: Any]]
        #expect(messages?.count == 1)
        #expect(messages?[0]["role"] as? String == "user")
        #expect(messages?[0]["content"] as? String == "hello")
    }

    @Test("CoachExpression initializes from mood string")
    func test_coachExpression_initFromMood() {
        #expect(CoachExpression(mood: "welcoming") == .welcoming)
        #expect(CoachExpression(mood: "thinking") == .thinking)
        #expect(CoachExpression(mood: "warm") == .warm)
        #expect(CoachExpression(mood: "focused") == .focused)
        #expect(CoachExpression(mood: "gentle") == .gentle)
        #expect(CoachExpression(mood: nil) == .welcoming)
        #expect(CoachExpression(mood: "invalid") == .welcoming)
    }
}
