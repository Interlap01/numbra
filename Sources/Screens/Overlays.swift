import SwiftUI

// MARK: - Minimap (paint-extras.jsx `Minimap`)

/// Source thumbnail with a viewport rectangle; appears only when zoomed in.
struct MinimapOverlay: View {
    let view: MinimapView?
    let thumb: UIImage?

    var body: some View {
        if let view, let thumb, view.zoomed {
            let mw: CGFloat = 86
            let mh = (mw * CGFloat(view.h) / CGFloat(view.w)).rounded()
            let sx = mw / CGFloat(view.w), sy = mh / CGFloat(view.h)
            let vx0 = max(0, -view.tx / view.scale), vy0 = max(0, -view.ty / view.scale)
            let vx1 = min(CGFloat(view.w), (view.cssW - view.tx) / view.scale)
            let vy1 = min(CGFloat(view.h), (view.cssH - view.ty) / view.scale)
            VStack {
                HStack {
                    ZStack(alignment: .topLeading) {
                        Image(uiImage: thumb).resizable().aspectRatio(contentMode: .fill)
                            .frame(width: mw, height: mh).clipped()
                        Rectangle()
                            .strokeBorder(Color.white, lineWidth: 1.5)
                            .frame(width: (vx1 - vx0) * sx, height: (vy1 - vy0) * sy)
                            .offset(x: vx0 * sx, y: vy0 * sy)
                    }
                    .frame(width: mw, height: mh)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.white.opacity(0.85), lineWidth: 2))
                    .shadow(color: .black.opacity(0.25), radius: 7, y: 4)
                    Spacer()
                }
                .padding(.leading, 14).padding(.top, 116)
                Spacer()
            }
            .transition(.scale(scale: 0.9).combined(with: .opacity))
            .animation(.easeOut(duration: 0.25), value: view.zoomed)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Tutorial coach-marks (paint-extras.jsx `TutorialOverlay`)

struct TutorialOverlay: View {
    var onDone: () -> Void
    @State private var i = 0

    private struct Step { let title: String; let body: String; let target: Int; let cardTop: Bool }
    // target: 0 none, 1 palette, 2 modes, 3 magic
    private let steps: [Step] = [
        Step(title: "Welcome to the canvas", body: "Each area shows a number. Fill it with the matching color to reveal your painting.", target: 0, cardTop: false),
        Step(title: "Your palette", body: "Pick a color here — the matching numbers light up on the canvas. It greys out when finished.", target: 1, cardTop: true),
        Step(title: "Two ways to color", body: "Tap instantly fills a piece. Switch to Paint to zoom in and slowly brush a single piece in by hand.", target: 2, cardTop: true),
        Step(title: "Magic & hints", body: "The wand fills every piece of the current color. Tap the target up top to fly to your next piece.", target: 3, cardTop: true),
    ]

    var body: some View {
        GeometryReader { geo in
            let step = steps[i]
            let spot = spotlight(step.target, geo)
            ZStack {
                // dim with a spotlight cutout
                Path { p in
                    p.addRect(CGRect(origin: .zero, size: geo.size))
                    if let spot { p.addRoundedRect(in: spot, cornerSize: CGSize(width: 16, height: 16)) }
                }
                .fill(Color(red: 18/255, green: 13/255, blue: 8/255, opacity: 0.62), style: FillStyle(eoFill: true))
                .ignoresSafeArea()

                if let spot {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                        .frame(width: spot.width, height: spot.height)
                        .position(x: spot.midX, y: spot.midY)
                }

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 5) {
                        ForEach(steps.indices, id: \.self) { k in
                            Capsule().fill(k == i ? Theme.terra : Theme.card2)
                                .frame(width: k == i ? 18 : 6, height: 6)
                        }
                    }
                    .padding(.bottom, 12)
                    Text(step.title).font(Theme.display(23)).foregroundStyle(Theme.ink)
                    Text(step.body).font(Theme.ui(14.5)).foregroundStyle(Theme.muted).lineSpacing(3)
                        .padding(.top, 6).padding(.bottom, 16)
                    HStack {
                        Button("Skip", action: onDone)
                            .font(Theme.ui(14, weight: .bold)).foregroundStyle(Theme.muted).buttonStyle(.plain)
                        Spacer()
                        NButton(title: i < steps.count - 1 ? "Next" : "Start painting", variant: .primary, size: .sm) {
                            if i < steps.count - 1 { withAnimation { i += 1 } } else { onDone() }
                        }
                    }
                }
                .padding(20)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.card))
                .shadow(color: .black.opacity(0.3), radius: 20, y: 16)
                .padding(.horizontal, 24)
                .position(x: geo.size.width / 2, y: step.cardTop ? geo.size.height * 0.34 : geo.size.height * 0.5)
            }
        }
    }

    private func spotlight(_ target: Int, _ geo: GeometryProxy) -> CGRect? {
        guard target != 0 else { return nil }
        let w = geo.size.width
        let dockBottom = geo.size.height - geo.safeAreaInsets.bottom
        switch target {
        case 1: return CGRect(x: 10, y: dockBottom - 116, width: w - 20, height: 84)
        case 2: return CGRect(x: 14, y: dockBottom - 172, width: w - 80, height: 48)
        case 3: return CGRect(x: w - 62, y: dockBottom - 172, width: 50, height: 50)
        default: return nil
        }
    }
}

// MARK: - Toast (paint-extras.jsx `Toast`)

struct ToastView: View {
    let toast: ToastInfo
    var onDismiss: () -> Void
    @State private var show = false

    var body: some View {
        VStack {
            HStack(spacing: 11) {
                Icon(name: toast.icon, size: 18, color: .white, weight: .bold)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(toast.color))
                VStack(alignment: .leading, spacing: 1) {
                    Text(toast.title).font(Theme.ui(14.5, weight: .heavy)).foregroundStyle(Theme.paper)
                    if let sub = toast.sub {
                        Text(sub).font(Theme.ui(12.5)).foregroundStyle(Theme.paper.opacity(0.7))
                    }
                }
            }
            .padding(.leading, 13).padding(.trailing, 18).padding(.vertical, 11)
            .background(Capsule().fill(Theme.ink))
            .shadow(color: .black.opacity(0.32), radius: 15, y: 10)
            .offset(y: show ? 0 : -24)
            .opacity(show ? 1 : 0)
            .padding(.top, 58)
            Spacer()
        }
        .allowsHitTesting(false)
        .task(id: toast.id) {
            show = false
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { show = true }
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            withAnimation(.easeOut(duration: 0.35)) { show = false }
            try? await Task.sleep(nanoseconds: 360_000_000)
            onDismiss()
        }
    }
}
