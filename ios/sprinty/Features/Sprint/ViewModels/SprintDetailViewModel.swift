import Foundation
import Observation
import UIKit
import UserNotifications
import GRDB

@MainActor
@Observable
final class SprintDetailViewModel {
    var sprint: Sprint?
    var steps: [SprintStep] = []
    var isLoading: Bool = false
    var localError: AppError?
    var isGeneratingRetro: Bool = false

    var progress: Double {
        guard !steps.isEmpty else { return 0 }
        return Double(steps.filter(\.completed).count) / Double(steps.count)
    }

    var completedCount: Int {
        steps.filter(\.completed).count
    }

    var dayNumber: Int {
        guard let sprint else { return 0 }
        return (Calendar.current.dateComponents([.day], from: sprint.startDate, to: Date()).day ?? 0) + 1
    }

    var totalDays: Int {
        guard let sprint else { return 0 }
        return (Calendar.current.dateComponents([.day], from: sprint.startDate, to: sprint.endDate).day ?? 0) + 1
    }

    private let appState: AppState
    private let databaseManager: DatabaseManager
    private let chatService: ChatServiceProtocol?
    private let notificationScheduler: NotificationSchedulerProtocol?
    private var celebrationTask: Task<Void, Never>?

    init(appState: AppState, databaseManager: DatabaseManager, chatService: ChatServiceProtocol? = nil, notificationScheduler: NotificationSchedulerProtocol? = nil) {
        self.appState = appState
        self.databaseManager = databaseManager
        self.chatService = chatService
        self.notificationScheduler = notificationScheduler
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let result: (Sprint?, [SprintStep]) = try await databaseManager.dbPool.read { db in
                // Fetch active sprint first
                if let sprint = try Sprint.active().fetchOne(db) {
                    let steps = try SprintStep.forSprint(id: sprint.id).fetchAll(db)
                    return (sprint, steps)
                }
                // Fallback: fetch most recently completed sprint (for retro display/retry)
                if let sprint = try Sprint
                    .filter(Column("status") == SprintStatus.complete.rawValue)
                    .order(Column("endDate").desc)
                    .limit(1)
                    .fetchOne(db) {
                    let steps = try SprintStep.forSprint(id: sprint.id).fetchAll(db)
                    return (sprint, steps)
                }
                return (nil, [])
            }
            self.sprint = result.0
            self.steps = result.1

            // Retry retro generation if sprint is complete but retro is missing
            if sprint?.status == .complete, sprint?.narrativeRetro == nil {
                if let sprint = self.sprint {
                    Task { [weak self] in
                        await self?.generateNarrativeRetro(for: sprint, steps: self?.steps ?? [])
                    }
                }
            }
        } catch {
            localError = .databaseError(underlying: error)
        }
    }

    func toggleStep(_ step: SprintStep, reduceMotion: Bool = false) async {
        var updated = step
        updated.completed.toggle()
        updated.completedAt = updated.completed ? Date() : nil
        let stepToWrite = updated

        do {
            let (updatedSteps, allDone, sprintReactivated) = try await databaseManager.dbPool.write { db -> ([SprintStep], Bool, Bool) in
                try stepToWrite.update(db)

                let allSteps = try SprintStep.forSprint(id: stepToWrite.sprintId).fetchAll(db)
                let allDone = allSteps.allSatisfy(\.completed)

                // Persist lastStepCompletedAt on Sprint record when completing a step
                if stepToWrite.completed, var activeSprint = try Sprint.active().fetchOne(db) {
                    activeSprint.lastStepCompletedAt = Date()
                    try activeSprint.update(db)
                }

                // Reverse sprint completion if uncompleting a step
                if !stepToWrite.completed, let sprintId = allSteps.first?.sprintId {
                    if var sprint = try Sprint.fetchOne(db, key: sprintId), sprint.status == .complete {
                        sprint.status = .active
                        try sprint.update(db)
                        return (allSteps, false, true)
                    }
                }

                return (allSteps, allDone, false)
            }

            self.steps = updatedSteps

            if allDone {
                // 1. Generate retro FIRST (sprint is still .active at this point)
                if let sprint = self.sprint {
                    await generateNarrativeRetro(for: sprint, steps: updatedSteps)
                }

                // 2. Schedule milestone notification (fires after user navigates away)
                if let scheduler = notificationScheduler {
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                    await scheduler.scheduleIfAllowed(type: .sprintMilestone, trigger: trigger)
                }

                // 3. THEN mark sprint complete
                try await databaseManager.dbPool.write { db in
                    if var activeSprint = try Sprint.active().fetchOne(db) {
                        activeSprint.status = .complete
                        try activeSprint.update(db)
                    }
                }
                self.sprint?.status = .complete
                appState.activeSprint = nil

                // 4. Differentiated celebration for sprint completion
                triggerSprintCompletion(reduceMotion: reduceMotion)
            } else if sprintReactivated {
                self.sprint?.status = .active
                if let sprint = self.sprint {
                    appState.activeSprint = sprint
                }
            } else if stepToWrite.completed {
                triggerCelebration(reduceMotion: reduceMotion)
            }
        } catch {
            localError = .databaseError(underlying: error)
        }
    }

    func generateNarrativeRetro(for sprint: Sprint, steps: [SprintStep]) async {
        guard let chatService else { return }
        isGeneratingRetro = true
        defer { isGeneratingRetro = false }

        let retroSteps = steps.map { SprintRetroStep(description: $0.description, coachContext: $0.coachContext) }
        let totalDays = max(1, (Calendar.current.dateComponents([.day], from: sprint.startDate, to: sprint.endDate).day ?? 0) + 1)

        var lastStepISO: String?
        if let lastCompleted = sprint.lastStepCompletedAt {
            lastStepISO = ISO8601DateFormatter().string(from: lastCompleted)
        }

        let sprintCtx = SprintContext(
            activeSprint: ActiveSprintInfo(
                name: sprint.name,
                status: sprint.status.rawValue,
                stepsCompleted: steps.filter(\.completed).count,
                stepsTotal: steps.count,
                dayNumber: totalDays,
                totalDays: totalDays,
                lastStepCompletedAt: lastStepISO,
                sprintJustCompleted: true
            ),
            retroSteps: retroSteps
        )

        do {
            var retroText = ""
            let messages = [ChatRequestMessage(role: "user", content: "Generate sprint retrospective")]
            let stream = chatService.streamChat(
                messages: messages,
                mode: "sprint_retro",
                profile: nil,
                userState: nil,
                ragContext: nil,
                sprintContext: sprintCtx
            )
            for try await event in stream {
                if case .token(let text) = event {
                    retroText += text
                }
            }

            guard !retroText.isEmpty else { return }

            let sprintId = sprint.id
            let finalText = retroText
            try await databaseManager.dbPool.write { db in
                if var sprintRecord = try Sprint.fetchOne(db, id: sprintId) {
                    sprintRecord.narrativeRetro = finalText
                    try sprintRecord.update(db)
                }
            }
            self.sprint?.narrativeRetro = finalText
        } catch {
            // Retro is non-critical — log error, keep placeholder
        }
    }

    func triggerCelebration(reduceMotion: Bool = false) {
        celebrationTask?.cancel()
        let previousState = appState.avatarState == .celebrating ? AvatarState.active : appState.avatarState
        appState.avatarState = .celebrating

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        if reduceMotion {
            appState.avatarState = previousState
            return
        }

        celebrationTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            self?.appState.avatarState = previousState
        }
    }

    private func triggerSprintCompletion(reduceMotion: Bool) {
        celebrationTask?.cancel()
        let previousState = appState.avatarState == .celebrating ? AvatarState.active : appState.avatarState
        appState.avatarState = .celebrating

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        guard !reduceMotion else {
            appState.avatarState = previousState
            return
        }

        celebrationTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1200))
            guard !Task.isCancelled else { return }
            self?.appState.avatarState = previousState
        }
    }

    #if DEBUG
    static func preview(
        sprint: Sprint? = nil,
        steps: [SprintStep] = []
    ) -> SprintDetailViewModel {
        let dbPath = NSTemporaryDirectory() + "preview_sprint_detail.sqlite"
        let dbPool = try! DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try! migrator.migrate(dbPool)
        let db = DatabaseManager(dbPool: dbPool)
        let appState = AppState()
        let vm = SprintDetailViewModel(appState: appState, databaseManager: db)
        vm.sprint = sprint
        vm.steps = steps
        return vm
    }
    #endif
}
