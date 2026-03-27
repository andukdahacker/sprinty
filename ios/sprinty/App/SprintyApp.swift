import SwiftUI
import UserNotifications

@main
struct SprintyApp: App {
    @State private var appState = AppState()
    @State private var notificationDelegate: CheckInNotificationDelegate?

    @Environment(\.colorScheme) private var colorScheme

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(\.coachingTheme, themeFor(context: .home, colorScheme: colorScheme))
                .task {
                    let delegate = CheckInNotificationDelegate(appState: appState)
                    notificationDelegate = delegate
                    UNUserNotificationCenter.current().delegate = delegate
                    await bootstrap()
                }
        }
    }

    private func bootstrap() async {
        do {
            let databaseManager = try DatabaseManager.create()
            appState.databaseManager = databaseManager

            let apiClient = try APIClient.fromConfiguration()
            let authService = AuthService(apiClient: apiClient)
            try await authService.ensureAuthenticated()
            appState.isAuthenticated = true
        } catch {
            appState.isAuthenticated = false
            if let appError = error as? AppError {
                switch appError {
                case .authExpired:
                    appState.needsReauth = true
                case .networkUnavailable:
                    appState.isOnline = false
                default:
                    break
                }
            }
        }
    }
}

final class CheckInNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    @MainActor private let appState: AppState

    @MainActor init(appState: AppState) {
        self.appState = appState
        super.init()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        if response.notification.request.identifier == CheckInNotificationService.checkInIdentifier {
            await MainActor.run {
                appState.pendingCheckIn = true
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner]
    }
}
