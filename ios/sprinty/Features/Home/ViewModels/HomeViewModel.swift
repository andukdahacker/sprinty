import Foundation
import Observation
import GRDB

@MainActor
@Observable
final class HomeViewModel {
    var greeting: String = "Welcome back"
    var timeOfDayGreeting: String = ""
    var avatarId: String = "avatar_default"

    private let appState: AppState
    private let databaseManager: DatabaseManager

    init(appState: AppState, databaseManager: DatabaseManager) {
        self.appState = appState
        self.databaseManager = databaseManager
    }

    func load() async {
        await loadUserProfile()
        updateGreeting()
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

    #if DEBUG
    /// Creates a pre-configured ViewModel for SwiftUI previews using a temp database.
    static func preview(
        greeting: String = "Welcome back",
        timeOfDayGreeting: String = "Good evening",
        avatarId: String = "avatar_default"
    ) -> HomeViewModel {
        let dbPath = NSTemporaryDirectory() + "preview_home.sqlite"
        let dbPool = try! DatabasePool(path: dbPath)
        var migrator = DatabaseMigrator()
        DatabaseMigrations.registerMigrations(&migrator)
        try! migrator.migrate(dbPool)
        let db = DatabaseManager(dbPool: dbPool)
        let vm = HomeViewModel(appState: AppState(), databaseManager: db)
        vm.greeting = greeting
        vm.timeOfDayGreeting = timeOfDayGreeting
        vm.avatarId = avatarId
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
