import SwiftUI
import UIKit

// MARK: - supporting types

enum Screen { case gallery, upload, difficulty, processing, paint, complete }

/// Difficulty presets (screens.jsx `DIFFS`).
struct Difficulty: Identifiable, Equatable {
    let id: String
    let label: String
    let colors: Int
    let detail: Int
    let sub: String
    let pieces: String

    static let all: [Difficulty] = [
        Difficulty(id: "easy", label: "Easy", colors: 20, detail: 132, sub: "Big, relaxing areas", pieces: "~150 pieces"),
        Difficulty(id: "medium", label: "Medium", colors: 32, detail: 192, sub: "A balanced session", pieces: "~350 pieces"),
        Difficulty(id: "hard", label: "Hard", colors: 48, detail: 264, sub: "Fine, intricate detail", pieces: "~650 pieces"),
    ]
}

struct Picked {
    var image: CGImage
    var title: String
    var custom: Bool
    var id: String?
    var isDaily: Bool = false
    var thumb: UIImage { UIImage(cgImage: image) }
}

struct PaintSession {
    /// Region data; nil after a relaunch until regenerated from `colors`/`detail`
    /// (the engine is deterministic, so the same source + options rebuild identical regions).
    var data: PBNData?
    var colors: Int
    var detail: Int
    var filled: [UInt8]?
    var order: [Int32]?
    var elapsed: TimeInterval
    var isHard: Bool
}

struct Project: Identifiable {
    let id: String
    var title: String
    var image: CGImage
    var thumb: UIImage
    var colors: Int
    var progress: Double
    var session: PaintSession?
}

struct Pack: Identifiable {
    let id: String
    let title: String
    let sceneIds: [String]
    let plus: Bool
    let count: Int
    var covers: [UIImage]
}

struct CompleteInfo {
    var img: UIImage
    var before: UIImage?
    var time: String
    var pieces: String
    var xp: String
    var data: PBNData?
    var order: [Int32]?
}

enum Overlay {
    case timelapse(data: PBNData, order: [Int32]?)
    case share(before: UIImage?, after: UIImage)
}

enum PaywallPending: Equatable {
    case generic
    case config(Difficulty)
}

struct ToastInfo: Identifiable {
    let id = UUID()
    var icon: String
    var color: Color
    var title: String
    var sub: String?
}

struct PaintSettings {
    var paper = "#F4EEDF"
    var dark = false
    var showNumbers = true
    var defaultMode = "tap"
    var colorblind = false
    var canvasBg: Color { dark ? Theme.chromeDark : Theme.chromeLight }
    var paperRGB: (Int, Int, Int) { Color.rgbTriple(paper) }
}

// MARK: - app model (navigation + state machine, app.jsx)

@MainActor
@Observable
final class AppModel {
    var screen: Screen = .gallery
    var projects: [Project] = []
    var picked: Picked?
    var data: PBNData?
    var initialFilled: [UInt8]?
    var sourceThumb: UIImage?
    var activeId: String?

    var isPlus = UserDefaults.standard.bool(forKey: "numbra_plus")
    var paywall: PaywallPending?
    var complete: CompleteInfo?
    var overlay: Overlay?
    var achOpen = false
    var packSheet: Pack?
    var toast: ToastInfo?

    var progress = Progression.touchOpen()
    var onboarded = UserDefaults.standard.string(forKey: "numbra_onboarded") == "1"
    var tutSeen = UserDefaults.standard.string(forKey: "numbra_tut") == "1"

    let settings = PaintSettings()

    private var startTime: Date = .now
    private var meta = (isCustom: false, isHard: false, isDaily: false)
    /// Engine options of the canvas being painted — recorded so the session can be
    /// regenerated after a relaunch.
    private var engineCfg = (colors: 0, detail: 0)

    private static let sampleMeta: [(id: String, key: String, title: String, colors: Int, progress: Double)] = [
        ("starry", "starry", "Starry Night", 14, 0),
        ("wave", "wave", "The Great Wave", 14, 0),
        ("sunset", "sunset", "Sunset Coast", 14, 0),
        ("lake", "lake", "Mountain Lake", 14, 0),
        ("bloom", "bloom", "In Bloom", 14, 0),
        ("balloon", "balloon", "Sky Drifter", 14, 0),
    ]

    private static let packMeta: [(id: String, title: String, sceneIds: [String], plus: Bool, count: Int?)] = [
        ("masters", "The Masters", ["starry", "wave"], false, nil),
        ("coast", "Coastlines", ["sunset", "lake"], false, nil),
        ("florals", "Florals", ["bloom", "sunset"], false, nil),
        ("skies", "Big Skies", ["balloon", "starry"], true, 12),
        ("nights", "City Nights", ["starry", "balloon"], true, 10),
    ]

    func bootstrap() {
        guard projects.isEmpty else { return }
        Task.detached(priority: .userInitiated) {
            let built: [(id: String, title: String, cg: CGImage, colors: Int, progress: Double)] =
                Self.sampleMeta.map { m in
                    (m.id, m.title, PBNSamples.make(m.key, size: 520), m.colors, m.progress)
                }
            let saved = ProjectStore.load()
            let savedImages: [String: CGImage] = saved.reduce(into: [:]) { acc, s in
                if !built.contains(where: { $0.id == s.id }), let cg = ProjectStore.loadImage(id: s.id) {
                    acc[s.id] = cg
                }
            }
            await MainActor.run {
                var samples = built.map {
                    Project(id: $0.id, title: $0.title, image: $0.cg, thumb: UIImage(cgImage: $0.cg),
                            colors: $0.colors, progress: $0.progress, session: nil)
                }
                // Rebuild the library in its saved order: samples get their saved progress and
                // session overlaid; custom projects come back from their saved PNGs.
                var merged: [Project] = []
                for s in saved {
                    let session = s.session.map {
                        PaintSession(data: nil, colors: $0.colors, detail: $0.detail,
                                     filled: [UInt8]($0.filled), order: $0.order,
                                     elapsed: $0.elapsed, isHard: $0.isHard)
                    }
                    if let idx = samples.firstIndex(where: { $0.id == s.id }) {
                        var p = samples.remove(at: idx)
                        p.progress = s.progress
                        p.session = session
                        merged.append(p)
                    } else if let cg = savedImages[s.id] {
                        merged.append(Project(id: s.id, title: s.title, image: cg, thumb: UIImage(cgImage: cg),
                                              colors: s.colors, progress: s.progress, session: session))
                    }
                }
                merged.append(contentsOf: samples)   // first run, or samples added since last save
                self.projects = merged
            }
        }
    }

    /// Serialize the whole library (cheap: fill states are a few hundred bytes each).
    private func persist() {
        ProjectStore.save(projects.map { p in
            ProjectStore.SavedProject(id: p.id, title: p.title, colors: p.colors, progress: p.progress,
                                      session: p.session.flatMap { s in
                                          guard let filled = s.filled else { return nil }
                                          return ProjectStore.SavedSession(colors: s.colors, detail: s.detail,
                                                                           filled: Data(filled), order: s.order ?? [],
                                                                           elapsed: s.elapsed, isHard: s.isHard)
                                      })
        })
    }

    private func isBuiltIn(_ id: String) -> Bool { Self.sampleMeta.contains { $0.id == id } }

    func sampleById(_ id: String) -> Project? { projects.first { $0.id == id } }

    /// Index into the built-in samples only — custom projects sit in the same list (and
    /// persist across launches), so positional indexing into `projects` would drift.
    var daily: Project? {
        let samples = sampleProjects
        guard !samples.isEmpty else { return nil }
        return samples[Progression.dailyIndex(samples.count)]
    }

    var packs: [Pack] {
        guard !projects.isEmpty else { return [] }
        return Self.packMeta.map { pk in
            let covers = pk.sceneIds.prefix(2).compactMap { sampleById($0)?.thumb }
            return Pack(id: pk.id, title: pk.title, sceneIds: pk.sceneIds, plus: pk.plus,
                        count: pk.count ?? pk.sceneIds.count, covers: Array(covers))
        }
    }

    var sampleProjects: [Project] { projects.filter { p in Self.sampleMeta.contains { $0.id == p.id } } }

    var projTitle: String { projects.first { $0.id == activeId }?.title ?? "Your painting" }

    // MARK: navigation

    func goNew() { picked = nil; screen = .upload }
    func pickImage(_ chosen: Picked) { picked = chosen; screen = .difficulty }

    func startPaint(_ d: PBNData, filled: [UInt8]?, thumb: UIImage?) {
        data = d; initialFilled = filled; sourceThumb = thumb; screen = .paint
    }

    func runEngine(_ cfg: Difficulty) {
        guard let picked else { return }
        progress = Progression.play()
        meta = (isCustom: picked.custom, isHard: cfg.id == "hard", isDaily: picked.isDaily)
        screen = .processing
        let src = picked.image
        let title = picked.title
        let custom = picked.custom
        let pid = picked.id
        Task {
            async let gen = Task.detached(priority: .userInitiated) {
                PBNEngine.generate(src, options: .init(colors: cfg.colors, detail: cfg.detail))
            }.value
            try? await Task.sleep(nanoseconds: 720_000_000)
            let d = await gen
            self.startTime = .now
            self.engineCfg = (cfg.colors, cfg.detail)
            let id = pid ?? "custom-\(Int(Date().timeIntervalSince1970 * 1000))"
            self.activeId = id
            if custom {
                self.projects.insert(Project(id: id, title: title, image: src, thumb: UIImage(cgImage: src),
                                             colors: cfg.colors, progress: 0, session: nil), at: 0)
                ProjectStore.saveImage(src, id: id)
                self.persist()
            }
            self.startPaint(d, filled: nil, thumb: UIImage(cgImage: src))
        }
    }

    func openProject(_ p: Project) {
        activeId = p.id
        meta = (isCustom: p.id.hasPrefix("custom"), isHard: p.session?.isHard ?? false, isDaily: false)
        if p.progress >= 1 {
            // Completed → the celebration screen (replay timelapse / share / start over).
            if let s = p.session, s.data == nil {
                revive(p, s) { self.showComplete(for: $0) }
            } else {
                showComplete(for: p)
            }
        } else if let session = p.session {
            // In progress → resume straight into the canvas (no Difficulty detour).
            progress = Progression.play()
            engineCfg = (session.colors, session.detail)
            if let d = session.data {
                startTime = Date().addingTimeInterval(-session.elapsed)
                startPaint(d, filled: session.filled, thumb: p.thumb)
            } else {
                revive(p, session) { proj in
                    guard let s = proj.session, let d = s.data else { return }
                    self.startTime = Date().addingTimeInterval(-s.elapsed)
                    self.startPaint(d, filled: s.filled, thumb: proj.thumb)
                }
            }
        } else {
            // Never started (or in-memory state lost) → choose a difficulty to generate.
            picked = Picked(image: p.image, title: p.title, custom: false, id: p.id)
            screen = .difficulty
        }
    }

    /// Regenerate the region data for a session restored from disk, behind the processing
    /// loader. The engine is pure, so the saved source + options rebuild identical regions;
    /// if the saved fill state no longer matches (engine changed between app versions), the
    /// session is dropped back to the difficulty selector rather than restored corrupt.
    private func revive(_ p: Project, _ s: PaintSession, then: @escaping (Project) -> Void) {
        picked = Picked(image: p.image, title: p.title, custom: p.id.hasPrefix("custom"), id: p.id)
        screen = .processing
        let src = p.image
        Task {
            let d = await Task.detached(priority: .userInitiated) {
                PBNEngine.generate(src, options: .init(colors: s.colors, detail: s.detail))
            }.value
            guard let idx = self.projects.firstIndex(where: { $0.id == p.id }) else { return }
            if let filled = s.filled, filled.count != d.regionCount {
                self.projects[idx].progress = 0
                self.projects[idx].session = nil
                self.persist()
                self.screen = .difficulty
                return
            }
            self.projects[idx].session?.data = d
            then(self.projects[idx])
        }
    }

    /// Build the Complete screen for an already-finished project, reusing its session data
    /// (if present) so timelapse replay and share work; otherwise a minimal celebration.
    private func showComplete(for p: Project) {
        if let s = p.session, let d = s.data {
            complete = CompleteInfo(img: Painter.painted(d), before: p.thumb,
                                    time: Self.fmtTime(s.elapsed), pieces: String(d.regionCount),
                                    xp: "", data: d, order: s.order)
        } else {
            complete = CompleteInfo(img: p.thumb, before: p.thumb, time: "—", pieces: "✓", xp: "", data: nil, order: nil)
        }
        sourceThumb = p.thumb
        screen = .complete
    }

    /// Restart the active painting by reopening the difficulty selector (regenerate / start
    /// over at any difficulty). Used by "Paint again" on the Complete screen and the in-canvas
    /// "Change difficulty" action.
    func restartActive() {
        guard let id = activeId, let p = projects.first(where: { $0.id == id }) else { screen = .gallery; return }
        resetProject(p)
    }

    /// Reset a painting back to a clean slate and reopen Difficulty so it can be regenerated
    /// (e.g. at a different difficulty) or started over. Distinct from resume.
    func resetProject(_ p: Project) {
        if let idx = projects.firstIndex(where: { $0.id == p.id }) {
            projects[idx].progress = 0
            projects[idx].session = nil
            persist()
        }
        activeId = p.id
        picked = Picked(image: p.image, title: p.title, custom: p.id.hasPrefix("custom"), id: p.id)
        screen = .difficulty
    }

    /// Remove a user-created project (and its saved image) from the library. Built-in
    /// samples can only be reset, not deleted.
    func deleteProject(_ p: Project) {
        guard !isBuiltIn(p.id) else { return }
        projects.removeAll { $0.id == p.id }
        ProjectStore.deleteImage(id: p.id)
        persist()
    }

    func canDelete(_ p: Project) -> Bool { !isBuiltIn(p.id) }

    func unlockPlus() {
        isPlus = true
        UserDefaults.standard.set(true, forKey: "numbra_plus")
    }

    func startDaily() {
        guard let daily else { return }
        picked = Picked(image: daily.image, title: daily.title, custom: false, id: daily.id, isDaily: true)
        screen = .difficulty
    }

    func openPack(_ pack: Pack) {
        if pack.plus && !isPlus { paywall = .generic; return }
        packSheet = pack
    }

    func startSceneFromPack(_ scene: Project) {
        packSheet = nil
        picked = Picked(image: scene.image, title: scene.title, custom: false, id: scene.id)
        screen = .difficulty
    }

    /// Set up the free onboarding canvas as a real, resumable project so the user keeps it in
    /// their library (they can finish it later). Generated at the hardest preset.
    func beginOnboardingCanvas(_ d: PBNData, src: CGImage, cfg: Difficulty) {
        let id = "onboarding-first"
        activeId = id
        data = d
        initialFilled = nil
        sourceThumb = UIImage(cgImage: src)
        startTime = .now
        meta = (isCustom: true, isHard: true, isDaily: false)
        engineCfg = (cfg.colors, cfg.detail)
        if !projects.contains(where: { $0.id == id }) {
            projects.insert(Project(id: id, title: "Your first canvas", image: src,
                                    thumb: UIImage(cgImage: src), colors: cfg.colors, progress: 0, session: nil), at: 0)
            ProjectStore.saveImage(src, id: id)
            persist()
        }
    }

    func saveSession(_ st: PaintCanvasEngine.State?) {
        guard let st, let data, let activeId else { return }
        let elapsed = Date().timeIntervalSince(startTime)
        if let idx = projects.firstIndex(where: { $0.id == activeId }) {
            projects[idx].progress = Double(st.done) / Double(st.total)
            projects[idx].session = PaintSession(data: data, colors: engineCfg.colors, detail: engineCfg.detail,
                                                 filled: st.filled, order: st.order,
                                                 elapsed: elapsed, isHard: meta.isHard)
            persist()
        }
    }

    func exitPaint(_ st: PaintCanvasEngine.State?) {
        saveSession(st)
        screen = .gallery
    }

    func finishPaint(_ st: PaintCanvasEngine.State?) {
        guard let data else { return }
        let elapsed = Date().timeIntervalSince(startTime)
        let mistakes = st?.mistakes ?? 0
        let order = st?.order
        if let activeId, let idx = projects.firstIndex(where: { $0.id == activeId }) {
            projects[idx].progress = 1
            projects[idx].session = PaintSession(data: data, colors: engineCfg.colors, detail: engineCfg.detail,
                                                 filled: st?.filled, order: order,
                                                 elapsed: elapsed, isHard: meta.isHard)
            persist()
        }
        let res = Progression.recordCompletion(pieces: data.regionCount, mistakes: mistakes,
                                               isCustom: meta.isCustom, isHard: meta.isHard, isDaily: meta.isDaily)
        progress = res.progress
        if let first = res.newly.first {
            toast = ToastInfo(icon: first.icon, color: Theme.sage, title: first.title,
                              sub: "Achievement unlocked · +\(res.xpGain) XP")
        } else {
            toast = ToastInfo(icon: "star", color: Theme.terra, title: "+\(res.xpGain) XP",
                              sub: res.leveledUp ? "Level \(res.level) reached!" : (mistakes == 0 ? "Flawless run!" : "Nicely done"))
        }
        let finalImg = Painter.painted(data)
        // `sourceThumb` is the exact image fed to the engine (same aspect as the painted
        // render), so the before/after panels show the same picture. Fall back to the
        // project thumb only if we somehow lost the source.
        let before = sourceThumb ?? sampleById(activeId ?? "")?.thumb
        complete = CompleteInfo(img: finalImg, before: before, time: Self.fmtTime(elapsed),
                                pieces: String(data.regionCount), xp: "+\(res.xpGain)", data: data, order: order)
        screen = .complete
    }

    func finishOnboarding() {
        onboarded = true
        UserDefaults.standard.set("1", forKey: "numbra_onboarded")
        // The guided onboarding demo already taught tap/paint/magic, so skip the redundant
        // in-canvas tutorial on the first real painting.
        finishTutorial()
    }
    func finishTutorial() {
        tutSeen = true
        UserDefaults.standard.set("1", forKey: "numbra_tut")
    }

    static func fmtTime(_ ms: TimeInterval) -> String {
        let s = Int(ms.rounded()); let m = s / 60
        return "\(m):\(String(format: "%02d", s % 60))"
    }
}

// MARK: - imaging helpers (renderFinal / thumbs from app.jsx)

enum Painter {
    /// Normalize a picked photo: bake in EXIF orientation and cap the long side so the
    /// canvas source (and its persisted PNG) stays small — the engine reads at most
    /// `detail` (≤264) pixels per side anyway.
    static func normalized(_ ui: UIImage, maxSide: CGFloat = 1024) -> CGImage? {
        let w = ui.size.width, h = ui.size.height
        guard w > 0, h > 0 else { return nil }
        let k = min(1, maxSide / max(w, h))
        let size = CGSize(width: (w * k).rounded(), height: (h * k).rounded())
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        fmt.opaque = true
        return UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
            ui.draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }

    /// A fully-painted render of the data (renderFinal in app.jsx).
    static func painted(_ data: PBNData) -> UIImage {
        let w = data.w, h = data.h
        var px = [UInt8](repeating: 255, count: w * h * 4)
        px.withUnsafeMutableBufferPointer { d in
            for r in 0..<data.regionCount {
                let c = data.palette[Int(data.regionColor[r])]
                for pp in data.regionPixels[r] {
                    let p = Int(pp)
                    d[p * 4] = UInt8(c.r); d[p * 4 + 1] = UInt8(c.g); d[p * 4 + 2] = UInt8(c.b); d[p * 4 + 3] = 255
                }
            }
        }
        let space = CGColorSpaceCreateDeviceRGB()
        let cg = px.withUnsafeMutableBytes { raw -> CGImage? in
            CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        }
        return cg.map { UIImage(cgImage: $0) } ?? UIImage()
    }
}
