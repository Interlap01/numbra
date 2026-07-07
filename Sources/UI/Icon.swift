import SwiftUI

/// The handoff ships one inline-SVG icon set (`ui-kit.jsx` `Icon`). Per the handoff
/// ("Reuse names or map to the codebase's icon lib"), each name maps to an SF Symbol.
struct Icon: View {
    let name: String
    var size: CGFloat = 24
    var color: Color = .primary
    var weight: Font.Weight = .medium

    private static let symbols: [String: String] = [
        "back": "chevron.left",
        "close": "xmark",
        "plus": "plus",
        "camera": "camera",
        "image": "photo",
        "sparkle": "sparkles",
        "share": "square.and.arrow.up",
        "check": "checkmark",
        "drop": "flame.fill",
        "brush": "paintbrush.pointed.fill",
        "tap": "hand.tap.fill",
        "wand": "wand.and.stars",
        "target": "scope",
        "plusN": "plus.magnifyingglass",
        "minus": "minus.magnifyingglass",
        "fit": "viewfinder",
        "lock": "lock.fill",
        "play": "play.fill",
        "chevron": "chevron.right",
        "grid": "square.grid.2x2.fill",
        "palette": "paintpalette.fill",
        "star": "star.fill",
        "clock": "clock.fill",
        "undo": "arrow.uturn.backward",
        "sound": "speaker.wave.2.fill",
        "mute": "speaker.slash.fill",
        "arrow-right": "arrow.right",
    ]

    var body: some View {
        Image(systemName: Self.symbols[name] ?? "questionmark")
            .font(.system(size: size, weight: weight))
            .foregroundStyle(color)
    }
}
