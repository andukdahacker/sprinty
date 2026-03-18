import SwiftUI

struct SpacingScale: Sendable {
    let dialogueTurn: CGFloat = 24
    let dialogueBreath: CGFloat = 8
    let homeElement: CGFloat = 16
    let insightPadding: CGFloat = 16
    let coachCharacterBottom: CGFloat = 16
    let inputAreaTop: CGFloat = 12
    let sectionGap: CGFloat = 32
    let minTouchTarget: CGFloat = 44

    /// Returns the screen margin based on device width.
    /// SE and small devices (<=375pt) get 16pt, all others get 20pt.
    func screenMargin(for width: CGFloat) -> CGFloat {
        width <= 375 ? 16 : 20
    }
}

// MARK: - Pro Max Content Column Cap

private struct ContentColumnModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: 390)
    }
}

extension View {
    func contentColumn() -> some View {
        modifier(ContentColumnModifier())
    }
}
