import Foundation

enum CopyStandards {
    static let blacklist: [String] = [
        "user",
        "session",
        "data",
        "error",
        "failed",
        "invalid",
        "submit",
        "retry",
        "loading",
        "processing",
        "notification",
        "sync",
        "cache",
        "timeout",
        "cancel",
    ]

    #if DEBUG
    static func assertCopyCompliance(_ text: String) {
        let lowered = text.lowercased()
        for word in blacklist {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(lowered.startIndex..., in: lowered)
                let match = regex.firstMatch(in: lowered, range: range)
                assert(
                    match == nil,
                    "UI copy contains blacklisted word '\(word)': \"\(text)\""
                )
            }
        }
    }

    static func containsBlacklistedWord(_ text: String) -> Bool {
        let lowered = text.lowercased()
        for word in blacklist {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               regex.firstMatch(in: lowered, range: NSRange(lowered.startIndex..., in: lowered)) != nil {
                return true
            }
        }
        return false
    }
    #endif
}
