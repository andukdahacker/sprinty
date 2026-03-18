import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.isAuthenticated, let databaseManager = appState.databaseManager {
            let chatService = makeChatService()
            let viewModel = CoachingViewModel(
                appState: appState,
                chatService: chatService,
                databaseManager: databaseManager
            )
            CoachingView(viewModel: viewModel)
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
    func streamChat(messages: [ChatRequestMessage], mode: String) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: AppError.networkUnavailable)
        }
    }
}
