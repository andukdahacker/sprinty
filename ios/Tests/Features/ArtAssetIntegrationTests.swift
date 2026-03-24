import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("Art Asset Integration — Story 4.6")
struct ArtAssetIntegrationTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    // MARK: - Task 8.4: Avatar ID + state → asset name mapping

    @Test("AvatarOptions.assetName builds correct name for classic active")
    func test_assetName_classicActive() {
        let result = AvatarOptions.assetName(for: "avatar_classic", state: .active)
        #expect(result == "avatar_classic_active")
    }

    @Test("AvatarOptions.assetName builds correct name for zen celebrating")
    func test_assetName_zenCelebrating() {
        let result = AvatarOptions.assetName(for: "avatar_zen", state: .celebrating)
        #expect(result == "avatar_zen_celebrating")
    }

    @Test("AvatarOptions.assetName builds correct name for minimal thinking")
    func test_assetName_minimalThinking() {
        let result = AvatarOptions.assetName(for: "avatar_minimal", state: .thinking)
        #expect(result == "avatar_minimal_thinking")
    }

    @Test("AvatarOptions.assetName builds correct name for all state combinations")
    func test_assetName_allCombinations() {
        let variants = ["avatar_classic", "avatar_minimal", "avatar_zen"]
        for variant in variants {
            for state in AvatarState.allCases {
                let result = AvatarOptions.assetName(for: variant, state: state)
                #expect(result == "\(variant)_\(state.rawValue)")
            }
        }
    }

    // MARK: - Task 8.5: CoachExpression.assetName(for:) mapping

    @Test("CoachExpression.assetName builds correct name for sage thinking")
    func test_coachExpression_assetName_sageThinking() {
        let result = CoachExpression.thinking.assetName(for: "coach_sage")
        #expect(result == "coach_sage_thinking")
    }

    @Test("CoachExpression.assetName builds correct name for mentor welcoming")
    func test_coachExpression_assetName_mentorWelcoming() {
        let result = CoachExpression.welcoming.assetName(for: "coach_mentor")
        #expect(result == "coach_mentor_welcoming")
    }

    @Test("CoachExpression.assetName builds correct name for guide gentle")
    func test_coachExpression_assetName_guideGentle() {
        let result = CoachExpression.gentle.assetName(for: "coach_guide")
        #expect(result == "coach_guide_gentle")
    }

    @Test("CoachExpression.assetName all expression combinations")
    func test_coachExpression_assetName_allCombinations() {
        let variants = ["coach_sage", "coach_mentor", "coach_guide"]
        for variant in variants {
            for expression in CoachExpression.allCases {
                let result = expression.assetName(for: variant)
                #expect(result == "\(variant)_\(expression.rawValue)")
            }
        }
    }

    // MARK: - Task 8.6: Database migration from SF Symbol IDs to asset IDs

    @Test("Migration v7 converts person.circle.fill avatar to avatar_classic")
    func test_migration_v7_avatarClassic() async throws {
        // Must insert data BEFORE v7 runs — build DB through v6 only, insert, then run v7
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)

        // Run through v6 only
        var partialMigrator = DatabaseMigrator()
        partialMigrator.registerMigration("v1") { db in
            try db.create(table: "ConversationSession") { t in
                t.column("id", .text).primaryKey().notNull()
                t.column("startedAt", .text).notNull()
                t.column("endedAt", .text)
                t.column("type", .text).notNull().defaults(to: "coaching")
                t.column("mode", .text).notNull().defaults(to: "discovery")
                t.column("safetyLevel", .text).notNull().defaults(to: "green")
                t.column("promptVersion", .text)
            }
            try db.create(table: "Message") { t in
                t.column("id", .text).primaryKey().notNull()
                t.column("sessionId", .text).notNull()
                t.column("role", .text).notNull()
                t.column("content", .text).notNull()
                t.column("timestamp", .text).notNull()
            }
        }
        partialMigrator.registerMigration("v2") { db in
            try db.create(table: "UserProfile") { t in
                t.column("id", .text).primaryKey().notNull()
                t.column("avatarId", .text).notNull().defaults(to: "")
                t.column("coachAppearanceId", .text).notNull().defaults(to: "")
                t.column("coachName", .text).notNull().defaults(to: "")
                t.column("onboardingStep", .integer).notNull().defaults(to: 0)
                t.column("onboardingCompleted", .boolean).notNull().defaults(to: false)
                t.column("values", .text)
                t.column("goals", .text)
                t.column("personalityTraits", .text)
                t.column("domainStates", .text)
                t.column("createdAt", .text).notNull()
                t.column("updatedAt", .text).notNull()
            }
        }
        try partialMigrator.migrate(dbPool)

        // Insert with old SF Symbol IDs
        try await dbPool.write { dbConn in
            try dbConn.execute(sql: """
                INSERT INTO UserProfile (id, avatarId, coachAppearanceId, coachName, onboardingStep, onboardingCompleted, createdAt, updatedAt)
                VALUES (?, 'person.circle.fill', 'person.circle.fill', 'Sage', 5, 1, datetime('now'), datetime('now'))
                """, arguments: [UUID().uuidString])
        }

        // Now run full migrations — v7 will convert
        var fullMigrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&fullMigrator)
        try fullMigrator.migrate(dbPool)

        let profile = try await dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn)
        }
        #expect(profile?.avatarId == "avatar_classic")
        #expect(profile?.coachAppearanceId == "coach_sage")
    }

    @Test("Migration v7 converts person.circle avatar to avatar_minimal")
    func test_migration_v7_avatarMinimal() async throws {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)

        var partialMigrator = DatabaseMigrator()
        partialMigrator.registerMigration("v1") { db in
            try db.create(table: "ConversationSession") { t in
                t.column("id", .text).primaryKey().notNull()
                t.column("startedAt", .text).notNull()
                t.column("endedAt", .text)
                t.column("type", .text).notNull().defaults(to: "coaching")
                t.column("mode", .text).notNull().defaults(to: "discovery")
                t.column("safetyLevel", .text).notNull().defaults(to: "green")
                t.column("promptVersion", .text)
            }
            try db.create(table: "Message") { t in
                t.column("id", .text).primaryKey().notNull()
                t.column("sessionId", .text).notNull()
                t.column("role", .text).notNull()
                t.column("content", .text).notNull()
                t.column("timestamp", .text).notNull()
            }
        }
        partialMigrator.registerMigration("v2") { db in
            try db.create(table: "UserProfile") { t in
                t.column("id", .text).primaryKey().notNull()
                t.column("avatarId", .text).notNull().defaults(to: "")
                t.column("coachAppearanceId", .text).notNull().defaults(to: "")
                t.column("coachName", .text).notNull().defaults(to: "")
                t.column("onboardingStep", .integer).notNull().defaults(to: 0)
                t.column("onboardingCompleted", .boolean).notNull().defaults(to: false)
                t.column("values", .text)
                t.column("goals", .text)
                t.column("personalityTraits", .text)
                t.column("domainStates", .text)
                t.column("createdAt", .text).notNull()
                t.column("updatedAt", .text).notNull()
            }
        }
        try partialMigrator.migrate(dbPool)

        try await dbPool.write { dbConn in
            try dbConn.execute(sql: """
                INSERT INTO UserProfile (id, avatarId, coachAppearanceId, coachName, onboardingStep, onboardingCompleted, createdAt, updatedAt)
                VALUES (?, 'person.circle', 'brain.head.profile', 'Mentor', 5, 1, datetime('now'), datetime('now'))
                """, arguments: [UUID().uuidString])
        }

        var fullMigrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&fullMigrator)
        try fullMigrator.migrate(dbPool)

        let profile = try await dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn)
        }
        #expect(profile?.avatarId == "avatar_minimal")
        #expect(profile?.coachAppearanceId == "coach_mentor")
    }

    @Test("Migration v7 converts empty string defaults")
    func test_migration_v7_emptyStringDefaults() async throws {
        // Test that the migration handles the empty-string default case
        // The v2 migration creates UserProfile with defaults to "" for avatarId and coachAppearanceId
        // The v7 migration should convert "" → "avatar_classic" / "coach_sage"
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)

        // Run migrations up to v6 only
        var partialMigrator = DatabaseMigrator()
        partialMigrator.registerMigration("v1") { db in
            try db.create(table: "ConversationSession") { t in
                t.column("id", .text).primaryKey().notNull()
                t.column("startedAt", .text).notNull()
                t.column("endedAt", .text)
                t.column("type", .text).notNull().defaults(to: "coaching")
                t.column("mode", .text).notNull().defaults(to: "discovery")
                t.column("safetyLevel", .text).notNull().defaults(to: "green")
                t.column("promptVersion", .text)
            }
            try db.create(table: "Message") { t in
                t.column("id", .text).primaryKey().notNull()
                t.column("sessionId", .text).notNull()
                t.column("role", .text).notNull()
                t.column("content", .text).notNull()
                t.column("timestamp", .text).notNull()
            }
        }
        partialMigrator.registerMigration("v2") { db in
            try db.create(table: "UserProfile") { t in
                t.column("id", .text).primaryKey().notNull()
                t.column("avatarId", .text).notNull().defaults(to: "")
                t.column("coachAppearanceId", .text).notNull().defaults(to: "")
                t.column("coachName", .text).notNull().defaults(to: "")
                t.column("onboardingStep", .integer).notNull().defaults(to: 0)
                t.column("onboardingCompleted", .boolean).notNull().defaults(to: false)
                t.column("values", .text)
                t.column("goals", .text)
                t.column("personalityTraits", .text)
                t.column("domainStates", .text)
                t.column("createdAt", .text).notNull()
                t.column("updatedAt", .text).notNull()
            }
        }
        try partialMigrator.migrate(dbPool)

        // Insert profile with empty strings (simulating pre-v7 onboarding)
        try await dbPool.write { dbConn in
            try dbConn.execute(sql: """
                INSERT INTO UserProfile (id, avatarId, coachAppearanceId, coachName, onboardingStep, onboardingCompleted, createdAt, updatedAt)
                VALUES (?, '', '', 'Sage', 0, 0, datetime('now'), datetime('now'))
                """, arguments: [UUID().uuidString])
        }

        // Now run full migrations (v7 will convert empty strings)
        var fullMigrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&fullMigrator)
        try fullMigrator.migrate(dbPool)

        let profile = try await dbPool.read { dbConn in
            try UserProfile.fetchOne(dbConn)
        }
        #expect(profile?.avatarId == "avatar_classic")
        #expect(profile?.coachAppearanceId == "coach_sage")
    }

    @Test("Migration v7 converts all SF Symbol variants correctly")
    func test_migration_v7_allVariants() async throws {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)

        // Run through v6
        var partialMigrator = DatabaseMigrator()
        partialMigrator.registerMigration("v1") { db in
            try db.create(table: "ConversationSession") { t in
                t.column("id", .text).primaryKey().notNull()
                t.column("startedAt", .text).notNull()
                t.column("endedAt", .text)
                t.column("type", .text).notNull().defaults(to: "coaching")
                t.column("mode", .text).notNull().defaults(to: "discovery")
                t.column("safetyLevel", .text).notNull().defaults(to: "green")
                t.column("promptVersion", .text)
            }
            try db.create(table: "Message") { t in
                t.column("id", .text).primaryKey().notNull()
                t.column("sessionId", .text).notNull()
                t.column("role", .text).notNull()
                t.column("content", .text).notNull()
                t.column("timestamp", .text).notNull()
            }
        }
        partialMigrator.registerMigration("v2") { db in
            try db.create(table: "UserProfile") { t in
                t.column("id", .text).primaryKey().notNull()
                t.column("avatarId", .text).notNull().defaults(to: "")
                t.column("coachAppearanceId", .text).notNull().defaults(to: "")
                t.column("coachName", .text).notNull().defaults(to: "")
                t.column("onboardingStep", .integer).notNull().defaults(to: 0)
                t.column("onboardingCompleted", .boolean).notNull().defaults(to: false)
                t.column("values", .text)
                t.column("goals", .text)
                t.column("personalityTraits", .text)
                t.column("domainStates", .text)
                t.column("createdAt", .text).notNull()
                t.column("updatedAt", .text).notNull()
            }
        }
        try partialMigrator.migrate(dbPool)

        // Insert 3 profiles with different SF Symbol IDs
        let mappings: [(avatar: String, coach: String, expectedAvatar: String, expectedCoach: String)] = [
            ("person.circle.fill", "person.circle.fill", "avatar_classic", "coach_sage"),
            ("person.circle", "brain.head.profile", "avatar_minimal", "coach_mentor"),
            ("figure.mind.and.body", "leaf.circle.fill", "avatar_zen", "coach_guide"),
        ]

        for mapping in mappings {
            try await dbPool.write { dbConn in
                try dbConn.execute(sql: """
                    INSERT INTO UserProfile (id, avatarId, coachAppearanceId, coachName, onboardingStep, onboardingCompleted, createdAt, updatedAt)
                    VALUES (?, ?, ?, 'Test', 5, 1, datetime('now'), datetime('now'))
                    """, arguments: [UUID().uuidString, mapping.avatar, mapping.coach])
            }
        }

        // Run full migrations
        var fullMigrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&fullMigrator)
        try fullMigrator.migrate(dbPool)

        let profiles: [UserProfile] = try await dbPool.read { dbConn in
            try UserProfile.fetchAll(dbConn)
        }

        let avatarIds = Set(profiles.map(\.avatarId))
        let coachIds = Set(profiles.map(\.coachAppearanceId))

        #expect(avatarIds == Set(["avatar_classic", "avatar_minimal", "avatar_zen"]))
        #expect(coachIds == Set(["coach_sage", "coach_mentor", "coach_guide"]))
    }

    // MARK: - Task 8.7: CoachingViewModel loads coachAppearanceId from database

    @Test("CoachingViewModel loads coachAppearanceId from DB")
    @MainActor
    func test_coachingViewModel_loadsCoachAppearanceId() async throws {
        let db = try makeTestDB()

        // Create profile with specific coach appearance
        try await db.dbPool.write { dbConn in
            let profile = UserProfile(
                id: UUID(),
                avatarId: "avatar_zen",
                coachAppearanceId: "coach_guide",
                coachName: "Guide",
                onboardingStep: 5,
                onboardingCompleted: true,
                values: nil,
                goals: nil,
                personalityTraits: nil,
                domainStates: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
            try profile.save(dbConn)
        }

        let appState = AppState()
        let mockChat = MockChatService()
        let vm = CoachingViewModel(appState: appState, chatService: mockChat, databaseManager: db)

        await vm.loadMessagesAsync()

        #expect(vm.coachAppearanceId == "coach_guide")
    }

    @Test("CoachingViewModel defaults coachAppearanceId when no profile")
    @MainActor
    func test_coachingViewModel_defaultsCoachAppearanceId() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let mockChat = MockChatService()
        let vm = CoachingViewModel(appState: appState, chatService: mockChat, databaseManager: db)

        await vm.loadMessagesAsync()

        #expect(vm.coachAppearanceId == "coach_sage")
    }

    // MARK: - AvatarOptions updated IDs

    @Test("AvatarOptions uses asset catalog IDs not SF Symbols")
    func test_avatarOptions_usesAssetCatalogIds() {
        for option in AvatarOptions.avatarOptions {
            #expect(option.id.hasPrefix("avatar_"))
        }
        for option in AvatarOptions.coachOptions {
            #expect(option.id.hasPrefix("coach_"))
        }
    }
}
