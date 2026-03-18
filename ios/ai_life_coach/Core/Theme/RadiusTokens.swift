import SwiftUI

struct RadiusTokens: Sendable {
    let container: CGFloat = 16
    let button: CGFloat = 16
    let input: CGFloat = 20    // pill shape
    let small: CGFloat = 8
    let sprintTrack: CGFloat = 3

    // Avatar uses .clipShape(Circle()) — no radius token needed
}
