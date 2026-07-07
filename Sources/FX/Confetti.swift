import SwiftUI

/// Canvas particle burst, ported from fx.jsx `Confetti`. Fires once on appear and
/// fades over ~2.6s. Squares and circles in the gallery palette.
struct ConfettiView: View {
    var duration: Double = 2.6

    private struct Particle {
        var x: CGFloat; var y: CGFloat
        var vx: CGFloat; var vy: CGFloat
        var g: CGFloat; var s: CGFloat
        var rot: CGFloat; var vr: CGFloat
        var color: Color; var square: Bool
    }

    @State private var particles: [Particle] = []
    @State private var elapsed: Double = 0
    @State private var last: Date = .now

    private let colors: [Color] = [0xC9694A, 0x6E8B6A, 0xE3C34A, 0x4F6FB0, 0xE8748C, 0xF4A259].map { Color(hex: $0) }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                Canvas { ctx, _ in
                    let alpha = max(0, 1 - elapsed / duration)
                    for p in particles {
                        ctx.opacity = alpha
                        ctx.translateBy(x: p.x, y: p.y)
                        ctx.rotate(by: .radians(Double(p.rot)))
                        if p.square {
                            ctx.fill(Path(CGRect(x: -p.s/2, y: -p.s/3, width: p.s, height: p.s*0.66)), with: .color(p.color))
                        } else {
                            ctx.fill(Path(ellipseIn: CGRect(x: -p.s/2, y: -p.s/2, width: p.s, height: p.s)), with: .color(p.color))
                        }
                        ctx.rotate(by: .radians(-Double(p.rot)))
                        ctx.translateBy(x: -p.x, y: -p.y)
                    }
                }
                .onChange(of: timeline.date) { _, now in step(now: now) }
            }
            .onAppear { seed(in: geo.size) }
        }
        .allowsHitTesting(false)
    }

    private func seed(in size: CGSize) {
        let W = size.width, H = size.height
        last = .now; elapsed = 0
        particles = (0..<130).map { _ in
            Particle(
                x: W/2 + CGFloat.random(in: -0.5...0.5) * W * 0.5,
                y: H * 0.32 + CGFloat.random(in: -20...20),
                vx: CGFloat.random(in: -3.5...3.5),
                vy: -6 - CGFloat.random(in: 0...7),
                g: 0.18 + CGFloat.random(in: 0...0.12),
                s: 4 + CGFloat.random(in: 0...6),
                rot: CGFloat.random(in: 0...6.28),
                vr: CGFloat.random(in: -0.2...0.2),
                color: colors.randomElement()!,
                square: Bool.random())
        }
    }

    private func step(now: Date) {
        guard elapsed < duration else { return }
        let dt = now.timeIntervalSince(last)
        last = now
        elapsed += dt
        // integrate at the design's ~60fps physics scale
        let steps = max(1, Int((dt * 60).rounded()))
        for _ in 0..<steps {
            for i in particles.indices {
                particles[i].vy += particles[i].g
                particles[i].x += particles[i].vx
                particles[i].y += particles[i].vy
                particles[i].vx *= 0.99
                particles[i].rot += particles[i].vr
            }
        }
    }
}
