import SwiftUI

struct CoachActionButton: View {
    let action: () -> Void

    @Environment(\.coachingTheme) private var theme

    var body: some View {
        Button(action: action) {
            Text("Talk to your coach")
                .primaryButtonStyle()
                .foregroundStyle(theme.palette.primaryActionText)
                .frame(maxWidth: .infinity)
                .frame(minHeight: theme.spacing.minTouchTarget)
                .background(
                    LinearGradient(
                        colors: [theme.palette.primaryActionStart, theme.palette.primaryActionEnd],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius.button))
        }
        .accessibilityLabel("Talk to your coach")
        .accessibilityHint("Opens your coaching conversation")
    }
}

#Preview("Light") {
    CoachActionButton(action: {})
        .padding()
        .environment(\.coachingTheme, themeFor(context: .home, colorScheme: .light))
}

#Preview("Dark") {
    CoachActionButton(action: {})
        .padding()
        .environment(\.coachingTheme, themeFor(context: .home, colorScheme: .dark))
}
