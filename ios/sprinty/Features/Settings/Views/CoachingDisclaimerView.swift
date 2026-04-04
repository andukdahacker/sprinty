import SwiftUI

struct CoachingDisclaimerView: View {
    @Environment(\.coachingTheme) private var theme

    var body: some View {
        GeometryReader { geometry in
            let margin = theme.spacing.screenMargin(for: geometry.size.width)

            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                    Text("What Sprinty Is")
                        .sectionHeadingStyle()
                        .foregroundStyle(theme.palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    Text("Sprinty is an AI coaching companion designed to help you grow, set goals, and reflect on what matters to you. Think of it as a thoughtful partner for your personal development journey — someone who listens, asks good questions, and helps you move forward.")
                        .font(theme.typography.insightTextFont)
                        .foregroundStyle(theme.palette.textSecondary)
                        .lineSpacing(theme.typography.insightTextLineSpacing)

                    Text("What Sprinty Is Not")
                        .sectionHeadingStyle()
                        .foregroundStyle(theme.palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    Text("Sprinty is not a therapist, doctor, or licensed counselor. It doesn't provide medical advice, diagnose conditions, or replace professional mental health support. If you're going through a crisis or need urgent help, please reach out to a qualified professional or contact a crisis helpline.")
                        .font(theme.typography.insightTextFont)
                        .foregroundStyle(theme.palette.textSecondary)
                        .lineSpacing(theme.typography.insightTextLineSpacing)

                    Text("How Coaching Works")
                        .sectionHeadingStyle()
                        .foregroundStyle(theme.palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    Text("Your coach learns from your conversations to become more helpful over time. It remembers your goals, values, and what you've shared so it can offer relevant guidance. Coaching is about growth, self-reflection, and taking meaningful steps — at your own pace.")
                        .font(theme.typography.insightTextFont)
                        .foregroundStyle(theme.palette.textSecondary)
                        .lineSpacing(theme.typography.insightTextLineSpacing)
                }
                .padding(.horizontal, margin)
                .padding(.top, theme.spacing.sectionGap)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [theme.palette.backgroundStart, theme.palette.backgroundEnd],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
        .navigationTitle("Coaching Disclaimer")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview("Light") {
    NavigationStack {
        CoachingDisclaimerView()
    }
}

#Preview("Dark") {
    NavigationStack {
        CoachingDisclaimerView()
    }
    .preferredColorScheme(.dark)
}
#endif
