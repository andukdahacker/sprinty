import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("SprintDetailViewModel Offline Tests")
struct SprintDetailViewModelOfflineTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    private func createActiveSprint(in db: DatabaseManager, stepCount: Int = 3) async throws -> (Sprint, [SprintStep]) {
        let sprint = Sprint(
            id: UUID(),
            name: "Test Sprint",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .weekOfYear, value: 2, to: Date())!,
            status: .active
        )
        let steps = (1...stepCount).map { i in
            SprintStep(
                id: UUID(),
                sprintId: sprint.id,
                description: "Step \(i)",
                completed: false,
                completedAt: nil,
                order: i,
                coachContext: nil
            )
        }

        try await db.dbPool.write { dbConn in
            try sprint.insert(dbConn)
            for step in steps {
                try step.insert(dbConn)
            }
        }
        return (sprint, steps)
    }

    // MARK: - Task 2: Offline-aware step completion

    @Test("toggleStep when offline sets pendingSync status")
    @MainActor func test_toggleStep_whenOffline_setsPendingSyncStatus() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        appState.isOnline = false
        let (_, steps) = try await createActiveSprint(in: db, stepCount: 3)
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db)
        await vm.load()

        await vm.toggleStep(vm.steps[0])

        #expect(vm.steps[0].completed == true)
        #expect(vm.steps[0].syncStatus == .pendingSync)

        // Verify persisted
        let fetched = try await db.dbPool.read { dbConn in
            try SprintStep.fetchOne(dbConn, key: steps[0].id)
        }
        #expect(fetched?.syncStatus == .pendingSync)
    }

    @Test("toggleStep when online keeps synced status")
    @MainActor func test_toggleStep_whenOnline_keepsSyncedStatus() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        appState.isOnline = true
        let (_, steps) = try await createActiveSprint(in: db, stepCount: 3)
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db)
        await vm.load()

        await vm.toggleStep(vm.steps[0])

        #expect(vm.steps[0].completed == true)
        #expect(vm.steps[0].syncStatus == .synced)

        let fetched = try await db.dbPool.read { dbConn in
            try SprintStep.fetchOne(dbConn, key: steps[0].id)
        }
        #expect(fetched?.syncStatus == .synced)
    }

    @Test("toggleStep allDone offline skips retro generation")
    @MainActor func test_toggleStep_allDoneOffline_skipsRetroGeneration() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        appState.isOnline = false
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Retro"),
            .done(safetyLevel: "green", domainTags: [], mood: nil, mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 20), promptVersion: nil, profileUpdate: nil, guardrail: nil)
        ]
        let (sprint, _) = try await createActiveSprint(in: db, stepCount: 2)
        appState.activeSprint = sprint
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db, chatService: mockChat)
        await vm.load()

        await vm.toggleStep(vm.steps[0])
        await vm.toggleStep(vm.steps[1])

        // Retro should NOT have been called
        #expect(mockChat.lastMode == nil)
        #expect(vm.sprint?.narrativeRetro == nil)
        #expect(vm.retroPending == true)
    }

    @Test("toggleStep allDone offline still marks sprint complete")
    @MainActor func test_toggleStep_allDoneOffline_stillMarksSprintComplete() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        appState.isOnline = false
        let (sprint, _) = try await createActiveSprint(in: db, stepCount: 2)
        appState.activeSprint = sprint
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db)
        await vm.load()

        await vm.toggleStep(vm.steps[0])
        await vm.toggleStep(vm.steps[1])

        #expect(vm.sprint?.status == .complete)
        #expect(appState.activeSprint == nil)

        let fetchedSprint = try await db.dbPool.read { dbConn in
            try Sprint.fetchOne(dbConn, key: sprint.id)
        }
        #expect(fetchedSprint?.status == .complete)
    }

    @Test("toggleStep allDone offline still fires celebration")
    @MainActor func test_toggleStep_allDoneOffline_stillFiresCelebration() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        appState.isOnline = false
        let (sprint, _) = try await createActiveSprint(in: db, stepCount: 2)
        appState.activeSprint = sprint
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db)
        await vm.load()

        await vm.toggleStep(vm.steps[0])
        await vm.toggleStep(vm.steps[1])

        #expect(appState.avatarState == .celebrating)
    }

    @Test("Uncompleting step sets syncStatus to synced regardless of connectivity")
    @MainActor func test_toggleStep_uncomplete_setsSynced() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        appState.isOnline = false
        let (_, steps) = try await createActiveSprint(in: db, stepCount: 3)
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db)
        await vm.load()

        // Complete step offline → pendingSync
        await vm.toggleStep(vm.steps[0])
        #expect(vm.steps[0].syncStatus == .pendingSync)

        // Uncomplete step (still offline) → synced
        await vm.toggleStep(vm.steps[0])
        #expect(vm.steps[0].completed == false)
        #expect(vm.steps[0].syncStatus == .synced)

        let fetched = try await db.dbPool.read { dbConn in
            try SprintStep.fetchOne(dbConn, key: steps[0].id)
        }
        #expect(fetched?.syncStatus == .synced)
    }

    // MARK: - Task 3: Auto-sync on reconnect

    @Test("syncOnReconnect updates steps to synced even when sprint active")
    @MainActor func test_syncOnReconnect_updatesStepsToSynced_evenWhenSprintActive() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        appState.isOnline = false
        let (_, steps) = try await createActiveSprint(in: db, stepCount: 3)
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db)
        await vm.load()

        // Complete a step offline
        await vm.toggleStep(vm.steps[0])
        #expect(vm.steps[0].syncStatus == .pendingSync)

        // Go back online and sync
        appState.isOnline = true
        await vm.syncOnReconnect()

        // Step should now be synced
        let fetched = try await db.dbPool.read { dbConn in
            try SprintStep.fetchOne(dbConn, key: steps[0].id)
        }
        #expect(fetched?.syncStatus == .synced)
        #expect(vm.recentlySyncedStepIds.contains(steps[0].id))
    }

    @Test("syncOnReconnect retries retro generation when sprint complete")
    @MainActor func test_syncOnReconnect_retriesRetroGeneration_whenSprintComplete() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        appState.isOnline = false
        let mockChat = MockChatService()
        let (sprint, _) = try await createActiveSprint(in: db, stepCount: 2)
        appState.activeSprint = sprint
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db, chatService: mockChat)
        await vm.load()

        // Complete all steps offline
        await vm.toggleStep(vm.steps[0])
        await vm.toggleStep(vm.steps[1])
        #expect(vm.sprint?.status == .complete)
        #expect(vm.retroPending == true)
        #expect(mockChat.lastMode == nil) // Not called yet

        // Stub retro response for reconnect
        mockChat.stubbedEvents = [
            .token(text: "Retro text"),
            .done(safetyLevel: "green", domainTags: [], mood: nil, mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 20), promptVersion: nil, profileUpdate: nil, guardrail: nil)
        ]

        // Go back online and sync
        appState.isOnline = true
        await vm.syncOnReconnect()

        #expect(mockChat.lastMode == "sprint_retro")
        #expect(vm.sprint?.narrativeRetro == "Retro text")
        #expect(vm.retroPending == false)
    }

    @Test("syncOnReconnect steps sync independent of retro failure")
    @MainActor func test_syncOnReconnect_stepsSync_independentOfRetroFailure() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        appState.isOnline = false
        let mockChat = MockChatService()
        let (sprint, steps) = try await createActiveSprint(in: db, stepCount: 2)
        appState.activeSprint = sprint
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db, chatService: mockChat)
        await vm.load()

        // Complete all steps offline
        await vm.toggleStep(vm.steps[0])
        await vm.toggleStep(vm.steps[1])

        // Stub retro failure for reconnect
        mockChat.stubbedError = AppError.networkUnavailable

        // Go back online and sync
        appState.isOnline = true
        await vm.syncOnReconnect()

        // Steps should be synced despite retro failure
        let fetched0 = try await db.dbPool.read { dbConn in
            try SprintStep.fetchOne(dbConn, key: steps[0].id)
        }
        let fetched1 = try await db.dbPool.read { dbConn in
            try SprintStep.fetchOne(dbConn, key: steps[1].id)
        }
        #expect(fetched0?.syncStatus == .synced)
        #expect(fetched1?.syncStatus == .synced)
        // Retro still pending
        #expect(vm.retroPending == true)
        #expect(vm.sprint?.narrativeRetro == nil)
    }

    @Test("syncOnReconnect when no pending steps is no-op")
    @MainActor func test_syncOnReconnect_whenNoPendingSteps_noOp() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        appState.isOnline = true
        let (_, _) = try await createActiveSprint(in: db, stepCount: 3)
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db)
        await vm.load()

        await vm.syncOnReconnect()

        #expect(vm.recentlySyncedStepIds.isEmpty)
    }

    // MARK: - Task 4: retroPending indicator

    @Test("retroPending set on offline sprint completion")
    @MainActor func test_retroPending_setOnOfflineSprintCompletion() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        appState.isOnline = false
        let (sprint, _) = try await createActiveSprint(in: db, stepCount: 2)
        appState.activeSprint = sprint
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db)
        await vm.load()

        await vm.toggleStep(vm.steps[0])
        await vm.toggleStep(vm.steps[1])

        #expect(vm.retroPending == true)
    }

    @Test("retroPending cleared after retro generation")
    @MainActor func test_retroPending_clearedAfterRetroGeneration() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Retro text"),
            .done(safetyLevel: "green", domainTags: [], mood: nil, mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 20), promptVersion: nil, profileUpdate: nil, guardrail: nil)
        ]

        let sprint = Sprint(
            id: UUID(),
            name: "Done Sprint",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .weekOfYear, value: 2, to: Date())!,
            status: .complete,
            narrativeRetro: nil
        )
        let steps = (1...2).map { i in
            SprintStep(
                id: UUID(),
                sprintId: sprint.id,
                description: "Step \(i)",
                completed: true,
                completedAt: Date(),
                order: i,
                coachContext: nil
            )
        }
        try await db.dbPool.write { dbConn in
            try sprint.insert(dbConn)
            for step in steps { try step.insert(dbConn) }
        }

        let vm = SprintDetailViewModel(appState: appState, databaseManager: db, chatService: mockChat)
        vm.sprint = sprint
        vm.steps = steps
        vm.retroPending = true

        await vm.generateNarrativeRetro(for: sprint, steps: steps)

        #expect(vm.retroPending == false)
        #expect(vm.sprint?.narrativeRetro == "Retro text")
    }

    // MARK: - Task 6: Integration tests

    @Test("Integration: offline complete step saves with pendingSync")
    @MainActor func test_integration_offlineCompleteStep_savesPendingSync() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        appState.isOnline = false
        let (_, steps) = try await createActiveSprint(in: db, stepCount: 3)
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db)
        await vm.load()

        await vm.toggleStep(vm.steps[0])

        // Haptic/celebration fire (avatar state changes)
        #expect(appState.avatarState == .celebrating)
        // Step saved with pendingSync
        let fetched = try await db.dbPool.read { dbConn in
            try SprintStep.fetchOne(dbConn, key: steps[0].id)
        }
        #expect(fetched?.completed == true)
        #expect(fetched?.syncStatus == .pendingSync)
    }

    @Test("Integration: offline complete all steps → sprint complete → no retro → retroPending")
    @MainActor func test_integration_offlineCompleteAll_noRetro() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        appState.isOnline = false
        let mockChat = MockChatService()
        let (sprint, _) = try await createActiveSprint(in: db, stepCount: 2)
        appState.activeSprint = sprint
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db, chatService: mockChat)
        await vm.load()

        await vm.toggleStep(vm.steps[0])
        await vm.toggleStep(vm.steps[1])

        #expect(vm.sprint?.status == .complete)
        #expect(mockChat.lastMode == nil) // Retro NOT generated
        #expect(vm.retroPending == true)
    }

    @Test("Integration: complete all offline → go online → retro generates → steps synced")
    @MainActor func test_integration_offlineThenOnline_retroGenerates_stepsSynced() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        appState.isOnline = false
        let mockChat = MockChatService()
        let (sprint, steps) = try await createActiveSprint(in: db, stepCount: 2)
        appState.activeSprint = sprint
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db, chatService: mockChat)
        await vm.load()

        // Complete all offline
        await vm.toggleStep(vm.steps[0])
        await vm.toggleStep(vm.steps[1])
        #expect(vm.sprint?.status == .complete)

        // Stub retro response
        mockChat.stubbedEvents = [
            .token(text: "Well done!"),
            .done(safetyLevel: "green", domainTags: [], mood: nil, mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 20), promptVersion: nil, profileUpdate: nil, guardrail: nil)
        ]

        // Go online and sync
        appState.isOnline = true
        await vm.syncOnReconnect()

        // Steps synced
        let fetched0 = try await db.dbPool.read { dbConn in
            try SprintStep.fetchOne(dbConn, key: steps[0].id)
        }
        let fetched1 = try await db.dbPool.read { dbConn in
            try SprintStep.fetchOne(dbConn, key: steps[1].id)
        }
        #expect(fetched0?.syncStatus == .synced)
        #expect(fetched1?.syncStatus == .synced)
        // Retro generated
        #expect(vm.sprint?.narrativeRetro == "Well done!")
        #expect(vm.retroPending == false)
        // Sync pulse IDs populated
        #expect(vm.recentlySyncedStepIds.contains(steps[0].id))
        #expect(vm.recentlySyncedStepIds.contains(steps[1].id))
    }

    @Test("Integration: step completed offline → app relaunch → step still pendingSync → reconnect → syncs")
    @MainActor func test_integration_offlineStep_relaunch_reconnect() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        appState.isOnline = false
        let (sprint, steps) = try await createActiveSprint(in: db, stepCount: 3)
        let vm1 = SprintDetailViewModel(appState: appState, databaseManager: db)
        await vm1.load()

        // Complete step offline
        await vm1.toggleStep(vm1.steps[0])
        #expect(vm1.steps[0].syncStatus == .pendingSync)

        // Simulate "app relaunch" — new ViewModel instance, same DB
        appState.isOnline = true
        let vm2 = SprintDetailViewModel(appState: appState, databaseManager: db)
        await vm2.load()

        // Step should still be pendingSync in DB
        let fetched = try await db.dbPool.read { dbConn in
            try SprintStep.fetchOne(dbConn, key: steps[0].id)
        }
        #expect(fetched?.syncStatus == .pendingSync)
        #expect(fetched?.completed == true)

        // Sync on reconnect
        await vm2.syncOnReconnect()

        let fetchedAfter = try await db.dbPool.read { dbConn in
            try SprintStep.fetchOne(dbConn, key: steps[0].id)
        }
        #expect(fetchedAfter?.syncStatus == .synced)
    }

    @Test("Integration: rapid online/offline toggling doesn't corrupt state")
    @MainActor func test_integration_rapidToggling_noCorruption() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let (sprint, steps) = try await createActiveSprint(in: db, stepCount: 3)
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db)
        await vm.load()

        // Alternate online/offline during completions
        appState.isOnline = false
        await vm.toggleStep(vm.steps[0]) // complete offline → pendingSync
        appState.isOnline = true
        await vm.toggleStep(vm.steps[1]) // complete online → synced
        appState.isOnline = false
        await vm.toggleStep(vm.steps[0]) // uncomplete offline → synced (reversal)
        appState.isOnline = true
        await vm.toggleStep(vm.steps[0]) // complete online → synced

        // Verify final state
        let allFetched = try await db.dbPool.read { dbConn in
            try SprintStep.forSprint(id: sprint.id).fetchAll(dbConn)
        }
        // Step 0: completed online → synced
        #expect(allFetched[0].completed == true)
        #expect(allFetched[0].syncStatus == .synced)
        // Step 1: completed online → synced
        #expect(allFetched[1].completed == true)
        #expect(allFetched[1].syncStatus == .synced)
        // Step 2: untouched
        #expect(allFetched[2].completed == false)
        #expect(allFetched[2].syncStatus == .synced)
    }
}
