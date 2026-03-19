import SwiftUI

// MARK: - Experience Context

enum ExperienceContext: Sendable {
    case home
    case conversation
}

// MARK: - Safety Theme Override

enum SafetyThemeOverride: Sendable {
    case none                    // Green
    case warmthIncrease          // Yellow
    case noticeableDesaturation  // Orange
    case significantDesaturation // Red
}

// MARK: - Coaching Theme

struct CoachingTheme: Sendable {
    let palette: ColorPalette
    let typography: TypographyScale
    let spacing: SpacingScale
    let cornerRadius: RadiusTokens

    func applying(safetyOverride: SafetyThemeOverride) -> CoachingTheme {
        self // Stub — Story 6.2 fills in
    }

    func applyingPauseMode() -> CoachingTheme {
        self // Stub — Story 7.1 fills in
    }

    func applyingAmbientMode(_ mode: CoachingMode, colorScheme: ColorScheme = .light) -> CoachingTheme {
        switch mode {
        case .discovery:
            let (start, end) = ColorPalette.discoveryBackgroundColors(for: colorScheme)
            let shifted = palette.discoveryWarmShift(backgroundStart: start, backgroundEnd: end)
            return CoachingTheme(palette: shifted, typography: typography, spacing: spacing, cornerRadius: cornerRadius)
        case .directive:
            return self // Stub — Story 2.2 fills in
        }
    }
}

// MARK: - Environment Key

private struct CoachingThemeKey: EnvironmentKey {
    static let defaultValue = CoachingTheme(
        palette: .homeLight,
        typography: TypographyScale(),
        spacing: SpacingScale(),
        cornerRadius: RadiusTokens()
    )
}

extension EnvironmentValues {
    var coachingTheme: CoachingTheme {
        get { self[CoachingThemeKey.self] }
        set { self[CoachingThemeKey.self] = newValue }
    }
}

// MARK: - Theme Selection

func themeFor(
    context: ExperienceContext,
    colorScheme: ColorScheme,
    safetyLevel: SafetyThemeOverride = .none,
    isPaused: Bool = false
) -> CoachingTheme {
    let palette: ColorPalette
    switch (context, colorScheme) {
    case (.home, .light):
        palette = .homeLight
    case (.home, .dark):
        palette = .homeDark
    case (.conversation, .light):
        palette = .conversationLight
    case (.conversation, .dark):
        palette = .conversationDark
    @unknown default:
        palette = .homeLight
    }

    var theme = CoachingTheme(
        palette: palette,
        typography: TypographyScale(),
        spacing: SpacingScale(),
        cornerRadius: RadiusTokens()
    )

    theme = theme.applying(safetyOverride: safetyLevel)

    if isPaused {
        theme = theme.applyingPauseMode()
    }

    return theme
}
