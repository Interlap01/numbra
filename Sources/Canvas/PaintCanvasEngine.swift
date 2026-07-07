import CoreGraphics
import QuartzCore

/// The interactive paint-by-numbers model — a faithful port of the mutable engine
/// state in pbn-canvas.jsx. Deliberately NOT observable: all state lives here and is
/// driven imperatively for performance (re-rendering per fill would not perform).
///
/// Owns: the fill & highlight pixel buffers, the boundary path, the image→screen
/// transform, fill/undo order, mistakes, and the transient hint/magic/ring effects.
/// The platform view reads this state to render and forwards touches to the actions.
final class PaintCanvasEngine {

    struct Transform { var scale: CGFloat; var tx: CGFloat; var ty: CGFloat }
    struct Ring { var x: CGFloat; var y: CGFloat; var r: CGFloat; var t: CFTimeInterval }
    struct Wrong { var x: CGFloat; var y: CGFloat; var t: CFTimeInterval }

    struct FillReport { let done: Int; let total: Int; let remaining: [Int]; let completedColor: Int; let canUndo: Bool }
    struct State { let filled: [UInt8]; let order: [Int32]; let mistakes: Int; let done: Int; let total: Int }

    // configuration set by the host view
    var selColor: Int = -1
    var paperRGB: (Int, Int, Int) = (0xF4, 0xEE, 0xDF)
    var mode: String = "tap"   // "tap" | "paint"
    var seamColor: CGColor = CGColor(red: 60 / 255, green: 45 / 255, blue: 30 / 255, alpha: 0.28)
    var showNumbers: Bool = true

    // callbacks
    var onFillChange: ((FillReport) -> Void)?
    var onComplete: (() -> Void)?
    var onWrong: (() -> Void)?
    var onFill: ((Int) -> Void)?
    var onMagic: (() -> Void)?
    var onNeedsDraw: (() -> Void)?

    private(set) var data: PBNData!
    private(set) var filled: [UInt8] = []
    private(set) var filledPerColor: [Int] = []
    private(set) var order: [Int32] = []
    private(set) var mistakes = 0

    private var fillBuf: [UInt8] = []   // RGBA, w*h*4
    private var hlBuf: [UInt8] = []     // RGBA, w*h*4
    private var fillDirty = true
    private var hlDirty = true
    private var fillImageCache: CGImage?
    private var hlImageCache: CGImage?

    private(set) var boundary = CGMutablePath()

    // transform / layout
    var t = Transform(scale: 1, tx: 0, ty: 0)
    private(set) var fit: CGFloat = 1
    private(set) var minScale: CGFloat = 1
    private(set) var maxScale: CGFloat = 16
    private(set) var cssW: CGFloat = 0
    private(set) var cssH: CGFloat = 0

    // transient effects
    private(set) var rings: [Ring] = []
    var wrong: Wrong?
    var hintPulse: CGFloat = 0

    // animations
    private var tween: (start: Transform, target: Transform, t0: CFTimeInterval, dur: CFTimeInterval)?
    private var hintFade: CFTimeInterval?
    private var magic: (targets: [Int32], i: Int, nextAt: CFTimeInterval)?

    private let colorSpace = CGColorSpaceCreateDeviceRGB()

    // MARK: - setup

    func setup(data: PBNData, initialFilled: [UInt8]?) {
        self.data = data
        let n = data.regionCount
        filled = [UInt8](repeating: 0, count: n)
        filledPerColor = [Int](repeating: 0, count: data.palette.count)
        order = []
        mistakes = 0
        rings = []
        wrong = nil
        partial = [:]
        lastBrush = nil
        tween = nil; hintFade = nil; magic = nil; hintPulse = 0

        let count = data.w * data.h * 4
        fillBuf = [UInt8](repeating: 0, count: count)
        hlBuf = [UInt8](repeating: 0, count: count)
        paintPaper()

        boundary = CGMutablePath()
        let seg = data.segments
        var i = 0
        while i < seg.count {
            boundary.move(to: CGPoint(x: CGFloat(seg[i]), y: CGFloat(seg[i + 1])))
            boundary.addLine(to: CGPoint(x: CGFloat(seg[i + 2]), y: CGFloat(seg[i + 3])))
            i += 4
        }

        if let init0 = initialFilled, init0.count == n {
            filled = init0
            for i in 0..<filledPerColor.count { filledPerColor[i] = 0 }
            order = []
            for r in 0..<n where filled[r] != 0 { filledPerColor[Int(data.regionColor[r])] += 1; order.append(Int32(r)) }
            repaintAllFilled()
        }
        fillDirty = true; hlDirty = true
        updateHighlight()
        reportFill(nil)
    }

    /// Re-tint paper & re-derive highlight when selected color / paper changes.
    func refreshForSelection() {
        guard data != nil else { return }
        paintPaper()
        repaintAllFilled()
        repaintPartial()
        updateHighlight()
        onNeedsDraw?()
    }

    // MARK: - buffer ops

    private func paintPaper() {
        let (pr, pg, pb) = paperRGB
        let n = data.w * data.h
        fillBuf.withUnsafeMutableBufferPointer { d in
            for i in 0..<n { d[i * 4] = UInt8(pr); d[i * 4 + 1] = UInt8(pg); d[i * 4 + 2] = UInt8(pb); d[i * 4 + 3] = 255 }
        }
        fillDirty = true
    }

    private func repaintAllFilled() {
        fillBuf.withUnsafeMutableBufferPointer { d in
            for r in 0..<data.regionCount where filled[r] != 0 {
                let col = data.palette[Int(data.regionColor[r])]
                for pp in data.regionPixels[r] {
                    let p = Int(pp)
                    d[p * 4] = UInt8(col.r); d[p * 4 + 1] = UInt8(col.g); d[p * 4 + 2] = UInt8(col.b); d[p * 4 + 3] = 255
                }
            }
        }
        fillDirty = true
    }

    private func updateHighlight() {
        let n = data.w * data.h
        hlBuf.withUnsafeMutableBufferPointer { d in
            for i in 0..<(n * 4) { d[i] = 0 }
            let sel = selColor
            if sel >= 0 {
                let col = data.palette[sel]
                for r in 0..<data.regionCount {
                    if filled[r] != 0 || Int(data.regionColor[r]) != sel { continue }
                    let cov = partial[r]
                    for pp in data.regionPixels[r] {
                        if cov?.contains(pp) == true { continue }   // already brushed in → no highlight
                        let p = Int(pp)
                        d[p * 4] = UInt8(col.r); d[p * 4 + 1] = UInt8(col.g); d[p * 4 + 2] = UInt8(col.b); d[p * 4 + 3] = 255
                    }
                }
            }
        }
        hlDirty = true
    }

    @discardableResult
    private func fillRegion(_ r: Int, silent: Bool = false, quiet: Bool = false) -> Bool {
        if filled[r] != 0 { return false }
        filled[r] = 1
        partial[r] = nil   // any in-progress brush coverage is now part of the completed fill
        order.append(Int32(r))
        let ci = Int(data.regionColor[r])
        filledPerColor[ci] += 1
        let col = data.palette[ci]
        fillBuf.withUnsafeMutableBufferPointer { d in
            hlBuf.withUnsafeMutableBufferPointer { hd in
                for pp in data.regionPixels[r] {
                    let p = Int(pp)
                    d[p * 4] = UInt8(col.r); d[p * 4 + 1] = UInt8(col.g); d[p * 4 + 2] = UInt8(col.b); d[p * 4 + 3] = 255
                    hd[p * 4 + 3] = 0
                }
            }
        }
        fillDirty = true; hlDirty = true
        if !silent {
            let c = data.centroids[r]
            rings.append(Ring(x: CGFloat(c.x), y: CGFloat(c.y), r: CGFloat(c.r), t: CACurrentMediaTime()))
        }
        if !quiet { onFill?(ci) }
        reportFill(ci)
        return true
    }

    private func unfillRegion(_ r: Int) {
        if filled[r] == 0 { return }
        filled[r] = 0
        let ci = Int(data.regionColor[r])
        filledPerColor[ci] -= 1
        let (pr, pg, pb) = paperRGB
        let restoreHl = ci == selColor
        let col = data.palette[ci]
        fillBuf.withUnsafeMutableBufferPointer { d in
            hlBuf.withUnsafeMutableBufferPointer { hd in
                for pp in data.regionPixels[r] {
                    let p = Int(pp)
                    d[p * 4] = UInt8(pr); d[p * 4 + 1] = UInt8(pg); d[p * 4 + 2] = UInt8(pb); d[p * 4 + 3] = 255
                    if restoreHl {
                        hd[p * 4] = UInt8(col.r); hd[p * 4 + 1] = UInt8(col.g); hd[p * 4 + 2] = UInt8(col.b); hd[p * 4 + 3] = 255
                    }
                }
            }
        }
        fillDirty = true; hlDirty = true
        reportFill(ci)
    }

    private func reportFill(_ ci: Int?) {
        var done = 0
        for r in 0..<data.regionCount where filled[r] != 0 { done += 1 }
        var remaining = [Int](repeating: 0, count: data.palette.count)
        for i in 0..<data.palette.count { remaining[i] = data.colorCounts[i] - filledPerColor[i] }
        let completed = (ci != nil && remaining[ci!] == 0) ? ci! : -1
        onFillChange?(FillReport(done: done, total: data.regionCount, remaining: remaining,
                                 completedColor: completed, canUndo: !order.isEmpty))
        if done == data.regionCount { onComplete?() }
    }

    // MARK: - layout / transform

    func layout(cssW: CGFloat, cssH: CGFloat, initial: Bool) {
        guard data != nil, cssW > 0, cssH > 0 else { return }
        self.cssW = cssW; self.cssH = cssH
        let pad: CGFloat = 24
        let f = min((cssW - pad * 2) / CGFloat(data.w), (cssH - pad * 2) / CGFloat(data.h))
        let oldFit = fit
        fit = f
        minScale = f * 0.85
        maxScale = max(f * 14, 40)   // allow deep zoom for precise pixel brushing
        if initial {
            t = Transform(scale: f, tx: (cssW - CGFloat(data.w) * f) / 2, ty: (cssH - CGFloat(data.h) * f) / 2)
        } else if oldFit > 0 {
            let ratio = t.scale / oldFit
            t.scale = f * ratio
            clampT()
        }
    }

    func clampT() {
        t.scale = max(minScale, min(maxScale, t.scale))
        let iw = CGFloat(data.w) * t.scale, ih = CGFloat(data.h) * t.scale
        // Generous overscroll: any point of the canvas — including the far corners — can be
        // dragged all the way to the screen centre, so no region stays trapped behind the
        // toolbar, palette, or floating controls. The pannable range therefore runs from
        // "far edge at centre" to "near edge at centre" on each axis.
        t.tx = max(cssW / 2 - iw, min(cssW / 2, t.tx))
        t.ty = max(cssH / 2 - ih, min(cssH / 2, t.ty))
    }

    // MARK: - coordinate mapping & hit testing

    func regionAt(_ cx: CGFloat, _ cy: CGFloat) -> Int {
        let ix = Int(floor((cx - t.tx) / t.scale)), iy = Int(floor((cy - t.ty) / t.scale))
        if ix < 0 || iy < 0 || ix >= data.w || iy >= data.h { return -1 }
        return Int(data.labels[iy * data.w + ix])
    }

    func imgPt(_ cx: CGFloat, _ cy: CGFloat) -> CGPoint {
        CGPoint(x: (cx - t.tx) / t.scale, y: (cy - t.ty) / t.scale)
    }

    // MARK: - painting actions

    func tryFillAt(_ cx: CGFloat, _ cy: CGFloat) {
        let r = regionAt(cx, cy)
        // Direct hit on an unfilled region of the selected color.
        if r >= 0, filled[r] == 0, Int(data.regionColor[r]) == selColor {
            fillRegion(r); onNeedsDraw?(); return
        }
        // Otherwise try to snap to the nearest unfilled selected-color region within a small
        // tap tolerance — this rescues sub-12px slivers that are nearly untappable at
        // fit-zoom, where a tap routinely lands on a neighbor.
        if let snapped = nearestSelectable(cx, cy) {
            fillRegion(snapped); onNeedsDraw?(); return
        }
        // A genuine miss on a wrong-color region records a mistake (mistake-proof rule).
        if r >= 0, filled[r] == 0 {
            let p = imgPt(cx, cy)
            wrong = Wrong(x: p.x, y: p.y, t: CACurrentMediaTime())
            mistakes += 1
            onWrong?(); onNeedsDraw?()
        }
    }

    /// Nearest unfilled region of the selected color whose centroid is within a screen-space
    /// tap tolerance of the touch point. Returns -1/`nil` when nothing qualifies.
    private func nearestSelectable(_ cx: CGFloat, _ cy: CGFloat) -> Int? {
        guard selColor >= 0 else { return nil }
        let tol: CGFloat = 24          // points of slop around the finger
        var best = -1
        var bd = tol * tol
        for r in 0..<data.regionCount {
            if filled[r] != 0 || Int(data.regionColor[r]) != selColor { continue }
            let c = data.centroids[r]
            let sx = CGFloat(c.x) * t.scale + t.tx, sy = CGFloat(c.y) * t.scale + t.ty
            let d = (sx - cx) * (sx - cx) + (sy - cy) * (sy - cy)
            if d < bd { bd = d; best = r }
        }
        return best >= 0 ? best : nil
    }

    /// Attempt to fill a region by id (used by accessibility activation / automation).
    /// Same mistake-proof semantics as `tryFillAt`, anchored at the region centroid.
    func attemptFill(region r: Int) {
        guard data != nil, r >= 0, r < data.regionCount, filled[r] == 0 else { return }
        if Int(data.regionColor[r]) == selColor {
            fillRegion(r); onNeedsDraw?()
        } else {
            let c = data.centroids[r]
            wrong = Wrong(x: CGFloat(c.x), y: CGFloat(c.y), t: CACurrentMediaTime())
            mistakes += 1
            onWrong?(); onNeedsDraw?()
        }
    }

    // MARK: - brush mode (free pixel painting, persistent coverage)

    /// "Paint" mode colors the *selected* color in pixel-by-pixel under the finger. Nothing
    /// is auto-filled at a halfway point — a piece is only marked complete once it is almost
    /// entirely covered, and the final sliver is then snapped in. Coverage is persistent
    /// (survives selection changes / save). Wrong-color areas under the brush are simply
    /// ignored — no mistakes — so the user can rest a finger or start a two-finger pan/zoom
    /// without the canvas firing a wrong-region.
    private var partial: [Int: Set<Int32>] = [:]   // region → covered pixels (still incomplete)
    private let brushCompleteFraction = 0.95
    private var lastBrush: CGPoint?

    /// Brush radius in image pixels. Kept ≥ ~0.7px so that at high zoom you can paint nearly
    /// pixel-by-pixel, while staying comfortably wide when zoomed out.
    private func brushRadiusImg(screen: CGFloat = 15) -> CGFloat { max(0.7, screen / t.scale) }

    func brushDown(_ cx: CGFloat, _ cy: CGFloat) { lastBrush = nil }

    /// Paint along the segment from the previous sample to this one so fast drags don't gap.
    func brushStroke(_ cx: CGFloat, _ cy: CGFloat) {
        let p = CGPoint(x: cx, y: cy)
        if let last = lastBrush {
            let dx = p.x - last.x, dy = p.y - last.y
            let dist = hypot(dx, dy)
            let step = max(1, brushRadiusImg() * t.scale * 0.6)   // screen px between dabs
            let n = Int(dist / step)
            if n > 0 { for i in 1...n { let f = CGFloat(i) / CGFloat(n); dab(last.x + dx * f, last.y + dy * f) } }
        }
        dab(p.x, p.y)
        lastBrush = p
    }

    func brushUp() { lastBrush = nil }

    private func dab(_ cx: CGFloat, _ cy: CGFloat) {
        guard data != nil, selColor >= 0 else { return }
        let ip = imgPt(cx, cy)
        let rad = brushRadiusImg(); let radI = Int(ceil(rad)); let rad2 = rad * rad
        let cxI = Int(floor(ip.x)), cyI = Int(floor(ip.y))
        var touched = Set<Int>()
        var newPx: [Int] = []
        fillBuf.withUnsafeMutableBufferPointer { d in
            for dy in -radI...radI {
                let y = cyI + dy; if y < 0 || y >= data.h { continue }
                for dx in -radI...radI {
                    let x = cxI + dx; if x < 0 || x >= data.w { continue }
                    let fdx = CGFloat(x) + 0.5 - ip.x, fdy = CGFloat(y) + 0.5 - ip.y
                    if fdx * fdx + fdy * fdy > rad2 { continue }
                    let p = y * data.w + x
                    let r = Int(data.labels[p])
                    if filled[r] != 0 || Int(data.regionColor[r]) != selColor { continue }
                    if partial[r]?.contains(Int32(p)) == true { continue }
                    partial[r, default: []].insert(Int32(p))
                    let col = data.palette[Int(data.regionColor[r])]
                    d[p * 4] = UInt8(col.r); d[p * 4 + 1] = UInt8(col.g); d[p * 4 + 2] = UInt8(col.b); d[p * 4 + 3] = 255
                    newPx.append(p); touched.insert(r)
                }
            }
        }
        if !newPx.isEmpty {
            hlBuf.withUnsafeMutableBufferPointer { hd in for p in newPx { hd[p * 4 + 3] = 0 } }
            fillDirty = true; hlDirty = true
        }
        // Snap a piece complete only once it's essentially fully painted.
        for r in touched {
            if let cov = partial[r], cov.count >= Int(Double(data.regionPixels[r].count) * brushCompleteFraction) {
                fillRegion(r)   // fills the remainder + emits ring/sound/count; clears partial[r]
            }
        }
        if !newPx.isEmpty { onNeedsDraw?() }
    }

    /// Re-apply persisted partial coverage onto the fill buffer (after a paper/selection reset).
    private func repaintPartial() {
        guard !partial.isEmpty else { return }
        fillBuf.withUnsafeMutableBufferPointer { d in
            for (r, cov) in partial {
                let col = data.palette[Int(data.regionColor[r])]
                for pp in cov { let p = Int(pp); d[p * 4] = UInt8(col.r); d[p * 4 + 1] = UInt8(col.g); d[p * 4 + 2] = UInt8(col.b); d[p * 4 + 3] = 255 }
            }
        }
        fillDirty = true
    }

    func zoomAt(_ cx: CGFloat, _ cy: CGFloat, _ factor: CGFloat) {
        let ip = imgPt(cx, cy)
        var ns = t.scale * factor
        ns = max(minScale, min(maxScale, ns))
        t.scale = ns; t.tx = cx - ip.x * ns; t.ty = cy - ip.y * ns
        clampT(); onNeedsDraw?()
    }

    func pan(toTx tx: CGFloat, ty: CGFloat) { t.tx = tx; t.ty = ty; clampT(); onNeedsDraw?() }

    func cancelTween() { tween = nil }

    private func tweenTo(_ target: Transform, dur: CFTimeInterval) {
        tween = (start: t, target: target, t0: CACurrentMediaTime(), dur: dur)
        onNeedsDraw?()
    }

    // MARK: - imperative API

    func hint() {
        guard data != nil, selColor >= 0 else { return }
        let ccx = (cssW / 2 - t.tx) / t.scale, ccy = (cssH / 2 - t.ty) / t.scale
        var best = -1; var bd = CGFloat.greatestFiniteMagnitude
        for r in 0..<data.regionCount {
            if filled[r] != 0 || Int(data.regionColor[r]) != selColor { continue }
            let c = data.centroids[r]
            let d = pow(CGFloat(c.x) - ccx, 2) + pow(CGFloat(c.y) - ccy, 2)
            if d < bd { bd = d; best = r }
        }
        flyToRegion(best)
    }

    /// Fly to and pulse the *largest* unfilled region of the selected color — used by the
    /// onboarding demo to point at an easy, satisfying first piece.
    func hintBiggest() {
        guard data != nil, selColor >= 0 else { return }
        var best = -1; var bestArea = -1
        for r in 0..<data.regionCount {
            if filled[r] != 0 || Int(data.regionColor[r]) != selColor { continue }
            let a = data.regionPixels[r].count
            if a > bestArea { bestArea = a; best = r }
        }
        flyToRegion(best)
    }

    private func flyToRegion(_ best: Int) {
        if best < 0 { return }
        let c = data.centroids[best]
        let target = max(t.scale, fit * 2.4)
        tweenTo(Transform(scale: target, tx: cssW / 2 - CGFloat(c.x) * target, ty: cssH / 2 - CGFloat(c.y) * target), dur: 0.52)
        hintPulse = 0.5
        hintFade = CACurrentMediaTime()
    }

    func magicFill() {
        guard data != nil, selColor >= 0 else { return }
        var targets = [Int32]()
        for r in 0..<data.regionCount where filled[r] == 0 && Int(data.regionColor[r]) == selColor { targets.append(Int32(r)) }
        if targets.isEmpty { return }
        onMagic?()
        magic = (targets: targets, i: 0, nextAt: CACurrentMediaTime())
        onNeedsDraw?()
    }

    func undo() {
        guard !order.isEmpty else { return }
        let r = Int(order.removeLast())
        unfillRegion(r)
        onNeedsDraw?()
    }

    func zoomBy(_ f: CGFloat) { zoomAt(cssW / 2, cssH / 2, f) }
    func fitView() { layout(cssW: cssW, cssH: cssH, initial: true); onNeedsDraw?() }

    func getState() -> State {
        var done = 0
        for r in 0..<data.regionCount where filled[r] != 0 { done += 1 }
        return State(filled: filled, order: order, mistakes: mistakes, done: done, total: data.regionCount)
    }

    // MARK: - per-frame advance (tween, hint fade, magic stagger, ring/wrong pruning)

    /// Steps time-based animations. Returns true if more frames are needed.
    @discardableResult
    func advance(now: CFTimeInterval) -> Bool {
        var animating = false

        if let tw = tween {
            let k = min(1, (now - tw.t0) / tw.dur)
            let e = k < 0.5 ? 2 * k * k : 1 - pow(-2 * k + 2, 2) / 2
            t.scale = tw.start.scale + (tw.target.scale - tw.start.scale) * CGFloat(e)
            t.tx = tw.start.tx + (tw.target.tx - tw.start.tx) * CGFloat(e)
            t.ty = tw.start.ty + (tw.target.ty - tw.start.ty) * CGFloat(e)
            if k >= 1 { tween = nil } else { animating = true }
        }

        if let hf = hintFade {
            let k = (now - hf) / 1.4
            hintPulse = max(0, 0.5 * (1 - CGFloat(k)))
            if k >= 1 { hintFade = nil; hintPulse = 0 } else { animating = true }
        }

        if var m = magic {
            if now >= m.nextAt {
                let batch = max(1, Int((Double(m.targets.count) / 14).rounded()))
                var k = 0
                while k < batch && m.i < m.targets.count { fillRegion(Int(m.targets[m.i]), quiet: true); m.i += 1; k += 1 }
                m.nextAt = now + 0.028
            }
            if m.i < m.targets.count { magic = m; animating = true } else { magic = nil }
        }

        // prune expired rings / wrong
        rings.removeAll { now - $0.t >= 0.46 }
        if let w = wrong, now - w.t >= 0.42 { wrong = nil }

        if !rings.isEmpty || wrong != nil || hintPulse > 0 || selColor >= 0 { animating = true }
        return animating
    }

    // MARK: - rendered images (rebuilt lazily when buffers change)

    func fillImage() -> CGImage? {
        if fillDirty || fillImageCache == nil { fillImageCache = makeImage(fillBuf); fillDirty = false }
        return fillImageCache
    }
    func highlightImage() -> CGImage? {
        if hlDirty || hlImageCache == nil { hlImageCache = makeImage(hlBuf); hlDirty = false }
        return hlImageCache
    }

    private func makeImage(_ buf: [UInt8]) -> CGImage? {
        var data = buf
        let w = self.data.w, h = self.data.h
        return data.withUnsafeMutableBytes { raw -> CGImage? in
            guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                      bytesPerRow: w * 4, space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            return ctx.makeImage()
        }
    }
}
