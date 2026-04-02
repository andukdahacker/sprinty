import StoreKit
import SwiftUI
import UserNotifications

@main
struct SprintyApp: App {
    @State private var appState = AppState()
    @State private var notificationDelegate: NotificationDelegate?
    @State private var authService: AuthService?
    @State private var subscriptionService: SubscriptionService?
    @State private var transactionListenerTask: Task<Void, Never>?

    @Environment(\.colorScheme) private var colorScheme

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(\.coachingTheme, themeFor(context: .home, colorScheme: colorScheme))
                .task {
                    let delegate = NotificationDelegate(appState: appState)
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
            let auth = AuthService(apiClient: apiClient)
            authService = auth
            try await auth.ensureAuthenticated()
            appState.isAuthenticated = true

            // Parse tier from JWT
            if let tierString = auth.tierFromCurrentToken(),
               let tier = Tier(rawValue: tierString) {
                appState.tier = tier
            }

            // Wire up subscription service and start transaction listener
            let subService = SubscriptionService(authService: auth) { [appState] in
                let tierString = auth.tierFromCurrentToken()
                await MainActor.run {
                    if let tierString, let tier = Tier(rawValue: tierString) {
                        appState.tier = tier
                    }
                }
            }
            subscriptionService = subService
            transactionListenerTask = Task {
                await subService.listenForTransactionUpdates()
            }
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

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    @MainActor private let appState: AppState

    @MainActor init(appState: AppState) {
        self.appState = appState
        super.init()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let identifier = response.notification.request.identifier
        if identifier == NotificationType.checkIn.identifier {
            await MainActor.run {
                appState.pendingCheckIn = true
                appState.pendingEngagementSource = .checkInNotification
            }
        } else if identifier == NotificationType.reEngagement.identifier {
            await MainActor.run {
                appState.pendingEngagementSource = .reEngagementNudge
            }
        } else if identifier == NotificationType.sprintMilestone.identifier {
            await MainActor.run {
                appState.pendingEngagementSource = .milestoneNotification
            }
        } else if identifier == NotificationType.pauseSuggestion.identifier {
            await MainActor.run {
                appState.pendingEngagementSource = .pauseSuggestionNotification
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
