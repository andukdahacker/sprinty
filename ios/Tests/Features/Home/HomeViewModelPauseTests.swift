import Testing
import Foundation
import GRDB
import SwiftUI
@testable import sprinty

@Suite("HomeViewModel Pause Mode")
struct HomeViewModelPauseTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    @discardableResult
    private func createProfile(in db: DatabaseManager, isPaused: Bool = false) async throws -> UserProfile {
        let profile = UserProfile(
            id: UUID(),
            avatarId: "avatar_classic",
            coachAppearanceId: "coach_sage",
            coachName: "Sage",
            onboardingStep: 5,
            onboardingCompleted: true,
            isPaused: isPaused,
            pausedAt: isPaused ? Date() : nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        try await db.dbPool.write { dbConn in
            try profile.insert(dbConn)
        }
        return profile
    }

    private func createSession(in db: DatabaseManager) async throws -> ConversationSession {
        let session = ConversationSession(
            id: UUID(),
            startedAt: Date(),
            endedAt: nil,
            type: .coaching,
            mode: .discovery,
            safetyLevel: .green,
            promptVersion: nil
        )
        try await db.dbPool.write { dbConn in
            try session.insert(dbConn)
        }
        return session
    }

    // MARK: - Task 6.1: Pause state persistence

    @Test("togglePause persists isPaused=true to database")
    @MainActor
    func test_togglePause_activate_persistsTrue() async throws {
        let db = try makeTestDB()
        _ = try await createProfile(in: db, isPaused: false)
        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)

        vm.togglePause()

        #expect(appState.isPaused == true)

        // Wait for async persistence (fire-and-forget Task in togglePause)
        try await Task.sleep(for: .milliseconds(300))

        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.current().fetchOne(dbConn)
        }
        #expect(profile?.isPaused == true)
        #expect(profile?.pausedAt != nil)
    }

    @Test("togglePause persists isPaused=false to database")
    @MainActor
    func test_togglePause_deactivate_persistsFalse() async throws {
        let db = try makeTestDB()
        _ = try await createProfile(in: db, isPaused: true)
        let appState = AppState()
        appState.isPaused = true
        let vm = HomeViewModel(appState: appState, databaseManager: db)

        vm.togglePause()

        #expect(appState.isPaused == false)

        // Wait for async persistence (fire-and-forget Task in togglePause)
        try await Task.sleep(for: .milliseconds(300))

        let profile = try await db.dbPool.read { dbConn in
            try UserProfile.current().fetchOne(dbConn)
        }
        #expect(profile?.isPaused == false)
        #expect(profile?.pausedAt == nil)
    }

    // MARK: - Task 6.2: Theme transformation

    @Test("Pause mode theme produces different palette from non-paused")
    func test_pauseTheme_producesDesaturatedPalette() {
        let base = themeFor(context: .home, colorScheme: .light, isPaused: false)
        let paused = themeFor(context: .home, colorScheme: .light, isPaused: true)

        let baseSat = base.palette.sendButton.hsbComponents.saturation
        let pausedSat = paused.palette.sendButton.hsbComponents.saturation
        #expect(pausedSat < baseSat)
    }

    @Test("Pause mode dark theme produces desaturated palette")
    func test_pauseTheme_dark_producesDesaturatedPalette() {
        let base = themeFor(context: .home, colorScheme: .dark, isPaused: false)
        let paused = themeFor(context: .home, colorScheme: .dark, isPaused: true)

        let baseSat = base.palette.sendButton.hsbComponents.saturation
        let pausedSat = paused.palette.sendButton.hsbComponents.saturation
        #expect(pausedSat < baseSat)
    }

    // MARK: - Task 6.3: ExperienceContext/HomeDisclosureStage derives paused state

    @Test("HomeDisclosureStage correctly derives paused when isPaused is true")
    @MainActor
    func test_homeStage_isPaused_returnsPaused() throws {
        let db = try makeTestDB()
        let appState = AppState()
        appState.isPaused = true
        let vm = HomeViewModel(appState: appState, databaseManager: db)
        vm.completedConversationCount = 5
        vm.hasActiveSprint = true

        #expect(vm.homeStage == .paused)
    }

    @Test("HomeDisclosureStage returns correct stage after unpausing")
    @MainActor
    func test_homeStage_unpause_returnsCorrectStage() throws {
        let db = try makeTestDB()
        let appState = AppState()
        appState.isPaused = true
        let vm = HomeViewModel(appState: appState, databaseManager: db)
        vm.completedConversationCount = 3
        vm.hasActiveSprint = true

        #expect(vm.homeStage == .paused)

        appState.isPaused = false
        #expect(vm.homeStage == .sprintActive)
    }

    // MARK: - Task 6.4: Notification suppression

    @Test("Insight display text shows pause message when paused")
    @MainActor
    func test_insightDisplayText_paused_showsPauseMessage() throws {
        let db = try makeTestDB()
        let appState = AppState()
        appState.isPaused = true
        let vm = HomeViewModel(appState: appState, databaseManager: db)
        vm.latestInsight = "Some real insight"

        #expect(vm.insightDisplayText == "Your coach is here when you're ready.")
    }

    // MARK: - Task 6.5: Safety override beats pause theme

    @Test("Safety level override beats pause theme")
    func test_safetyOverride_beatsPause() {
        let pauseOnly = themeFor(context: .home, colorScheme: .light, safetyLevel: .none, isPaused: true)
        let safetyAndPause = themeFor(context: .home, colorScheme: .light, safetyLevel: .significantDesaturation, isPaused: true)

        // Safety + pause should be more desaturated than pause alone
        let pauseSat = pauseOnly.palette.sendButton.hsbComponents.saturation
        let bothSat = safetyAndPause.palette.sendButton.hsbComponents.saturation
        #expect(bothSat < pauseSat)
    }

    // MARK: - Task 6.6: AvatarState.derive(isPaused: true) returns .resting

    @Test("AvatarState.derive returns .resting when paused")
    func test_avatarState_isPaused_resting() {
        #expect(AvatarState.derive(isPaused: true) == .resting)
    }

    @Test("AvatarState.derive returns .active when not paused")
    func test_avatarState_notPaused_active() {
        #expect(AvatarState.derive(isPaused: false) == .active)
    }

    @Test("togglePause sets avatar to resting on activation")
    @MainActor
    func test_togglePause_activate_setsAvatarResting() throws {
        let db = try makeTestDB()
        let appState = AppState()
        appState.avatarState = .active
        let vm = HomeViewModel(appState: appState, databaseManager: db)

        vm.togglePause()

        #expect(appState.avatarState == .resting)
    }

    @Test("togglePause sets avatar to active on deactivation")
    @MainActor
    func test_togglePause_deactivate_setsAvatarActive() throws {
        let db = try makeTestDB()
        let appState = AppState()
        appState.isPaused = true
        appState.avatarState = .resting
        let vm = HomeViewModel(appState: appState, databaseManager: db)

        vm.togglePause()

        #expect(appState.avatarState == .active)
    }

    // MARK: - Rest well message

    @Test("togglePause appends Rest well message on activation")
    @MainActor
    func test_togglePause_activate_appendsRestWellMessage() async throws {
        let db = try makeTestDB()
        _ = try await createProfile(in: db)
        let session = try await createSession(in: db)
        let appState = AppState()
        let vm = HomeViewModel(appState: appState, databaseManager: db)

        vm.togglePause()

        // Wait for async message insertion (fire-and-forget Task in togglePause)
        try await Task.sleep(for: .milliseconds(300))

        let messages = try await db.dbPool.read { dbConn in
            try Message.forSession(id: session.id).fetchAll(dbConn)
        }
        #expect(messages.count == 1)
        #expect(messages.first?.role == .assistant)
        #expect(messages.first?.content == "Rest well.")
    }

    @Test("togglePause does NOT append Rest well on deactivation")
    @MainActor
    func test_togglePause_deactivate_noRestWellMessage() async throws {
        let db = try makeTestDB()
        _ = try await createProfile(in: db)
        let session = try await createSession(in: db)
        let appState = AppState()
        appState.isPaused = true
        let vm = HomeViewModel(appState: appState, databaseManager: db)

        vm.togglePause()

        // Wait for any potential async operations (fire-and-forget Task in togglePause)
        try await Task.sleep(for: .milliseconds(300))

        let messages = try await db.dbPool.read { dbConn in
            try Message.forSession(id: session.id).fetchAll(dbConn)
        }
        #expect(messages.isEmpty)
    }
}
