import SwiftUI

/// Celebrate + share. Port of screens.jsx `CompleteScreen`. Only the framed painting
/// animates (scale, not opacity) so the end state is always visible (capture-safe).
struct CompleteView: View {
    let model: AppModel
    let info: CompleteInfo
    @State private var appeared = false

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            ConfettiView().ignoresSafeArea()

            VStack(spacing: 0) {
                Kicker(text: "Masterpiece complete", size: 13, tracking: 0.16 * 13)
                Text(model.projTitle).font(Theme.display(34)).foregroundStyle(Theme.ink).lineLimit(1).padding(.top, 6)

                GeometryReader { geo in
                    let side = geo.size.width * 0.78
                    Image(uiImage: info.img)
                        .interpolation(.none).resizable()
                        .aspectRatio(1, contentMode: .fill)
                        .frame(width: side, height: side)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.white.opacity(0.9), lineWidth: 8))
                        .shadow(color: Color(red: 60/255, green: 40/255, blue: 25/255).opacity(0.28), radius: 25, y: 22)
                        .rotationEffect(.degrees(-1.5))
                        .scaleEffect(appeared ? 1 : 0.4)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 26)
                }
                .frame(height: 300)

                HStack(spacing: 26) {
                    Stat(icon: "clock", value: info.time.isEmpty ? "—" : info.time, label: "Time")
                    Rectangle().fill(Theme.line).frame(width: 1, height: 44)
                    Stat(icon: "grid", value: info.pieces, label: "Pieces")
                    Rectangle().fill(Theme.line).frame(width: 1, height: 44)
                    Stat(icon: "star", value: info.xp.isEmpty ? "+50" : info.xp, label: "XP")
                }
                .padding(.top, 28)

                Spacer()

                VStack(spacing: 10) {
                    NButton(title: "Watch timelapse", variant: .primary, size: .lg, icon: "play", fullWidth: true) {
                        if let data = info.data { model.overlay = .timelapse(data: data, order: info.order) }
                    }
                    HStack(spacing: 10) {
                        NButton(title: "Share", variant: .soft, size: .md, icon: "share", fullWidth: true) {
                            model.overlay = .share(before: info.before, after: info.img)
                        }
                        NButton(title: "Studio", variant: .soft, size: .md, icon: "grid", fullWidth: true) {
                            model.screen = .gallery
                        }
                    }
                    Button { model.restartActive() } label: {
                        HStack(spacing: 7) {
                            Icon(name: "undo", size: 15, color: Theme.terra, weight: .bold)
                            Text("Paint again · change difficulty").font(Theme.ui(14.5, weight: .bold)).foregroundStyle(Theme.terra)
                        }
                    }
                    .buttonStyle(.plain).padding(.top, 4)
                }
                .padding(.top, 30)
            }
            .padding(.horizontal, 24)
            .padding(.top, 80).padding(.bottom, 30)
        }
        .onAppear { withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) { appeared = true } }
    }
}

private struct Stat: View {
    let icon: String; let value: String; let label: String
    var body: some View {
        VStack(spacing: 4) {
            Icon(name: icon, size: 20, color: Theme.muted, weight: .regular)
            Text(value).font(Theme.ui(18, weight: .heavy)).foregroundStyle(Theme.ink)
            Text(label.uppercased()).font(Theme.ui(11.5)).tracking(0.06 * 11.5).foregroundStyle(Theme.muted)
        }
    }
}
