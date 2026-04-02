import Testing
import Foundation
import GRDB
@testable import sprinty

// --- Story 8.3 Tests ---

@Suite("DoneEventData Guardrail Decoding")
struct DoneEventGuardrailTests {

    @Test
    func test_doneEvent_decodesGuardrailTrue() throws {
        let json = """
        {"safetyLevel":"green","domainTags":[],"mood":"welcoming","mode":"discovery","memoryReferenced":false,"challengerUsed":false,"usage":{"inputTokens":10,"outputTokens":5},"guardrail":true}
        """
        let sseEvent = SSEEvent(type: "done", data: json)
        let event = try ChatEvent.from(sseEvent: sseEvent)

        if case .done(_, _, _, _, _, _, _, _, _, let guardrail) = event {
            #expect(guardrail == true)
        } else {
            Issue.record("Expected .done event")
        }
    }

    @Test
    func test_doneEvent_decodesGuardrailAbsent() throws {
        let json = """
        {"safetyLevel":"green","domainTags":[],"mood":"welcoming","mode":"discovery","memoryReferenced":false,"challengerUsed":false,"usage":{"inputTokens":10,"outputTokens":5}}
        """
        let sseEvent = SSEEvent(type: "done", data: json)
        let event = try ChatEvent.from(sseEvent: sseEvent)

        if case .done(_, _, _, _, _, _, _, _, _, let guardrail) = event {
            #expect(guardrail == nil)
        } else {
            Issue.record("Expected .done event")
        }
    }

    @Test
    func test_doneEvent_decodesGuardrailFalse() throws {
        let json = """
        {"safetyLevel":"green","domainTags":[],"mood":"welcoming","mode":"discovery","memoryReferenced":false,"challengerUsed":false,"usage":{"inputTokens":10,"outputTokens":5},"guardrail":false}
        """
        let sseEvent = SSEEvent(type: "done", data: json)
        let event = try ChatEvent.from(sseEvent: sseEvent)

        if case .done(_, _, _, _, _, _, _, _, _, let guardrail) = event {
            #expect(guardrail == false)
        } else {
            Issue.record("Expected .done event")
        }
    }
}

@Suite("CoachingViewModel Guardrail State")
struct CoachingViewModelGuardrailTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("guardrail_test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    @Test @MainActor
    func test_guardrailActive_setsIsGuardrailActive() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let mockChat = MockChatService()
        let viewModel = CoachingViewModel(
            appState: appState,
            chatService: mockChat,
            databaseManager: db
        )

        mockChat.stubbedEvents = [
            .token(text: "Let's pause."),
            .done(safetyLevel: "green", domainTags: [], mood: "gentle", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 5, outputTokens: 3), promptVersion: nil, profileUpdate: nil, guardrail: true)
        ]

        await viewModel.sendMessage("Hello")
        // Wait for streaming task
        try? await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.isGuardrailActive == true)
    }

    @Test @MainActor
    func test_guardrailNil_doesNotSetActive() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let mockChat = MockChatService()
        let viewModel = CoachingViewModel(
            appState: appState,
            chatService: mockChat,
            databaseManager: db
        )

        mockChat.stubbedEvents = [
            .token(text: "Hi!"),
            .done(safetyLevel: "green", domainTags: [], mood: "welcoming", mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 5, outputTokens: 3), promptVersion: nil, profileUpdate: nil, guardrail: nil)
        ]

        await viewModel.sendMessage("Hello")
        try? await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.isGuardrailActive == false)
    }
}
