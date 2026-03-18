import Testing
import Foundation
@testable import ai_life_coach

@Suite("SSEParser")
struct SSEParserTests {
    @Test("Parses token events")
    func test_parse_tokenEvents_returnsTokenText() async throws {
        let input = """
        event: token
        data: {"text": "I hear you. "}

        event: token
        data: {"text": "Let's explore that together."}

        """

        let events = try await parseLines(from: input)

        #expect(events.count == 2)
        #expect(events[0].type == "token")
        #expect(events[0].data == "{\"text\": \"I hear you. \"}")
        #expect(events[1].type == "token")
        #expect(events[1].data == "{\"text\": \"Let's explore that together.\"}")
    }

    @Test("Parses done event with mood field")
    func test_parse_doneEvent_returnsDoneWithMood() async throws {
        let input = """
        event: done
        data: {"safetyLevel": "green", "domainTags": [], "mood": "welcoming", "usage": {"inputTokens": 50, "outputTokens": 12}}

        """

        let events = try await parseLines(from: input)

        #expect(events.count == 1)
        #expect(events[0].type == "done")
        #expect(events[0].data.contains("\"mood\": \"welcoming\""))
    }

    @Test("Parses complete stream with token and done events")
    func test_parse_completeStream_returnsAllEvents() async throws {
        let input = """
        event: token
        data: {"text": "Hello "}

        event: token
        data: {"text": "there."}

        event: done
        data: {"safetyLevel": "green", "domainTags": [], "mood": "welcoming", "usage": {"inputTokens": 10, "outputTokens": 5}}

        """

        let events = try await parseLines(from: input)

        #expect(events.count == 3)
        #expect(events[0].type == "token")
        #expect(events[1].type == "token")
        #expect(events[2].type == "done")
    }

    @Test("Handles empty stream gracefully")
    func test_parse_emptyStream_returnsNoEvents() async throws {
        let events = try await parseLines(from: "")
        #expect(events.isEmpty)
    }

    @Test("Ignores incomplete events without blank line terminator")
    func test_parse_incompleteEvent_ignored() async throws {
        let input = "event: token\ndata: {\"text\": \"incomplete\"}"

        let events = try await parseLines(from: input)
        #expect(events.isEmpty)
    }

    @Test("ChatEvent.from converts token SSE event to ChatEvent")
    func test_chatEventFrom_tokenSSE() throws {
        let sseEvent = SSEEvent(type: "token", data: "{\"text\": \"hello\"}")
        let chatEvent = try ChatEvent.from(sseEvent: sseEvent)

        if case .token(let text) = chatEvent {
            #expect(text == "hello")
        } else {
            Issue.record("Expected token event")
        }
    }

    @Test("ChatEvent.from converts done SSE event to ChatEvent")
    func test_chatEventFrom_doneSSE() throws {
        let json = "{\"safetyLevel\": \"green\", \"domainTags\": [], \"mood\": \"welcoming\", \"usage\": {\"inputTokens\": 50, \"outputTokens\": 12}}"
        let sseEvent = SSEEvent(type: "done", data: json)
        let chatEvent = try ChatEvent.from(sseEvent: sseEvent)

        if case .done(let safety, let tags, let mood, let usage) = chatEvent {
            #expect(safety == "green")
            #expect(tags.isEmpty)
            #expect(mood == "welcoming")
            #expect(usage.inputTokens == 50)
        } else {
            Issue.record("Expected done event")
        }
    }

    // MARK: - Helpers

    private func parseLines(from string: String) async throws -> [SSEEvent] {
        let lines = string.components(separatedBy: "\n")

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
