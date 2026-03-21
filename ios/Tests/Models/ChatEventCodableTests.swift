import Testing
import Foundation
@testable import sprinty

@Suite("ChatEvent Codable")
struct ChatEventCodableTests {

    // MARK: - Fixture-based tests

    @Test("Decodes token event from fixture SSE data")
    func test_fromSSE_tokenEvent_fromFixture() throws {
        let fixtureContent = try loadFixture("sse-token-event.txt")
        let events = parseSSEFixture(fixtureContent)

        #expect(!events.isEmpty)
        let chatEvent = try ChatEvent.from(sseEvent: events[0])

        if case .token(let text) = chatEvent {
            #expect(text == "I hear you. ")
        } else {
            Issue.record("Expected token event")
        }
    }

    @Test("Decodes done event from fixture SSE data")
    func test_fromSSE_doneEvent_fromFixture() throws {
        let fixtureContent = try loadFixture("sse-done-event.txt")
        let events = parseSSEFixture(fixtureContent)

        #expect(events.count == 1)
        let chatEvent = try ChatEvent.from(sseEvent: events[0])

        if case .done(let safetyLevel, let domainTags, let mood, let mode, let challengerUsed, let usage, let promptVersion, _) = chatEvent {
            #expect(safetyLevel == "green")
            #expect(domainTags.isEmpty)
            #expect(mood == "welcoming")
            #expect(mode == "discovery")
            #expect(challengerUsed == false)
            #expect(usage.inputTokens == 50)
            #expect(usage.outputTokens == 12)
            #expect(promptVersion == "abc123")
        } else {
            Issue.record("Expected done event")
        }
    }

    @Test("ChatRequest encodes matching fixture format")
    func test_chatRequest_matchesFixture() throws {
        let fixtureData = try Data(contentsOf: fixtureURL("chat-request-sample.json"))
        let fixtureJSON = try JSONSerialization.jsonObject(with: fixtureData) as? [String: Any]

        let request = ChatRequest(
            messages: [ChatRequestMessage(role: "user", content: "I've been feeling stuck at work lately.")],
            mode: "discovery",
            promptVersion: "1.0",
            profile: nil
        )
        let encoded = try JSONEncoder().encode(request)
        let encodedJSON = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]

        #expect(encodedJSON?["mode"] as? String == fixtureJSON?["mode"] as? String)
        #expect(encodedJSON?["promptVersion"] as? String == fixtureJSON?["promptVersion"] as? String)

        let fixtureMessages = fixtureJSON?["messages"] as? [[String: Any]]
        let encodedMessages = encodedJSON?["messages"] as? [[String: Any]]
        #expect(fixtureMessages?.count == encodedMessages?.count)
        #expect(fixtureMessages?[0]["role"] as? String == encodedMessages?[0]["role"] as? String)
        #expect(fixtureMessages?[0]["content"] as? String == encodedMessages?[0]["content"] as? String)
    }

    // MARK: - Edge cases

    @Test("Decodes done event with empty domainTags array")
    func test_fromSSE_doneEvent_emptyDomainTags() throws {
        let json = """
        {"safetyLevel": "green", "domainTags": [], "mood": "welcoming", "usage": {"inputTokens": 10, "outputTokens": 5}}
        """
        let sseEvent = SSEEvent(type: "done", data: json)
        let chatEvent = try ChatEvent.from(sseEvent: sseEvent)

        if case .done(_, let domainTags, _, _, _, _, _, _) = chatEvent {
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

        if case .done(_, _, let mood, _, _, _, _, _) = chatEvent {
            #expect(mood == nil)
        } else {
            Issue.record("Expected done event")
        }
    }

    @Test("Decodes done event and extracts mode field")
    func test_parseSseEvent_withDoneEvent_extractsMode() throws {
        let json = """
        {"safetyLevel": "green", "domainTags": ["career"], "mood": "warm", "mode": "discovery", "usage": {"inputTokens": 10, "outputTokens": 5}, "promptVersion": "abc"}
        """
        let sseEvent = SSEEvent(type: "done", data: json)
        let chatEvent = try ChatEvent.from(sseEvent: sseEvent)

        if case .done(_, _, _, let mode, _, _, _, _) = chatEvent {
            #expect(mode == "discovery")
        } else {
            Issue.record("Expected done event")
        }
    }

    @Test("Decodes done event with nil mode for backward compat")
    func test_parseSseEvent_withDoneEvent_nilMode() throws {
        let json = """
        {"safetyLevel": "green", "domainTags": [], "mood": "welcoming", "usage": {"inputTokens": 10, "outputTokens": 5}}
        """
        let sseEvent = SSEEvent(type: "done", data: json)
        let chatEvent = try ChatEvent.from(sseEvent: sseEvent)

        if case .done(_, _, _, let mode, _, _, _, _) = chatEvent {
            #expect(mode == nil)
        } else {
            Issue.record("Expected done event")
        }
    }

    @Test("Decodes done event with challengerUsed true")
    func test_fromSSE_doneEvent_challengerUsedTrue() throws {
        let json = """
        {"safetyLevel": "green", "domainTags": ["career"], "mood": "focused", "mode": "discovery", "challengerUsed": true, "usage": {"inputTokens": 30, "outputTokens": 20}, "promptVersion": "v2"}
        """
        let sseEvent = SSEEvent(type: "done", data: json)
        let chatEvent = try ChatEvent.from(sseEvent: sseEvent)

        if case .done(_, _, _, _, let challengerUsed, _, _, _) = chatEvent {
            #expect(challengerUsed == true)
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

    // MARK: - Helpers

    private func fixtureURL(_ filename: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Models/
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // ios/
            .deletingLastPathComponent() // project root
            .appendingPathComponent("docs")
            .appendingPathComponent("fixtures")
            .appendingPathComponent(filename)
    }

    private func loadFixture(_ filename: String) throws -> String {
        try String(contentsOf: fixtureURL(filename), encoding: .utf8)
    }

    private func parseSSEFixture(_ content: String) -> [SSEEvent] {
        let lines = content.components(separatedBy: "\n")
        var currentEventType: String?
        var currentData: String?
        var events: [SSEEvent] = []

        for line in lines {
            if line.hasPrefix("event: ") {
                currentEventType = String(line.dropFirst(7))
            } else if line.hasPrefix("data: ") {
                currentData = String(line.dropFirst(6))
            } else if line.isEmpty {
                if let eventType = currentEventType, let data = currentData {
                    events.append(SSEEvent(type: eventType, data: data))
                }
                currentEventType = nil
                currentData = nil
            }
        }
        return events
    }
}
