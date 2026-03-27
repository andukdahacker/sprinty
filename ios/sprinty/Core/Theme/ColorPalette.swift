import SwiftUI

// MARK: - Color Hex Initializer

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

// MARK: - Color Palette

struct ColorPalette: Sendable {
    // Background gradient
    let backgroundStart: Color
    let backgroundEnd: Color

    // Primary text
    let textPrimary: Color
    let textSecondary: Color

    // Avatar
    let avatarGlow: Color
    let avatarGradientStart: Color
    let avatarGradientEnd: Color

    // Insight card
    let insightBackground: Color

    // Sprint
    let sprintTrack: Color
    let sprintProgressStart: Color
    let sprintProgressEnd: Color

    // Primary action button
    let primaryActionStart: Color
    let primaryActionEnd: Color
    let primaryActionText: Color

    // Coaching conversation
    let coachDialogue: Color
    let userDialogue: Color
    let userAccent: Color
    let coachPortraitGradientStart: Color
    let coachPortraitGradientEnd: Color
    let coachPortraitGlow: Color
    let coachNameText: Color
    let coachStatusText: Color
    let dateSeparator: Color
    let inputBorder: Color
    let sendButton: Color
}

// MARK: - Home Light Palette (AC2)

extension ColorPalette {
    static let homeLight = ColorPalette(
        // Home Light: warm restful tones
        backgroundStart: Color(hex: 0xF4F2EC),
        backgroundEnd: Color(hex: 0xEDE8E0),
        textPrimary: Color(hex: 0x3A3A30),
        textSecondary: Color(hex: 0x8B8B78),
        avatarGlow: Color(hex: 0x8B9B7A, opacity: 0.30),
        avatarGradientStart: Color(hex: 0xC4D4B0),
        avatarGradientEnd: Color(hex: 0x8B9B7A),
        insightBackground: Color(hex: 0x8B9B7A, opacity: 0.10),
        sprintTrack: Color(hex: 0x8B9B7A, opacity: 0.12),
        sprintProgressStart: Color(hex: 0x748465), // Adjusted from #8B9B7A for WCAG 3:1 non-text contrast (AC9)
        sprintProgressEnd: Color(hex: 0x7A8B6B),
        primaryActionStart: Color(hex: 0x7A8B6B),
        primaryActionEnd: Color(hex: 0x6B7A5A),
        primaryActionText: Color.white,
        // Conversation tokens — mapped to home equivalents
        coachDialogue: Color(hex: 0x3A3A30),
        userDialogue: Color(hex: 0x3A3A30),
        userAccent: Color(hex: 0x748465), // Adjusted from #8B9B7A for WCAG 3:1 non-text contrast (AC9)
        coachPortraitGradientStart: Color(hex: 0xC4D4B0),
        coachPortraitGradientEnd: Color(hex: 0x8B9B7A),
        coachPortraitGlow: Color(hex: 0x8B9B7A, opacity: 0.25),
        coachNameText: Color(hex: 0x3A3A30),
        coachStatusText: Color(hex: 0x8B8B78),
        dateSeparator: Color(hex: 0x3A3A30, opacity: 0.35),
        inputBorder: Color(hex: 0x788264, opacity: 0.20),
        sendButton: Color(hex: 0x7A8B6B)
    )
}

// MARK: - Home Dark Palette (AC3)

extension ColorPalette {
    static let homeDark = ColorPalette(
        // Home Dark: warm dark tones, never cold/technical
        backgroundStart: Color(hex: 0x181A16),
        backgroundEnd: Color(hex: 0x141612),
        textPrimary: Color(hex: 0xD8D8C8),
        textSecondary: Color(hex: 0x6B7A5A),
        avatarGlow: Color(hex: 0x8B9B7A, opacity: 0.20),
        avatarGradientStart: Color(hex: 0x2A3020),
        avatarGradientEnd: Color(hex: 0x3A4830),
        insightBackground: Color(hex: 0x8B9B7A, opacity: 0.06),
        sprintTrack: Color(hex: 0x8B9B7A, opacity: 0.08),
        sprintProgressStart: Color(hex: 0x8B9B7A),
        sprintProgressEnd: Color(hex: 0x7A8B6B),
        primaryActionStart: Color(hex: 0x4A5A3A),
        primaryActionEnd: Color(hex: 0x3E4E30),
        primaryActionText: Color(hex: 0xD0D8C0),
        // Conversation tokens — mapped to home dark equivalents
        coachDialogue: Color(hex: 0xD8D8C8),
        userDialogue: Color(hex: 0xD8D8C8),
        userAccent: Color(hex: 0x8B9B7A, opacity: 0.30),
        coachPortraitGradientStart: Color(hex: 0x2A3020),
        coachPortraitGradientEnd: Color(hex: 0x3A4830),
        coachPortraitGlow: Color(hex: 0x8B9B7A, opacity: 0.10),
        coachNameText: Color(hex: 0xD8D8C8),
        coachStatusText: Color(hex: 0x6B7A5A),
        dateSeparator: Color(hex: 0xD8D8C8, opacity: 0.35),
        inputBorder: Color(hex: 0x788264, opacity: 0.12),
        sendButton: Color(hex: 0x607252) // Adjusted from #4A5A3A for WCAG 3:1 contrast (AC9)
    )
}

// MARK: - Conversation Light Palette (AC4)

extension ColorPalette {
    static let conversationLight = ColorPalette(
        // Conversation Light
        backgroundStart: Color(hex: 0xF8F5EE),
        backgroundEnd: Color(hex: 0xF0ECE2),
        // Home tokens — mapped to conversation equivalents
        textPrimary: Color(hex: 0x3A3A30),
        textSecondary: Color(hex: 0x8B8B78),
        avatarGlow: Color(hex: 0x8B9B7A, opacity: 0.25),
        avatarGradientStart: Color(hex: 0xB8C8A0),
        avatarGradientEnd: Color(hex: 0x8B9B7A),
        insightBackground: Color(hex: 0x8B9B7A, opacity: 0.10),
        sprintTrack: Color(hex: 0x8B9B7A, opacity: 0.12),
        sprintProgressStart: Color(hex: 0x748465), // Adjusted from #8B9B7A for WCAG 3:1 non-text contrast (AC9)
        sprintProgressEnd: Color(hex: 0x7A8B6B),
        primaryActionStart: Color(hex: 0x7A8B6B),
        primaryActionEnd: Color(hex: 0x6B7A5A),
        primaryActionText: Color.white,
        // Conversation Light tokens
        coachDialogue: Color(hex: 0x3A3A30),
        userDialogue: Color(hex: 0x4A4A3C),
        userAccent: Color(hex: 0x748465), // Adjusted from #8B9B7A for WCAG 3:1 non-text contrast (AC9)
        coachPortraitGradientStart: Color(hex: 0xB8C8A0),
        coachPortraitGradientEnd: Color(hex: 0x8B9B7A),
        coachPortraitGlow: Color(hex: 0x8B9B7A, opacity: 0.25),
        coachNameText: Color(hex: 0x3A3A30),
        coachStatusText: Color(hex: 0x8B8B78),
        dateSeparator: Color(hex: 0x3A3A30, opacity: 0.35),
        inputBorder: Color(hex: 0x788264, opacity: 0.20),
        sendButton: Color(hex: 0x7A8B6B)
    )
}

// MARK: - Conversation Dark Palette (AC5)

extension ColorPalette {
    static let conversationDark = ColorPalette(
        // Conversation Dark
        backgroundStart: Color(hex: 0x1C1E18),
        backgroundEnd: Color(hex: 0x181A14),
        // Home tokens — mapped to conversation dark equivalents
        textPrimary: Color(hex: 0xC4C4B4),
        textSecondary: Color(hex: 0x6B7A5A),
        avatarGlow: Color(hex: 0x8B9B7A, opacity: 0.10),
        avatarGradientStart: Color(hex: 0x3A4830),
        avatarGradientEnd: Color(hex: 0x5A6B48),
        insightBackground: Color(hex: 0x8B9B7A, opacity: 0.06),
        sprintTrack: Color(hex: 0x8B9B7A, opacity: 0.08),
        sprintProgressStart: Color(hex: 0x8B9B7A),
        sprintProgressEnd: Color(hex: 0x7A8B6B),
        primaryActionStart: Color(hex: 0x4A5A3A),
        primaryActionEnd: Color(hex: 0x3E4E30),
        primaryActionText: Color(hex: 0xD0D8C0),
        // Conversation Dark tokens — coach dialogue warm off-white, never pure white
        coachDialogue: Color(hex: 0xC4C4B4),
        userDialogue: Color(hex: 0xB0B0A0),
        userAccent: Color(hex: 0x8B9B7A, opacity: 0.30),
        coachPortraitGradientStart: Color(hex: 0x3A4830),
        coachPortraitGradientEnd: Color(hex: 0x5A6B48),
        coachPortraitGlow: Color(hex: 0x8B9B7A, opacity: 0.10),
        coachNameText: Color(hex: 0xD0D0C0),
        coachStatusText: Color(hex: 0x6B7A5A),
        dateSeparator: Color(hex: 0xD0D0C0, opacity: 0.35),
        inputBorder: Color(hex: 0x788264, opacity: 0.12),
        sendButton: Color(hex: 0x607252) // Adjusted from #4A5A3A for WCAG 3:1 contrast (AC9)
    )
}

// MARK: - Safety Override Transformation

extension ColorPalette {
    /// Transforms ALL 25 color properties based on the safety override level.
    /// Unlike ambient mode shifts (which only replace backgrounds), safety transforms
    /// every property to create a cohesive visual environment for the safety state.
    func applying(safetyOverride: SafetyThemeOverride) -> ColorPalette {
        switch safetyOverride {
        case .none:
            return self
        case .warmthIncrease:
            // Yellow: subtle warmth +8%, saturation -12%
            return transformAll(warmthFactor: 0.08, desaturationFactor: 0.12)
        case .noticeableDesaturation:
            // Orange: saturation -45%, slight warmth +5%
            return transformAll(warmthFactor: 0.05, desaturationFactor: 0.45)
        case .significantDesaturation:
            // Red: saturation -75%, warmth +10% for warm monochrome
            return transformAll(warmthFactor: 0.10, desaturationFactor: 0.75)
        }
    }

    private func transformAll(warmthFactor: CGFloat, desaturationFactor: CGFloat) -> ColorPalette {
        func transform(_ color: Color) -> Color {
            color.adjustedSaturation(by: desaturationFactor)
                .adjustedWarmth(by: warmthFactor)
        }

        return ColorPalette(
            backgroundStart: transform(backgroundStart),
            backgroundEnd: transform(backgroundEnd),
            textPrimary: transform(textPrimary),
            textSecondary: transform(textSecondary),
            avatarGlow: transform(avatarGlow),
            avatarGradientStart: transform(avatarGradientStart),
            avatarGradientEnd: transform(avatarGradientEnd),
            insightBackground: transform(insightBackground),
            sprintTrack: transform(sprintTrack),
            sprintProgressStart: transform(sprintProgressStart),
            sprintProgressEnd: transform(sprintProgressEnd),
            primaryActionStart: transform(primaryActionStart),
            primaryActionEnd: transform(primaryActionEnd),
            primaryActionText: transform(primaryActionText),
            coachDialogue: transform(coachDialogue),
            userDialogue: transform(userDialogue),
            userAccent: transform(userAccent),
            coachPortraitGradientStart: transform(coachPortraitGradientStart),
            coachPortraitGradientEnd: transform(coachPortraitGradientEnd),
            coachPortraitGlow: transform(coachPortraitGlow),
            coachNameText: transform(coachNameText),
            coachStatusText: transform(coachStatusText),
            dateSeparator: transform(dateSeparator),
            inputBorder: transform(inputBorder),
            sendButton: transform(sendButton)
        )
    }
}

// MARK: - Discovery Ambient Mode Shift

extension ColorPalette {
    /// Discovery background colors by color scheme.
    /// Light: #FAF4E4 / #F2EBDA — warmer/golden shift from conversation base.
    /// Dark: #1E1C16 / #1A1812 — warmer dark shift from conversation base.
    static func discoveryBackgroundColors(for colorScheme: ColorScheme) -> (start: Color, end: Color) {
        switch colorScheme {
        case .dark:
            return (Color(hex: 0x1E1C16), Color(hex: 0x1A1812))
        default:
            return (Color(hex: 0xFAF4E4), Color(hex: 0xF2EBDA))
        }
    }

    /// Shifts background gradient toward warmer/golden tones for Discovery mode.
    /// Only background gradient changes — all text colors remain unchanged.
    /// Note: If safety override is active, ambient shifts should be suppressed (Story 6.2).
    func discoveryWarmShift(backgroundStart newStart: Color, backgroundEnd newEnd: Color) -> ColorPalette {
        ColorPalette(
            backgroundStart: newStart,
            backgroundEnd: newEnd,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            avatarGlow: avatarGlow,
            avatarGradientStart: avatarGradientStart,
            avatarGradientEnd: avatarGradientEnd,
            insightBackground: insightBackground,
            sprintTrack: sprintTrack,
            sprintProgressStart: sprintProgressStart,
            sprintProgressEnd: sprintProgressEnd,
            primaryActionStart: primaryActionStart,
            primaryActionEnd: primaryActionEnd,
            primaryActionText: primaryActionText,
            coachDialogue: coachDialogue,
            userDialogue: userDialogue,
            userAccent: userAccent,
            coachPortraitGradientStart: coachPortraitGradientStart,
            coachPortraitGradientEnd: coachPortraitGradientEnd,
            coachPortraitGlow: coachPortraitGlow,
            coachNameText: coachNameText,
            coachStatusText: coachStatusText,
            dateSeparator: dateSeparator,
            inputBorder: inputBorder,
            sendButton: sendButton
        )
    }
}

// MARK: - Challenger Ambient Mode Shift

extension ColorPalette {
    /// Challenger background colors by color scheme.
    /// Light: #EDE8E0 / #E4DED4 — deeper earth tones, grounded feel.
    /// Dark: #1A1816 / #161412 — deeper warm dark, grounded feel.
    static func challengerBackgroundColors(for colorScheme: ColorScheme) -> (start: Color, end: Color) {
        switch colorScheme {
        case .dark:
            return (Color(hex: 0x1A1816), Color(hex: 0x161412))
        default:
            return (Color(hex: 0xEDE8E0), Color(hex: 0xE4DED4))
        }
    }

    /// Shifts background gradient toward deeper/grounded tones for Challenger capability.
    /// Only background gradient changes — all text colors remain unchanged.
    func challengerGroundedShift(backgroundStart newStart: Color, backgroundEnd newEnd: Color) -> ColorPalette {
        ColorPalette(
            backgroundStart: newStart,
            backgroundEnd: newEnd,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            avatarGlow: avatarGlow,
            avatarGradientStart: avatarGradientStart,
            avatarGradientEnd: avatarGradientEnd,
            insightBackground: insightBackground,
            sprintTrack: sprintTrack,
            sprintProgressStart: sprintProgressStart,
            sprintProgressEnd: sprintProgressEnd,
            primaryActionStart: primaryActionStart,
            primaryActionEnd: primaryActionEnd,
            primaryActionText: primaryActionText,
            coachDialogue: coachDialogue,
            userDialogue: userDialogue,
            userAccent: userAccent,
            coachPortraitGradientStart: coachPortraitGradientStart,
            coachPortraitGradientEnd: coachPortraitGradientEnd,
            coachPortraitGlow: coachPortraitGlow,
            coachNameText: coachNameText,
            coachStatusText: coachStatusText,
            dateSeparator: dateSeparator,
            inputBorder: inputBorder,
            sendButton: sendButton
        )
    }
}

// MARK: - Directive Ambient Mode Shift

extension ColorPalette {
    /// Directive background colors by color scheme.
    /// Light: #F2F5F8 / #E8ECF0 — cooler/blue-gray shift from conversation base.
    /// Dark: #181C1E / #14181A — cooler dark shift from conversation base.
    /// Note: If safety override is active, ambient shifts should be suppressed (Story 6.2).
    static func directiveBackgroundColors(for colorScheme: ColorScheme) -> (start: Color, end: Color) {
        switch colorScheme {
        case .dark:
            return (Color(hex: 0x181C1E), Color(hex: 0x14181A))
        default:
            return (Color(hex: 0xF2F5F8), Color(hex: 0xE8ECF0))
        }
    }

    /// Shifts background gradient toward cooler/focused tones for Directive mode.
    /// Only background gradient changes — all text colors remain unchanged.
    /// Note: If safety override is active, ambient shifts should be suppressed (Story 6.2).
    func directiveCoolShift(backgroundStart newStart: Color, backgroundEnd newEnd: Color) -> ColorPalette {
        ColorPalette(
            backgroundStart: newStart,
            backgroundEnd: newEnd,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            avatarGlow: avatarGlow,
            avatarGradientStart: avatarGradientStart,
            avatarGradientEnd: avatarGradientEnd,
            insightBackground: insightBackground,
            sprintTrack: sprintTrack,
            sprintProgressStart: sprintProgressStart,
            sprintProgressEnd: sprintProgressEnd,
            primaryActionStart: primaryActionStart,
            primaryActionEnd: primaryActionEnd,
            primaryActionText: primaryActionText,
            coachDialogue: coachDialogue,
            userDialogue: userDialogue,
            userAccent: userAccent,
            coachPortraitGradientStart: coachPortraitGradientStart,
            coachPortraitGradientEnd: coachPortraitGradientEnd,
            coachPortraitGlow: coachPortraitGlow,
            coachNameText: coachNameText,
            coachStatusText: coachStatusText,
            dateSeparator: dateSeparator,
            inputBorder: inputBorder,
            sendButton: sendButton
        )
    }
}
