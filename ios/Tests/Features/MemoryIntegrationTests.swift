import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("Memory Integration Tests")
struct MemoryIntegrationTests {

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
        goals: [String]? = nil
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
            personalityTraits: nil,
            domainStates: nil,
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

    // MARK: - 8.1 Full flow: load profile → edit fact → verify persisted

    @Test("Full flow: load profile, edit fact, verify update persisted")
    @MainActor
    func test_fullFlow_editProfileFact() async throws {
        let db = try makeTestDB()
        let profile = try await createProfile(in: db, values: ["honesty", "growth"])

        let vm = MemoryViewModel(databaseManager: db)
        await vm.load()

        #expect(vm.profileFacts.count == 3) // coachName + 2 values
        let valueFact = vm.profileFacts.first { $0.id == "values-0" }!
        #expect(valueFact.value == "honesty")

        await vm.updateProfileFact(valueFact, newValue: "integrity")

        // Verify ViewModel reloaded
        let updatedFact = vm.profileFacts.first { $0.id == "values-0" }!
        #expect(updatedFact.value == "integrity")

        // Verify DB persisted
        let dbProfile = try await db.dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn, key: profile.id)
        }
        #expect(dbProfile?.decodedValues?.first == "integrity")
        #expect(dbProfile!.updatedAt > profile.updatedAt)
    }

    // MARK: - 8.2 Full flow: load memories → delete → verify removed from DB and vector search

    @Test("Full flow: load memories, delete memory, verify removed from DB and vector search")
    @MainActor
    func test_fullFlow_deleteMemory() async throws {
        let db = try makeTestDB()
        let sessionId = try await createSession(in: db)
        let (summary, rowid) = try await createSummary(in: db, sessionId: sessionId)

        let mockPipeline = MockEmbeddingPipeline()
        let vm = MemoryViewModel(databaseManager: db, embeddingPipeline: mockPipeline)
        await vm.load()

        #expect(vm.memories.count == 1)
        let memory = vm.memories[0]

        await vm.deleteMemory(memory)

        // Verify ViewModel reflects deletion
        #expect(vm.memories.isEmpty)

        // Verify DB deletion
        let remaining = try await db.dbPool.read { dbConn in
            try ConversationSummary.fetchOne(dbConn, key: summary.id)
        }
        #expect(remaining == nil)

        // Verify vector search cleanup called
        #expect(mockPipeline.deleteEmbeddingCallCount == 1)
        #expect(mockPipeline.lastDeletedRowid == rowid)
    }

    // MARK: - 8.3 Full flow: load tags → remove tag → verify removed from all summaries

    @Test("Full flow: load tags, remove tag, verify removed from all summaries")
    @MainActor
    func test_fullFlow_removeDomainTag() async throws {
        let db = try makeTestDB()
        let sessionId = try await createSession(in: db)
        let (s1, _) = try await createSummary(in: db, sessionId: sessionId, summary: "s1", domainTags: ["career", "health"])
        let (s2, _) = try await createSummary(in: db, sessionId: sessionId, summary: "s2", domainTags: ["career", "relationships"])

        let vm = MemoryViewModel(databaseManager: db)
        await vm.load()

        #expect(vm.domainTags.contains("career"))
        #expect(vm.domainTags.count == 3)

        await vm.removeDomainTag("career")

        // Verify ViewModel
        #expect(!vm.domainTags.contains("career"))
        #expect(vm.domainTags == ["health", "relationships"])

        // Verify DB — summaries still exist but without the tag
        let allSummaries = try await db.dbPool.read { dbConn in
            try ConversationSummary.fetchAll(dbConn)
        }
        #expect(allSummaries.count == 2)
        for s in allSummaries {
            #expect(!s.decodedDomainTags.contains("career"))
        }
    }

    // MARK: - 8.4 Empty state for new user

    @Test("Empty state displays correctly for new user with no data")
    @MainActor
    func test_emptyState_newUser() async throws {
        let db = try makeTestDB()
        let vm = MemoryViewModel(databaseManager: db)

        await vm.load()

        #expect(vm.isEmpty == true)
        #expect(vm.profileFacts.isEmpty)
        #expect(vm.memories.isEmpty)
        #expect(vm.domainTags.isEmpty)
        #expect(vm.localError == nil)
    }

    // MARK: - 8.5 Deletion confirmation flow

    @Test("Deletion flow: delete profile fact removes it, delete memory calls pipeline")
    @MainActor
    func test_deletionFlow_confirmations() async throws {
        let db = try makeTestDB()
        let profile = try await createProfile(in: db, values: ["honesty"])
        let sessionId = try await createSession(in: db)
        _ = try await createSummary(in: db, sessionId: sessionId, summary: "important moment")

        let mockPipeline = MockEmbeddingPipeline()
        let vm = MemoryViewModel(databaseManager: db, embeddingPipeline: mockPipeline)
        await vm.load()

        // Delete profile fact
        let fact = vm.profileFacts.first { $0.id == "values-0" }!
        await vm.deleteProfileFact(fact)

        let updatedProfile = try await db.dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn, key: profile.id)
        }
        #expect(updatedProfile?.values == nil)

        // Delete memory
        await vm.load() // reload to get fresh memories
        let memory = vm.memories[0]
        await vm.deleteMemory(memory)

        #expect(vm.memories.isEmpty)
        #expect(mockPipeline.deleteEmbeddingCallCount == 1)
    }
}
