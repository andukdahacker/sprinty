import Foundation
import Observation
import UIKit
import GRDB
import SwiftUI

@MainActor
@Observable
final class HomeViewModel {
    var greeting: String = "Welcome back"
    var timeOfDayGreeting: String = ""
    var avatarId: String = "avatar_classic"
    var avatarState: AvatarState { appState.avatarState }
    var completedConversationCount: Int = 0
    var latestInsight: String?
    var latestCheckIn: String?
    var hasActiveSprint: Bool = false
    var sprintProgress: Double = 0
    var sprintCurrentStep: Int = 0
    var sprintTotalSteps: Int = 0
    var sprintName: String = ""
    var sprintDayNumber: Int = 0
    var sprintTotalDays: Int = 0

    private(set) var isPostCrisis: Bool = false

    var homeStage: HomeDisclosureStage {
        if appState.isPaused { return .paused }
        if isPostCrisis { return .welcome }
        if hasActiveSprint { return .sprintActive }
        if completedConversationCount >= 1 { return .insightUnlocked }
        return .welcome
    }

    var insightDisplayText: String? {
        if appState.isPaused { return "Your coach is here when you're ready." }
        if isPostCrisis { return nil }
        if let latestInsight { return latestInsight }
        if completedConversationCount >= 1 { return "Your coach is getting to know you..." }
        return nil
    }

    private let appState: AppState
    private let databaseManager: DatabaseManager
    private let insightService: InsightServiceProtocol?
    private var celebrationTask: Task<Void, Never>?

    init(appState: AppState, databaseManager: DatabaseManager, insightService: InsightServiceProtocol? = nil) {
        self.appState = appState
        self.databaseManager = databaseManager
        self.insightService = insightService
    }

    func triggerCelebration() {
        celebrationTask?.cancel()
        let previousState = appState.avatarState == .celebrating ? AvatarState.active : appState.avatarState
        appState.avatarState = .celebrating

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        celebrationTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            self?.appState.avatarState = previousState
        }
    }

    func load() async {
        await loadUserProfile()
        updateGreeting()
        await loadCompletedConversationCount()
        await loadLatestInsight()
        await loadLatestCheckIn()
        await loadActiveSprint()
    }

    private func loadUserProfile() async {
        do {
            let profile = try await databaseManager.dbPool.read { db in
                try UserProfile.current().fetchOne(db)
            }
            if let profile {
                avatarId = profile.avatarId
                if profile.lastSafetyBoundaryAt != nil {
                    isPostCrisis = true
                    appState.avatarState = .resting
                }
            }
        } catch {
            // Fallback to defaults
        }
    }

    private func loadCompletedConversationCount() async {
        do {
            let count = try await databaseManager.dbPool.read { db in
                try ConversationSession.completedCount(db)
            }
            completedConversationCount = count
        } catch {
            completedConversationCount = 0
        }
    }

    private func loadLatestInsight() async {
        if let insightService {
            latestInsight = await insightService.generateDailyInsight()
        } else {
            do {
                let summary = try await databaseManager.dbPool.read { db in
                    try ConversationSummary.recent(limit: 1).fetchOne(db)
                }
                latestInsight = summary?.summary
            } catch {
                latestInsight = nil
            }
        }
    }

    private func loadLatestCheckIn() async {
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
            latestCheckIn = checkIn?.summary
        } catch {
            latestCheckIn = nil
        }
    }

    private func loadActiveSprint() async {
        do {
            let sprintData: (hasActive: Bool, completed: Int, total: Int, name: String, dayNumber: Int, totalDays: Int) = try await databaseManager.dbPool.read { db in
                guard let sprint = try Sprint.active().fetchOne(db) else {
                    return (false, 0, 0, "", 0, 0)
                }

                let dayNumber = (Calendar.current.dateComponents([.day], from: sprint.startDate, to: Date()).day ?? 0) + 1
                let totalDays = (Calendar.current.dateComponents([.day], from: sprint.startDate, to: sprint.endDate).day ?? 0) + 1

                let steps = try SprintStep.forSprint(id: sprint.id).fetchAll(db)
                let completed = steps.filter(\.completed).count

                return (true, completed, steps.count, sprint.name, dayNumber, totalDays)
            }
            hasActiveSprint = sprintData.hasActive
            sprintCurrentStep = sprintData.completed
            sprintTotalSteps = sprintData.total
            sprintProgress = sprintData.total > 0 ? Double(sprintData.completed) / Double(sprintData.total) : 0
            sprintName = sprintData.name
            sprintDayNumber = sprintData.dayNumber
            sprintTotalDays = sprintData.totalDays
        } catch {
            hasActiveSprint = false
            sprintProgress = 0
            sprintCurrentStep = 0
            sprintTotalSteps = 0
            sprintName = ""
            sprintDayNumber = 0
            sprintTotalDays = 0
        }
    }

    // MARK: - Pause Mode

    func togglePause() {
        let newPaused = !appState.isPaused
        appState.isPaused = newPaused
        appState.avatarState = AvatarState.derive(isPaused: newPaused)

        // VoiceOver announcement
        let announcement = newPaused ? "Pause Mode activated" : "Pause Mode deactivated"
        UIAccessibility.post(notification: .announcement, argument: announcement)

        // Persist to database
        Task { [weak self] in
            guard let self else { return }
            guard !Task.isCancelled else { return }
            do {
                try await databaseManager.dbPool.write { db in
                    guard var profile = try UserProfile.current().fetchOne(db) else { return }
                    profile.isPaused = newPaused
                    profile.pausedAt = newPaused ? Date() : nil
                    profile.updatedAt = Date()
                    try profile.update(db)
                }
            } catch {
                // Persistence failed — runtime state already updated
            }
        }

        // "Rest well" message on activation
        if newPaused {
            Task { [weak self] in
                guard let self else { return }
                guard !Task.isCancelled else { return }
                await appendRestWellMessage()
            }
        }
    }

    private func appendRestWellMessage() async {
        do {
            // Find the most recent session
            let session = try await databaseManager.dbPool.read { db in
                try ConversationSession.recent(limit: 1).fetchOne(db)
            }
            guard let session else { return }

            let message = Message(
                id: UUID(),
                sessionId: session.id,
                role: .assistant,
                content: "Rest well.",
                timestamp: Date()
            )
            try await databaseManager.dbPool.write { db in
                try message.insert(db)
            }
        } catch {
            // Best effort — don't block pause activation
        }
    }

    #if DEBUG
    /// Creates a pre-configured ViewModel for SwiftUI previews using a temp database.
    static func preview(
        greeting: String = "Welcome back",
        timeOfDayGreeting: String = "Good evening",
        avatarId: String = "avatar_classic",
        avatarState: AvatarState = .active,
        completedConversationCount: Int = 0,
        latestInsight: String? = nil,
        latestCheckIn: String? = nil,
        hasActiveSprint: Bool = false,
        sprintProgress: Double = 0,
        sprintCurrentStep: Int = 0,
        sprintTotalSteps: Int = 0,
        sprintName: String = "",
        sprintDayNumber: Int = 0,
        sprintTotalDays: Int = 0,
        isPaused: Bool = false,
        insightService: InsightServiceProtocol? = nil
    ) -> HomeViewModel {
        let dbPath = NSTemporaryDirectory() + "preview_home.sqlite"
        let dbPool = try! DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try! migrator.migrate(dbPool)
        let db = DatabaseManager(dbPool: dbPool)
        let appState = AppState()
        appState.avatarState = avatarState
        appState.isPaused = isPaused
        let vm = HomeViewModel(appState: appState, databaseManager: db, insightService: insightService)
        vm.greeting = greeting
        vm.timeOfDayGreeting = timeOfDayGreeting
        vm.avatarId = avatarId
        vm.completedConversationCount = completedConversationCount
        vm.latestInsight = latestInsight
        vm.latestCheckIn = latestCheckIn
        vm.hasActiveSprint = hasActiveSprint
        vm.sprintProgress = sprintProgress
        vm.sprintCurrentStep = sprintCurrentStep
        vm.sprintTotalSteps = sprintTotalSteps
        vm.sprintName = sprintName
        vm.sprintDayNumber = sprintDayNumber
        vm.sprintTotalDays = sprintTotalDays
        return vm
    }
    #endif

    // internal for testing — accepts date parameter for deterministic tests
    func updateGreeting(for date: Date = Date()) {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12:
            timeOfDayGreeting = "Good morning"
        case 12..<17:
            timeOfDayGreeting = "Good afternoon"
        default:
            timeOfDayGreeting = "Good evening"
        }
    }
}
