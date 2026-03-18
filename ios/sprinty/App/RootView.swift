import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: CoachingViewModel?
    @State private var onboardingViewModel: OnboardingViewModel?
    @State private var onboardingChecked = false

    var body: some View {
        if appState.isAuthenticated, let databaseManager = appState.databaseManager {
            if !onboardingChecked {
                Color.clear.task {
                    await checkOnboardingState(databaseManager: databaseManager)
                }
            } else if !appState.onboardingCompleted {
                onboardingView(databaseManager: databaseManager)
            } else if let viewModel {
                CoachingView(viewModel: viewModel)
            } else {
                Color.clear.onAppear {
                    let chatService = makeChatService()
                    viewModel = CoachingViewModel(
                        appState: appState,
                        chatService: chatService,
                        databaseManager: databaseManager
                    )
                }
            }
        } else if appState.needsReauth {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text("Re-authentication needed")
                    .font(.headline)
            }
        } else if !appState.isOnline {
            VStack(spacing: 16) {
                Image(systemName: "wifi.slash")
                    .font(.largeTitle)
                    .foregroundStyle(.red)
                Text("No connection")
                    .font(.headline)
            }
        } else {
            VStack(spacing: 16) {
                ProgressView()
                Text("Connecting...")
                    .font(.headline)
            }
        }
    }

    private func checkOnboardingState(databaseManager: DatabaseManager) async {
        do {
            let profile = try await databaseManager.dbPool.read { db in
                try UserProfile.current().fetchOne(db)
            }
            if let profile, profile.onboardingCompleted {
                appState.onboardingCompleted = true
            }
        } catch {
            // No profile or error — treat as not onboarded
        }
        onboardingChecked = true
    }

    @ViewBuilder
    private func onboardingView(databaseManager: DatabaseManager) -> some View {
        if let onboardingViewModel {
            OnboardingContainerView(
                viewModel: onboardingViewModel,
                makeChatService: makeChatService
            )
        } else {
            Color.clear.onAppear {
                onboardingViewModel = OnboardingViewModel(
                    appState: appState,
                    databaseManager: databaseManager
                )
            }
        }
    }

    private func makeChatService() -> ChatServiceProtocol {
        let urlString = Bundle.main.infoDictionary?["COACH_API_URL"] as? String ?? "http://localhost:8080"
        guard let baseURL = URL(string: urlString) else {
            return FailingChatService()
        }
        let apiClient = APIClient(baseURL: baseURL)
        let authService = AuthService(apiClient: apiClient)
        return ChatService(baseURL: baseURL, authService: authService)
    }
}

private struct FailingChatService: ChatServiceProtocol {
    func streamChat(messages: [ChatRequestMessage], mode: String, profile: ChatProfile?) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: AppError.networkUnavailable)
        }
    }
}
