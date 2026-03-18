import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    var isAuthenticated = false
    var needsReauth = false
    var isOnline = true
    var onboardingCompleted = false
    var databaseManager: DatabaseManager?
}
