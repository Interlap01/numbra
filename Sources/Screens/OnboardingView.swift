import SwiftUI
import PhotosUI

/// First-launch onboarding. Intro slides → a free, one-off "pick a photo (library/camera)
/// or a sample, watch it become a canvas" → a guided turn in the *real* paint screen
/// (pulse the biggest piece, let the user fill a couple) → a celebratory reveal → the Plus
/// paywall. The slides are a port of onboarding.jsx; the interactive demo is new.
struct OnboardingView: View {
    let model: AppModel
    var onDone: () -> Void

    private enum Phase { case slides, pick, generating, painting, reveal, paywall }
    @State private var phase: Phase = .slides
    @State private var index = 0

    @State private var data: PBNData?
    @State private var sampleThumb: UIImage?
    @State private var painted: UIImage?
    @State private var filledCount = 0
    @State private var revealed = false

    // photo pick step
    @State private var photoItem: PhotosPickerItem?
    @State private var showLibrary = false
    @State private var showCamera = false
    private var cameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    private struct Slide {
        let sampleKey: String; let bg: Color; let kicker: String; let title: String; let body: String
    }
    private let slides: [Slide] = [
        Slide(sampleKey: "starry", bg: Theme.slideStarry, kicker: "Welcome to Numbra",
              title: "Painting,\nby the numbers",
              body: "Color the calm — one numbered piece at a time. From the great masters to your own photos."),
        Slide(sampleKey: "wave", bg: Theme.slideWave, kicker: "Any image, transformed",
              title: "Every photo\nbecomes a canvas",
              body: "Numbra traces any picture into paintable regions and assigns a palette. Choose a difficulty and begin."),
        Slide(sampleKey: "bloom", bg: Theme.slideMatisse, kicker: "Made for unwinding",
              title: "Tap, drag,\nunwind",
              body: "Two relaxing ways to color, gentle sound, hints when you're stuck, and a timelapse of every piece you place."),
    ]
    @State private var slideImages: [UIImage] = []

    private var slide: Slide { slides[index] }
    private var isLast: Bool { index == slides.count - 1 }

    var body: some View {
        Group {
            switch phase {
            case .slides:     slidesView
            case .pick:       pickView
            case .generating: generatingView
            case .painting:   paintingView
            case .reveal:     revealView
            case .paywall:    paywallView
            }
        }
        .animation(.easeInOut(duration: 0.4), value: phase)
        .task { await buildSlideImages() }
    }

    private func buildSlideImages() async {
        guard slideImages.isEmpty else { return }
        let keys = slides.map { $0.sampleKey }
        let imgs = await Task.detached(priority: .userInitiated) {
            keys.map { UIImage(cgImage: PBNSamples.make($0, size: 1200)) }   // crisp on 3x screens
        }.value
        await MainActor.run { slideImages = imgs }
    }

    // MARK: intro slides

    private var slidesView: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                slide.bg.ignoresSafeArea().animation(.easeInOut(duration: 0.5), value: index)

                VStack(spacing: 0) {
                    // artwork stage (~52%) — real sample scenes crossfading
                    ZStack {
                        ForEach(slides.indices, id: \.self) { k in
                            Group {
                                if k < slideImages.count {
                                    Image(uiImage: slideImages[k]).resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    slides[k].bg
                                }
                            }
                            .opacity(k == index ? 1 : 0)
                            .scaleEffect(k == index ? 1 : 1.06)
                            .animation(.easeInOut(duration: 0.55), value: index)
                        }
                        VStack {
                            Spacer()
                            LinearGradient(colors: [slide.bg, slide.bg.opacity(0)], startPoint: .bottom, endPoint: .top)
                                .frame(height: 120)
                        }
                    }
                    .frame(height: max(360, geo.size.height * 0.52))
                    .clipped()

                    // copy
                    VStack(alignment: .leading, spacing: 0) {
                        Kicker(text: slide.kicker, color: .white.opacity(0.65), tracking: 0.16 * 13)
                        Text(slide.title)
                            .font(Theme.display(44, weight: .medium))
                            .foregroundStyle(.white)
                            .lineSpacing(0)
                            .padding(.top, 10)
                        Text(slide.body)
                            .font(Theme.ui(16))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineSpacing(4)
                            .frame(maxWidth: 320, alignment: .leading)
                            .padding(.top, 16)

                        Spacer()

                        HStack(spacing: 7) {
                            ForEach(slides.indices, id: \.self) { k in
                                Capsule()
                                    .fill(k == index ? Color.white : Color.white.opacity(0.32))
                                    .frame(width: k == index ? 26 : 8, height: 8)
                                    .animation(.easeOut(duration: 0.3), value: index)
                            }
                        }
                        .padding(.bottom, 22)

                        Button {
                            if isLast { withAnimation { phase = .pick } } else { withAnimation { index += 1 } }
                        } label: {
                            HStack(spacing: 9) {
                                Text(isLast ? "Try it free" : "Continue")
                                    .font(Theme.ui(17, weight: .bold))
                                Icon(name: "arrow-right", size: 18, color: slide.bg, weight: .bold)
                            }
                            .foregroundStyle(slide.bg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(Capsule().fill(Color.white))
                        }
                        .buttonStyle(PressableStyle())
                        .padding(.bottom, 34)
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .ignoresSafeArea(edges: .top)

                skipPill
            }
        }
    }

    private var skipPill: some View {
        HStack {
            Spacer()
            Button(action: onDone) {
                Text("Skip")
                    .font(Theme.ui(13.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    // Dark capsule so white text stays readable over light artwork (e.g. the sky).
                    .background(Capsule().fill(Color.black.opacity(0.35)))
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    // MARK: pick a photo (free, ungated — library / camera / sample)

    private var pickView: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer().frame(height: 88)
                Kicker(text: "Free — no account needed")
                Text("Pick a photo\nto paint")
                    .font(Theme.display(40, weight: .medium)).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center).lineSpacing(0).padding(.top, 8)
                Text("Numbra traces it into a numbered canvas. Use one of your own, or try a sample.")
                    .font(Theme.ui(15)).foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center).lineSpacing(3)
                    .frame(maxWidth: 320).padding(.top, 12).padding(.bottom, 28)

                VStack(spacing: 12) {
                    pickButton(icon: "image", title: "Choose from library", subtitle: "Use one of your photos", dark: true) { showLibrary = true }
                    pickButton(icon: "camera", title: "Take a photo",
                               subtitle: cameraAvailable ? "Use your camera" : "Camera unavailable here",
                               dark: false, disabled: !cameraAvailable) { showCamera = true }
                }
                .padding(.horizontal, 22)

                Spacer()

                Button { startGeneration(from: PBNSamples.make("starry", size: 460), title: "Starry Night") } label: {
                    Text("Or try a sample painting")
                        .font(Theme.ui(15, weight: .bold)).foregroundStyle(Theme.terra)
                }
                .buttonStyle(PressableStyle()).padding(.bottom, 10)

                Button("Skip", action: onDone)
                    .font(Theme.ui(14, weight: .semibold)).foregroundStyle(Theme.muted).buttonStyle(.plain)
                    .padding(.bottom, 30)
            }
        }
        .photosPicker(isPresented: $showLibrary, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let d = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: d), let cg = Painter.normalized(img) {
                    await MainActor.run { startGeneration(from: cg, title: "Your photo") }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { img in
                showCamera = false
                if let cg = img.flatMap({ Painter.normalized($0) }) { startGeneration(from: cg, title: "Your photo") }
            }
            .ignoresSafeArea()
        }
    }

    private func pickButton(icon: String, title: String, subtitle: String, dark: Bool,
                            disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: { if !disabled { action() } }) {
            HStack(spacing: 14) {
                Icon(name: icon, size: 24, color: dark ? Theme.paper : Theme.ink, weight: .regular)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(Theme.ui(15.5, weight: .bold)).foregroundStyle(dark ? Theme.paper : Theme.ink)
                    Text(subtitle).font(Theme.ui(12.5)).foregroundStyle(dark ? Theme.paper.opacity(0.6) : Theme.muted)
                }
                Spacer()
                Icon(name: "arrow-right", size: 17, color: dark ? Theme.paper.opacity(0.7) : Theme.muted, weight: .bold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18).padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(dark ? Theme.ink : Theme.card)
                    .overlay(dark ? nil : RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.line, lineWidth: 1.5))
            )
        }
        .buttonStyle(PressableStyle())
        .opacity(disabled ? 0.45 : 1)
    }

    // MARK: generation beat ("free, once")

    private var generatingView: some View {
        ZStack {
            Theme.slideStarry.ignoresSafeArea()
            MotifView(kind: .swirl).opacity(0.18).blur(radius: 2).ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView().controlSize(.large).tint(.white)
                Text("Turning a masterpiece\ninto a canvas…")
                    .font(Theme.display(26)).foregroundStyle(.white)
                    .multilineTextAlignment(.center).lineSpacing(2)
                Text("Numbra is tracing the regions and picking a palette — free, no account needed.")
                    .font(Theme.ui(14)).foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center).lineSpacing(2)
                    .frame(maxWidth: 300)
            }
            .padding(40)
        }
    }

    // MARK: guided paint (real PaintView)

    private var paintingView: some View {
        ZStack {
            model.settings.canvasBg.ignoresSafeArea()
            if let d = data {
                PaintView(model: model, data: d, onboarding: true,
                          onProgress: { done, _ in
                              filledCount = done
                              if done >= 2 { scheduleReveal() }
                          },
                          onFinishOnboarding: { goReveal() })
                    .id("onboarding-paint")
            }
            coachOverlay
        }
    }

    private var coachOverlay: some View {
        VStack {
            VStack(spacing: 4) {
                Text(coachTitle).font(Theme.ui(16, weight: .heavy)).foregroundStyle(.white)
                Text(coachBody).font(Theme.ui(13))
                    .foregroundStyle(.white.opacity(0.82)).multilineTextAlignment(.center).lineSpacing(1)
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .frame(maxWidth: 320)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.ink.opacity(0.92)))
            .shadow(color: .black.opacity(0.3), radius: 14, y: 8)
            .padding(.top, 108)
            .animation(.easeOut(duration: 0.25), value: filledCount)
            Spacer()
        }
        .allowsHitTesting(false)
    }

    private var coachTitle: String {
        switch filledCount { case 0: return "Tap the glowing piece"; case 1: return "Nice — one more!"; default: return "Beautiful." }
    }
    private var coachBody: String {
        switch filledCount {
        case 0:  return "The highlighted areas all share the selected color. Tap one to fill it in."
        case 1:  return "Fill another glowing piece to get the hang of it."
        default: return "Revealing your painting…"
        }
    }

    // MARK: reveal

    private var revealView: some View {
        ZStack {
            Theme.slideStarry.ignoresSafeArea()
            ConfettiView().ignoresSafeArea()
            VStack(spacing: 0) {
                Kicker(text: "Your first canvas", color: .white.opacity(0.7), tracking: 0.16 * 13)
                Text("Look what you made")
                    .font(Theme.display(34)).foregroundStyle(.white).padding(.top, 6)

                if let p = painted {
                    Image(uiImage: p).interpolation(.none).resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.white.opacity(0.9), lineWidth: 8))
                        .shadow(color: .black.opacity(0.35), radius: 26, y: 20)
                        .rotationEffect(.degrees(-1.5))
                        .scaleEffect(revealed ? 1 : 0.5)
                        .padding(.top, 30)
                }

                Text("That's Numbra — every photo becomes a calm, paintable canvas you finish piece by piece.")
                    .font(Theme.ui(15)).foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center).lineSpacing(3)
                    .frame(maxWidth: 320).padding(.top, 26)

                Spacer()

                Button { withAnimation { phase = .paywall } } label: {
                    HStack(spacing: 9) {
                        Text("Continue").font(Theme.ui(17, weight: .bold))
                        Icon(name: "arrow-right", size: 18, color: Theme.slideStarry, weight: .bold)
                    }
                    .foregroundStyle(Theme.slideStarry)
                    .frame(maxWidth: .infinity).padding(.vertical, 17)
                    .background(Capsule().fill(Color.white))
                }
                .buttonStyle(PressableStyle())
                .padding(.horizontal, 28).padding(.bottom, 36)
            }
            .padding(.top, 90)
        }
        .onAppear { withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) { revealed = true } }
    }

    // MARK: paywall (reuses the real Plus paywall as the final step)

    private var paywallView: some View {
        ZStack {
            // Soft vertical wash so the page reads as an intentional full screen, not a
            // stranded sheet.
            LinearGradient(colors: [Theme.terra.opacity(0.10), Theme.paper],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
            VStack {
                Spacer(minLength: 24)
                PaywallContent(model: model, onboardingFinish: onDone)
                    .padding(.horizontal, 26).padding(.vertical, 30)
                    .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Theme.card))
                    .shadow(color: Color(red: 60/255, green: 40/255, blue: 25/255).opacity(0.16), radius: 26, y: 18)
                    .padding(.horizontal, 18)
                Spacer(minLength: 24)
            }
        }
    }

    // MARK: flow helpers

    /// Process the chosen image (the user's library/camera photo, or a sample) for free at the
    /// hardest preset, set it up as a kept library project, and drop into the guided demo.
    private func startGeneration(from src: CGImage, title: String) {
        withAnimation { phase = .generating }
        let cfg = Difficulty.all.first { $0.id == "hard" } ?? Difficulty.all[0]
        Task.detached(priority: .userInitiated) {
            let d = PBNEngine.generate(src, options: .init(colors: cfg.colors, detail: cfg.detail))
            let thumb = UIImage(cgImage: src)
            let final = Painter.painted(d)
            try? await Task.sleep(nanoseconds: 1_100_000_000)   // let the loader breathe
            await MainActor.run {
                data = d
                sampleThumb = thumb
                painted = final
                model.beginOnboardingCanvas(d, src: src, cfg: cfg)
                withAnimation { phase = .painting }
            }
        }
    }

    private func scheduleReveal() {
        guard phase == .painting else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { goReveal() }
    }

    private func goReveal() {
        guard phase == .painting else { return }
        withAnimation { phase = .reveal }
    }
}

// MARK: - camera capture (UIImagePickerController bridge)

/// Minimal camera capture for the onboarding "Take a photo" option. Returns nil if the
/// user cancels. (PhotosUI's picker handles the library; only the camera needs UIKit.)
struct CameraPicker: UIViewControllerRepresentable {
    var onPicked: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let c = UIImagePickerController()
        c.sourceType = .camera
        c.delegate = context.coordinator
        return c
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onPicked: (UIImage?) -> Void
        init(onPicked: @escaping (UIImage?) -> Void) { self.onPicked = onPicked }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onPicked(info[.originalImage] as? UIImage)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onPicked(nil) }
    }
}

// MARK: - motifs (hand-built SVG homages → SwiftUI Canvas)

enum MotifKind { case swirl, wave, leaves }

struct MotifView: View {
    let kind: MotifKind
    var body: some View {
        Canvas { ctx, size in
            // viewBox 0 0 240 200, "meet" (uniform scale, centered)
            let s = min(size.width / 240, size.height / 200)
            let ox = (size.width - 240 * s) / 2, oy = (size.height - 200 * s) / 2
            let tf = CGAffineTransform(translationX: ox, y: oy).scaledBy(x: s, y: s)
            switch kind {
            case .swirl: drawSwirl(ctx, tf)
            case .wave: drawWave(ctx, tf)
            case .leaves: drawLeaves(ctx, tf)
            }
        }
    }

    private func col(_ hex: UInt32, _ a: Double = 1) -> GraphicsContext.Shading { .color(Color(hex: hex, opacity: a)) }

    private func path(_ build: (inout Path) -> Void, _ tf: CGAffineTransform) -> Path {
        var p = Path(); build(&p); return p.applying(tf)
    }

    private func drawSwirl(_ ctx: GraphicsContext, _ tf: CGAffineTransform) {
        ctx.fill(path({ $0.addRect(CGRect(x: 0, y: 0, width: 240, height: 200)) }, tf), with: col(0x162a63))
        ctx.fill(path({ $0.addRect(CGRect(x: 0, y: 0, width: 240, height: 200)) }, tf),
                 with: .linearGradient(Gradient(colors: [Color(hex: 0x1b3a8c, opacity: 0.5), Color(hex: 0x0c1840, opacity: 0.7)]),
                                       startPoint: tf.transformed(0, 0), endPoint: tf.transformed(0, 200)))
        func spiral(_ cx: Double, _ cy: Double, _ turns: Int, _ color: UInt32, _ sw: Double, _ a: Double) {
            var p = Path(); p.move(to: CGPoint(x: cx, y: cy))
            for i in 1...(turns * 24) {
                let ang = Double(i) * 0.26, r = Double(i) * 1.05
                p.addLine(to: CGPoint(x: cx + cos(ang) * r, y: cy + sin(ang) * r))
            }
            ctx.stroke(p.applying(tf), with: col(color, a), style: StrokeStyle(lineWidth: sw * tf.a, lineCap: .round))
        }
        spiral(150, 70, 4, 0x7fa8e8, 4, 0.9)
        spiral(150, 70, 3, 0xe7c044, 2.2, 0.9)
        for star in [(60.0, 50.0, 13.0), (200, 130, 10), (40, 120, 8), (110, 40, 7)] {
            ctx.fill(path({ $0.addEllipse(in: CGRect(x: star.0 - star.2, y: star.1 - star.2, width: star.2 * 2, height: star.2 * 2)) }, tf), with: col(0xe7c044, 0.25))
            let r2 = star.2 * 0.42
            ctx.fill(path({ $0.addEllipse(in: CGRect(x: star.0 - r2, y: star.1 - r2, width: r2 * 2, height: r2 * 2)) }, tf), with: col(0xf4dd86))
        }
        ctx.fill(path({ p in
            p.move(to: CGPoint(x: 30, y: 200))
            p.addCurve(to: CGPoint(x: 24, y: 96), control1: CGPoint(x: 18, y: 150), control2: CGPoint(x: 30, y: 120))
            p.addCurve(to: CGPoint(x: 44, y: 200), control1: CGPoint(x: 40, y: 124), control2: CGPoint(x: 46, y: 158))
            p.closeSubpath()
        }, tf), with: col(0x10371f))
        ctx.fill(path({ $0.addRect(CGRect(x: 70, y: 172, width: 120, height: 28)) }, tf), with: col(0x1d2c4a))
        for x in [80.0, 104, 128, 152, 176] {
            ctx.fill(path({ p in
                p.move(to: CGPoint(x: x, y: 172)); p.addLine(to: CGPoint(x: x + 12, y: 160)); p.addLine(to: CGPoint(x: x + 24, y: 172)); p.closeSubpath()
            }, tf), with: col(0x1d2c4a))
        }
        for x in [100.0, 140, 168] {
            ctx.fill(path({ $0.addRect(CGRect(x: x, y: 180, width: 6, height: 9)) }, tf), with: col(0xe7c044))
        }
    }

    private func drawWave(_ ctx: GraphicsContext, _ tf: CGAffineTransform) {
        ctx.fill(path({ $0.addRect(CGRect(x: 0, y: 0, width: 240, height: 200)) }, tf), with: col(0xece6d4))
        ctx.fill(path({ $0.addEllipse(in: CGRect(x: 148, y: 38, width: 44, height: 44)) }, tf), with: col(0xf0e3c4))
        ctx.fill(path({ p in p.move(to: CGPoint(x: 150, y: 150)); p.addLine(to: CGPoint(x: 188, y: 96)); p.addLine(to: CGPoint(x: 226, y: 150)); p.closeSubpath() }, tf), with: col(0x3a5d77))
        ctx.fill(path({ p in
            p.move(to: CGPoint(x: 188, y: 96)); p.addLine(to: CGPoint(x: 174, y: 116)); p.addLine(to: CGPoint(x: 183, y: 120))
            p.addLine(to: CGPoint(x: 188, y: 112)); p.addLine(to: CGPoint(x: 193, y: 121)); p.addLine(to: CGPoint(x: 202, y: 116)); p.closeSubpath()
        }, tf), with: col(0xf4f1e6))
        ctx.fill(path({ p in
            p.move(to: CGPoint(x: -5, y: 150))
            p.addCurve(to: CGPoint(x: 110, y: 110), control1: CGPoint(x: 30, y: 90), control2: CGPoint(x: 70, y: 80))
            p.addCurve(to: CGPoint(x: 175, y: 64), control1: CGPoint(x: 150, y: 140), control2: CGPoint(x: 130, y: 70))
            p.addCurve(to: CGPoint(x: 78, y: 120), control1: CGPoint(x: 120, y: 60), control2: CGPoint(x: 120, y: 130))
            p.addCurve(to: CGPoint(x: 20, y: 150), control1: CGPoint(x: 120, y: 150), control2: CGPoint(x: 60, y: 175))
            p.closeSubpath()
        }, tf), with: col(0x173a5e))
        ctx.fill(path({ p in
            p.move(to: CGPoint(x: -5, y: 158))
            p.addCurve(to: CGPoint(x: 120, y: 138), control1: CGPoint(x: 40, y: 120), control2: CGPoint(x: 90, y: 118))
            p.addCurve(to: CGPoint(x: 245, y: 158), control1: CGPoint(x: 160, y: 165), control2: CGPoint(x: 200, y: 150))
            p.addLine(to: CGPoint(x: 245, y: 205)); p.addLine(to: CGPoint(x: -5, y: 205)); p.closeSubpath()
        }, tf), with: col(0x1f4f78))
        for f in [(40.0, 96.0, 7.0), (62, 86, 6), (88, 92, 7), (108, 104, 5), (150, 70, 6)] {
            ctx.fill(path({ $0.addEllipse(in: CGRect(x: f.0 - f.2, y: f.1 - f.2, width: f.2 * 2, height: f.2 * 2)) }, tf), with: col(0xf4f1e6))
        }
        ctx.fill(path({ p in
            p.move(to: CGPoint(x: -5, y: 175))
            p.addCurve(to: CGPoint(x: 160, y: 175), control1: CGPoint(x: 50, y: 160), control2: CGPoint(x: 110, y: 168))
            p.addCurve(to: CGPoint(x: 245, y: 176), control1: CGPoint(x: 200, y: 180), control2: CGPoint(x: 230, y: 174))
            p.addLine(to: CGPoint(x: 245, y: 205)); p.addLine(to: CGPoint(x: -5, y: 205)); p.closeSubpath()
        }, tf), with: col(0x102a44))
    }

    private func drawLeaves(_ ctx: GraphicsContext, _ tf: CGAffineTransform) {
        ctx.fill(path({ $0.addRect(CGRect(x: 0, y: 0, width: 240, height: 200)) }, tf), with: col(0x1E8A78))
        ctx.fill(path({ p in
            p.move(to: CGPoint(x: 50, y: 30))
            p.addCurve(to: CGPoint(x: 70, y: 90), control1: CGPoint(x: 90, y: 20), control2: CGPoint(x: 96, y: 70))
            p.addCurve(to: CGPoint(x: 50, y: 30), control1: CGPoint(x: 40, y: 110), control2: CGPoint(x: 20, y: 70))
            p.closeSubpath()
        }, tf), with: col(0xE0492F))
        ctx.fill(path({ p in
            p.move(to: CGPoint(x: 150, y: 24))
            p.addCurve(to: CGPoint(x: 150, y: 96), control1: CGPoint(x: 200, y: 30), control2: CGPoint(x: 196, y: 96))
            p.addCurve(to: CGPoint(x: 150, y: 24), control1: CGPoint(x: 120, y: 96), control2: CGPoint(x: 110, y: 40))
            p.closeSubpath()
        }, tf), with: col(0xE0A52E))
        ctx.fill(path({ p in
            p.move(to: CGPoint(x: 40, y: 130))
            p.addCurve(to: CGPoint(x: 96, y: 174), control1: CGPoint(x: 80, y: 110), control2: CGPoint(x: 120, y: 140))
            p.addCurve(to: CGPoint(x: 40, y: 130), control1: CGPoint(x: 72, y: 200), control2: CGPoint(x: 20, y: 170))
            p.closeSubpath()
        }, tf), with: col(0xF2EAD8))
        ctx.fill(path({ p in
            p.move(to: CGPoint(x: 150, y: 120))
            p.addCurve(to: CGPoint(x: 170, y: 184), control1: CGPoint(x: 200, y: 116), control2: CGPoint(x: 210, y: 170))
            p.addCurve(to: CGPoint(x: 150, y: 120), control1: CGPoint(x: 140, y: 194), control2: CGPoint(x: 120, y: 130))
            p.closeSubpath()
        }, tf), with: col(0x2746C9))
        for st in [(120.0, 60.0), (200, 150), (30, 90)] {
            ctx.fill(path({ p in
                let x = st.0, y = st.1
                p.move(to: CGPoint(x: x, y: y - 8)); p.addLine(to: CGPoint(x: x + 2.5, y: y - 2.5))
                p.addLine(to: CGPoint(x: x + 8, y: y - 1.8)); p.addLine(to: CGPoint(x: x + 4, y: y + 2.2))
                p.addLine(to: CGPoint(x: x + 5, y: y + 7.8)); p.addLine(to: CGPoint(x: x, y: y + 5))
                p.addLine(to: CGPoint(x: x - 5, y: y + 7.8)); p.addLine(to: CGPoint(x: x - 4, y: y + 2.2))
                p.addLine(to: CGPoint(x: x - 8, y: y - 1.8)); p.addLine(to: CGPoint(x: x - 2.5, y: y - 2.5)); p.closeSubpath()
            }, tf), with: col(0xF2EAD8))
        }
    }
}

private extension CGAffineTransform {
    func transformed(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y).applying(self) }
}
