import SwiftUI

// MARK: - Color Hex Initializer (matches main app's ColorPalette.swift extension)

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

// MARK: - Widget Color Tokens

enum WidgetColors {
    // Background
    static let backgroundLight = Color(hex: 0xF4F2EC)
    static let backgroundDark = Color(hex: 0x2A2A28)

    // Text
    static let textPrimary = Color(hex: 0x3A3A30)
    static let textSecondary = Color(hex: 0x8B8B78)
    static let textPrimaryDark = Color(hex: 0xE8E6E0)
    static let textSecondaryDark = Color(hex: 0x9A9A88)

    // Sprint progress
    static let sprintTrack = Color(hex: 0x8B9B7A, opacity: 0.12)
    static let sprintProgressStart = Color(hex: 0x748465)
    static let sprintProgressEnd = Color(hex: 0x7A8B6B)
}
