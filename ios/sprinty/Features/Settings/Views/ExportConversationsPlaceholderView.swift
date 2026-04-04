import SwiftUI

struct ExportConversationsPlaceholderView: View {
    @Environment(\.coachingTheme) private var theme

    var body: some View {
        GeometryReader { geometry in
            let margin = theme.spacing.screenMargin(for: geometry.size.width)

            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                    Text("Export Conversations")
                        .sectionHeadingStyle()
                        .foregroundStyle(theme.palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    Text("This feature is on its way. You'll be able to export your conversations soon so you can keep a personal copy of your coaching journey.")
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
        .navigationTitle("Export Conversations")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview("Light") {
    NavigationStack {
        ExportConversationsPlaceholderView()
    }
}

#Preview("Dark") {
    NavigationStack {
        ExportConversationsPlaceholderView()
    }
    .preferredColorScheme(.dark)
}
#endif
