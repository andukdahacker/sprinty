import SwiftUI

struct OnboardingWelcomeView: View {
    let onAdvance: () -> Void

    @Environment(\.coachingTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: theme.spacing.dialogueTurn) {
            Spacer()

            VStack(spacing: 8) {
                Text("sprinty")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(theme.palette.textPrimary)
                    .accessibilityLabel("sprinty — your personal coach")

                Text("your personal coach")
                    .homeGreetingStyle()
                    .foregroundStyle(theme.palette.textSecondary)
            }
            .opacity(reduceMotion ? 1 : (appeared ? 1 : 0))
            .scaleEffect(reduceMotion ? 1 : (appeared ? 1 : 0.9))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentColumn()
        .task {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 0.4)) {
                    appeared = true
                }
            }

            do {
                try await Task.sleep(for: .seconds(3))
                if !Task.isCancelled {
                    onAdvance()
                }
            } catch {
                // Task cancelled — view dismissed
            }
        }
    }
}

#Preview {
    OnboardingWelcomeView(onAdvance: {})
        .background(
            LinearGradient(
                colors: [ColorPalette.homeLight.backgroundStart, ColorPalette.homeLight.backgroundEnd],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
}
