import Foundation

protocol OnDeviceSafetyClassifierProtocol: Sendable {
    func classify(_ text: String) async -> SafetyLevel?
}

final class OnDeviceSafetyClassifier: OnDeviceSafetyClassifierProtocol, @unchecked Sendable {

    // Crisis-related keywords for iOS 17-25 keyword-based fallback
    private static let crisisKeywords: [String] = [
        "kill myself", "end my life", "want to die", "suicide",
        "self-harm", "self harm", "hurt myself", "cutting myself",
        "don't want to live", "no reason to live", "better off dead",
        "end it all", "take my life", "overdose"
    ]

    private static let warningKeywords: [String] = [
        "hopeless", "can't go on", "give up on everything",
        "no point in living", "wish i was dead", "not worth it anymore"
    ]

    func classify(_ text: String) async -> SafetyLevel? {
        // iOS 26+: Use Apple Foundation Models if available
        if #available(iOS 26, *) {
            if let level = await classifyWithFoundationModels(text) {
                return level
            }
        }

        // Fallback: keyword-based heuristic for all iOS versions
        return classifyWithKeywords(text)
    }

    @available(iOS 26, *)
    private func classifyWithFoundationModels(_ text: String) async -> SafetyLevel? {
        // Foundation Models integration — requires device with Apple Silicon
        // Returns nil if FoundationModels is not available on this device
        // The actual FoundationModels import and LanguageModelSession usage
        // requires iOS 26 SDK; this method will be compiled but only called on iOS 26+
        return nil
    }

    private func classifyWithKeywords(_ text: String) -> SafetyLevel? {
        let lowered = text.lowercased()

        for keyword in Self.crisisKeywords {
            if lowered.contains(keyword) {
                return .red
            }
        }

        for keyword in Self.warningKeywords {
            if lowered.contains(keyword) {
                return .orange
            }
        }

        return nil
    }
}
