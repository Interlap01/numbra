import SwiftUI

/// The full coloring experience around `PaintCanvas`: top bar, zoom/sound rail,
/// bottom dock (mode toggle + magic-fill + palette rail), minimap, tutorial.
/// Port of paint-screen.jsx `PaintScreen`.
struct PaintView: View {
    let model: AppModel
    let data: PBNData

    /// Onboarding mode reuses the real paint experience but suppresses the in-canvas
    /// tutorial, reports fill progress, and routes completion/back to the onboarding flow
    /// instead of the studio.
    var onboarding = false
    var onProgress: (Int, Int) -> Void = { _, _ in }
    var onFinishOnboarding: () -> Void = {}

    @State private var handle = PaintCanvasHandle()
    @State private var mode: String
    @State private var sel: Int
    @State private var remaining: [Int]
    @State private var done: Int
    @State private var canUndo: Bool
    @State private var shakeTrigger = 0
    @State private var minimap: MinimapView?
    @State private var tut: Bool
    @State private var sound: Bool
    @State private var brushing = false   // paint mode: brush armed (one-finger paints) vs pan

    private var settings: PaintSettings { model.settings }
    private var total: Int { data.regionCount }
    private var pct: Int { total > 0 ? Int((Double(done) / Double(total) * 100).rounded()) : 0 }
    private var ink: Color { settings.dark ? .white : Theme.ink }
    private var seamColor: CGColor {
        settings.colorblind ? CGColor(red: 22/255, green: 16/255, blue: 9/255, alpha: 0.6)
                            : CGColor(red: 60/255, green: 45/255, blue: 30/255, alpha: 0.28)
    }
    private var showNumbers: Bool { settings.colorblind ? true : settings.showNumbers }

    init(model: AppModel, data: PBNData, onboarding: Bool = false,
         onProgress: @escaping (Int, Int) -> Void = { _, _ in },
         onFinishOnboarding: @escaping () -> Void = {}) {
        self.model = model
        self.data = data
        self.onboarding = onboarding
        self.onProgress = onProgress
        self.onFinishOnboarding = onFinishOnboarding
        // derive starting remaining-per-color + done from any restored fills
        var rem = data.colorCounts
        var d = 0
        if let init0 = model.initialFilled {
            for r in 0..<data.regionCount where init0[r] != 0 { rem[Int(data.regionColor[r])] -= 1; d += 1 }
        }
        _mode = State(initialValue: model.settings.defaultMode)
        _sel = State(initialValue: Self.firstIncomplete(data, rem))
        _remaining = State(initialValue: rem)
        _done = State(initialValue: d)
        _canUndo = State(initialValue: d > 0)
        _tut = State(initialValue: !model.tutSeen)
        _sound = State(initialValue: UserDefaults.standard.string(forKey: "numbra_sound") == "1")
    }

    var body: some View {
        ZStack {
            settings.canvasBg.ignoresSafeArea()

            PaintCanvas(
                data: data, selColor: sel, mode: mode, brushing: mode == "paint" && brushing,
                paperRGB: settings.paperRGB,
                seamColor: seamColor, showNumbers: showNumbers, initialFilled: model.initialFilled, handle: handle,
                onFillChange: { report in
                    done = report.done; remaining = report.remaining; canUndo = report.canUndo
                    if report.completedColor == sel {
                        let next = Self.firstIncomplete(data, report.remaining)
                        if remaining[next] > 0 { sel = next }
                    }
                    onProgress(report.done, report.total)
                    // In the demo, persist progress (so the canvas is kept in the library) and
                    // glide the next-biggest piece to center after each fill.
                    if onboarding && report.done > 0 {
                        model.saveSession(handle.state())
                        DispatchQueue.main.async { handle.hintBiggest() }
                    }
                },
                onComplete: { onboarding ? onFinishOnboarding() : model.finishPaint(handle.state()) },
                onWrong: { shakeTrigger += 1; FX.shared.haptic("wrong") },
                onFill: { ci in if sound { FX.shared.fill(ci) }; FX.shared.haptic() },
                onMagic: { if sound { FX.shared.magic() } },
                onView: { minimap = $0 }
            )
            .ignoresSafeArea()

            MinimapOverlay(view: minimap, thumb: model.sourceThumb)

            topBar
            rightRail
            bottomDock

            if tut && !onboarding {
                TutorialOverlay { tut = false; model.finishTutorial() }
            }
        }
        .modifier(ShakeEffect(shakes: shakeTrigger))
        .animation(.linear(duration: 0.34), value: shakeTrigger)
        .onAppear {
            // In the onboarding demo, fly to and pulse the largest piece of the first color
            // so the user has an obvious, satisfying place to tap.
            if onboarding {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { handle.hintBiggest() }
            }
        }
        .onChange(of: mode) { _, m in if m != "paint" { brushing = false } }
        .onChange(of: sound) { _, on in
            FX.shared.setEnabled(on)
            if on { FX.shared.ambienceOn() } else { FX.shared.ambienceOff() }
            UserDefaults.standard.set(on ? "1" : "0", forKey: "numbra_sound")
        }
        .onDisappear { FX.shared.ambienceOff() }
    }

    // MARK: top bar

    private var topBar: some View {
        VStack {
            HStack(spacing: 9) {
                canvasButton("back", label: "Back") { onboarding ? onFinishOnboarding() : model.exitPaint(handle.state()) }
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(settings.dark ? Color.white.opacity(0.14) : Color.black.opacity(0.07))
                            Capsule().fill(Theme.terra).frame(width: g.size.width * CGFloat(pct) / 100)
                                .animation(.easeOut(duration: 0.3), value: pct)
                        }
                    }
                    .frame(height: 8)
                    Text("\(pct)% · \(done)/\(total) pieces")
                        .font(Theme.ui(11.5, weight: .bold))
                        .foregroundStyle(settings.dark ? .white.opacity(0.65) : Theme.muted)
                }
                canvasButton("undo", label: "Undo", disabled: !canUndo) { handle.undo() }
                canvasButton("target", label: "Find next piece") { handle.hint() }
                if !onboarding {
                    Menu {
                        Button { model.restartActive() } label: { Label("Change difficulty", systemImage: "slider.horizontal.3") }
                        Button { model.exitPaint(handle.state()) } label: { Label("Save & exit to studio", systemImage: "square.grid.2x2") }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .bold)).foregroundStyle(ink)
                            .frame(width: 42, height: 42)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.ultraThinMaterial))
                            .shadow(color: .black.opacity(0.12), radius: 5, y: 3)
                    }
                    .accessibilityLabel("More options")
                }
            }
            .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 10)
            .background(LinearGradient(colors: [settings.canvasBg, settings.canvasBg.opacity(0)], startPoint: .top, endPoint: .bottom).ignoresSafeArea(edges: .top))
            Spacer()
        }
    }

    // MARK: right rail

    private var rightRail: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    canvasButton("plusN", label: "Zoom in") { handle.zoomBy(1.5) }
                    canvasButton("minus", label: "Zoom out") { handle.zoomBy(0.66) }
                    canvasButton("fit", label: "Fit to screen") { handle.fitView() }
                    canvasButton(sound ? "sound" : "mute", label: "Sound & ambience", on: sound) { sound.toggle() }
                    // Brush toggle lives here (in paint mode) — right under the thumb, next to
                    // zoom, for quick switching between moving and painting.
                    if mode == "paint" {
                        Button { withAnimation(.easeOut(duration: 0.15)) { brushing.toggle() } } label: {
                            Icon(name: "brush", size: 23, color: .white, weight: .bold)
                                .frame(width: 52, height: 52)
                                .background(RoundedRectangle(cornerRadius: 17, style: .continuous)
                                    .fill(brushing ? Theme.terra : Theme.sage))
                                .shadow(color: (brushing ? Theme.terra : Theme.sage).opacity(0.4), radius: 9, y: 6)
                                .overlay(alignment: .topTrailing) {
                                    if !brushing {
                                        Image(systemName: "hand.draw.fill")
                                            .font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                                            .padding(4).background(Circle().fill(Theme.ink)).offset(x: 4, y: -4)
                                    }
                                }
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel(brushing ? "Brush on — one finger paints" : "Brush off — one finger moves the canvas")
                    }
                }
                .padding(.trailing, 12)
            }
            .padding(.bottom, 188)
        }
    }

    // MARK: bottom dock

    private var bottomDock: some View {
        VStack {
            Spacer()
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Segmented(value: $mode, options: [
                        SegOption(value: "tap", label: "Tap", icon: "tap"),
                        SegOption(value: "paint", label: "Paint", icon: "brush"),
                    ])
                    Button { handle.magicFill() } label: {
                        Icon(name: "wand", size: 23, color: .white, weight: .regular)
                            .frame(width: 48, height: 48)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.sage))
                            .shadow(color: Theme.sage.opacity(0.34), radius: 8, y: 6)
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Magic fill")
                }
                .padding(.horizontal, 14).padding(.bottom, 12)

                if mode == "paint" {
                    Text(brushing ? "Brush on — drag to paint this color" : "Drag to move · tap the brush to paint")
                        .font(Theme.ui(11.5, weight: .semibold))
                        .foregroundStyle(settings.dark ? .white.opacity(0.6) : Theme.muted)
                        .padding(.bottom, 8)
                }

                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(data.palette.indices, id: \.self) { i in
                            swatch(i)
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 8)
                }
                .scrollIndicators(.hidden)
            }
            .padding(.top, 14).padding(.bottom, 20)
            .background(LinearGradient(colors: [settings.canvasBg, settings.canvasBg.opacity(0)], startPoint: .bottom, endPoint: .top).ignoresSafeArea(edges: .bottom))
        }
    }

    private func swatch(_ i: Int) -> some View {
        let c = data.palette[i]
        let rem = remaining[i]
        let active = i == sel
        let finished = rem == 0
        return Button { sel = i } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(hex: UInt32((c.r << 16) | (c.g << 8) | c.b)))
                        .frame(width: 52, height: 52)
                        .overlay(c.light ? RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.black.opacity(0.12), lineWidth: 1.5) : nil)
                        // Ring radius = swatch radius (16) + outward inset (3) so it stays
                        // concentric with the swatch corner instead of looking pinched.
                        .overlay(active ? RoundedRectangle(cornerRadius: 19, style: .continuous).strokeBorder(Theme.terra, lineWidth: 3).padding(-3) : nil)
                        .shadow(color: .black.opacity(active ? 0 : 0.16), radius: 4, y: 3)
                    if finished {
                        Icon(name: "check", size: 22, color: c.light ? Color(hex: 0x2b2722) : .white, weight: .heavy)
                    } else {
                        Text("\(c.num)").font(Theme.ui(19, weight: .heavy))
                            .foregroundStyle(c.light ? Color(hex: 0x2b2722).opacity(0.85) : .white.opacity(0.95))
                    }
                }
                if !finished {
                    Text("\(rem)").font(Theme.ui(11.5, weight: .bold))
                        .foregroundStyle(settings.dark ? .white.opacity(0.6) : Theme.muted)
                } else {
                    Text(" ").font(Theme.ui(11.5, weight: .bold))
                }
            }
            .frame(width: 58)
            .opacity(finished ? 0.4 : 1)
            .offset(y: active ? -6 : 0)
            .animation(.easeOut(duration: 0.15), value: active)
        }
        .buttonStyle(.plain)
    }

    // MARK: canvas icon button

    private func canvasButton(_ name: String, label: String, disabled: Bool = false, on: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: { if !disabled { action() } }) {
            Icon(name: name, size: 21, color: on ? .white : ink, weight: .semibold)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(on ? AnyShapeStyle(Theme.sage) : AnyShapeStyle(.ultraThinMaterial))
                )
                .shadow(color: .black.opacity(0.12), radius: 5, y: 3)
        }
        .buttonStyle(.plain)
        .opacity(disabled ? 0.4 : 1)
        .disabled(disabled)
        .accessibilityLabel(label)
    }

    static func firstIncomplete(_ data: PBNData, _ remaining: [Int]) -> Int {
        for i in 0..<data.palette.count where remaining[i] > 0 { return i }
        return 0
    }
}

/// Horizontal shake for wrong placements (paint-screen.jsx `shakeX`).
/// `animatableData` interpolates continuously between successive `shakes` values,
/// so sin() sweeps several oscillations per increment.
struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    init(shakes: Int) { animatableData = CGFloat(shakes) }
    func effectValue(size: CGSize) -> ProjectionTransform {
        let dx = 8 * sin(animatableData * .pi * 6)
        return ProjectionTransform(CGAffineTransform(translationX: dx, y: 0))
    }
}
