import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("ConversationExportService")
struct ConversationExportServiceTests {

    private func makeTestDB() throws -> DatabasePool {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return dbPool
    }

    private func createSession(in dbPool: DatabasePool, startedAt: Date = Date()) throws -> ConversationSession {
        let session = ConversationSession(
            id: UUID(),
            startedAt: startedAt,
            endedAt: nil,
            type: .coaching,
            mode: .discovery,
            safetyLevel: .green,
            promptVersion: "1.0"
        )
        try dbPool.write { db in
            try session.save(db)
        }
        return session
    }

    @discardableResult
    private func createMessage(in dbPool: DatabasePool, sessionId: UUID, role: MessageRole = .user, content: String, timestamp: Date = Date(), deliveryStatus: MessageDeliveryStatus = .sent) throws -> Message {
        let message = Message(
            id: UUID(),
            sessionId: sessionId,
            role: role,
            content: content,
            timestamp: timestamp,
            deliveryStatus: deliveryStatus
        )
        try dbPool.write { db in
            try message.save(db)
        }
        return message
    }

    private func makeDate(year: Int = 2026, month: Int = 3, day: Int = 14, hour: Int = 10) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.timeZone = TimeZone(identifier: "America/New_York")
        return Calendar.current.date(from: components)!
    }

    // MARK: - hasConversations

    @Test
    func test_hasConversations_noSessions_returnsFalse() async throws {
        let dbPool = try makeTestDB()
        let service = ConversationExportService(dbPool: dbPool)

        let result = try await service.hasConversations()

        #expect(result == false)
    }

    @Test
    func test_hasConversations_withSessions_returnsTrue() async throws {
        let dbPool = try makeTestDB()
        _ = try createSession(in: dbPool)
        let service = ConversationExportService(dbPool: dbPool)

        let result = try await service.hasConversations()

        #expect(result == true)
    }

    // MARK: - Export Formatting

    @Test
    func test_export_emptyDatabase_returnsHeaderOnly() async throws {
        let dbPool = try makeTestDB()
        let service = ConversationExportService(dbPool: dbPool)

        let url = try await service.exportConversations()
        let content = try String(contentsOf: url, encoding: .utf8)

        #expect(content == "# My Coaching Conversations\n")
    }

    @Test
    func test_export_userMessageAsBlockquote() async throws {
        let dbPool = try makeTestDB()
        let date = makeDate()
        let session = try createSession(in: dbPool, startedAt: date)
        try createMessage(in: dbPool, sessionId: session.id, role: .user, content: "Hello coach", timestamp: date)
        let service = ConversationExportService(dbPool: dbPool)

        let url = try await service.exportConversations()
        let content = try String(contentsOf: url, encoding: .utf8)

        #expect(content.contains("> Hello coach"))
    }

    @Test
    func test_export_assistantMessageAsPlainParagraph() async throws {
        let dbPool = try makeTestDB()
        let date = makeDate()
        let session = try createSession(in: dbPool, startedAt: date)
        try createMessage(in: dbPool, sessionId: session.id, role: .assistant, content: "Welcome to coaching", timestamp: date)
        let service = ConversationExportService(dbPool: dbPool)

        let url = try await service.exportConversations()
        let content = try String(contentsOf: url, encoding: .utf8)

        #expect(content.contains("\nWelcome to coaching\n"))
        #expect(!content.contains("> Welcome to coaching"))
    }

    @Test
    func test_export_systemMessagesExcluded() async throws {
        let dbPool = try makeTestDB()
        let date = makeDate()
        let session = try createSession(in: dbPool, startedAt: date)
        try createMessage(in: dbPool, sessionId: session.id, role: .system, content: "System prompt", timestamp: date)
        try createMessage(in: dbPool, sessionId: session.id, role: .user, content: "Hello", timestamp: date.addingTimeInterval(1))
        let service = ConversationExportService(dbPool: dbPool)

        let url = try await service.exportConversations()
        let content = try String(contentsOf: url, encoding: .utf8)

        #expect(!content.contains("System prompt"))
        #expect(content.contains("> Hello"))
    }

    @Test
    func test_export_dateHeaderFormat() async throws {
        let dbPool = try makeTestDB()
        let date = makeDate(year: 2026, month: 3, day: 14)
        let session = try createSession(in: dbPool, startedAt: date)
        try createMessage(in: dbPool, sessionId: session.id, role: .user, content: "Test", timestamp: date)
        let service = ConversationExportService(dbPool: dbPool)

        let url = try await service.exportConversations()
        let content = try String(contentsOf: url, encoding: .utf8)

        #expect(content.contains("## March 14, 2026"))
    }

    @Test
    func test_export_multipleSessionsWithDifferentDates() async throws {
        let dbPool = try makeTestDB()
        let day1 = makeDate(year: 2026, month: 3, day: 14)
        let day2 = makeDate(year: 2026, month: 3, day: 15)

        let session1 = try createSession(in: dbPool, startedAt: day1)
        try createMessage(in: dbPool, sessionId: session1.id, role: .user, content: "Day one message", timestamp: day1)

        let session2 = try createSession(in: dbPool, startedAt: day2)
        try createMessage(in: dbPool, sessionId: session2.id, role: .user, content: "Day two message", timestamp: day2)

        let service = ConversationExportService(dbPool: dbPool)
        let url = try await service.exportConversations()
        let content = try String(contentsOf: url, encoding: .utf8)

        #expect(content.contains("## March 14, 2026"))
        #expect(content.contains("## March 15, 2026"))
        #expect(content.contains("> Day one message"))
        #expect(content.contains("> Day two message"))
    }

    @Test
    func test_export_pendingMessagesIncluded() async throws {
        let dbPool = try makeTestDB()
        let date = makeDate()
        let session = try createSession(in: dbPool, startedAt: date)
        try createMessage(in: dbPool, sessionId: session.id, role: .user, content: "Pending thought", timestamp: date, deliveryStatus: .pending)
        let service = ConversationExportService(dbPool: dbPool)

        let url = try await service.exportConversations()
        let content = try String(contentsOf: url, encoding: .utf8)

        #expect(content.contains("> Pending thought"))
    }

    @Test
    func test_export_fullConversationFormat() async throws {
        let dbPool = try makeTestDB()
        let date = makeDate(year: 2026, month: 3, day: 14, hour: 10)

        let session = try createSession(in: dbPool, startedAt: date)
        try createMessage(in: dbPool, sessionId: session.id, role: .user, content: "I'm excited to start.", timestamp: date)
        try createMessage(in: dbPool, sessionId: session.id, role: .assistant, content: "That's wonderful to hear!", timestamp: date.addingTimeInterval(1))
        try createMessage(in: dbPool, sessionId: session.id, role: .user, content: "I feel stuck at work.", timestamp: date.addingTimeInterval(2))

        let service = ConversationExportService(dbPool: dbPool)
        let url = try await service.exportConversations()
        let content = try String(contentsOf: url, encoding: .utf8)

        let expected = """
        # My Coaching Conversations

        ## March 14, 2026

        > I'm excited to start.

        That's wonderful to hear!

        > I feel stuck at work.
        """

        #expect(content == expected + "\n")
    }

    @Test
    func test_export_sameDateAcrossSessionsShowsOneHeader() async throws {
        let dbPool = try makeTestDB()
        let morning = makeDate(year: 2026, month: 3, day: 14, hour: 9)
        let afternoon = makeDate(year: 2026, month: 3, day: 14, hour: 15)

        let session1 = try createSession(in: dbPool, startedAt: morning)
        try createMessage(in: dbPool, sessionId: session1.id, role: .user, content: "Morning", timestamp: morning)

        let session2 = try createSession(in: dbPool, startedAt: afternoon)
        try createMessage(in: dbPool, sessionId: session2.id, role: .user, content: "Afternoon", timestamp: afternoon)

        let service = ConversationExportService(dbPool: dbPool)
        let url = try await service.exportConversations()
        let content = try String(contentsOf: url, encoding: .utf8)

        let dateHeaderCount = content.components(separatedBy: "## March 14, 2026").count - 1
        #expect(dateHeaderCount == 1)
    }

    @Test
    func test_export_fileExtensionIsMd() async throws {
        let dbPool = try makeTestDB()
        let service = ConversationExportService(dbPool: dbPool)

        let url = try await service.exportConversations()

        #expect(url.pathExtension == "md")
        #expect(url.lastPathComponent == "sprinty-conversations.md")
    }
}
