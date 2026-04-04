import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.coachingTheme) private var theme

    var body: some View {
        GeometryReader { geometry in
            let margin = theme.spacing.screenMargin(for: geometry.size.width)

            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                    Text("Using Sprinty")
                        .sectionHeadingStyle()
                        .foregroundStyle(theme.palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    Text("Sprinty is designed for people aged 17 and older. By using the app, you agree to use it respectfully and for its intended purpose — personal growth and self-reflection coaching.")
                        .font(theme.typography.insightTextFont)
                        .foregroundStyle(theme.palette.textSecondary)
                        .lineSpacing(theme.typography.insightTextLineSpacing)

                    Text("What You Can Expect")
                        .sectionHeadingStyle()
                        .foregroundStyle(theme.palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    Text("We do our best to make Sprinty helpful, reliable, and available. That said, AI coaching has limitations — it may not always understand your situation perfectly, and it's not a substitute for professional advice. We're always improving, and your patience and feedback help us get better.")
                        .font(theme.typography.insightTextFont)
                        .foregroundStyle(theme.palette.textSecondary)
                        .lineSpacing(theme.typography.insightTextLineSpacing)

                    Text("Your Rights")
                        .sectionHeadingStyle()
                        .foregroundStyle(theme.palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    Text("You have full control over your data. You can export your conversations, delete everything, or stop using the app at any time. We believe your coaching journey belongs to you.")
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
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview("Light") {
    NavigationStack {
        TermsOfServiceView()
    }
}

#Preview("Dark") {
    NavigationStack {
        TermsOfServiceView()
    }
    .preferredColorScheme(.dark)
}
#endif
