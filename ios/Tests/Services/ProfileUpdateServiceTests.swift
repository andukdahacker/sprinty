import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("ProfileUpdateService")
struct ProfileUpdateServiceTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    private func createProfile(in db: DatabaseManager, values: [String]? = nil, goals: [String]? = nil, traits: [String]? = nil, domainStates: [String: DomainState]? = nil) async throws -> UserProfile {
        let profile = UserProfile(
            id: UUID(),
            avatarId: "default",
            coachAppearanceId: "default",
            coachName: "Luna",
            onboardingStep: 5,
            onboardingCompleted: true,
            values: values.map { UserProfile.encodeArray($0) },
            goals: goals.map { UserProfile.encodeArray($0) },
            personalityTraits: traits.map { UserProfile.encodeArray($0) },
            domainStates: domainStates.map { UserProfile.encodeDomainStates($0) },
            createdAt: Date(),
            updatedAt: Date()
        )
        try await db.dbPool.write { dbConn in
            try profile.save(dbConn)
        }
        return profile
    }

    // MARK: - Task 7.3: Merge logic tests

    @Test("Append new values without duplicates")
    func test_applyUpdate_appendsValues_noDuplicates() async throws {
        let db = try makeTestDB()
        let profile = try await createProfile(in: db, values: ["honesty", "growth"])
        let service = ProfileUpdateService(databaseManager: db)

        let update = ProfileUpdate(
            values: ["Growth", "creativity"],
            goals: nil,
            personalityTraits: nil,
            domainStates: nil,
            corrections: nil
        )

        try await service.applyUpdate(update, to: profile.id)

        let updated = try await db.dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn, key: profile.id)
        }
        let decodedValues = updated?.decodedValues ?? []
        #expect(decodedValues.count == 3)
        #expect(decodedValues.contains("honesty"))
        #expect(decodedValues.contains("growth"))
        #expect(decodedValues.contains("creativity"))
    }

    @Test("Append new goals deduplicated")
    func test_applyUpdate_appendsGoals_deduplicated() async throws {
        let db = try makeTestDB()
        let profile = try await createProfile(in: db, goals: ["exercise more"])
        let service = ProfileUpdateService(databaseManager: db)

        let update = ProfileUpdate(
            values: nil,
            goals: ["Exercise More", "read daily"],
            personalityTraits: nil,
            domainStates: nil,
            corrections: nil
        )

        try await service.applyUpdate(update, to: profile.id)

        let updated = try await db.dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn, key: profile.id)
        }
        let decodedGoals = updated?.decodedGoals ?? []
        #expect(decodedGoals.count == 2)
        #expect(decodedGoals.contains("exercise more"))
        #expect(decodedGoals.contains("read daily"))
    }

    @Test("Domain key merge — update existing, add new")
    func test_applyUpdate_domainKeyMerge() async throws {
        let db = try makeTestDB()
        let existing: [String: DomainState] = [
            "career": DomainState(status: "active", conversationCount: 3, lastUpdated: "2026-03-20")
        ]
        let profile = try await createProfile(in: db, domainStates: existing)
        let service = ProfileUpdateService(databaseManager: db)

        let update = ProfileUpdate(
            values: nil,
            goals: nil,
            personalityTraits: nil,
            domainStates: [
                "career": DomainState(status: "transitioning", conversationCount: 4, lastUpdated: "2026-03-21"),
                "health": DomainState(status: nil, conversationCount: 1, lastUpdated: "2026-03-21")
            ],
            corrections: nil
        )

        try await service.applyUpdate(update, to: profile.id)

        let updated = try await db.dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn, key: profile.id)
        }
        let states = updated?.decodedDomainStates ?? [:]
        #expect(states.count == 2)
        #expect(states["career"]?.status == "transitioning")
        #expect(states["career"]?.conversationCount == 4)
        #expect(states["health"]?.conversationCount == 1)
    }

    @Test("Invalid domain keys are silently dropped")
    func test_applyUpdate_invalidDomainKeys_dropped() async throws {
        let db = try makeTestDB()
        let profile = try await createProfile(in: db)
        let service = ProfileUpdateService(databaseManager: db)

        let update = ProfileUpdate(
            values: nil,
            goals: nil,
            personalityTraits: nil,
            domainStates: [
                "career": DomainState(status: "active", conversationCount: 1, lastUpdated: "2026-03-21"),
                "invalid-domain": DomainState(status: "x", conversationCount: 1, lastUpdated: "2026-03-21")
            ],
            corrections: nil
        )

        try await service.applyUpdate(update, to: profile.id)

        let updated = try await db.dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn, key: profile.id)
        }
        let states = updated?.decodedDomainStates ?? [:]
        #expect(states.count == 1)
        #expect(states["career"] != nil)
        #expect(states["invalid-domain"] == nil)
    }

    // MARK: - Task 7.9: Input validation

    @Test("Values exceeding 20 items are truncated")
    func test_applyUpdate_valuesExceeding20_truncated() async throws {
        let db = try makeTestDB()
        let profile = try await createProfile(in: db, values: Array(repeating: "existing", count: 0).enumerated().map { "value\($0.offset)" })
        let service = ProfileUpdateService(databaseManager: db)

        let newValues = (0..<25).map { "new_value_\($0)" }
        let update = ProfileUpdate(
            values: newValues,
            goals: nil,
            personalityTraits: nil,
            domainStates: nil,
            corrections: nil
        )

        try await service.applyUpdate(update, to: profile.id)

        let updated = try await db.dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn, key: profile.id)
        }
        let decodedValues = updated?.decodedValues ?? []
        #expect(decodedValues.count == 20)
    }

    @Test("Strings exceeding 200 chars are truncated")
    func test_applyUpdate_longStrings_truncated() async throws {
        let db = try makeTestDB()
        let profile = try await createProfile(in: db)
        let service = ProfileUpdateService(databaseManager: db)

        let longValue = String(repeating: "a", count: 300)
        let update = ProfileUpdate(
            values: [longValue],
            goals: nil,
            personalityTraits: nil,
            domainStates: nil,
            corrections: nil
        )

        try await service.applyUpdate(update, to: profile.id)

        let updated = try await db.dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn, key: profile.id)
        }
        let decodedValues = updated?.decodedValues ?? []
        #expect(decodedValues.count == 1)
        #expect(decodedValues[0].count == 200)
    }

    @Test("Update to nil profile fields initializes them")
    func test_applyUpdate_nilFields_initializes() async throws {
        let db = try makeTestDB()
        let profile = try await createProfile(in: db)
        let service = ProfileUpdateService(databaseManager: db)

        let update = ProfileUpdate(
            values: ["honesty"],
            goals: ["run a marathon"],
            personalityTraits: ["determined"],
            domainStates: nil,
            corrections: nil
        )

        try await service.applyUpdate(update, to: profile.id)

        let updated = try await db.dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn, key: profile.id)
        }
        #expect(updated?.decodedValues == ["honesty"])
        #expect(updated?.decodedGoals == ["run a marathon"])
        #expect(updated?.decodedPersonalityTraits == ["determined"])
    }
}
