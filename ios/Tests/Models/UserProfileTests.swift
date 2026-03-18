import Foundation
import Testing
import GRDB
@testable import sprinty

@Suite("UserProfile Tests")
struct UserProfileTests {
    private func createInMemoryDatabase() throws -> DatabaseQueue {
        let dbQueue = try DatabaseQueue(configuration: Configuration())
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbQueue)
        return dbQueue
    }

    private func makeProfile(
        id: UUID = UUID(),
        avatarId: String = "person.circle.fill",
        coachAppearanceId: String = "person.circle.fill",
        coachName: String = "Sage",
        onboardingStep: Int = 0,
        onboardingCompleted: Bool = false
    ) -> UserProfile {
        UserProfile(
            id: id,
            avatarId: avatarId,
            coachAppearanceId: coachAppearanceId,
            coachName: coachName,
            onboardingStep: onboardingStep,
            onboardingCompleted: onboardingCompleted,
            values: nil,
            goals: nil,
            personalityTraits: nil,
            domainStates: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    @Test("UserProfile table is created with correct columns")
    func tableCreated() throws {
        let db = try createInMemoryDatabase()
        try db.read { db in
            let columns = try db.columns(in: "UserProfile")
            let columnNames = columns.map(\.name)
            #expect(columnNames.contains("id"))
            #expect(columnNames.contains("avatarId"))
            #expect(columnNames.contains("coachAppearanceId"))
            #expect(columnNames.contains("coachName"))
            #expect(columnNames.contains("onboardingStep"))
            #expect(columnNames.contains("onboardingCompleted"))
            #expect(columnNames.contains("values"))
            #expect(columnNames.contains("goals"))
            #expect(columnNames.contains("personalityTraits"))
            #expect(columnNames.contains("domainStates"))
            #expect(columnNames.contains("createdAt"))
            #expect(columnNames.contains("updatedAt"))
        }
    }

    @Test("Can insert and fetch UserProfile")
    func insertAndFetch() throws {
        let db = try createInMemoryDatabase()
        let profile = makeProfile()
        try db.write { db in
            try profile.insert(db)
        }
        let fetched = try db.read { db in
            try UserProfile.fetchOne(db, key: profile.id)
        }
        #expect(fetched != nil)
        #expect(fetched?.id == profile.id)
        #expect(fetched?.avatarId == "person.circle.fill")
        #expect(fetched?.coachName == "Sage")
        #expect(fetched?.onboardingStep == 0)
        #expect(fetched?.onboardingCompleted == false)
    }

    @Test("Codable roundtrip preserves all fields")
    func codableRoundtrip() throws {
        let profile = makeProfile(
            avatarId: "figure.mind.and.body",
            coachAppearanceId: "leaf.circle.fill",
            coachName: "Guide",
            onboardingStep: 2,
            onboardingCompleted: false
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(profile)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(UserProfile.self, from: data)
        #expect(decoded.id == profile.id)
        #expect(decoded.avatarId == "figure.mind.and.body")
        #expect(decoded.coachAppearanceId == "leaf.circle.fill")
        #expect(decoded.coachName == "Guide")
        #expect(decoded.onboardingStep == 2)
        #expect(decoded.onboardingCompleted == false)
        #expect(decoded.values == nil)
        #expect(decoded.goals == nil)
    }

    @Test("UserProfile.current() returns a profile when one exists")
    func currentQuery() throws {
        let db = try createInMemoryDatabase()
        let profile = makeProfile()
        try db.write { db in
            try profile.insert(db)
        }
        let fetched = try db.read { db in
            try UserProfile.current().fetchOne(db)
        }
        #expect(fetched != nil)
        #expect(fetched?.id == profile.id)
    }

    @Test("UserProfile.current() returns nil when no profile exists")
    func currentQueryEmpty() throws {
        let db = try createInMemoryDatabase()
        let fetched = try db.read { db in
            try UserProfile.current().fetchOne(db)
        }
        #expect(fetched == nil)
    }

    @Test("Can update UserProfile fields")
    func updateProfile() throws {
        let db = try createInMemoryDatabase()
        var profile = makeProfile()
        try db.write { db in
            try profile.insert(db)
        }
        profile.onboardingStep = 2
        profile.coachName = "Mentor"
        profile.updatedAt = Date()
        try db.write { db in
            try profile.update(db)
        }
        let fetched = try db.read { db in
            try UserProfile.fetchOne(db, key: profile.id)
        }
        #expect(fetched?.onboardingStep == 2)
        #expect(fetched?.coachName == "Mentor")
    }

    @Test("Architecture fields store and retrieve JSON strings")
    func architectureFieldsJsonStorage() throws {
        let db = try createInMemoryDatabase()
        var profile = makeProfile()
        profile.values = "[\"growth\",\"balance\"]"
        profile.goals = "[\"exercise daily\"]"
        profile.personalityTraits = "[\"introverted\"]"
        profile.domainStates = "{\"fitness\":\"active\"}"
        try db.write { db in
            try profile.insert(db)
        }
        let fetched = try db.read { db in
            try UserProfile.fetchOne(db, key: profile.id)
        }
        #expect(fetched?.values == "[\"growth\",\"balance\"]")
        #expect(fetched?.goals == "[\"exercise daily\"]")
        #expect(fetched?.personalityTraits == "[\"introverted\"]")
        #expect(fetched?.domainStates == "{\"fitness\":\"active\"}")
    }

    @Test("v2 migration is idempotent")
    func migrationIdempotent() throws {
        let dbQueue = try DatabaseQueue(configuration: Configuration())
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbQueue)
        try migrator.migrate(dbQueue)
    }
}
