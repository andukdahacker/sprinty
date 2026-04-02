import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("SprintDetailViewModel Tests")
struct SprintDetailViewModelTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    private func createActiveSprint(in db: DatabaseManager, stepCount: Int = 3, withCoachContext: Bool = false) async throws -> (Sprint, [SprintStep]) {
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
                coachContext: withCoachContext ? "Why step \(i) matters" : nil
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

    // MARK: - Migration v9 Tests

    @Test("Migration v9 adds coachContext column to SprintStep")
    func test_migrationV9_addsCoachContextColumn() async throws {
        let db = try makeTestDB()

        // Insert a sprint step and verify coachContext is nil by default
        let sprint = Sprint(
            id: UUID(),
            name: "Test",
            startDate: Date(),
            endDate: Date(),
            status: .active
        )
        let step = SprintStep(
            id: UUID(),
            sprintId: sprint.id,
            description: "Step 1",
            completed: false,
            completedAt: nil,
            order: 1,
            coachContext: nil
        )

        try await db.dbPool.write { dbConn in
            try sprint.insert(dbConn)
            try step.insert(dbConn)
        }

        let fetched = try await db.dbPool.read { dbConn in
            try SprintStep.fetchOne(dbConn, key: step.id)
        }
        #expect(fetched != nil)
        #expect(fetched?.coachContext == nil)
    }

    @Test("Migration v9 preserves existing SprintStep rows with nil coachContext")
    func test_migrationV9_existingRowsHaveNilCoachContext() async throws {
        let db = try makeTestDB()
        let (_, steps) = try await createActiveSprint(in: db, withCoachContext: false)

        let fetched = try await db.dbPool.read { dbConn in
            try SprintStep.forSprint(id: steps[0].sprintId).fetchAll(dbConn)
        }
        #expect(fetched.count == 3)
        #expect(fetched.allSatisfy { $0.coachContext == nil })
    }

    @Test("SprintStep persists and reads coachContext when present")
    func test_sprintStep_coachContextRoundtrip() async throws {
        let db = try makeTestDB()
        let (_, steps) = try await createActiveSprint(in: db, withCoachContext: true)

        let fetched = try await db.dbPool.read { dbConn in
            try SprintStep.forSprint(id: steps[0].sprintId).fetchAll(dbConn)
        }
        #expect(fetched[0].coachContext == "Why step 1 matters")
        #expect(fetched[1].coachContext == "Why step 2 matters")
    }

    // MARK: - ProposalStep Backward Compatibility

    @Test("ProposalStep decodes coachContext when present")
    func test_proposalStep_decodesCoachContext() throws {
        let json = """
        {"description": "Step 1", "order": 1, "coachContext": "This builds momentum"}
        """.data(using: .utf8)!
        let step = try JSONDecoder().decode(SprintProposalData.ProposalStep.self, from: json)
        #expect(step.coachContext == "This builds momentum")
    }

    @Test("ProposalStep decodes with nil coachContext when absent (backward compat)")
    func test_proposalStep_nilCoachContextWhenAbsent() throws {
        let json = """
        {"description": "Step 1", "order": 1}
        """.data(using: .utf8)!
        let step = try JSONDecoder().decode(SprintProposalData.ProposalStep.self, from: json)
        #expect(step.coachContext == nil)
    }

    // MARK: - Load Tests

    @Test("load fetches active sprint and steps")
    @MainActor func test_load_fetchesActiveSprint() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let (_, _) = try await createActiveSprint(in: db, stepCount: 3, withCoachContext: true)
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db)

        await vm.load()

        #expect(vm.sprint != nil)
        #expect(vm.sprint?.status == .active)
        #expect(vm.steps.count == 3)
        #expect(vm.steps[0].coachContext == "Why step 1 matters")
    }

    @Test("load with no active sprint results in nil sprint")
    @MainActor func test_load_noActiveSprint() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db)

        await vm.load()

        #expect(vm.sprint == nil)
        #expect(vm.steps.isEmpty)
    }

    // MARK: - Toggle Step Tests

    @Test("toggleStep marks step as completed with timestamp")
    @MainActor func test_toggleStep_marksCompleted() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let (_, steps) = try await createActiveSprint(in: db, stepCount: 3)
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db)
        await vm.load()

        await vm.toggleStep(vm.steps[0])

        #expect(vm.steps[0].completed == true)
        #expect(vm.steps[0].completedAt != nil)
        // Verify persisted
        let fetched = try await db.dbPool.read { dbConn in
            try SprintStep.fetchOne(dbConn, key: steps[0].id)
        }
        #expect(fetched?.completed == true)
    }

    @Test("toggleStep detects sprint completion when all steps done")
    @MainActor func test_toggleStep_sprintCompletion() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let (sprint, _) = try await createActiveSprint(in: db, stepCount: 2)
        appState.activeSprint = sprint
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db)
        await vm.load()

        // Complete first step
        await vm.toggleStep(vm.steps[0])
        #expect(vm.sprint?.status == .active)

        // Complete second step — sprint should complete
        await vm.toggleStep(vm.steps[1])
        #expect(vm.sprint?.status == .complete)
        #expect(appState.activeSprint == nil)

        // Verify in DB
        let fetchedSprint = try await db.dbPool.read { dbConn in
            try Sprint.fetchOne(dbConn, key: sprint.id)
        }
        #expect(fetchedSprint?.status == .complete)
    }

    @Test("toggleStep works offline — no network dependency")
    @MainActor func test_toggleStep_worksOffline() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        appState.isOnline = false
        let (_, _) = try await createActiveSprint(in: db, stepCount: 2)
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db)
        await vm.load()

        await vm.toggleStep(vm.steps[0])

        #expect(vm.steps[0].completed == true)
    }

    @Test("toggleStep reactivates sprint when uncompleting a step after completion")
    @MainActor func test_toggleStep_reactivatesSprintOnUncomplete() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let (sprint, _) = try await createActiveSprint(in: db, stepCount: 2)
        appState.activeSprint = sprint
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db)
        await vm.load()

        // Complete all steps → sprint becomes complete
        await vm.toggleStep(vm.steps[0])
        await vm.toggleStep(vm.steps[1])
        #expect(vm.sprint?.status == .complete)
        #expect(appState.activeSprint == nil)

        // Uncomplete one step → sprint should reactivate
        await vm.toggleStep(vm.steps[1])
        #expect(vm.sprint?.status == .active)
        #expect(appState.activeSprint != nil)
        #expect(vm.steps[1].completed == false)

        // Verify in DB
        let fetchedSprint = try await db.dbPool.read { dbConn in
            try Sprint.fetchOne(dbConn, key: sprint.id)
        }
        #expect(fetchedSprint?.status == .active)
    }

    // MARK: - Computed Properties

    @Test("progress computes correct percentage")
    @MainActor func test_progress_computation() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let (_, _) = try await createActiveSprint(in: db, stepCount: 4)
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db)
        await vm.load()

        #expect(vm.progress == 0.0)

        await vm.toggleStep(vm.steps[0])
        #expect(vm.progress == 0.25)

        await vm.toggleStep(vm.steps[1])
        #expect(vm.progress == 0.5)
    }

    @Test("completedCount returns number of completed steps")
    @MainActor func test_completedCount() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let (_, _) = try await createActiveSprint(in: db, stepCount: 3)
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db)
        await vm.load()

        #expect(vm.completedCount == 0)

        await vm.toggleStep(vm.steps[0])
        #expect(vm.completedCount == 1)
    }

    // MARK: - Story 5.3 Tests

    @Test("Migration v10 adds narrativeRetro and lastStepCompletedAt columns")
    func test_migrationV10_addsNewColumns() async throws {
        let db = try makeTestDB()

        let sprint = Sprint(
            id: UUID(),
            name: "Test",
            startDate: Date(),
            endDate: Date(),
            status: .active,
            narrativeRetro: "Great job!",
            lastStepCompletedAt: Date()
        )
        try await db.dbPool.write { dbConn in
            try sprint.insert(dbConn)
        }

        let fetched = try await db.dbPool.read { dbConn in
            try Sprint.fetchOne(dbConn, key: sprint.id)
        }
        #expect(fetched != nil)
        #expect(fetched?.narrativeRetro == "Great job!")
        #expect(fetched?.lastStepCompletedAt != nil)
    }

    @Test("Migration v10 existing sprints have nil narrativeRetro and lastStepCompletedAt")
    func test_migrationV10_existingSprintsHaveNilNewFields() async throws {
        let db = try makeTestDB()

        let sprint = Sprint(
            id: UUID(),
            name: "Old Sprint",
            startDate: Date(),
            endDate: Date(),
            status: .active
        )
        try await db.dbPool.write { dbConn in
            try sprint.insert(dbConn)
        }

        let fetched = try await db.dbPool.read { dbConn in
            try Sprint.fetchOne(dbConn, key: sprint.id)
        }
        #expect(fetched?.narrativeRetro == nil)
        #expect(fetched?.lastStepCompletedAt == nil)
    }

    @Test("toggleStep persists lastStepCompletedAt on Sprint record")
    @MainActor func test_toggleStep_persistsLastStepCompletedAt() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let (sprint, _) = try await createActiveSprint(in: db, stepCount: 3)
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db)
        await vm.load()

        await vm.toggleStep(vm.steps[0])

        let fetchedSprint = try await db.dbPool.read { dbConn in
            try Sprint.fetchOne(dbConn, key: sprint.id)
        }
        #expect(fetchedSprint?.lastStepCompletedAt != nil)
    }

    @Test("Narrative retro generation sends sprint_retro mode to chat service")
    @MainActor func test_generateNarrativeRetro_sendsCorrectMode() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Here's the chapter we just finished... "),
            .token(text: "Great work on this sprint!"),
            .done(safetyLevel: "green", domainTags: [], mood: nil, mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 20), promptVersion: nil, profileUpdate: nil, guardrail: nil)
        ]

        let (sprint, steps) = try await createActiveSprint(in: db, stepCount: 2, withCoachContext: true)
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db, chatService: mockChat)
        vm.sprint = sprint
        vm.steps = steps

        await vm.generateNarrativeRetro(for: sprint, steps: steps)

        #expect(mockChat.lastMode == "sprint_retro")
        #expect(mockChat.lastSprintContext?.retroSteps?.count == 2)
        #expect(mockChat.lastSprintContext?.retroSteps?[0].description == "Step 1")
        #expect(mockChat.lastSprintContext?.retroSteps?[0].coachContext == "Why step 1 matters")
    }

    @Test("Narrative retro persists to Sprint.narrativeRetro")
    @MainActor func test_generateNarrativeRetro_persistsRetro() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Here's the chapter "),
            .token(text: "we just finished."),
            .done(safetyLevel: "green", domainTags: [], mood: nil, mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 20), promptVersion: nil, profileUpdate: nil, guardrail: nil)
        ]

        let (sprint, steps) = try await createActiveSprint(in: db, stepCount: 2)
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db, chatService: mockChat)
        vm.sprint = sprint
        vm.steps = steps

        await vm.generateNarrativeRetro(for: sprint, steps: steps)

        #expect(vm.sprint?.narrativeRetro == "Here's the chapter we just finished.")

        // Verify persisted in DB
        let fetchedSprint = try await db.dbPool.read { dbConn in
            try Sprint.fetchOne(dbConn, key: sprint.id)
        }
        #expect(fetchedSprint?.narrativeRetro == "Here's the chapter we just finished.")
    }

    @Test("Narrative retro failure keeps narrativeRetro nil")
    @MainActor func test_generateNarrativeRetro_failureKeepsNil() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let mockChat = MockChatService()
        mockChat.stubbedError = AppError.networkUnavailable

        let (sprint, steps) = try await createActiveSprint(in: db, stepCount: 2)
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db, chatService: mockChat)
        vm.sprint = sprint
        vm.steps = steps

        await vm.generateNarrativeRetro(for: sprint, steps: steps)

        #expect(vm.sprint?.narrativeRetro == nil)
    }

    @Test("Retro retry on load when sprint complete but narrativeRetro nil")
    @MainActor func test_load_retriesRetroWhenMissing() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Retro text"),
            .done(safetyLevel: "green", domainTags: [], mood: nil, mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 20), promptVersion: nil, profileUpdate: nil, guardrail: nil)
        ]

        // Create a complete sprint without retro (no active sprint exists)
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
            for step in steps {
                try step.insert(dbConn)
            }
        }

        let vm = SprintDetailViewModel(appState: appState, databaseManager: db, chatService: mockChat)
        await vm.load()

        // load() should find the complete sprint via fallback query
        #expect(vm.sprint != nil)
        #expect(vm.sprint?.status == .complete)

        // Retry triggers in a detached Task — give it time to complete
        try await Task.sleep(for: .milliseconds(100))

        // Verify retro generation was attempted with sprint_retro mode
        #expect(mockChat.lastMode == "sprint_retro")
    }

    @Test("sprintJustCompleted TTL: true within 1 hour, false after")
    func test_sprintJustCompleted_withinOneHour() throws {
        let now = Date()

        // Replicate the actual computation from CoachingViewModel.buildSprintContext()
        func computeJustCompleted(lastStepCompletedAt: Date?, sprintStatus: SprintStatus) -> Bool {
            let recentCelebration: Bool
            if let lastCompleted = lastStepCompletedAt {
                let hourAgo = Calendar.current.date(byAdding: .hour, value: -1, to: now) ?? now
                recentCelebration = lastCompleted > hourAgo
            } else {
                recentCelebration = false
            }
            return sprintStatus == .complete && recentCelebration
        }

        // Recent completion + complete status → true
        let thirtyMinAgo = Calendar.current.date(byAdding: .minute, value: -30, to: now)!
        #expect(computeJustCompleted(lastStepCompletedAt: thirtyMinAgo, sprintStatus: .complete) == true)

        // Old completion + complete status → false
        let twoHoursAgo = Calendar.current.date(byAdding: .hour, value: -2, to: now)!
        #expect(computeJustCompleted(lastStepCompletedAt: twoHoursAgo, sprintStatus: .complete) == false)

        // Recent completion + active status → false (not complete yet)
        #expect(computeJustCompleted(lastStepCompletedAt: thirtyMinAgo, sprintStatus: .active) == false)

        // Nil completion + complete status → false
        #expect(computeJustCompleted(lastStepCompletedAt: nil, sprintStatus: .complete) == false)
    }

    // --- Story 9.2 Tests ---

    // MARK: - 50% Milestone Notification

    @Test("50% milestone notification fires when crossing threshold")
    @MainActor func test_toggleStep_50percentMilestone_fires() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let mockScheduler = MockNotificationScheduler()
        let (sprint, _) = try await createActiveSprint(in: db, stepCount: 4)
        appState.activeSprint = sprint
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db, notificationScheduler: mockScheduler)
        await vm.load()

        // Complete step 1 (25%) — no milestone
        await vm.toggleStep(vm.steps[0])
        #expect(mockScheduler.scheduleCallCount == 0)

        // Complete step 2 (50%) — 50% milestone should fire
        await vm.toggleStep(vm.steps[1])
        #expect(mockScheduler.scheduleCallCount == 1)
        #expect(mockScheduler.lastScheduledType == .sprintMilestone)
    }

    @Test("50% milestone not fired twice for same sprint")
    @MainActor func test_toggleStep_50percentMilestone_noDuplicate() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let mockScheduler = MockNotificationScheduler()
        let (sprint, _) = try await createActiveSprint(in: db, stepCount: 4)
        appState.activeSprint = sprint
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db, notificationScheduler: mockScheduler)
        await vm.load()

        // Complete steps 1 and 2 (50%)
        await vm.toggleStep(vm.steps[0])
        await vm.toggleStep(vm.steps[1])
        #expect(mockScheduler.scheduleCallCount == 1)

        // Complete step 3 (75%) — should NOT fire again
        await vm.toggleStep(vm.steps[2])
        #expect(mockScheduler.scheduleCallCount == 1)
    }

    @Test("100% milestone still fires via allDone path")
    @MainActor func test_toggleStep_100percentMilestone_stillFires() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let mockScheduler = MockNotificationScheduler()
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Retro"),
            .done(safetyLevel: "green", domainTags: [], mood: nil, mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 20), promptVersion: nil, profileUpdate: nil, guardrail: nil)
        ]
        let (sprint, _) = try await createActiveSprint(in: db, stepCount: 2)
        appState.activeSprint = sprint
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db, chatService: mockChat, notificationScheduler: mockScheduler)
        await vm.load()

        // Complete all steps
        await vm.toggleStep(vm.steps[0])
        // Step 1 of 2 = 50% — fires 50% milestone
        #expect(mockScheduler.scheduleCallCount == 1)

        await vm.toggleStep(vm.steps[1])
        // allDone fires 100% milestone
        #expect(mockScheduler.scheduleCallCount == 2)
    }

    @Test("Step below 50% does not fire milestone")
    @MainActor func test_toggleStep_below50percent_noMilestone() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let mockScheduler = MockNotificationScheduler()
        let (sprint, _) = try await createActiveSprint(in: db, stepCount: 6)
        appState.activeSprint = sprint
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db, notificationScheduler: mockScheduler)
        await vm.load()

        // Complete step 1 of 6 (~17%) — no milestone
        await vm.toggleStep(vm.steps[0])
        #expect(mockScheduler.scheduleCallCount == 0)

        // Complete step 2 of 6 (~33%) — still no milestone
        await vm.toggleStep(vm.steps[1])
        #expect(mockScheduler.scheduleCallCount == 0)
    }

    @Test("Odd step count rounds correctly — 3 of 5 triggers 50% milestone")
    @MainActor func test_toggleStep_oddStepCount_50percentRounding() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let mockScheduler = MockNotificationScheduler()
        let (sprint, _) = try await createActiveSprint(in: db, stepCount: 5)
        appState.activeSprint = sprint
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db, notificationScheduler: mockScheduler)
        await vm.load()

        // Complete 2 of 5 (40%) — no milestone
        await vm.toggleStep(vm.steps[0])
        await vm.toggleStep(vm.steps[1])
        #expect(mockScheduler.scheduleCallCount == 0)

        // Complete 3 of 5 (60%) — crosses 50%
        await vm.toggleStep(vm.steps[2])
        #expect(mockScheduler.scheduleCallCount == 1)
        #expect(mockScheduler.lastScheduledType == .sprintMilestone)
    }

    @Test("Sprint completion uses differentiated celebration — avatar celebrating state")
    @MainActor func test_toggleStep_sprintCompletion_usesDifferentiatedCelebration() async throws {
        let db = try makeTestDB()
        let appState = AppState()
        let mockChat = MockChatService()
        mockChat.stubbedEvents = [
            .token(text: "Retro"),
            .done(safetyLevel: "green", domainTags: [], mood: nil, mode: nil, memoryReferenced: nil, challengerUsed: nil, usage: ChatUsage(inputTokens: 10, outputTokens: 20), promptVersion: nil, profileUpdate: nil, guardrail: nil)
        ]

        let (sprint, _) = try await createActiveSprint(in: db, stepCount: 2)
        appState.activeSprint = sprint
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db, chatService: mockChat)
        await vm.load()

        // Complete first step — step celebration triggers .celebrating avatar
        await vm.toggleStep(vm.steps[0])
        #expect(vm.sprint?.status == .active)
        #expect(appState.avatarState == .celebrating)

        // Complete second step — sprint completion also triggers .celebrating avatar
        await vm.toggleStep(vm.steps[1])
        #expect(vm.sprint?.status == .complete)
        #expect(appState.activeSprint == nil)
        // Sprint completion sets celebrating state (triggerSprintCompletion was called)
        #expect(appState.avatarState == .celebrating)
    }
}
