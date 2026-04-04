import SwiftUI

struct PrivacyInformationView: View {
    @Environment(\.coachingTheme) private var theme

    var body: some View {
        GeometryReader { geometry in
            let margin = theme.spacing.screenMargin(for: geometry.size.width)

            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                    Text("Your Data, Your Device")
                        .sectionHeadingStyle()
                        .foregroundStyle(theme.palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    Text("All your conversations, goals, and coaching history stay right here on your phone. Sprinty doesn't upload your personal data to external servers or share it with anyone.")
                        .font(theme.typography.insightTextFont)
                        .foregroundStyle(theme.palette.textSecondary)
                        .lineSpacing(theme.typography.insightTextLineSpacing)

                    Text("During Conversations")
                        .sectionHeadingStyle()
                        .foregroundStyle(theme.palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    Text("When you're actively chatting with your coach, your messages are sent to an AI provider to generate responses. The provider processes your messages in real time but does not store them afterward. Once the conversation is over, only your device keeps the record.")
                        .font(theme.typography.insightTextFont)
                        .foregroundStyle(theme.palette.textSecondary)
                        .lineSpacing(theme.typography.insightTextLineSpacing)

                    Text("You're in Control")
                        .sectionHeadingStyle()
                        .foregroundStyle(theme.palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    Text("You own your data completely. You can export your conversations anytime to keep a personal copy, or delete everything if you'd like a fresh start. There are no hoops to jump through — it's your data and your choice.")
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
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview("Light") {
    NavigationStack {
        PrivacyInformationView()
    }
}

#Preview("Dark") {
    NavigationStack {
        PrivacyInformationView()
    }
    .preferredColorScheme(.dark)
}
#endif
