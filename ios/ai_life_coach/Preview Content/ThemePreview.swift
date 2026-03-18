#if DEBUG
import SwiftUI

// MARK: - Four-Palette Preview Helper

struct ThemePreviewer<Content: View>: View {
    let content: (CoachingTheme) -> Content

    init(@ViewBuilder content: @escaping (CoachingTheme) -> Content) {
        self.content = content
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                paletteSection("Home Light", theme: themeFor(context: .home, colorScheme: .light))
                    .environment(\.colorScheme, .light)
                paletteSection("Home Dark", theme: themeFor(context: .home, colorScheme: .dark))
                    .environment(\.colorScheme, .dark)
                paletteSection("Conversation Light", theme: themeFor(context: .conversation, colorScheme: .light))
                    .environment(\.colorScheme, .light)
                paletteSection("Conversation Dark", theme: themeFor(context: .conversation, colorScheme: .dark))
                    .environment(\.colorScheme, .dark)
            }
            .padding()
        }
    }

    @ViewBuilder
    private func paletteSection(_ label: String, theme: CoachingTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.headline)
            content(theme)
                .environment(\.coachingTheme, theme)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [theme.palette.backgroundStart, theme.palette.backgroundEnd],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Theme Showcase

struct ThemeShowcaseView: View {
    var body: some View {
        ThemePreviewer { theme in
            VStack(alignment: .leading, spacing: 12) {
                // Color swatches
                colorRow(theme)

                // Typography samples
                typographyRow(theme)

                // Spacing samples
                spacingRow(theme)
            }
        }
    }

    @ViewBuilder
    private func colorRow(_ theme: CoachingTheme) -> some View {
        HStack(spacing: 4) {
            swatch(theme.palette.textPrimary, label: "Primary")
            swatch(theme.palette.textSecondary, label: "Secondary")
            swatch(theme.palette.sendButton, label: "Action")
            swatch(theme.palette.avatarGradientStart, label: "Avatar")
        }
    }

    @ViewBuilder
    private func swatch(_ color: Color, label: String) -> some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 40, height: 40)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func typographyRow(_ theme: CoachingTheme) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Coach voice sample")
                .coachVoiceStyle()
                .foregroundStyle(theme.palette.coachDialogue)
            Text("User voice sample")
                .userVoiceStyle()
                .foregroundStyle(theme.palette.userDialogue)
            Text("Insight text")
                .insightTextStyle()
                .foregroundStyle(theme.palette.textSecondary)
        }
    }

    @ViewBuilder
    private func spacingRow(_ theme: CoachingTheme) -> some View {
        HStack(spacing: theme.spacing.dialogueBreath) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: theme.cornerRadius.small)
                    .fill(theme.palette.insightBackground)
                    .frame(height: 20)
            }
        }
    }
}

#Preview("Theme Showcase") {
    ThemeShowcaseView()
}
#endif
