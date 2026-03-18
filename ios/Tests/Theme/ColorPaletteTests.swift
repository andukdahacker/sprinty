import Testing
import SwiftUI
import UIKit
@testable import ai_life_coach

// MARK: - UIColor Helper

private extension Color {
    var components: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    var hexValue: UInt {
        let c = components
        let r = UInt(round(c.red * 255))
        let g = UInt(round(c.green * 255))
        let b = UInt(round(c.blue * 255))
        return (r << 16) | (g << 8) | b
    }
}

/// Compute relative luminance per WCAG 2.1
private func relativeLuminance(_ color: Color) -> Double {
    let c = color.components
    func linearize(_ v: CGFloat) -> Double {
        let d = Double(v)
        return d <= 0.03928 ? d / 12.92 : pow((d + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * linearize(c.red) + 0.7152 * linearize(c.green) + 0.0722 * linearize(c.blue)
}

/// Compute contrast ratio per WCAG 2.1
private func contrastRatio(_ fg: Color, _ bg: Color) -> Double {
    let l1 = relativeLuminance(fg)
    let l2 = relativeLuminance(bg)
    let lighter = max(l1, l2)
    let darker = min(l1, l2)
    return (lighter + 0.05) / (darker + 0.05)
}

// MARK: - Palette Token Access Tests

@Suite("ColorPalette — All tokens accessible")
struct ColorPaletteTokenTests {
    @Test("Home Light has all tokens")
    func homeLightAllTokens() {
        let p = ColorPalette.homeLight
        _ = p.backgroundStart
        _ = p.backgroundEnd
        _ = p.textPrimary
        _ = p.textSecondary
        _ = p.avatarGlow
        _ = p.avatarGradientStart
        _ = p.avatarGradientEnd
        _ = p.insightBackground
        _ = p.sprintTrack
        _ = p.sprintProgressStart
        _ = p.sprintProgressEnd
        _ = p.primaryActionStart
        _ = p.primaryActionEnd
        _ = p.primaryActionText
        _ = p.coachDialogue
        _ = p.userDialogue
        _ = p.userAccent
        _ = p.coachPortraitGradientStart
        _ = p.coachPortraitGradientEnd
        _ = p.coachPortraitGlow
        _ = p.coachNameText
        _ = p.coachStatusText
        _ = p.dateSeparator
        _ = p.inputBorder
        _ = p.sendButton
    }

    @Test("Home Dark has all tokens")
    func homeDarkAllTokens() {
        let p = ColorPalette.homeDark
        _ = p.backgroundStart
        _ = p.backgroundEnd
        _ = p.textPrimary
        _ = p.textSecondary
        _ = p.avatarGlow
        _ = p.avatarGradientStart
        _ = p.avatarGradientEnd
        _ = p.insightBackground
        _ = p.sprintTrack
        _ = p.sprintProgressStart
        _ = p.sprintProgressEnd
        _ = p.primaryActionStart
        _ = p.primaryActionEnd
        _ = p.primaryActionText
        _ = p.coachDialogue
        _ = p.userDialogue
        _ = p.userAccent
        _ = p.coachPortraitGradientStart
        _ = p.coachPortraitGradientEnd
        _ = p.coachPortraitGlow
        _ = p.coachNameText
        _ = p.coachStatusText
        _ = p.dateSeparator
        _ = p.inputBorder
        _ = p.sendButton
    }

    @Test("Conversation Light has all tokens")
    func conversationLightAllTokens() {
        let p = ColorPalette.conversationLight
        _ = p.backgroundStart
        _ = p.backgroundEnd
        _ = p.textPrimary
        _ = p.textSecondary
        _ = p.avatarGlow
        _ = p.avatarGradientStart
        _ = p.avatarGradientEnd
        _ = p.insightBackground
        _ = p.sprintTrack
        _ = p.sprintProgressStart
        _ = p.sprintProgressEnd
        _ = p.primaryActionStart
        _ = p.primaryActionEnd
        _ = p.primaryActionText
        _ = p.coachDialogue
        _ = p.userDialogue
        _ = p.userAccent
        _ = p.coachPortraitGradientStart
        _ = p.coachPortraitGradientEnd
        _ = p.coachPortraitGlow
        _ = p.coachNameText
        _ = p.coachStatusText
        _ = p.dateSeparator
        _ = p.inputBorder
        _ = p.sendButton
    }

    @Test("Conversation Dark has all tokens")
    func conversationDarkAllTokens() {
        let p = ColorPalette.conversationDark
        _ = p.backgroundStart
        _ = p.backgroundEnd
        _ = p.textPrimary
        _ = p.textSecondary
        _ = p.avatarGlow
        _ = p.avatarGradientStart
        _ = p.avatarGradientEnd
        _ = p.insightBackground
        _ = p.sprintTrack
        _ = p.sprintProgressStart
        _ = p.sprintProgressEnd
        _ = p.primaryActionStart
        _ = p.primaryActionEnd
        _ = p.primaryActionText
        _ = p.coachDialogue
        _ = p.userDialogue
        _ = p.userAccent
        _ = p.coachPortraitGradientStart
        _ = p.coachPortraitGradientEnd
        _ = p.coachPortraitGlow
        _ = p.coachNameText
        _ = p.coachStatusText
        _ = p.dateSeparator
        _ = p.inputBorder
        _ = p.sendButton
    }
}

// MARK: - Coach Dialogue Never Pure White

@Suite("ColorPalette — Dark conversation coach dialogue")
struct CoachDialogueTests {
    @Test("Conversation dark coachDialogue is NOT pure white")
    func conversationDarkCoachDialogueNotPureWhite() {
        let c = ColorPalette.conversationDark.coachDialogue.components
        let isPureWhite = c.red >= 0.99 && c.green >= 0.99 && c.blue >= 0.99
        #expect(!isPureWhite, "coachDialogue must be warm off-white (#C4C4B4), never pure white")
    }

    @Test("Conversation dark coachDialogue matches #C4C4B4")
    func conversationDarkCoachDialogueValue() {
        let hex = ColorPalette.conversationDark.coachDialogue.hexValue
        #expect(hex == 0xC4C4B4, "Expected #C4C4B4 but got \(String(hex, radix: 16))")
    }
}

// MARK: - Contrast Ratio Tests

@Suite("ColorPalette — WCAG AA contrast compliance")
struct ContrastTests {
    // Body text: 4.5:1 minimum
    @Test("Home Light body text contrast >= 4.5:1")
    func homeLightBodyTextContrast() {
        let ratio = contrastRatio(
            ColorPalette.homeLight.textPrimary,
            ColorPalette.homeLight.backgroundStart
        )
        #expect(ratio >= 4.5, "Home Light text contrast \(ratio) < 4.5:1")
    }

    @Test("Home Dark body text contrast >= 4.5:1")
    func homeDarkBodyTextContrast() {
        let ratio = contrastRatio(
            ColorPalette.homeDark.textPrimary,
            ColorPalette.homeDark.backgroundStart
        )
        #expect(ratio >= 4.5, "Home Dark text contrast \(ratio) < 4.5:1")
    }

    @Test("Conversation Light coachDialogue contrast >= 4.5:1")
    func conversationLightDialogueContrast() {
        let ratio = contrastRatio(
            ColorPalette.conversationLight.coachDialogue,
            ColorPalette.conversationLight.backgroundStart
        )
        #expect(ratio >= 4.5, "Conversation Light dialogue contrast \(ratio) < 4.5:1")
    }

    @Test("Conversation Dark coachDialogue contrast >= 4.5:1")
    func conversationDarkDialogueContrast() {
        let ratio = contrastRatio(
            ColorPalette.conversationDark.coachDialogue,
            ColorPalette.conversationDark.backgroundStart
        )
        #expect(ratio >= 4.5, "Conversation Dark dialogue contrast \(ratio) < 4.5:1")
    }

    // Non-text UI elements: 3:1 minimum
    @Test("Home Light sendButton contrast >= 3:1")
    func homeLightSendButtonContrast() {
        let ratio = contrastRatio(
            ColorPalette.homeLight.sendButton,
            ColorPalette.homeLight.backgroundStart
        )
        #expect(ratio >= 3.0, "Home Light sendButton contrast \(ratio) < 3:1")
    }

    @Test("Conversation Light sendButton contrast >= 3:1")
    func conversationLightSendButtonContrast() {
        let ratio = contrastRatio(
            ColorPalette.conversationLight.sendButton,
            ColorPalette.conversationLight.backgroundStart
        )
        #expect(ratio >= 3.0, "Conversation Light sendButton contrast \(ratio) < 3:1")
    }

    @Test("Home Dark sendButton contrast >= 3:1")
    func homeDarkSendButtonContrast() {
        let ratio = contrastRatio(
            ColorPalette.homeDark.sendButton,
            ColorPalette.homeDark.backgroundStart
        )
        #expect(ratio >= 3.0, "Home Dark sendButton contrast \(ratio) < 3:1")
    }

    @Test("Conversation Dark sendButton contrast >= 3:1")
    func conversationDarkSendButtonContrast() {
        let ratio = contrastRatio(
            ColorPalette.conversationDark.sendButton,
            ColorPalette.conversationDark.backgroundStart
        )
        #expect(ratio >= 3.0, "Conversation Dark sendButton contrast \(ratio) < 3:1")
    }

    // Non-text: userAccent border — 3:1 minimum (AC9)
    @Test("Home Light userAccent contrast >= 3:1")
    func homeLightUserAccentContrast() {
        let ratio = contrastRatio(
            ColorPalette.homeLight.userAccent,
            ColorPalette.homeLight.backgroundStart
        )
        #expect(ratio >= 3.0, "Home Light userAccent contrast \(ratio) < 3:1")
    }

    @Test("Conversation Light userAccent contrast >= 3:1")
    func conversationLightUserAccentContrast() {
        let ratio = contrastRatio(
            ColorPalette.conversationLight.userAccent,
            ColorPalette.conversationLight.backgroundStart
        )
        #expect(ratio >= 3.0, "Conversation Light userAccent contrast \(ratio) < 3:1")
    }

    // Non-text: sprintProgress bar — 3:1 minimum (AC9)
    @Test("Home Light sprintProgress contrast >= 3:1")
    func homeLightSprintProgressContrast() {
        let ratio = contrastRatio(
            ColorPalette.homeLight.sprintProgressStart,
            ColorPalette.homeLight.backgroundStart
        )
        #expect(ratio >= 3.0, "Home Light sprintProgress contrast \(ratio) < 3:1")
    }

    @Test("Home Dark sprintProgress contrast >= 3:1")
    func homeDarkSprintProgressContrast() {
        let ratio = contrastRatio(
            ColorPalette.homeDark.sprintProgressStart,
            ColorPalette.homeDark.backgroundStart
        )
        #expect(ratio >= 3.0, "Home Dark sprintProgress contrast \(ratio) < 3:1")
    }
}
