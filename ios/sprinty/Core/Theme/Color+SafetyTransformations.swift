import SwiftUI
import UIKit

// MARK: - Safety Color Transformations

extension Color {
    /// Reduces the saturation of a color by a factor (0.0 = no change, 1.0 = fully desaturated).
    /// Works in HSB color space. Dark mode colors produce warm grays, not cold grays.
    func adjustedSaturation(by factor: CGFloat) -> Color {
        let components = hsbComponents
        let newSaturation = components.saturation * (1.0 - factor)
        return Color(
            hue: components.hue,
            saturation: max(0, min(1, newSaturation)),
            brightness: components.brightness,
            opacity: components.opacity
        )
    }

    /// Shifts the hue of a color toward warmth (orange/amber direction).
    /// Factor 0.0 = no change, 1.0 = full warmth shift.
    /// Warmth target hue is ~0.08 (amber/warm orange).
    func adjustedWarmth(by factor: CGFloat) -> Color {
        let components = hsbComponents
        let warmTarget: CGFloat = 0.08 // Amber/warm orange hue
        let currentHue = components.hue

        // Shift hue toward warm target via shortest path on the hue circle
        var hueDifference = warmTarget - currentHue
        if hueDifference > 0.5 { hueDifference -= 1.0 }
        if hueDifference < -0.5 { hueDifference += 1.0 }
        let newHue = currentHue + hueDifference * factor

        // Wrap hue to 0...1 range
        let wrappedHue = newHue - floor(newHue)

        return Color(
            hue: wrappedHue,
            saturation: components.saturation,
            brightness: components.brightness,
            opacity: components.opacity
        )
    }

    // MARK: - HSB Component Extraction

    /// Extracts HSB components from a SwiftUI Color via UIColor conversion.
    var hsbComponents: (hue: CGFloat, saturation: CGFloat, brightness: CGFloat, opacity: CGFloat) {
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (hue: h, saturation: s, brightness: b, opacity: a)
    }
}
