import Testing
import Foundation
import SwiftUI
@testable import sprinty

@Suite("CoachingTheme Safety Transformations")
struct CoachingThemeSafetyTests {

    private func makeTheme(palette: ColorPalette) -> CoachingTheme {
        CoachingTheme(
            palette: palette,
            typography: TypographyScale(),
            spacing: SpacingScale(),
            cornerRadius: RadiusTokens()
        )
    }

    // MARK: - .none returns identical palette

    @Test(".none override returns identical palette")
    func test_noneOverride_identicalPalette() {
        let theme = makeTheme(palette: .homeLight)
        let result = theme.applying(safetyOverride: .none)

        // Verify multiple key colors are identical (guard returns self)
        func assertSameHSB(_ a: Color, _ b: Color, label: String) {
            let aHSB = a.hsbComponents
            let bHSB = b.hsbComponents
            #expect(abs(aHSB.hue - bHSB.hue) < 0.001, "\(label) hue mismatch")
            #expect(abs(aHSB.saturation - bHSB.saturation) < 0.001, "\(label) saturation mismatch")
            #expect(abs(aHSB.brightness - bHSB.brightness) < 0.001, "\(label) brightness mismatch")
        }
        assertSameHSB(theme.palette.backgroundStart, result.palette.backgroundStart, label: "backgroundStart")
        assertSameHSB(theme.palette.sendButton, result.palette.sendButton, label: "sendButton")
        assertSameHSB(theme.palette.textPrimary, result.palette.textPrimary, label: "textPrimary")
        assertSameHSB(theme.palette.avatarGlow, result.palette.avatarGlow, label: "avatarGlow")
    }

    // MARK: - warmthIncrease (Yellow)

    @Test(".warmthIncrease produces warmer, slightly less saturated colors")
    func test_warmthIncrease_warmerLessSaturated() {
        let theme = makeTheme(palette: .conversationLight)
        let result = theme.applying(safetyOverride: .warmthIncrease)

        // Saturation should decrease slightly
        let originalSat = theme.palette.sendButton.hsbComponents.saturation
        let resultSat = result.palette.sendButton.hsbComponents.saturation
        #expect(resultSat < originalSat)

        // Change should be subtle (not more than 20% reduction)
        let reductionFactor = 1.0 - (resultSat / max(originalSat, 0.001))
        #expect(reductionFactor < 0.20)
    }

    // MARK: - noticeableDesaturation (Orange)

    @Test(".noticeableDesaturation produces visibly desaturated colors")
    func test_noticeableDesaturation_visible() {
        let theme = makeTheme(palette: .conversationLight)
        let result = theme.applying(safetyOverride: .noticeableDesaturation)

        let originalSat = theme.palette.sendButton.hsbComponents.saturation
        let resultSat = result.palette.sendButton.hsbComponents.saturation
        #expect(resultSat < originalSat)

        // Reduction should be noticeable (at least 30%)
        let reductionFactor = 1.0 - (resultSat / max(originalSat, 0.001))
        #expect(reductionFactor > 0.30)
    }

    // MARK: - significantDesaturation (Red)

    @Test(".significantDesaturation produces near-monochrome warm colors")
    func test_significantDesaturation_nearMonochrome() {
        let theme = makeTheme(palette: .conversationLight)
        let result = theme.applying(safetyOverride: .significantDesaturation)

        let originalSat = theme.palette.sendButton.hsbComponents.saturation
        let resultSat = result.palette.sendButton.hsbComponents.saturation
        #expect(resultSat < originalSat)

        // Reduction should be very significant (at least 60%)
        let reductionFactor = 1.0 - (resultSat / max(originalSat, 0.001))
        #expect(reductionFactor > 0.60)
    }

    // MARK: - All 4 base palettes

    @Test("Transformations work on homeLight palette")
    func test_homeLight_transforms() {
        verifyAllTransformations(palette: .homeLight)
    }

    @Test("Transformations work on homeDark palette")
    func test_homeDark_transforms() {
        verifyAllTransformations(palette: .homeDark)
    }

    @Test("Transformations work on conversationLight palette")
    func test_conversationLight_transforms() {
        verifyAllTransformations(palette: .conversationLight)
    }

    @Test("Transformations work on conversationDark palette")
    func test_conversationDark_transforms() {
        verifyAllTransformations(palette: .conversationDark)
    }

    private func verifyAllTransformations(palette: ColorPalette) {
        let theme = makeTheme(palette: palette)

        // Each override level should produce a different palette from the original
        let yellow = theme.applying(safetyOverride: .warmthIncrease)
        let orange = theme.applying(safetyOverride: .noticeableDesaturation)
        let red = theme.applying(safetyOverride: .significantDesaturation)

        // sendButton is a reliably saturated color across all palettes
        let originalSat = theme.palette.sendButton.hsbComponents.saturation
        let yellowSat = yellow.palette.sendButton.hsbComponents.saturation
        let orangeSat = orange.palette.sendButton.hsbComponents.saturation
        let redSat = red.palette.sendButton.hsbComponents.saturation

        // Each level should be progressively more desaturated
        // (only check if original has measurable saturation)
        if originalSat > 0.05 {
            #expect(yellowSat <= originalSat)
            #expect(orangeSat < yellowSat)
            #expect(redSat < orangeSat)
        }
    }

    // MARK: - Dark mode warm grays

    @Test("Dark mode desaturation produces warm grays, not cold grays")
    func test_darkMode_warmGrays() {
        let theme = makeTheme(palette: .homeDark)
        let red = theme.applying(safetyOverride: .significantDesaturation)

        // Background should have warm hue (amber range ~0.05-0.15) after transformation
        let bgHSB = red.palette.backgroundStart.hsbComponents
        // Warm hue is in the amber/orange range (0.0-0.2)
        // Cold gray would have no hue influence or a blue hue (~0.6)
        if bgHSB.saturation > 0.01 {
            #expect(bgHSB.hue < 0.3 || bgHSB.hue > 0.9) // Warm side of the spectrum
        }
    }

    // MARK: - Safety-wins-all (Task 7.5)

    @Test("Ambient mode shifts produce different result than safety-only theme")
    func test_safetyWinsAll_ambientDiffersFromSafety() {
        // When safety is active, CoachingView skips ambient mode shifts.
        // Verify that applying ambient on top of safety WOULD change the palette,
        // proving the suppression in CoachingView is load-bearing.
        let safetyTheme = themeFor(context: .conversation, colorScheme: .light, safetyLevel: .warmthIncrease)
        let withAmbient = safetyTheme.applyingAmbientMode(.discovery, colorScheme: .light)

        let safetyBg = safetyTheme.palette.backgroundStart.hsbComponents
        let ambientBg = withAmbient.palette.backgroundStart.hsbComponents

        // Ambient replaces backgrounds, so they must differ — confirming suppression matters
        let hueDiff = abs(safetyBg.hue - ambientBg.hue)
        let satDiff = abs(safetyBg.saturation - ambientBg.saturation)
        let briDiff = abs(safetyBg.brightness - ambientBg.brightness)
        #expect(hueDiff > 0.001 || satDiff > 0.001 || briDiff > 0.001)
    }

    @Test("Challenger shift produces different result than safety-only theme")
    func test_safetyWinsAll_challengerDiffersFromSafety() {
        let safetyTheme = themeFor(context: .conversation, colorScheme: .light, safetyLevel: .noticeableDesaturation)
        let withChallenger = safetyTheme.applyingChallengerShift(colorScheme: .light)

        let safetyBg = safetyTheme.palette.backgroundStart.hsbComponents
        let challengerBg = withChallenger.palette.backgroundStart.hsbComponents

        let hueDiff = abs(safetyBg.hue - challengerBg.hue)
        let satDiff = abs(safetyBg.saturation - challengerBg.saturation)
        let briDiff = abs(safetyBg.brightness - challengerBg.brightness)
        #expect(hueDiff > 0.001 || satDiff > 0.001 || briDiff > 0.001)
    }
}
