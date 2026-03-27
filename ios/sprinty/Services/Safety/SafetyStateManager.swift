import Foundation
import Observation

@MainActor
@Observable
final class SafetyStateManager: SafetyStateManagerProtocol {
    var currentLevel: SafetyLevel = .green

    private var turnsAtElevatedLevel: Int = 0
    private var consecutiveGreenCount: Int = 0
    private var activeElevatedLevel: SafetyLevel?

    func processClassification(_ level: SafetyLevel, source: SafetyClassificationSource) -> SafetyLevel {
        // Failsafe bypasses sticky entirely
        if source == .failsafe {
            clearStickyState()
            currentLevel = level
            return level
        }

        // New Orange or Red escalation
        if level == .orange || level == .red {
            activeElevatedLevel = level
            consecutiveGreenCount = 0
            turnsAtElevatedLevel = 0
            currentLevel = level
            return level
        }

        // Green with active sticky
        if level == .green, let elevated = activeElevatedLevel {
            turnsAtElevatedLevel += 1
            consecutiveGreenCount += 1

            if turnsAtElevatedLevel >= 3 || consecutiveGreenCount >= 2 {
                clearStickyState()
                currentLevel = .green
                return .green
            }

            currentLevel = elevated
            return elevated
        }

        // Yellow with active sticky
        if level == .yellow, let elevated = activeElevatedLevel {
            consecutiveGreenCount = 0
            turnsAtElevatedLevel += 1
            currentLevel = elevated
            return elevated
        }

        // No sticky active — return level as-is
        currentLevel = level
        return level
    }

    func resetSession() {
        clearStickyState()
        currentLevel = .green
    }

    private func clearStickyState() {
        turnsAtElevatedLevel = 0
        consecutiveGreenCount = 0
        activeElevatedLevel = nil
    }
}
