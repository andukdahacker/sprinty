import Testing
import SwiftUI
@testable import sprinty

@Suite("SpacingScale — 9 spacing tokens on 8pt grid")
struct SpacingScaleTests {
    private let spacing = SpacingScale()

    @Test("dialogueTurn is 24pt")
    func dialogueTurn() {
        #expect(spacing.dialogueTurn == 24)
    }

    @Test("dialogueBreath is 8pt")
    func dialogueBreath() {
        #expect(spacing.dialogueBreath == 8)
    }

    @Test("homeElement is 16pt")
    func homeElement() {
        #expect(spacing.homeElement == 16)
    }

    @Test("insightPadding is 16pt")
    func insightPadding() {
        #expect(spacing.insightPadding == 16)
    }

    @Test("coachCharacterBottom is 16pt")
    func coachCharacterBottom() {
        #expect(spacing.coachCharacterBottom == 16)
    }

    @Test("inputAreaTop is 12pt")
    func inputAreaTop() {
        #expect(spacing.inputAreaTop == 12)
    }

    @Test("sectionGap is 32pt")
    func sectionGap() {
        #expect(spacing.sectionGap == 32)
    }

    @Test("minTouchTarget is 44pt")
    func minTouchTarget() {
        #expect(spacing.minTouchTarget == 44)
    }

    @Test("SE margin is 16pt when width <= 375")
    func seMargin() {
        #expect(spacing.screenMargin(for: 375) == 16)
        #expect(spacing.screenMargin(for: 320) == 16)
    }

    @Test("Standard margin is 20pt when width > 375")
    func standardMargin() {
        #expect(spacing.screenMargin(for: 390) == 20)
        #expect(spacing.screenMargin(for: 430) == 20)
    }
}

@Suite("RadiusTokens — Corner radii")
struct RadiusTokensTests {
    private let radii = RadiusTokens()

    @Test("container radius is 16pt")
    func container() {
        #expect(radii.container == 16)
    }

    @Test("button radius is 16pt")
    func button() {
        #expect(radii.button == 16)
    }

    @Test("input radius is 20pt (pill)")
    func input() {
        #expect(radii.input == 20)
    }

    @Test("small radius is 8pt")
    func small() {
        #expect(radii.small == 8)
    }

    @Test("sprintTrack radius is 3pt")
    func sprintTrack() {
        #expect(radii.sprintTrack == 3)
    }
}
