import Foundation
import Testing
import GRDB
@testable import sprinty

// --- Story 5.4 Tests ---

@Suite("CheckIn Model Tests")
struct CheckInTests {
    private func createInMemoryDatabase() throws -> DatabaseQueue {
        let dbQueue = try DatabaseQueue(configuration: Configuration())
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbQueue)
        return dbQueue
    }

    private func createSession(in db: DatabaseQueue, type: SessionType = .checkIn) throws -> ConversationSession {
        let session = ConversationSession(
            id: UUID(),
            startedAt: Date(),
            endedAt: nil,
            type: type,
            mode: .discovery,
            safetyLevel: .green,
            promptVersion: nil,
            modeHistory: nil,
            moodHistory: nil
        )
        try db.write { dbConn in
            try session.insert(dbConn)
        }
        return session
    }

    private func createSprint(in db: DatabaseQueue) throws -> Sprint {
        let sprint = Sprint(
            id: UUID(),
            name: "Test Sprint",
            startDate: Date(),
            endDate: Date(timeIntervalSinceNow: 7 * 86400),
            status: .active
        )
        try db.write { dbConn in
            try sprint.insert(dbConn)
        }
        return sprint
    }

    private func makeCheckIn(sessionId: UUID, sprintId: UUID, summary: String = "Feeling good today", createdAt: Date = Date()) -> CheckIn {
        CheckIn(id: UUID(), sessionId: sessionId, sprintId: sprintId, summary: summary, createdAt: createdAt)
    }

    // MARK: - Encoding/Decoding

    @Test("CheckIn Codable roundtrip preserves all fields")
    func test_codableRoundtrip() throws {
        let now = Date()
        let checkIn = CheckIn(id: UUID(), sessionId: UUID(), sprintId: UUID(), summary: "Great progress", createdAt: now)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(checkIn)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CheckIn.self, from: data)
        #expect(decoded.id == checkIn.id)
        #expect(decoded.sessionId == checkIn.sessionId)
        #expect(decoded.sprintId == checkIn.sprintId)
        #expect(decoded.summary == "Great progress")
    }

    // MARK: - Insert and Fetch

    @Test("Can insert and fetch CheckIn")
    func test_insertAndFetch() throws {
        let db = try createInMemoryDatabase()
        let session = try createSession(in: db)
        let sprint = try createSprint(in: db)
        let checkIn = makeCheckIn(sessionId: session.id, sprintId: sprint.id)

        try db.write { dbConn in
            try checkIn.insert(dbConn)
        }

        let fetched = try db.read { dbConn in
            try CheckIn.fetchOne(dbConn, key: checkIn.id)
        }
        #expect(fetched != nil)
        #expect(fetched?.id == checkIn.id)
        #expect(fetched?.summary == "Feeling good today")
        #expect(fetched?.sessionId == session.id)
        #expect(fetched?.sprintId == sprint.id)
    }

    // MARK: - Query Extensions

    @Test("latest() returns most recent check-in")
    func test_latest() throws {
        let db = try createInMemoryDatabase()
        let session = try createSession(in: db)
        let sprint = try createSprint(in: db)
        let older = makeCheckIn(sessionId: session.id, sprintId: sprint.id, summary: "Old", createdAt: Date(timeIntervalSinceNow: -86400))
        let newer = makeCheckIn(sessionId: session.id, sprintId: sprint.id, summary: "New", createdAt: Date())

        try db.write { dbConn in
            try older.insert(dbConn)
            try newer.insert(dbConn)
        }

        let fetched = try db.read { dbConn in
            try CheckIn.latest().fetchOne(dbConn)
        }
        #expect(fetched?.summary == "New")
    }

    @Test("latestToday() returns check-in from today only")
    func test_latestToday_returnsToday() throws {
        let db = try createInMemoryDatabase()
        let session = try createSession(in: db)
        let sprint = try createSprint(in: db)
        let yesterday = makeCheckIn(sessionId: session.id, sprintId: sprint.id, summary: "Yesterday", createdAt: Date(timeIntervalSinceNow: -86400))
        let today = makeCheckIn(sessionId: session.id, sprintId: sprint.id, summary: "Today", createdAt: Date())

        try db.write { dbConn in
            try yesterday.insert(dbConn)
            try today.insert(dbConn)
        }

        let fetched = try db.read { dbConn in
            try CheckIn.latestToday().fetchOne(dbConn)
        }
        #expect(fetched?.summary == "Today")
    }

    @Test("latestToday() returns nil when no check-in today")
    func test_latestToday_returnsNil_whenNoneToday() throws {
        let db = try createInMemoryDatabase()
        let session = try createSession(in: db)
        let sprint = try createSprint(in: db)
        let yesterday = makeCheckIn(sessionId: session.id, sprintId: sprint.id, summary: "Yesterday", createdAt: Date(timeIntervalSinceNow: -86400))

        try db.write { dbConn in
            try yesterday.insert(dbConn)
        }

        let fetched = try db.read { dbConn in
            try CheckIn.latestToday().fetchOne(dbConn)
        }
        #expect(fetched == nil)
    }

    @Test("latestThisWeek() returns check-in from current week")
    func test_latestThisWeek() throws {
        let db = try createInMemoryDatabase()
        let session = try createSession(in: db)
        let sprint = try createSprint(in: db)
        let thisWeek = makeCheckIn(sessionId: session.id, sprintId: sprint.id, summary: "This week", createdAt: Date())

        try db.write { dbConn in
            try thisWeek.insert(dbConn)
        }

        let fetched = try db.read { dbConn in
            try CheckIn.latestThisWeek().fetchOne(dbConn)
        }
        #expect(fetched?.summary == "This week")
    }

    @Test("forSprint() returns check-ins for specific sprint")
    func test_forSprint() throws {
        let db = try createInMemoryDatabase()
        let session = try createSession(in: db)
        let sprint1 = try createSprint(in: db)
        let sprint2Id = UUID()
        try db.write { dbConn in
            try Sprint(id: sprint2Id, name: "Sprint 2", startDate: Date(), endDate: Date(timeIntervalSinceNow: 86400), status: .active).insert(dbConn)
        }

        let checkIn1 = makeCheckIn(sessionId: session.id, sprintId: sprint1.id, summary: "Sprint 1 check-in")
        let checkIn2 = makeCheckIn(sessionId: session.id, sprintId: sprint2Id, summary: "Sprint 2 check-in")

        try db.write { dbConn in
            try checkIn1.insert(dbConn)
            try checkIn2.insert(dbConn)
        }

        let sprint1CheckIns = try db.read { dbConn in
            try CheckIn.forSprint(id: sprint1.id).fetchAll(dbConn)
        }
        #expect(sprint1CheckIns.count == 1)
        #expect(sprint1CheckIns.first?.summary == "Sprint 1 check-in")
    }

    // MARK: - Migration v11

    @Test("v11 migration creates CheckIn table with correct columns")
    func test_migration_v11_checkInTable() throws {
        let db = try createInMemoryDatabase()
        try db.read { dbConn in
            let columns = try dbConn.columns(in: "CheckIn")
            let columnNames = columns.map(\.name)
            #expect(columnNames.contains("id"))
            #expect(columnNames.contains("sessionId"))
            #expect(columnNames.contains("sprintId"))
            #expect(columnNames.contains("summary"))
            #expect(columnNames.contains("createdAt"))
        }
    }

    @Test("v11 migration adds check-in columns to UserProfile")
    func test_migration_v11_userProfileColumns() throws {
        let db = try createInMemoryDatabase()
        try db.read { dbConn in
            let columns = try dbConn.columns(in: "UserProfile")
            let columnNames = columns.map(\.name)
            #expect(columnNames.contains("checkInCadence"))
            #expect(columnNames.contains("checkInTimeHour"))
            #expect(columnNames.contains("checkInWeekday"))
        }
    }

    @Test("v11 migration UserProfile defaults are correct")
    func test_migration_v11_userProfileDefaults() throws {
        let db = try createInMemoryDatabase()
        let profile = UserProfile(
            id: UUID(),
            avatarId: "avatar_classic",
            coachAppearanceId: "coach_sage",
            coachName: "Sage",
            onboardingStep: 0,
            onboardingCompleted: false,
            createdAt: Date(),
            updatedAt: Date()
        )
        try db.write { dbConn in
            try profile.insert(dbConn)
        }
        let fetched = try db.read { dbConn in
            try UserProfile.fetchOne(dbConn, key: profile.id)
        }
        #expect(fetched?.checkInCadence == "daily")
        #expect(fetched?.checkInTimeHour == 9)
        #expect(fetched?.checkInWeekday == nil)
    }

    // MARK: - SessionType

    @Test("SessionType has checkIn case")
    func test_sessionType_checkIn() throws {
        let db = try createInMemoryDatabase()
        let session = ConversationSession(
            id: UUID(),
            startedAt: Date(),
            endedAt: nil,
            type: .checkIn,
            mode: .discovery,
            safetyLevel: .green,
            promptVersion: nil,
            modeHistory: nil,
            moodHistory: nil
        )
        try db.write { dbConn in
            try session.insert(dbConn)
        }
        let fetched = try db.read { dbConn in
            try ConversationSession.fetchOne(dbConn, key: session.id)
        }
        #expect(fetched?.type == .checkIn)
    }
}
