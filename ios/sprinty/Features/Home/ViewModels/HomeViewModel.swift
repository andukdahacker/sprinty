import Foundation
import Observation
import UIKit
import GRDB

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

    var homeStage: HomeDisclosureStage {
        if appState.isPaused { return .paused }
        if hasActiveSprint { return .sprintActive }
        if completedConversationCount >= 1 { return .insightUnlocked }
        return .welcome
    }

    var insightDisplayText: String? {
        if appState.isPaused { return "Your coach is here when you're ready." }
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
        // Check-in data deferred to Story 5.4 — gracefully return nil
        latestCheckIn = nil
    }

    private func loadActiveSprint() async {
        // Sprint models deferred to Story 5.1 — gracefully handle missing table
        do {
            let sprintData: (hasActive: Bool, completed: Int, total: Int, name: String, dayNumber: Int, totalDays: Int) = try await databaseManager.dbPool.read { db in
                guard try db.tableExists("Sprint") else {
                    return (false, 0, 0, "", 0, 0)
                }
                guard let row = try Row.fetchOne(db, sql: "SELECT id, name, startDate, endDate FROM Sprint WHERE status = 'active' LIMIT 1") else {
                    return (false, 0, 0, "", 0, 0)
                }

                let name: String = row["name"] ?? ""

                // Calculate day number and total days from dates
                var dayNumber = 0
                var totalDays = 0
                let formatter = ISO8601DateFormatter()
                if let startStr: String = row["startDate"],
                   let endStr: String = row["endDate"],
                   let startDate = formatter.date(from: startStr),
                   let endDate = formatter.date(from: endStr) {
                    dayNumber = (Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0) + 1
                    totalDays = (Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0) + 1
                }

                guard try db.tableExists("SprintStep") else {
                    return (true, 0, 0, name, dayNumber, totalDays)
                }
                let sprintId: String = row["id"]
                let completed = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM SprintStep WHERE sprintId = ? AND completedAt IS NOT NULL", arguments: [sprintId]) ?? 0
                let total = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM SprintStep WHERE sprintId = ?", arguments: [sprintId]) ?? 0
                return (true, completed, total, name, dayNumber, totalDays)
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
