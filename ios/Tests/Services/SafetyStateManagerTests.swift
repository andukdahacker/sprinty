import Testing
import Foundation
@testable import sprinty

@Suite("SafetyStateManager")
struct SafetyStateManagerTests {

    @MainActor
    private func makeManager() -> SafetyStateManager {
        SafetyStateManager()
    }

    // MARK: - Basic classification passthrough

    @Test("Green returns green when no sticky active")
    @MainActor
    func test_green_noSticky_returnsGreen() {
        let manager = makeManager()
        let result = manager.processClassification(.green, source: .genuine)
        #expect(result == .green)
        #expect(manager.currentLevel == .green)
    }

    @Test("Yellow returns yellow when no sticky active")
    @MainActor
    func test_yellow_noSticky_returnsYellow() {
        let manager = makeManager()
        let result = manager.processClassification(.yellow, source: .genuine)
        #expect(result == .yellow)
        #expect(manager.currentLevel == .yellow)
    }

    @Test("Orange returns orange")
    @MainActor
    func test_orange_returnsOrange() {
        let manager = makeManager()
        let result = manager.processClassification(.orange, source: .genuine)
        #expect(result == .orange)
        #expect(manager.currentLevel == .orange)
    }

    @Test("Red returns red")
    @MainActor
    func test_red_returnsRed() {
        let manager = makeManager()
        let result = manager.processClassification(.red, source: .genuine)
        #expect(result == .red)
        #expect(manager.currentLevel == .red)
    }

    // MARK: - Sticky minimum: consecutive Green×2 releases

    @Test("Green→Orange→Green→Green→Green: Green×2 releases at turn 2")
    @MainActor
    func test_stickyRelease_consecutiveGreen2() {
        let manager = makeManager()

        let r1 = manager.processClassification(.green, source: .genuine)
        #expect(r1 == .green)

        let r2 = manager.processClassification(.orange, source: .genuine)
        #expect(r2 == .orange)

        let r3 = manager.processClassification(.green, source: .genuine)
        #expect(r3 == .orange) // Sticky holds: turn 1, consecutiveGreen=1

        let r4 = manager.processClassification(.green, source: .genuine)
        #expect(r4 == .green) // Released: consecutiveGreen=2

        let r5 = manager.processClassification(.green, source: .genuine)
        #expect(r5 == .green) // Normal
    }

    @Test("Green→Red→Green→Green: Green×2 releases at turn 2")
    @MainActor
    func test_stickyRelease_red_consecutiveGreen2() {
        let manager = makeManager()

        let r1 = manager.processClassification(.green, source: .genuine)
        #expect(r1 == .green)

        let r2 = manager.processClassification(.red, source: .genuine)
        #expect(r2 == .red)

        let r3 = manager.processClassification(.green, source: .genuine)
        #expect(r3 == .red) // Sticky holds: turn 1, consecutiveGreen=1

        let r4 = manager.processClassification(.green, source: .genuine)
        #expect(r4 == .green) // Released: consecutiveGreen=2
    }

    // MARK: - Sticky minimum: Yellow resets consecutiveGreen

    @Test("Green→Orange→Yellow→Green→Green→Green: Yellow resets consecutiveGreen, 3-turn releases")
    @MainActor
    func test_stickyRelease_yellowResetsGreenCount_3turnRelease() {
        let manager = makeManager()

        let r1 = manager.processClassification(.green, source: .genuine)
        #expect(r1 == .green)

        let r2 = manager.processClassification(.orange, source: .genuine)
        #expect(r2 == .orange)

        // Yellow: resets consecutiveGreen to 0, turn 1
        let r3 = manager.processClassification(.yellow, source: .genuine)
        #expect(r3 == .orange) // Sticky holds

        // Green: turn 2, consecutiveGreen=1
        let r4 = manager.processClassification(.green, source: .genuine)
        #expect(r4 == .orange) // Sticky holds (not yet 3 turns or 2 consecutive green)

        // Green: turn 3, turnsAtElevated=3 → releases
        let r5 = manager.processClassification(.green, source: .genuine)
        #expect(r5 == .green) // Released via 3-turn threshold

        let r6 = manager.processClassification(.green, source: .genuine)
        #expect(r6 == .green)
    }

    @Test("Green→Orange→Green→Yellow→Green→Green→Green: Yellow mid-stream resets consecutiveGreen")
    @MainActor
    func test_stickyRelease_yellowMidStream_3turnRelease() {
        let manager = makeManager()

        let r1 = manager.processClassification(.green, source: .genuine)
        #expect(r1 == .green)

        let r2 = manager.processClassification(.orange, source: .genuine)
        #expect(r2 == .orange)

        // Green: turn 1, consecutiveGreen=1
        let r3 = manager.processClassification(.green, source: .genuine)
        #expect(r3 == .orange) // Sticky holds

        // Yellow: turn 2, resets consecutiveGreen to 0
        let r4 = manager.processClassification(.yellow, source: .genuine)
        #expect(r4 == .orange) // Sticky holds

        // Green: turn 3, turnsAtElevated=3 → releases
        let r5 = manager.processClassification(.green, source: .genuine)
        #expect(r5 == .green) // Released via 3-turn threshold

        let r6 = manager.processClassification(.green, source: .genuine)
        #expect(r6 == .green)
    }

    // MARK: - Failsafe source bypasses sticky

    @Test("Orange(failsafe)→Green: no sticky applied")
    @MainActor
    func test_failsafe_noSticky() {
        let manager = makeManager()

        let r1 = manager.processClassification(.orange, source: .failsafe)
        #expect(r1 == .orange)

        let r2 = manager.processClassification(.green, source: .genuine)
        #expect(r2 == .green) // No sticky — failsafe cleared it
    }

    // MARK: - Re-escalation resets counters

    @Test("Orange(genuine)→Orange(genuine)→Green→Green: re-escalation resets turnsAtElevated")
    @MainActor
    func test_reescalation_resetsCounters() {
        let manager = makeManager()

        let r1 = manager.processClassification(.orange, source: .genuine)
        #expect(r1 == .orange)

        // Re-escalation: resets turnsAtElevated to 0
        let r2 = manager.processClassification(.orange, source: .genuine)
        #expect(r2 == .orange)

        // Green: turn 1 (from reset), consecutiveGreen=1
        let r3 = manager.processClassification(.green, source: .genuine)
        #expect(r3 == .orange) // Sticky holds

        // Green: turn 2, consecutiveGreen=2 → releases
        let r4 = manager.processClassification(.green, source: .genuine)
        #expect(r4 == .green) // Released
    }

    // MARK: - Session reset

    @Test("Session reset clears all sticky state")
    @MainActor
    func test_sessionReset_clearsAll() {
        let manager = makeManager()

        _ = manager.processClassification(.red, source: .genuine)
        #expect(manager.currentLevel == .red)

        manager.resetSession()
        #expect(manager.currentLevel == .green)

        // After reset, no sticky should be active
        let r = manager.processClassification(.green, source: .genuine)
        #expect(r == .green)
    }

    // MARK: - Yellow does not trigger sticky

    @Test("Yellow does not trigger sticky minimum")
    @MainActor
    func test_yellow_noStickyTriggered() {
        let manager = makeManager()

        let r1 = manager.processClassification(.yellow, source: .genuine)
        #expect(r1 == .yellow)

        let r2 = manager.processClassification(.green, source: .genuine)
        #expect(r2 == .green) // No sticky — yellow doesn't trigger it
    }
}
