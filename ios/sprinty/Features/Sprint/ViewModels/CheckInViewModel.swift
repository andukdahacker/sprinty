import Foundation
import Observation
import GRDB

@MainActor
@Observable
final class CheckInViewModel {
    var coachResponse: String = ""
    var isStreaming: Bool = false
    var isComplete: Bool = false
    var localError: String?

    private let appState: AppState
    private let databaseManager: DatabaseManager
    private let chatService: ChatServiceProtocol
    private let sprintService: SprintServiceProtocol
    private var streamingTask: Task<Void, Never>?
    private var sessionId: UUID?
    private var sprintId: UUID?

    init(appState: AppState, databaseManager: DatabaseManager, chatService: ChatServiceProtocol, sprintService: SprintServiceProtocol) {
        self.appState = appState
        self.databaseManager = databaseManager
        self.chatService = chatService
        self.sprintService = sprintService
    }

    func startCheckIn() {
        guard !isStreaming else { return }
        isStreaming = true
        coachResponse = ""
        localError = nil

        streamingTask = Task { [weak self] in
            guard let self else { return }
            do {
                // Create check-in session
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
                try await databaseManager.dbPool.write { db in
                    try session.insert(db)
                }
                self.sessionId = session.id

                guard !Task.isCancelled else { return }

                // Build sprint context
                let sprintContext = try await buildSprintContext()

                guard !Task.isCancelled else { return }

                // Send check-in message
                let userMessage = ChatRequestMessage(role: "user", content: "Quick check-in: here's where I am on my sprint")

                // Save user message
                let message = Message(
                    id: UUID(),
                    sessionId: session.id,
                    role: .user,
                    content: userMessage.content,
                    timestamp: Date()
                )
                try await databaseManager.dbPool.write { db in
                    try message.insert(db)
                }

                // Load profile for request
                let profile = try await loadChatProfile()

                let stream = chatService.streamChat(
                    messages: [userMessage],
                    mode: "check_in",
                    profile: profile,
                    userState: nil,
                    ragContext: nil,
                    sprintContext: sprintContext
                )

                var fullResponse = ""
                for try await event in stream {
                    guard !Task.isCancelled else { return }
                    switch event {
                    case .token(let text):
                        fullResponse += text
                        self.coachResponse = fullResponse
                    case .done(let safetyLevel, _, _, _, _, _, _, _, _):
                        // Save assistant message
                        let assistantMessage = Message(
                            id: UUID(),
                            sessionId: session.id,
                            role: .assistant,
                            content: fullResponse,
                            timestamp: Date()
                        )
                        try await self.databaseManager.dbPool.write { db in
                            try assistantMessage.insert(db)
                        }

                        // Handle safety escalation
                        if safetyLevel == "orange" || safetyLevel == "red" {
                            // Safety escalation — don't save as check-in
                            self.isStreaming = false
                            return
                        }

                        // End session
                        try await self.databaseManager.dbPool.write { db in
                            var s = session
                            s.endedAt = Date()
                            try s.update(db)
                        }
                    case .sprintProposal:
                        break
                    }
                }

                guard !Task.isCancelled else { return }

                self.coachResponse = fullResponse
                self.isStreaming = false
                self.isComplete = true

            } catch {
                guard !Task.isCancelled else { return }
                self.isStreaming = false
                self.localError = "Your coach needs a moment. Try again shortly."
            }
        }
    }

    func saveCheckIn() async {
        guard let sessionId, let sprintId, !coachResponse.isEmpty else { return }

        let checkIn = CheckIn(
            id: UUID(),
            sessionId: sessionId,
            sprintId: sprintId,
            summary: coachResponse,
            createdAt: Date()
        )

        do {
            try await databaseManager.dbPool.write { db in
                try checkIn.insert(db)
            }
        } catch {
            // Write failed — check-in still visible in conversation history
        }
    }

    func latestCheckInSummary() async -> String? {
        do {
            let profile = try await databaseManager.dbPool.read { db in
                try UserProfile.current().fetchOne(db)
            }
            let cadence = profile?.checkInCadence ?? "daily"

            let checkIn: CheckIn? = try await databaseManager.dbPool.read { db in
                if cadence == "weekly" {
                    return try CheckIn.latestThisWeek().fetchOne(db)
                } else {
                    return try CheckIn.latestToday().fetchOne(db)
                }
            }
            return checkIn?.summary
        } catch {
            return nil
        }
    }

    func cancelStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        isStreaming = false
    }

    private func buildSprintContext() async throws -> SprintContext? {
        guard let sprintData = try await sprintService.activeSprint() else { return nil }
        self.sprintId = sprintData.sprint.id

        let sprint = sprintData.sprint
        let steps = sprintData.steps
        let completed = steps.filter(\.completed).count

        let dayNumber = (Calendar.current.dateComponents([.day], from: sprint.startDate, to: Date()).day ?? 0) + 1
        let totalDays = (Calendar.current.dateComponents([.day], from: sprint.startDate, to: sprint.endDate).day ?? 0) + 1

        let info = ActiveSprintInfo(
            name: sprint.name,
            status: sprint.status.rawValue,
            stepsCompleted: completed,
            stepsTotal: steps.count,
            dayNumber: dayNumber,
            totalDays: totalDays
        )
        return SprintContext(activeSprint: info)
    }

    private func loadChatProfile() async throws -> ChatProfile? {
        let profile = try await databaseManager.dbPool.read { db in
            try UserProfile.current().fetchOne(db)
        }
        guard let profile else { return nil }
        return ChatProfile(
            coachName: profile.coachName,
            values: profile.decodedValues,
            goals: profile.decodedGoals,
            personalityTraits: profile.decodedPersonalityTraits,
            domainStates: profile.decodedDomainStates
        )
    }

    #if DEBUG
    static func preview(
        coachResponse: String = "",
        isStreaming: Bool = false,
        isComplete: Bool = false
    ) -> CheckInViewModel {
        let dbPath = NSTemporaryDirectory() + "preview_checkin.sqlite"
        let dbPool = try! DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try! migrator.migrate(dbPool)
        let db = DatabaseManager(dbPool: dbPool)
        let appState = AppState()
        let chatService = FailingPreviewChatService()
        let sprintService = FailingPreviewSprintService()
        let vm = CheckInViewModel(appState: appState, databaseManager: db, chatService: chatService, sprintService: sprintService)
        vm.coachResponse = coachResponse
        vm.isStreaming = isStreaming
        vm.isComplete = isComplete
        return vm
    }
    #endif
}

#if DEBUG
private struct FailingPreviewChatService: ChatServiceProtocol {
    func streamChat(messages: [ChatRequestMessage], mode: String, profile: ChatProfile?, userState: UserState? = nil, ragContext: String? = nil, sprintContext: SprintContext? = nil) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func summarize(messages: [ChatRequestMessage]) async throws -> SummaryResponse {
        throw AppError.networkUnavailable
    }
}

private struct FailingPreviewSprintService: SprintServiceProtocol {
    func createSprint(from proposal: SprintProposalData, durationWeeks: Int) async throws -> Sprint {
        throw AppError.networkUnavailable
    }
    func activeSprint() async throws -> (sprint: Sprint, steps: [SprintStep])? { nil }
    func savePendingProposal(_ proposal: PendingSprintProposal) throws {}
    func loadPendingProposal() -> PendingSprintProposal? { nil }
    func clearPendingProposal() {}
}
#endif
