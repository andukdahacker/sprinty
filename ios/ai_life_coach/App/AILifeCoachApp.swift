import SwiftUI

@main
struct AILifeCoachApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
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
