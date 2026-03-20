import Testing
import SwiftUI
@testable import sprinty

@Suite("themeFor — palette selection by context and color scheme")
struct ThemeForTests {
    @Test("Home + light returns homeLight palette")
    func homeLight() {
        let theme = themeFor(context: .home, colorScheme: .light)
        // homeLight backgroundStart is #F4F2EC
        let expected = Color(hex: 0xF4F2EC)
        #expect(colorsMatch(theme.palette.backgroundStart, expected))
    }

    @Test("Home + dark returns homeDark palette")
    func homeDark() {
        let theme = themeFor(context: .home, colorScheme: .dark)
        // homeDark backgroundStart is #181A16
        let expected = Color(hex: 0x181A16)
        #expect(colorsMatch(theme.palette.backgroundStart, expected))
    }

    @Test("Conversation + light returns conversationLight palette")
    func conversationLight() {
        let theme = themeFor(context: .conversation, colorScheme: .light)
        // conversationLight backgroundStart is #F8F5EE
        let expected = Color(hex: 0xF8F5EE)
        #expect(colorsMatch(theme.palette.backgroundStart, expected))
    }

    @Test("Conversation + dark returns conversationDark palette")
    func conversationDark() {
        let theme = themeFor(context: .conversation, colorScheme: .dark)
        // conversationDark backgroundStart is #1C1E18
        let expected = Color(hex: 0x1C1E18)
        #expect(colorsMatch(theme.palette.backgroundStart, expected))
    }

    @Test("Safety override stub returns same theme")
    func safetyOverrideStub() {
        let theme = themeFor(context: .home, colorScheme: .light, safetyLevel: .warmthIncrease)
        let baseline = themeFor(context: .home, colorScheme: .light, safetyLevel: .none)
        // Stub returns self, so palettes should be identical
        #expect(colorsMatch(theme.palette.backgroundStart, baseline.palette.backgroundStart))
    }

    @Test("Pause mode stub returns same theme")
    func pauseModeStub() {
        let theme = themeFor(context: .home, colorScheme: .light, isPaused: true)
        let baseline = themeFor(context: .home, colorScheme: .light, isPaused: false)
        #expect(colorsMatch(theme.palette.backgroundStart, baseline.palette.backgroundStart))
    }

    @Test("Discovery ambient mode returns warmer light palette")
    func test_applyingAmbientMode_discovery_returnsWarmerPalette() {
        let base = themeFor(context: .conversation, colorScheme: .light)
        let discovery = base.applyingAmbientMode(.discovery, colorScheme: .light)

        // Discovery background should differ from base conversation background
        let baseStart = Color(hex: 0xF8F5EE)
        let discoveryStart = Color(hex: 0xFAF4E4)
        #expect(!colorsMatch(discovery.palette.backgroundStart, baseStart))
        #expect(colorsMatch(discovery.palette.backgroundStart, discoveryStart))

        // Text colors should remain unchanged
        #expect(colorsMatch(discovery.palette.textPrimary, base.palette.textPrimary))
    }

    @Test("Discovery ambient mode returns warmer dark palette")
    func test_applyingAmbientMode_discovery_darkMode_returnsWarmerPalette() {
        let base = themeFor(context: .conversation, colorScheme: .dark)
        let discovery = base.applyingAmbientMode(.discovery, colorScheme: .dark)

        // Discovery dark background should match the warm-shifted values
        let discoveryStart = Color(hex: 0x1E1C16)
        let discoveryEnd = Color(hex: 0x1A1812)
        #expect(colorsMatch(discovery.palette.backgroundStart, discoveryStart))
        #expect(colorsMatch(discovery.palette.backgroundEnd, discoveryEnd))

        // Text colors should remain unchanged
        #expect(colorsMatch(discovery.palette.textPrimary, base.palette.textPrimary))
    }

    @Test("Directive ambient mode returns cooler light palette")
    func test_applyingAmbientMode_directive_returnsCoolerPalette() {
        let base = themeFor(context: .conversation, colorScheme: .light)
        let directive = base.applyingAmbientMode(.directive, colorScheme: .light)

        // Directive background should differ from base conversation background (cooler, not warmer)
        let baseStart = Color(hex: 0xF8F5EE)
        let directiveStart = Color(hex: 0xF2F5F8)
        #expect(!colorsMatch(directive.palette.backgroundStart, baseStart))
        #expect(colorsMatch(directive.palette.backgroundStart, directiveStart))
    }

    @Test("Directive ambient mode returns cooler dark palette")
    func test_applyingAmbientMode_directive_darkMode_returnsCoolerPalette() {
        let base = themeFor(context: .conversation, colorScheme: .dark)
        let directive = base.applyingAmbientMode(.directive, colorScheme: .dark)

        // Directive dark background should match the cool-shifted values
        let directiveStart = Color(hex: 0x181C1E)
        let directiveEnd = Color(hex: 0x14181A)
        #expect(colorsMatch(directive.palette.backgroundStart, directiveStart))
        #expect(colorsMatch(directive.palette.backgroundEnd, directiveEnd))

        // Text colors should remain unchanged
        #expect(colorsMatch(directive.palette.textPrimary, base.palette.textPrimary))
    }

    @Test("Directive ambient mode preserves text colors")
    func test_applyingAmbientMode_directive_textColorsUnchanged() {
        let base = themeFor(context: .conversation, colorScheme: .light)
        let directive = base.applyingAmbientMode(.directive, colorScheme: .light)

        #expect(colorsMatch(directive.palette.textPrimary, base.palette.textPrimary))
        #expect(colorsMatch(directive.palette.textSecondary, base.palette.textSecondary))
        #expect(colorsMatch(directive.palette.coachDialogue, base.palette.coachDialogue))
        #expect(colorsMatch(directive.palette.userDialogue, base.palette.userDialogue))
    }

    @Test("Theme includes typography, spacing, and corner radius")
    func themeComponentsPresent() {
        let theme = themeFor(context: .home, colorScheme: .light)
        // Verify components are initialized with expected values
        #expect(theme.typography.coachVoiceLineSpacing == 11)
        #expect(theme.spacing.minTouchTarget == 44)
        #expect(theme.cornerRadius.container == 16)
    }
}

// MARK: - Color Comparison Helper

private func colorsMatch(_ a: Color, _ b: Color, tolerance: CGFloat = 0.01) -> Bool {
    let ac = UIColor(a)
    let bc = UIColor(b)
    var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
    var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
    ac.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
    bc.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
    return abs(ar - br) <= tolerance
        && abs(ag - bg) <= tolerance
        && abs(ab - bb) <= tolerance
        && abs(aa - ba) <= tolerance
}
