import SwiftUI

@main
struct SprintyApp: App {
    @State private var appState = AppState()

    @Environment(\.colorScheme) private var colorScheme

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(\.coachingTheme, themeFor(context: .home, colorScheme: colorScheme))
                .task {
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
