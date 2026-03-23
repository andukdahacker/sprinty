import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("MemoryViewModel")
struct MemoryViewModelTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    private func createProfile(
        in db: DatabaseManager,
        coachName: String = "Luna",
        values: [String]? = nil,
        goals: [String]? = nil,
        traits: [String]? = nil,
        domainStates: [String: DomainState]? = nil
    ) async throws -> UserProfile {
        let profile = UserProfile(
            id: UUID(),
            avatarId: "default",
            coachAppearanceId: "default",
            coachName: coachName,
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

    private func createSession(in db: DatabaseManager) async throws -> UUID {
        let session = ConversationSession(
            id: UUID(),
            startedAt: Date(),
            endedAt: nil,
            type: .coaching,
            mode: .discovery,
            safetyLevel: .green,
            promptVersion: nil,
            modeHistory: nil,
            moodHistory: nil
        )
        try await db.dbPool.write { dbConn in
            try session.save(dbConn)
        }
        return session.id
    }

    private func createSummary(
        in db: DatabaseManager,
        sessionId: UUID,
        summary: String = "Test summary",
        keyMoments: [String] = ["moment1"],
        domainTags: [String] = ["career"]
    ) async throws -> (ConversationSummary, Int64) {
        let summaryRecord = ConversationSummary(
            id: UUID(),
            sessionId: sessionId,
            summary: summary,
            keyMoments: ConversationSummary.encodeArray(keyMoments),
            domainTags: ConversationSummary.encodeArray(domainTags),
            emotionalMarkers: nil,
            keyDecisions: nil,
            goalReferences: nil,
            embedding: nil,
            createdAt: Date()
        )
        let rowid: Int64 = try await db.dbPool.write { dbConn in
            try summaryRecord.insert(dbConn)
            return dbConn.lastInsertedRowID
        }
        return (summaryRecord, rowid)
    }

    // MARK: - Task 1: Loading Tests

    @Test("Load profile facts from UserProfile")
    @MainActor
    func test_load_profileFacts_fromUserProfile() async throws {
        let db = try makeTestDB()
        _ = try await createProfile(in: db, coachName: "Luna", values: ["honesty", "growth"], goals: ["get fit"])
        let vm = MemoryViewModel(databaseManager: db)

        await vm.load()

        #expect(vm.profileFacts.count == 4) // coachName + 2 values + 1 goal
        #expect(vm.profileFacts[0].id == "coachName")
        #expect(vm.profileFacts[0].value == "Luna")
        #expect(vm.profileFacts[1].id == "values-0")
        #expect(vm.profileFacts[1].value == "honesty")
        #expect(vm.profileFacts[2].id == "values-1")
        #expect(vm.profileFacts[2].value == "growth")
        #expect(vm.profileFacts[3].id == "goals-0")
        #expect(vm.profileFacts[3].value == "get fit")
    }

    @Test("Load profile with personality traits and domain states")
    @MainActor
    func test_load_profileFacts_withTraitsAndDomains() async throws {
        let db = try makeTestDB()
        let domains: [String: DomainState] = [
            "career": DomainState(status: "transitioning", conversationCount: 3, lastUpdated: nil)
        ]
        _ = try await createProfile(in: db, traits: ["empathetic"], domainStates: domains)
        let vm = MemoryViewModel(databaseManager: db)

        await vm.load()

        let traitFact = vm.profileFacts.first { $0.id == "personality-0" }
        #expect(traitFact?.value == "empathetic")
        #expect(traitFact?.category == "Personality")

        let domainFact = vm.profileFacts.first { $0.id == "domain-career" }
        #expect(domainFact?.value == "transitioning")
        #expect(domainFact?.category == "Life Situation")
    }

    @Test("Load memories from ConversationSummary records")
    @MainActor
    func test_load_memories_fromSummaries() async throws {
        let db = try makeTestDB()
        let sessionId = try await createSession(in: db)
        _ = try await createSummary(in: db, sessionId: sessionId, summary: "Discussed career goals", domainTags: ["career"])

        let vm = MemoryViewModel(databaseManager: db)
        await vm.load()

        #expect(vm.memories.count == 1)
        #expect(vm.memories[0].summary == "Discussed career goals")
        #expect(vm.memories[0].domainTags == ["career"])
    }

    @Test("Aggregate domain tags across summaries — unique and sorted")
    @MainActor
    func test_load_domainTags_aggregatedUniqueSorted() async throws {
        let db = try makeTestDB()
        let sessionId = try await createSession(in: db)
        _ = try await createSummary(in: db, sessionId: sessionId, summary: "s1", domainTags: ["career", "health"])
        _ = try await createSummary(in: db, sessionId: sessionId, summary: "s2", domainTags: ["career", "relationships"])

        let vm = MemoryViewModel(databaseManager: db)
        await vm.load()

        #expect(vm.domainTags == ["career", "health", "relationships"])
    }

    @Test("Empty state when no profile or memories exist")
    @MainActor
    func test_load_emptyState_noData() async throws {
        let db = try makeTestDB()
        let vm = MemoryViewModel(databaseManager: db)

        await vm.load()

        #expect(vm.isEmpty == true)
        #expect(vm.profileFacts.isEmpty)
        #expect(vm.memories.isEmpty)
        #expect(vm.domainTags.isEmpty)
    }

    @Test("Not empty when profile exists but no memories")
    @MainActor
    func test_load_notEmpty_profileOnly() async throws {
        let db = try makeTestDB()
        _ = try await createProfile(in: db)
        let vm = MemoryViewModel(databaseManager: db)

        await vm.load()

        #expect(vm.isEmpty == false)
        #expect(vm.profileFacts.isEmpty == false)
    }

    // MARK: - Task 2: Edit/Delete Profile Facts

    @Test("Edit profile fact — update value and verify updatedAt changes")
    @MainActor
    func test_updateProfileFact_updatesValue() async throws {
        let db = try makeTestDB()
        let profile = try await createProfile(in: db, values: ["honesty"])
        let originalUpdatedAt = profile.updatedAt
        let vm = MemoryViewModel(databaseManager: db)
        await vm.load()

        let fact = vm.profileFacts.first { $0.id == "values-0" }!
        // Small delay to ensure updatedAt differs
        try await Task.sleep(for: .milliseconds(10))
        await vm.updateProfileFact(fact, newValue: "integrity")

        let updated = try await db.dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn, key: profile.id)
        }
        #expect(updated?.decodedValues?.first == "integrity")
        #expect(updated!.updatedAt > originalUpdatedAt)
    }

    @Test("Edit coach name fact")
    @MainActor
    func test_updateProfileFact_coachName() async throws {
        let db = try makeTestDB()
        let profile = try await createProfile(in: db, coachName: "Luna")
        let vm = MemoryViewModel(databaseManager: db)
        await vm.load()

        let fact = vm.profileFacts.first { $0.id == "coachName" }!
        await vm.updateProfileFact(fact, newValue: "Sage")

        let updated = try await db.dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn, key: profile.id)
        }
        #expect(updated?.coachName == "Sage")
    }

    @Test("Delete profile fact — removes value from array")
    @MainActor
    func test_deleteProfileFact_removesFromArray() async throws {
        let db = try makeTestDB()
        let profile = try await createProfile(in: db, values: ["honesty", "growth"])
        let vm = MemoryViewModel(databaseManager: db)
        await vm.load()

        let fact = vm.profileFacts.first { $0.id == "values-0" }!
        await vm.deleteProfileFact(fact)

        let updated = try await db.dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn, key: profile.id)
        }
        #expect(updated?.decodedValues == ["growth"])
    }

    @Test("Delete last value — sets field to nil")
    @MainActor
    func test_deleteProfileFact_lastValue_setsNil() async throws {
        let db = try makeTestDB()
        let profile = try await createProfile(in: db, values: ["honesty"])
        let vm = MemoryViewModel(databaseManager: db)
        await vm.load()

        let fact = vm.profileFacts.first { $0.id == "values-0" }!
        await vm.deleteProfileFact(fact)

        let updated = try await db.dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn, key: profile.id)
        }
        #expect(updated?.values == nil)
    }

    @Test("Delete goal fact")
    @MainActor
    func test_deleteProfileFact_goal() async throws {
        let db = try makeTestDB()
        let profile = try await createProfile(in: db, goals: ["get fit", "read more"])
        let vm = MemoryViewModel(databaseManager: db)
        await vm.load()

        let fact = vm.profileFacts.first { $0.id == "goals-0" }!
        await vm.deleteProfileFact(fact)

        let updated = try await db.dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn, key: profile.id)
        }
        #expect(updated?.decodedGoals == ["read more"])
    }

    @Test("Delete domain state fact")
    @MainActor
    func test_deleteProfileFact_domainState() async throws {
        let db = try makeTestDB()
        let domains: [String: DomainState] = [
            "career": DomainState(status: "exploring", conversationCount: 1, lastUpdated: nil),
            "health": DomainState(status: "active", conversationCount: 2, lastUpdated: nil)
        ]
        let profile = try await createProfile(in: db, domainStates: domains)
        let vm = MemoryViewModel(databaseManager: db)
        await vm.load()

        let fact = vm.profileFacts.first { $0.id == "domain-career" }!
        await vm.deleteProfileFact(fact)

        let updated = try await db.dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn, key: profile.id)
        }
        #expect(updated?.decodedDomainStates?["career"] == nil)
        #expect(updated?.decodedDomainStates?["health"] != nil)
    }

    // MARK: - Task 3: Memory Deletion

    @Test("Delete memory — removes ConversationSummary from DB")
    @MainActor
    func test_deleteMemory_removesFromDB() async throws {
        let db = try makeTestDB()
        let sessionId = try await createSession(in: db)
        let (summary, rowid) = try await createSummary(in: db, sessionId: sessionId)

        let mockPipeline = MockEmbeddingPipeline()
        let vm = MemoryViewModel(databaseManager: db, embeddingPipeline: mockPipeline)
        await vm.load()

        #expect(vm.memories.count == 1)

        await vm.deleteMemory(vm.memories[0])

        let remaining = try await db.dbPool.read { dbConn in
            try ConversationSummary.fetchOne(dbConn, key: summary.id)
        }
        #expect(remaining == nil)
        #expect(vm.memories.isEmpty)
    }

    @Test("Delete memory — calls deleteEmbedding on pipeline")
    @MainActor
    func test_deleteMemory_callsDeleteEmbedding() async throws {
        let db = try makeTestDB()
        let sessionId = try await createSession(in: db)
        let (_, rowid) = try await createSummary(in: db, sessionId: sessionId)

        let mockPipeline = MockEmbeddingPipeline()
        let vm = MemoryViewModel(databaseManager: db, embeddingPipeline: mockPipeline)
        await vm.load()

        let memory = vm.memories[0]
        await vm.deleteMemory(memory)

        #expect(mockPipeline.deleteEmbeddingCallCount == 1)
        #expect(mockPipeline.lastDeletedRowid == memory.rowid)
    }

    // MARK: - Task 4: Domain Tag Removal

    @Test("Remove domain tag — removes from all summaries")
    @MainActor
    func test_removeDomainTag_removesFromAllSummaries() async throws {
        let db = try makeTestDB()
        let sessionId = try await createSession(in: db)
        _ = try await createSummary(in: db, sessionId: sessionId, summary: "s1", domainTags: ["career", "health"])
        _ = try await createSummary(in: db, sessionId: sessionId, summary: "s2", domainTags: ["career", "relationships"])

        let vm = MemoryViewModel(databaseManager: db)
        await vm.load()

        #expect(vm.domainTags.contains("career"))

        await vm.removeDomainTag("career")

        #expect(!vm.domainTags.contains("career"))
        #expect(vm.domainTags.contains("health"))
        #expect(vm.domainTags.contains("relationships"))

        // Verify DB state
        let allSummaries = try await db.dbPool.read { dbConn in
            try ConversationSummary.fetchAll(dbConn)
        }
        for summary in allSummaries {
            #expect(!summary.decodedDomainTags.contains("career"))
        }
    }

    @Test("Remove domain tag — does not delete ConversationSummary records")
    @MainActor
    func test_removeDomainTag_preservesSummaries() async throws {
        let db = try makeTestDB()
        let sessionId = try await createSession(in: db)
        _ = try await createSummary(in: db, sessionId: sessionId, domainTags: ["career"])

        let vm = MemoryViewModel(databaseManager: db)
        await vm.load()

        await vm.removeDomainTag("career")

        #expect(vm.memories.count == 1) // Summary still exists
    }
}
