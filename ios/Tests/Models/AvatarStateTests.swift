import Testing
@testable import sprinty

@Suite("AvatarState")
struct AvatarStateTests {

    // MARK: - Display names

    @Test("Active display name")
    func test_displayName_active() {
        #expect(AvatarState.active.displayName == "Active")
    }

    @Test("Resting display name")
    func test_displayName_resting() {
        #expect(AvatarState.resting.displayName == "Resting")
    }

    @Test("Celebrating display name")
    func test_displayName_celebrating() {
        #expect(AvatarState.celebrating.displayName == "Celebrating")
    }

    @Test("Thinking display name")
    func test_displayName_thinking() {
        #expect(AvatarState.thinking.displayName == "Thinking")
    }

    @Test("Struggling display name")
    func test_displayName_struggling() {
        #expect(AvatarState.struggling.displayName == "Struggling")
    }

    // MARK: - Saturation multipliers

    @Test("Active saturation is 1.0")
    func test_saturation_active() {
        #expect(AvatarState.active.saturationMultiplier == 1.0)
    }

    @Test("Resting saturation is 0.65")
    func test_saturation_resting() {
        #expect(AvatarState.resting.saturationMultiplier == 0.65)
    }

    @Test("Celebrating saturation is 1.15")
    func test_saturation_celebrating() {
        #expect(AvatarState.celebrating.saturationMultiplier == 1.15)
    }

    @Test("Thinking saturation is 0.85")
    func test_saturation_thinking() {
        #expect(AvatarState.thinking.saturationMultiplier == 0.85)
    }

    @Test("Struggling saturation is 0.55")
    func test_saturation_struggling() {
        #expect(AvatarState.struggling.saturationMultiplier == 0.55)
    }

    // MARK: - Derivation

    @Test("Derive returns resting when paused")
    func test_derive_isPaused_resting() {
        #expect(AvatarState.derive(isPaused: true) == .resting)
    }

    @Test("Derive returns active when not paused")
    func test_derive_notPaused_active() {
        #expect(AvatarState.derive(isPaused: false) == .active)
    }

    // MARK: - Enum completeness

    @Test("All five cases exist")
    func test_allCases_countIsFive() {
        #expect(AvatarState.allCases.count == 5)
    }

    @Test("Each case has unique display name")
    func test_displayNames_areUnique() {
        let names = AvatarState.allCases.map(\.displayName)
        #expect(Set(names).count == names.count)
    }

    @Test("Each case has unique saturation")
    func test_saturations_areUnique() {
        let values = AvatarState.allCases.map(\.saturationMultiplier)
        #expect(Set(values).count == values.count)
    }
}
