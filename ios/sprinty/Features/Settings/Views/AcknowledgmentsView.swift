import SwiftUI

struct AcknowledgmentsView: View {
    @Environment(\.coachingTheme) private var theme

    private let libraries = [
        AcknowledgedLibrary(name: "GRDB.swift", description: "A toolkit for SQLite databases, with a focus on application development."),
        AcknowledgedLibrary(name: "sqlite-vec", description: "A SQLite extension for vector search and embeddings."),
        AcknowledgedLibrary(name: "Lottie", description: "Beautiful animations rendered natively from Adobe After Effects."),
        AcknowledgedLibrary(name: "Sentry", description: "Application monitoring and error tracking.")
    ]

    var body: some View {
        GeometryReader { geometry in
            let margin = theme.spacing.screenMargin(for: geometry.size.width)

            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                    Text("Open Source Libraries")
                        .sectionHeadingStyle()
                        .foregroundStyle(theme.palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    Text("Sprinty is built with the help of these wonderful open-source projects. We're grateful to the developers and communities behind them.")
                        .font(theme.typography.insightTextFont)
                        .foregroundStyle(theme.palette.textSecondary)
                        .lineSpacing(theme.typography.insightTextLineSpacing)

                    ForEach(libraries) { library in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(library.name)
                                .sectionHeadingStyle()
                                .foregroundStyle(theme.palette.textPrimary)

                            Text(library.description)
                                .font(theme.typography.insightTextFont)
                                .foregroundStyle(theme.palette.textSecondary)
                                .lineSpacing(theme.typography.insightTextLineSpacing)
                        }
                        .accessibilityElement(children: .combine)
                    }
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
        .navigationTitle("Acknowledgments")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AcknowledgedLibrary: Identifiable {
    let name: String
    let description: String

    var id: String { name }
}

#if DEBUG
#Preview("Light") {
    NavigationStack {
        AcknowledgmentsView()
    }
}

#Preview("Dark") {
    NavigationStack {
        AcknowledgmentsView()
    }
    .preferredColorScheme(.dark)
}
#endif
