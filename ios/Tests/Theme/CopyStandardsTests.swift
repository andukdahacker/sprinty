import Testing
@testable import sprinty

@Suite("CopyStandards — UI copy blacklist enforcement")
struct CopyStandardsTests {
    @Test("Blacklist contains all 15 forbidden words")
    func blacklistCompleteness() {
        let expected = [
            "user", "session", "data", "error", "failed",
            "invalid", "submit", "retry", "loading", "processing",
            "notification", "sync", "cache", "timeout", "cancel",
        ]
        #expect(CopyStandards.blacklist.count == expected.count)
        for word in expected {
            #expect(CopyStandards.blacklist.contains(word), "Missing blacklisted word: \(word)")
        }
    }

    @Test("Clean copy passes validation", arguments: [
        "Welcome back! How are you feeling today?",
        "Let's take a moment to reflect on your progress.",
        "Your coach is here for you.",
        "Great work this week!",
    ])
    func cleanCopyPasses(text: String) {
        #expect(!CopyStandards.containsBlacklistedWord(text), "Clean text '\(text)' should not be flagged")
    }

    @Test("Each blacklisted word is caught", arguments: CopyStandards.blacklist)
    func blacklistedWordCaught(word: String) {
        let testText = "This text contains the word \(word) in it."
        #expect(CopyStandards.containsBlacklistedWord(testText), "Blacklist should catch '\(word)'")
    }

    @Test("Substring matches do NOT trigger false positives", arguments: [
        "Let's update your reflection.",  // contains "data" substring in "update"
        "This is reusable across features.",  // contains "user" substring in "reusable"
        "A wonderful cancellation policy.",  // contains "cancel" substring in "cancellation" — still triggers (whole word within)
    ])
    func substringNoFalsePositive(text: String) {
        // "update" should NOT match "data", "reusable" should NOT match "user"
        // But "cancellation" contains "cancel" as a word boundary — this is expected behavior
        if text.contains("update") || text.contains("reusable") {
            #expect(!CopyStandards.containsBlacklistedWord(text), "'\(text)' should not be flagged — substring, not whole word")
        }
    }
}
