import SwiftUI

struct HomeView: View {
    let viewModel: HomeViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onTalkToCoach: () -> Void
    var onOpenSettings: (() -> Void)?

    private var homeTheme: CoachingTheme {
        themeFor(context: .home, colorScheme: colorScheme)
    }

    var body: some View {
        GeometryReader { geometry in
            let margin = homeTheme.spacing.screenMargin(for: geometry.size.width)
            let avatarSize: CGFloat = geometry.size.width <= 375 ? 56 : 64

            VStack(spacing: 0) {
                // Stage 1: Avatar + Greeting
                HStack(alignment: .center, spacing: homeTheme.spacing.homeElement) {
                    AvatarView(avatarId: viewModel.avatarId, size: avatarSize)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.greeting)
                            .homeTitleStyle()
                            .foregroundStyle(homeTheme.palette.textPrimary)

                        Text(viewModel.timeOfDayGreeting)
                            .homeGreetingStyle()
                            .foregroundStyle(homeTheme.palette.textSecondary)
                    }

                    Spacer()

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

                // Stage 2 (future): Insight card — hidden until >= 1 completed conversation
                // Stage 3 (future): Sprint progress — hidden until active sprint exists

                Spacer()

                // Primary action
                CoachActionButton(action: onTalkToCoach)
                    .padding(.horizontal, margin)
                    .padding(.bottom, homeTheme.spacing.sectionGap)
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
        }
        .environment(\.coachingTheme, homeTheme)
        .task {
            await viewModel.load()
        }
    }
}

#if DEBUG
#Preview("Light") {
    HomeView(viewModel: .preview()) {}
        .environment(AppState())
}

#Preview("Dark") {
    HomeView(viewModel: .preview()) {}
        .environment(AppState())
        .preferredColorScheme(.dark)
}

#Preview("SE 375pt") {
    HomeView(viewModel: .preview()) {}
        .environment(AppState())
        .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
}

#Preview("Pro Max 430pt") {
    HomeView(viewModel: .preview()) {}
        .environment(AppState())
        .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro Max"))
}
#endif
