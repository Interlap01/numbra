import SwiftUI

/// An image that fills its frame (cover), used for thumbnails and previews.
struct CoverImage: View {
    let image: UIImage
    var body: some View {
        Image(uiImage: image)
            .resizable()
            .interpolation(.medium)
            .aspectRatio(contentMode: .fill)
            .clipped()
    }
}

/// Uppercase, letter-spaced label (the "kicker" used across screens).
struct Kicker: View {
    let text: String
    var color: Color = Theme.terra
    var size: CGFloat = 13
    var tracking: CGFloat = 0.14 * 13
    var body: some View {
        Text(text.uppercased())
            .font(Theme.ui(size, weight: .bold))
            .tracking(tracking)
            .foregroundStyle(color)
    }
}

/// Circular back button (screens.jsx header).
struct CircleBackButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Icon(name: "back", size: 22, color: Theme.ink, weight: .bold)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Theme.card2))
        }
        .buttonStyle(.plain)
    }
}

/// Bottom gradient used over thumbnails for legible captions.
struct BottomScrim: View {
    var height: CGFloat = 0.55
    var body: some View {
        LinearGradient(colors: [Color(red: 20/255, green: 14/255, blue: 8/255, opacity: 0.7), .clear],
                       startPoint: .bottom, endPoint: .init(x: 0.5, y: 1 - height))
    }
}
