import SwiftUI

struct HomeView: View {
    let viewModel: HomeViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onTalkToCoach: () -> Void
    var onOpenSettings: (() -> Void)?
    var onOpenSprintDetail: (() -> Void)?
    var onOpenCheckIn: (() -> Void)?

    private var homeTheme: CoachingTheme {
        themeFor(context: .home, colorScheme: colorScheme, isPaused: viewModel.homeStage == .paused)
    }

    var body: some View {
        GeometryReader { geometry in
            let margin = homeTheme.spacing.screenMargin(for: geometry.size.width)
            let avatarSize: CGFloat = geometry.size.width <= 375 ? 56 : 64

            VStack(spacing: 0) {
                // Greeting + Avatar
                HStack(alignment: .center, spacing: homeTheme.spacing.homeElement) {
                    AvatarView(avatarId: viewModel.avatarId, size: avatarSize, state: viewModel.avatarState)
                        .accessibilitySortPriority(4)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.greeting)
                            .homeTitleStyle()
                            .foregroundStyle(homeTheme.palette.textPrimary)

                        Text(viewModel.timeOfDayGreeting)
                            .homeGreetingStyle()
                            .foregroundStyle(homeTheme.palette.textSecondary)
                    }
                    .accessibilitySortPriority(5)

                    Spacer()

                    Button {
                        viewModel.togglePause()
                    } label: {
                        Image(systemName: viewModel.homeStage == .paused ? "play.circle" : "pause.circle")
                            .font(.title3)
                            .foregroundStyle(homeTheme.palette.textSecondary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(viewModel.homeStage == .paused ? "Resume coaching" : "Pause coaching")

                    if let onOpenSettings {
                        Button {
                            onOpenSettings()
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.title3)
                                .foregroundStyle(homeTheme.palette.textSecondary)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Settings")
                    }
                }
                .padding(.horizontal, margin)
                .padding(.top, homeTheme.spacing.sectionGap)

                // Stage-dependent content
                Group {
                    if viewModel.homeStage == .welcome {
                        HomeEmptyStateView()
                            .padding(.top, homeTheme.spacing.homeElement)
                            .transition(.opacity)
                    }

                    if let insightText = viewModel.insightDisplayText,
                       viewModel.homeStage != .welcome {
                        InsightCardView(content: insightText)
                            .padding(.top, homeTheme.spacing.homeElement)
                            .transition(.opacity)
                            .accessibilitySortPriority(3)
                    }

                    if viewModel.homeStage == .sprintActive || (viewModel.homeStage == .paused && viewModel.hasActiveSprint) {
                        Button {
                            onOpenSprintDetail?()
                        } label: {
                            SprintProgressView(
                                progress: viewModel.sprintProgress,
                                currentStep: viewModel.sprintCurrentStep,
                                totalSteps: viewModel.sprintTotalSteps,
                                isMuted: viewModel.homeStage == .paused,
                                sprintName: viewModel.sprintName,
                                dayNumber: viewModel.sprintDayNumber,
                                totalDays: viewModel.sprintTotalDays
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.homeStage == .paused)
                        .padding(.top, homeTheme.spacing.homeElement)
                        .transition(.opacity)
                        .accessibilitySortPriority(2)
                    }

                    if let checkIn = viewModel.latestCheckIn,
                       (viewModel.homeStage == .sprintActive || viewModel.homeStage == .paused) {
                        CheckInSummaryView(summary: checkIn)
                            .padding(.top, homeTheme.spacing.homeElement)
                            .transition(.opacity)
                    } else if viewModel.latestCheckIn == nil,
                              viewModel.homeStage == .sprintActive {
                        Button {
                            onOpenCheckIn?()
                        } label: {
                            Label("Check in", systemImage: "bubble.left")
                                .font(homeTheme.typography.insightTextFont)
                        }
                        .buttonStyle(.bordered)
                        .tint(homeTheme.palette.primaryActionStart)
                        .padding(.top, homeTheme.spacing.homeElement)
                        .transition(.opacity)
                        .accessibilityLabel("Check in with your coach")
                    }
                }
                .padding(.horizontal, margin)
                .animation(reduceMotion ? .none : .easeInOut(duration: 0.2), value: viewModel.homeStage)

                Spacer()

                // Primary action — always visible, stays fully saturated even in Pause
                CoachActionButton(action: onTalkToCoach)
                    .saturation(viewModel.homeStage == .paused ? 1 / 0.7 : 1.0)
                    .padding(.horizontal, margin)
                    .padding(.bottom, homeTheme.spacing.sectionGap)
                    .accessibilitySortPriority(1)
            }
            .contentColumn()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [homeTheme.palette.backgroundStart, homeTheme.palette.backgroundEnd],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .saturation(viewModel.homeStage == .paused ? 0.7 : 1.0)
            .animation(
                reduceMotion ? .none : .easeInOut(duration: viewModel.homeStage == .paused ? 1.2 : 0.6),
                value: viewModel.homeStage == .paused
            )
        }
        .environment(\.coachingTheme, homeTheme)
        .task {
            await viewModel.load()
        }
    }
}

#if DEBUG
#Preview("Stage 1: Welcome") {
    HomeView(viewModel: .preview()) {}
        .environment(AppState())
}

#Preview("Stage 2: Insight Unlocked") {
    HomeView(
        viewModel: .preview(
            completedConversationCount: 3,
            latestInsight: "You've been making great progress on career goals this week."
        )
    ) {}
        .environment(AppState())
}

#Preview("Stage 3: Sprint Active") {
    HomeView(
        viewModel: .preview(
            completedConversationCount: 5,
            latestInsight: "Your reflection on work-life balance showed real depth.",
            hasActiveSprint: true,
            sprintProgress: 0.4,
            sprintCurrentStep: 2,
            sprintTotalSteps: 5,
            sprintName: "Career Growth",
            sprintDayNumber: 3,
            sprintTotalDays: 7
        )
    ) {}
        .environment(AppState())
}

#Preview("Stage 4: Paused") {
    let appState = AppState()
    appState.isPaused = true
    return HomeView(
        viewModel: .preview(
            completedConversationCount: 5,
            latestInsight: "Ignored in pause",
            hasActiveSprint: true,
            sprintProgress: 0.4,
            sprintCurrentStep: 2,
            sprintTotalSteps: 5,
            sprintName: "Career Growth",
            sprintDayNumber: 3,
            sprintTotalDays: 7,
            isPaused: true
        )
    ) {}
        .environment(appState)
}

#Preview("Sprint Tappable") {
    HomeView(
        viewModel: .preview(
            completedConversationCount: 5,
            latestInsight: "Your reflection showed real depth.",
            hasActiveSprint: true,
            sprintProgress: 0.4,
            sprintCurrentStep: 2,
            sprintTotalSteps: 5,
            sprintName: "Career Growth",
            sprintDayNumber: 3,
            sprintTotalDays: 7
        ),
        onTalkToCoach: {},
        onOpenSprintDetail: { }
    )
    .environment(AppState())
}

#Preview("Dark") {
    HomeView(
        viewModel: .preview(
            completedConversationCount: 2,
            latestInsight: "Your coach noticed a pattern in how you approach challenges."
        )
    ) {}
        .environment(AppState())
        .preferredColorScheme(.dark)
}
#endif
