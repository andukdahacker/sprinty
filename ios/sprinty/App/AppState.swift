import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    var isAuthenticated = false
    var needsReauth = false
    var isOnline = true
    var onboardingCompleted = false
    var avatarState: AvatarState = .active
    var isPaused: Bool = false
    var activeSprint: Sprint?
    var databaseManager: DatabaseManager?
}
