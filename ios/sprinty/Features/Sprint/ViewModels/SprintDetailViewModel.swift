import Foundation
import Observation
import UIKit
import GRDB

@MainActor
@Observable
final class SprintDetailViewModel {
    var sprint: Sprint?
    var steps: [SprintStep] = []
    var isLoading: Bool = false
    var localError: AppError?

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
    private var celebrationTask: Task<Void, Never>?

    init(appState: AppState, databaseManager: DatabaseManager) {
        self.appState = appState
        self.databaseManager = databaseManager
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let result: (Sprint?, [SprintStep]) = try await databaseManager.dbPool.read { db in
                guard let sprint = try Sprint.active().fetchOne(db) else {
                    return (nil, [])
                }
                let steps = try SprintStep.forSprint(id: sprint.id).fetchAll(db)
                return (sprint, steps)
            }
            self.sprint = result.0
            self.steps = result.1
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
            let (updatedSteps, sprintCompleted, sprintReactivated) = try await databaseManager.dbPool.write { db -> ([SprintStep], Bool, Bool) in
                try stepToWrite.update(db)

                let allSteps = try SprintStep.forSprint(id: stepToWrite.sprintId).fetchAll(db)
                let allDone = allSteps.allSatisfy(\.completed)

                if allDone {
                    if var activeSprint = try Sprint.active().fetchOne(db) {
                        activeSprint.status = .complete
                        try activeSprint.update(db)
                    }
                    return (allSteps, true, false)
                }

                // Reverse sprint completion if uncompleting a step
                if !stepToWrite.completed, let sprintId = allSteps.first?.sprintId {
                    if var sprint = try Sprint.fetchOne(db, key: sprintId), sprint.status == .complete {
                        sprint.status = .active
                        try sprint.update(db)
                        return (allSteps, false, true)
                    }
                }

                return (allSteps, false, false)
            }

            self.steps = updatedSteps
            if sprintCompleted {
                self.sprint?.status = .complete
                appState.activeSprint = nil
            } else if sprintReactivated {
                self.sprint?.status = .active
                if let sprint = self.sprint {
                    appState.activeSprint = sprint
                }
            }

            if stepToWrite.completed {
                triggerCelebration(reduceMotion: reduceMotion)
            }
        } catch {
            localError = .databaseError(underlying: error)
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
