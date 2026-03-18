import Testing
import SwiftUI
@testable import ai_life_coach

@Suite("TypographyScale — 12 semantic text styles")
struct TypographyScaleTests {
    private let scale = TypographyScale()

    @Test("All 12 font tokens produce valid values")
    func allFontTokensValid() {
        // Dialogue
        _ = scale.coachVoiceFont
        _ = scale.userVoiceFont
        _ = scale.coachVoiceEmphasisFont

        // Content
        _ = scale.insightTextFont
        _ = scale.sprintLabelFont

        // Coach identity
        _ = scale.coachNameFont
        _ = scale.coachStatusFont

        // Date
        _ = scale.dateSeparatorFont

        // Home
        _ = scale.homeGreetingFont
        _ = scale.homeTitleFont

        // Section
        _ = scale.sectionHeadingFont

        // Button
        _ = scale.primaryButtonFont
    }

    @Test("coachVoice has 1.65 line height spacing (11pt)")
    func coachVoiceLineSpacing() {
        #expect(scale.coachVoiceLineSpacing == 11)
    }

    @Test("userVoice has 1.65 line height spacing (11pt)")
    func userVoiceLineSpacing() {
        #expect(scale.userVoiceLineSpacing == 11)
    }

    @Test("coachVoiceEmphasis has 1.65 line height spacing (11pt)")
    func coachVoiceEmphasisLineSpacing() {
        #expect(scale.coachVoiceEmphasisLineSpacing == 11)
    }

    @Test("coachVoice uses body font")
    func coachVoiceUsesBody() {
        #expect(scale.coachVoiceFont == .body)
    }

    @Test("userVoice uses body font")
    func userVoiceUsesBody() {
        #expect(scale.userVoiceFont == .body)
    }

    @Test("insightText uses subheadline font")
    func insightTextUsesSubheadline() {
        #expect(scale.insightTextFont == .subheadline)
    }

    @Test("sprintLabel uses footnote font")
    func sprintLabelUsesFootnote() {
        #expect(scale.sprintLabelFont == .footnote)
    }

    @Test("coachName uses footnote font with semibold weight")
    func coachNameFontAndWeight() {
        #expect(scale.coachNameFont == .footnote)
        #expect(scale.coachNameWeight == .semibold)
    }

    @Test("homeTitle uses title3 font")
    func homeTitleUsesTitle3() {
        #expect(scale.homeTitleFont == .title3)
    }

    @Test("primaryButton uses callout font with semibold weight")
    func primaryButtonFontAndWeight() {
        #expect(scale.primaryButtonFont == .callout)
        #expect(scale.primaryButtonWeight == .semibold)
    }

    @Test("primaryButton has 1.0 line height (0pt spacing)")
    func primaryButtonNoLineSpacing() {
        #expect(scale.primaryButtonLineSpacing == 0)
    }
}
