import SwiftUI
import OSLog

struct RootView: View {
    @Environment(AppState.self) private var appState
    @State private var homeViewModel: HomeViewModel?
    @State private var coachingViewModel: CoachingViewModel?
    @State private var onboardingViewModel: OnboardingViewModel?
    @State private var onboardingChecked = false
    @State private var showConversation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if appState.isAuthenticated, let databaseManager = appState.databaseManager {
            if !onboardingChecked {
                Color.clear.task {
                    await checkOnboardingState(databaseManager: databaseManager)
                }
            } else if !appState.onboardingCompleted {
                onboardingView(databaseManager: databaseManager)
            } else {
                authenticatedView(databaseManager: databaseManager)
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

    @ViewBuilder
    private func authenticatedView(databaseManager: DatabaseManager) -> some View {
        if let homeViewModel {
            ZStack {
                HomeView(viewModel: homeViewModel) {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.45)) {
                        ensureCoachingViewModel(databaseManager: databaseManager)
                        showConversation = true
                    }
                }
                .opacity(showConversation ? 0 : 1)
                .offset(y: showConversation ? -20 : 0)

                if showConversation, let coachingViewModel {
                    CoachingView(viewModel: coachingViewModel)
                        .transition(.opacity)
                        .overlay(alignment: .topLeading) {
                            Button {
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                                    showConversation = false
                                }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .frame(width: 44, height: 44)
                            }
                            .padding(.leading, 8)
                            .padding(.top, 4)
                            .accessibilityLabel("Back to home")
                        }
                }
            }
        } else {
            Color.clear.onAppear {
                homeViewModel = HomeViewModel(
                    appState: appState,
                    databaseManager: databaseManager
                )
            }
        }
    }

    private func ensureCoachingViewModel(databaseManager: DatabaseManager) {
        guard coachingViewModel == nil else { return }
        let chatService = makeChatService()
        let embeddingPipeline = makeEmbeddingPipeline(databaseManager: databaseManager)
        let profileUpdateService = ProfileUpdateService(databaseManager: databaseManager)
        let profileEnricher = ProfileEnricher(databaseManager: databaseManager)
        coachingViewModel = CoachingViewModel(
            appState: appState,
            chatService: chatService,
            databaseManager: databaseManager,
            embeddingPipeline: embeddingPipeline,
            profileUpdateService: profileUpdateService,
            profileEnricher: profileEnricher
        )
    }

    private func makeEmbeddingPipeline(databaseManager: DatabaseManager) -> EmbeddingPipelineProtocol? {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "sprinty", category: "memory")

        guard let modelURL = Bundle.main.url(forResource: "MiniLM", withExtension: "mlmodelc") ?? Bundle.main.url(forResource: "MiniLM", withExtension: "mlpackage"),
              let vocabURL = Bundle.main.url(forResource: "vocab", withExtension: "txt")
        else {
            logger.warning("Core ML model or vocab not found — embedding pipeline disabled")
            return nil
        }

        do {
            let embeddingService = try EmbeddingService(modelURL: modelURL, vocabURL: vocabURL)

            guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.ducdo.sprinty") else {
                logger.warning("App Group container not available — embedding pipeline disabled")
                return nil
            }

            let vectorDBPath = containerURL.appendingPathComponent("sprinty-vectors.sqlite").path
            let vectorSearch = try VectorSearch(path: vectorDBPath)
            try vectorSearch.createTable()

            return EmbeddingPipeline(
                embeddingService: embeddingService,
                vectorSearch: vectorSearch,
                databaseManager: databaseManager
            )
        } catch {
            logger.error("Failed to initialize embedding pipeline: \(error)")
            return nil
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
    func streamChat(messages: [ChatRequestMessage], mode: String, profile: ChatProfile?, userState: UserState? = nil, ragContext: String? = nil) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: AppError.networkUnavailable)
        }
    }

    func summarize(messages: [ChatRequestMessage]) async throws -> SummaryResponse {
        throw AppError.networkUnavailable
    }
}
