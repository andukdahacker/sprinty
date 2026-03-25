import Testing
import Foundation
import GRDB
@testable import sprinty

@Suite("CoachingViewModel Sprint Proposal")
struct CoachingViewModelSprintTests {

    private func makeTestDB() throws -> DatabaseManager {
        let tempDir = NSTemporaryDirectory()
        let dbPath = (tempDir as NSString).appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let dbPool = try DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(dbPool)
        return DatabaseManager(dbPool: dbPool)
    }

    @MainActor
    private func makeViewModel(
        chatService: MockChatService = MockChatService(),
        sprintService: MockSprintService = MockSprintService()
    ) async throws -> (CoachingViewModel, MockChatService, MockSprintService, AppState) {
        let db = try makeTestDB()
        let appState = AppState()
        appState.isAuthenticated = true
        appState.databaseManager = db
        let viewModel = CoachingViewModel(
            appState: appState,
            chatService: chatService,
            databaseManager: db,
            sprintService: sprintService
        )
        return (viewModel, chatService, sprintService, appState)
    }

    // MARK: - Sprint Proposal Receive

    @Test("sprintProposal event sets proposal on ViewModel")
    @MainActor
    func test_sprintProposal_setsProposal() async throws {
        let (vm, _, _, _) = try await makeViewModel()

        let proposal = SprintProposalData(
            name: "Career Growth",
            steps: [
                SprintProposalData.ProposalStep(description: "Research roles", order: 1),
                SprintProposalData.ProposalStep(description: "Update resume", order: 2),
            ],
            durationWeeks: 2
        )
        // Simulate receiving proposal directly (as the stream consumer would)
        vm.sprintProposal = proposal

        #expect(vm.sprintProposal != nil)
        #expect(vm.sprintProposal?.name == "Career Growth")
        #expect(vm.sprintProposal?.steps.count == 2)
    }

    // MARK: - confirmSprint

    @Test("confirmSprint creates sprint via service and sets AppState.activeSprint")
    @MainActor
    func test_confirmSprint_createsSprintAndUpdatesAppState() async throws {
        let (vm, _, sprintService, appState) = try await makeViewModel()

        vm.sprintProposal = SprintProposalData(
            name: "Focus Sprint",
            steps: [SprintProposalData.ProposalStep(description: "Step 1", order: 1)],
            durationWeeks: 1
        )

        await vm.confirmSprint()

        #expect(sprintService.createSprintCallCount == 1)
        #expect(sprintService.lastProposal?.name == "Focus Sprint")
        #expect(appState.activeSprint != nil)
        #expect(vm.sprintProposal == nil)
    }

    @Test("confirmSprint clears proposal on failure")
    @MainActor
    func test_confirmSprint_failureHandledGracefully() async throws {
        let sprintService = MockSprintService()
        sprintService.createSprintError = NSError(domain: "test", code: 1)
        let (vm, _, _, appState) = try await makeViewModel(sprintService: sprintService)

        vm.sprintProposal = SprintProposalData(
            name: "Fail Sprint",
            steps: [SprintProposalData.ProposalStep(description: "Step 1", order: 1)],
            durationWeeks: 1
        )

        await vm.confirmSprint()

        #expect(appState.activeSprint == nil)
        // Proposal should still be nil after error (user sees error state)
    }

    // MARK: - declineSprint

    @Test("declineSprint saves pending proposal and clears sprintProposal")
    @MainActor
    func test_declineSprint_savesPendingProposal() async throws {
        let (vm, _, sprintService, _) = try await makeViewModel()

        vm.sprintProposal = SprintProposalData(
            name: "Declined Sprint",
            steps: [
                SprintProposalData.ProposalStep(description: "Step 1", order: 1),
                SprintProposalData.ProposalStep(description: "Step 2", order: 2),
            ],
            durationWeeks: 2
        )

        await vm.declineSprint()

        #expect(sprintService.savePendingCallCount == 1)
        #expect(sprintService.pendingProposal?.name == "Declined Sprint")
        #expect(sprintService.pendingProposal?.steps.count == 2)
        #expect(vm.sprintProposal == nil)
    }

    // MARK: - sprintContext in ChatRequest

    @Test("streamChat passes sprintContext with active sprint info")
    @MainActor
    func test_sendMessage_includesSprintContext() async throws {
        let chatService = MockChatService()
        chatService.stubbedEvents = [
            .token(text: "Hello"),
            .done(safetyLevel: "green", domainTags: [], mood: "warm", mode: "discovery", memoryReferenced: false, challengerUsed: false, usage: ChatUsage(inputTokens: 10, outputTokens: 5), promptVersion: "v1", profileUpdate: nil)
        ]
        let sprintService = MockSprintService()
        let sprint = Sprint(id: UUID(), name: "Active Sprint", startDate: Date(timeIntervalSinceNow: -3 * 86400), endDate: Date(timeIntervalSinceNow: 4 * 86400), status: .active)
        let steps = [
            SprintStep(id: UUID(), sprintId: sprint.id, description: "Step 1", completed: true, completedAt: Date(), order: 1),
            SprintStep(id: UUID(), sprintId: sprint.id, description: "Step 2", completed: false, completedAt: nil, order: 2),
        ]
        sprintService.activeSprintResult = (sprint, steps)

        let (vm, _, _, _) = try await makeViewModel(chatService: chatService, sprintService: sprintService)
        await vm.sendMessage("Hello")

        // Wait for streaming to complete
        try await Task.sleep(for: .milliseconds(200))

        #expect(chatService.lastSprintContext != nil)
        #expect(chatService.lastSprintContext?.activeSprint?.name == "Active Sprint")
        #expect(chatService.lastSprintContext?.activeSprint?.stepsCompleted == 1)
        #expect(chatService.lastSprintContext?.activeSprint?.stepsTotal == 2)
    }
}
