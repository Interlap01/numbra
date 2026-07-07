import SwiftUI

/// Design tokens from the handoff (Numbra.html `:root`). Colors are the gallery /
/// Post-Impressionist palette; type uses a serif for the Bodoni Moda display role and
/// the system sans for the Space Grotesk UI role (closest native equivalents).
enum Theme {
    // palette
    static let paper   = Color(hex: 0xE7E3EF)   // app background — pale lavender-grey
    static let ink     = Color(hex: 0x221B33)   // deep ink-aubergine
    static let muted   = Color(hex: 0x786F8C)   // secondary text
    static let terra   = Color(hex: 0xE0492F)   // PRIMARY ACCENT — vermilion
    static let sage    = Color(hex: 0x1E8A78)   // viridian — success / magic-fill / "on"
    static let gold    = Color(hex: 0xE0A52E)
    static let ultra   = Color(hex: 0x2746C9)
    static let card    = Color(hex: 0xFBFAFE)
    static let card2   = Color(hex: 0xE1DCEC)
    static let line    = Color(red: 34/255, green: 27/255, blue: 51/255, opacity: 0.10)

    // canvas chrome
    static let canvasPaperDefault = (0xF4, 0xEE, 0xDF)
    static let chromeDark   = Color(hex: 0x16130f)
    static let chromeLight  = Color(hex: 0xECE3D3)

    // onboarding slide backgrounds
    static let slideStarry  = Color(hex: 0x162a63)
    static let slideWave    = Color(hex: 0x1f4f78)
    static let slideMatisse = Color(hex: 0x1E8A78)

    // type
    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    /// Parse a "#rrggbb" string into an (r,g,b) Int triple.
    static func rgbTriple(_ hex: String) -> (Int, Int, Int) {
        var s = hex; if s.hasPrefix("#") { s.removeFirst() }
        let v = UInt32(s, radix: 16) ?? 0
        return (Int((v >> 16) & 255), Int((v >> 8) & 255), Int(v & 255))
    }
}
