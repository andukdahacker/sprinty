import Testing
import Foundation
@testable import sprinty

@Suite("SafetyHandler")
struct SafetyHandlerTests {
    let handler = SafetyHandler()

    // MARK: - classify()

    @Test("Nil server level fails safe to yellow (UX-DR71)")
    func test_classify_nilServerLevel_returnsYellow() {
        let result = handler.classify(serverLevel: nil)
        #expect(result == .yellow)
    }

    @Test("Server level passed through when present")
    func test_classify_serverLevelPresent_passesThrough() {
        #expect(handler.classify(serverLevel: .green) == .green)
        #expect(handler.classify(serverLevel: .yellow) == .yellow)
        #expect(handler.classify(serverLevel: .orange) == .orange)
        #expect(handler.classify(serverLevel: .red) == .red)
    }

    // MARK: - uiState()

    @Test("Green state has no hidden elements and welcoming expression")
    func test_uiState_green() {
        let state = handler.uiState(for: .green)
        #expect(state.level == .green)
        #expect(state.hiddenElements.isEmpty)
        #expect(state.coachExpression == .welcoming)
        #expect(state.notificationBehavior == .normal)
        #expect(state.showCrisisResources == false)
    }

    @Test("Yellow state has gentle expression and no hidden elements")
    func test_uiState_yellow() {
        let state = handler.uiState(for: .yellow)
        #expect(state.level == .yellow)
        #expect(state.hiddenElements.isEmpty)
        #expect(state.coachExpression == .gentle)
        #expect(state.notificationBehavior == .normal)
        #expect(state.showCrisisResources == false)
    }

    @Test("Orange state hides gamification and shows crisis resources")
    func test_uiState_orange() {
        let state = handler.uiState(for: .orange)
        #expect(state.level == .orange)
        #expect(state.hiddenElements.contains(.gamification))
        #expect(state.hiddenElements.contains(.celebrations))
        #expect(state.hiddenElements.contains(.sprintProgress))
        #expect(!state.hiddenElements.contains(.avatarActivity))
        #expect(state.coachExpression == .gentle)
        #expect(state.notificationBehavior == .safetyOnly)
        #expect(state.showCrisisResources == true)
    }

    @Test("Red state hides all elements and shows crisis resources prominently")
    func test_uiState_red() {
        let state = handler.uiState(for: .red)
        #expect(state.level == .red)
        #expect(state.hiddenElements == Set(HiddenElement.allCases))
        #expect(state.coachExpression == .gentle)
        #expect(state.notificationBehavior == .suppressed)
        #expect(state.showCrisisResources == true)
    }

    // MARK: - SafetyThemeOverride mapping

    @Test("SafetyLevel maps to correct SafetyThemeOverride")
    func test_safetyThemeOverrideMapping() {
        let mappings: [(SafetyLevel, SafetyThemeOverride)] = [
            (.green, .none),
            (.yellow, .warmthIncrease),
            (.orange, .noticeableDesaturation),
            (.red, .significantDesaturation),
        ]

        for (level, expectedOverride) in mappings {
            let state = handler.uiState(for: level)
            let override: SafetyThemeOverride = switch state.level {
            case .green: .none
            case .yellow: .warmthIncrease
            case .orange: .noticeableDesaturation
            case .red: .significantDesaturation
            }
            #expect(override == expectedOverride)
        }
    }
}
