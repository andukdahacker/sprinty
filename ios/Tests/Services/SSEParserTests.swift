import Testing
import Foundation
@testable import sprinty

@Suite("SSEParser")
struct SSEParserTests {

    // MARK: - Real SSEParser Tests

    @Test("Parses token events from fixture file")
    func test_parse_tokenEvents_fromFixture() async throws {
        let input = try loadFixture("sse-token-event.txt")
        let events = try await parseSSE(input)

        #expect(events.count == 2)
        #expect(events[0].type == "token")
        #expect(events[0].data == "{\"text\": \"I hear you. \"}")
        #expect(events[1].type == "token")
        #expect(events[1].data == "{\"text\": \"Let's explore that together.\"}")
    }

    @Test("Parses done event with mood field from fixture file")
    func test_parse_doneEvent_fromFixture() async throws {
        let input = try loadFixture("sse-done-event.txt")
        let events = try await parseSSE(input)

        #expect(events.count == 1)
        #expect(events[0].type == "done")
        #expect(events[0].data.contains("\"mood\": \"welcoming\""))
    }

    @Test("Parses complete stream with token and done events")
    func test_parse_completeStream_returnsAllEvents() async throws {
        let tokenFixture = try loadFixture("sse-token-event.txt")
        let doneFixture = try loadFixture("sse-done-event.txt")
        let combined = tokenFixture + "\n" + doneFixture

        let events = try await parseSSE(combined)

        #expect(events.count == 3)
        #expect(events[0].type == "token")
        #expect(events[1].type == "token")
        #expect(events[2].type == "done")
    }

    @Test("Handles empty stream gracefully")
    func test_parse_emptyStream_returnsNoEvents() async throws {
        let events = try await parseSSE("")
        #expect(events.isEmpty)
    }

    @Test("Ignores incomplete events without blank line terminator")
    func test_parse_incompleteEvent_ignored() async throws {
        let input = "event: token\ndata: {\"text\": \"incomplete\"}"
        let events = try await parseSSE(input)
        #expect(events.isEmpty)
    }

    // MARK: - ChatEvent.from conversion

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

    private func loadFixture(_ filename: String) throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let fixtureURL = testFile
            .deletingLastPathComponent() // Services/
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // ios/
            .deletingLastPathComponent() // project root
            .appendingPathComponent("docs")
            .appendingPathComponent("fixtures")
            .appendingPathComponent(filename)
        return try String(contentsOf: fixtureURL, encoding: .utf8)
    }

    private func parseSSE(_ input: String) async throws -> [SSEEvent] {
        let lines = AsyncLineSequence(string: input)
        let parser = SSEParser()
        let stream = parser.parseLines(lines)

        var events: [SSEEvent] = []
        for try await event in stream {
            events.append(event)
        }
        return events
    }
}

private struct AsyncLineSequence: AsyncSequence, Sendable {
    typealias Element = String
    let lines: [String]

    init(string: String) {
        self.lines = string.components(separatedBy: "\n")
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(lines: lines)
    }

    struct AsyncIterator: AsyncIteratorProtocol {
        let lines: [String]
        var index = 0

        mutating func next() -> String? {
            guard index < lines.count else { return nil }
            let line = lines[index]
            index += 1
            return line
        }
    }
}
