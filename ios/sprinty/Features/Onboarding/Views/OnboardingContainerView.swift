import SwiftUI

struct OnboardingContainerView: View {
    @Bindable var viewModel: OnboardingViewModel
    let makeChatService: () -> ChatServiceProtocol

    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var coachingViewModel: CoachingViewModel?

    private var homeTheme: CoachingTheme {
        themeFor(context: .home, colorScheme: colorScheme, safetyLevel: .none, isPaused: false)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [homeTheme.palette.backgroundStart, homeTheme.palette.backgroundEnd],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            switch viewModel.currentStep {
            case .welcome:
                OnboardingWelcomeView {
                    Task {
                        await viewModel.advanceFromWelcome()
                    }
                }

            case .avatarSelection:
                AvatarSelectionView(
                    selectedAvatarId: viewModel.selectedAvatarId,
                    onSelect: { viewModel.selectAvatar($0) },
                    onConfirm: {
                        Task {
                            await viewModel.confirmAvatar()
                        }
                    }
                )
                .transition(reduceMotion ? .identity : .opacity)

            case .coachSelection:
                CoachNamingView(
                    selectedCoachAppearanceId: viewModel.selectedCoachAppearanceId,
                    coachName: viewModel.coachName,
                    onSelectAppearance: { viewModel.selectCoachAppearance($0) },
                    onUpdateName: { viewModel.updateCoachName($0) },
                    onConfirm: {
                        Task {
                            await viewModel.confirmCoach()
                        }
                    }
                )
                .transition(reduceMotion ? .identity : .opacity.animation(.easeInOut(duration: 0.25)))

            case .complete:
                if let coachingViewModel {
                    CoachingView(viewModel: coachingViewModel)
                        .transition(reduceMotion ? .identity : .opacity.animation(.easeInOut(duration: 0.45)))
                } else {
                    Color.clear.onAppear {
                        setupCoachingAndComplete()
                    }
                }
            }
        }
        .environment(\.coachingTheme, homeTheme)
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.4), value: viewModel.currentStep)
        .task {
            await viewModel.resumeFromLastStep()
        }
    }

    private func setupCoachingAndComplete() {
        guard let databaseManager = appState.databaseManager else {
            assertionFailure("databaseManager must be set before reaching onboarding completion")
            return
        }
        let chatService = makeChatService()
        coachingViewModel = CoachingViewModel(
            appState: appState,
            chatService: chatService,
            databaseManager: databaseManager
        )
        Task {
            await viewModel.completeOnboarding()
        }
    }
}
