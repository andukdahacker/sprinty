import SwiftUI

struct TypographyScale: Sendable {
    // Dialogue text — 1.65 line height
    let coachVoiceFont: Font = .body
    let coachVoiceWeight: Font.Weight = .regular
    let coachVoiceLineSpacing: CGFloat = 11 // 17pt body × 0.65

    let userVoiceFont: Font = .body
    let userVoiceWeight: Font.Weight = .regular
    let userVoiceLineSpacing: CGFloat = 11

    let coachVoiceEmphasisFont: Font = .body
    let coachVoiceEmphasisWeight: Font.Weight = .semibold
    let coachVoiceEmphasisLineSpacing: CGFloat = 11

    // Insight text — 1.5 line height
    let insightTextFont: Font = .subheadline
    let insightTextWeight: Font.Weight = .regular
    let insightTextLineSpacing: CGFloat = 7 // ~14pt × 0.5

    // Sprint label — 1.4 line height
    let sprintLabelFont: Font = .footnote
    let sprintLabelWeight: Font.Weight = .medium
    let sprintLabelLineSpacing: CGFloat = 5 // ~13pt × 0.4

    // Coach identity
    let coachNameFont: Font = .footnote
    let coachNameWeight: Font.Weight = .semibold
    let coachNameLineSpacing: CGFloat = 4 // ~13pt × 0.3

    let coachStatusFont: Font = .caption2
    let coachStatusWeight: Font.Weight = .regular
    let coachStatusLineSpacing: CGFloat = 3 // ~11pt × 0.3

    // Date separator
    let dateSeparatorFont: Font = .caption2
    let dateSeparatorWeight: Font.Weight = .regular
    let dateSeparatorLineSpacing: CGFloat = 3

    // Home
    let homeGreetingFont: Font = .caption
    let homeGreetingWeight: Font.Weight = .regular
    let homeGreetingLineSpacing: CGFloat = 5 // ~12pt × 0.4

    let homeTitleFont: Font = .title3
    let homeTitleWeight: Font.Weight = .semibold
    let homeTitleLineSpacing: CGFloat = 6 // ~20pt × 0.3

    // Section heading
    let sectionHeadingFont: Font = .title3
    let sectionHeadingWeight: Font.Weight = .semibold
    let sectionHeadingLineSpacing: CGFloat = 6

    // Button
    let primaryButtonFont: Font = .callout
    let primaryButtonWeight: Font.Weight = .semibold
    let primaryButtonLineSpacing: CGFloat = 0 // 1.0 line height
}

// MARK: - View Extension Modifiers

extension View {
    func coachVoiceStyle() -> some View {
        let scale = TypographyScale()
        return self
            .font(scale.coachVoiceFont.weight(scale.coachVoiceWeight))
            .lineSpacing(scale.coachVoiceLineSpacing)
    }

    func userVoiceStyle() -> some View {
        let scale = TypographyScale()
        return self
            .font(scale.userVoiceFont.weight(scale.userVoiceWeight))
            .lineSpacing(scale.userVoiceLineSpacing)
    }

    func coachVoiceEmphasisStyle() -> some View {
        let scale = TypographyScale()
        return self
            .font(scale.coachVoiceEmphasisFont.weight(scale.coachVoiceEmphasisWeight))
            .lineSpacing(scale.coachVoiceEmphasisLineSpacing)
    }

    func insightTextStyle() -> some View {
        let scale = TypographyScale()
        return self
            .font(scale.insightTextFont.weight(scale.insightTextWeight))
            .lineSpacing(scale.insightTextLineSpacing)
    }

    func sprintLabelStyle() -> some View {
        let scale = TypographyScale()
        return self
            .font(scale.sprintLabelFont.weight(scale.sprintLabelWeight))
            .lineSpacing(scale.sprintLabelLineSpacing)
    }

    func coachNameStyle() -> some View {
        let scale = TypographyScale()
        return self
            .font(scale.coachNameFont.weight(scale.coachNameWeight))
            .lineSpacing(scale.coachNameLineSpacing)
    }

    func coachStatusStyle() -> some View {
        let scale = TypographyScale()
        return self
            .font(scale.coachStatusFont.weight(scale.coachStatusWeight))
            .lineSpacing(scale.coachStatusLineSpacing)
    }

    func dateSeparatorStyle() -> some View {
        let scale = TypographyScale()
        return self
            .font(scale.dateSeparatorFont.weight(scale.dateSeparatorWeight))
            .lineSpacing(scale.dateSeparatorLineSpacing)
    }

    func homeGreetingStyle() -> some View {
        let scale = TypographyScale()
        return self
            .font(scale.homeGreetingFont.weight(scale.homeGreetingWeight))
            .lineSpacing(scale.homeGreetingLineSpacing)
    }

    func homeTitleStyle() -> some View {
        let scale = TypographyScale()
        return self
            .font(scale.homeTitleFont.weight(scale.homeTitleWeight))
            .lineSpacing(scale.homeTitleLineSpacing)
    }

    func sectionHeadingStyle() -> some View {
        let scale = TypographyScale()
        return self
            .font(scale.sectionHeadingFont.weight(scale.sectionHeadingWeight))
            .lineSpacing(scale.sectionHeadingLineSpacing)
    }

    func primaryButtonStyle() -> some View {
        let scale = TypographyScale()
        return self
            .font(scale.primaryButtonFont.weight(scale.primaryButtonWeight))
            .lineSpacing(scale.primaryButtonLineSpacing)
    }
}
