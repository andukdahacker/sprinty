import SwiftUI

struct DeleteAllDataPlaceholderView: View {
    @Environment(\.coachingTheme) private var theme

    var body: some View {
        GeometryReader { geometry in
            let margin = theme.spacing.screenMargin(for: geometry.size.width)

            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                    Text("Delete All Data")
                        .sectionHeadingStyle()
                        .foregroundStyle(theme.palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    Text("This feature is on its way. Soon you'll be able to delete all your data if you'd like a completely fresh start. Your data, your choice — always.")
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
        .navigationTitle("Delete All Data")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview("Light") {
    NavigationStack {
        DeleteAllDataPlaceholderView()
    }
}

#Preview("Dark") {
    NavigationStack {
        DeleteAllDataPlaceholderView()
    }
    .preferredColorScheme(.dark)
}
#endif
