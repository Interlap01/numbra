import UIKit
import SwiftUI
import QuartzCore

/// The platform draw + gesture layer for `PaintCanvasEngine`. A layer-backed UIView
/// that renders imperatively (Core Graphics) and forwards multitouch to the engine.
/// Preserves the design's redraw resilience: a CADisplayLink drives smooth animation
/// and a ~45ms timer fallback guarantees a paint even if the link is throttled/paused.
final class PaintCanvasUIView: UIView {
    let engine = PaintCanvasEngine()

    /// In paint mode, whether one finger paints (true) or pans (false). When false the brush
    /// is idle so the user can drag to reposition with a single finger, then toggle it on.
    var brushEnabled = false

    private var link: CADisplayLink?
    private var fallback: Timer?
    private var dirty = true

    // gesture state
    private var pts: [UITouch: CGPoint] = [:]
    private enum Gesture { case none, pinch, panTap, paint }
    private var gesture: Gesture = .none
    private var panBase: (x: CGFloat, y: CGFloat, tx: CGFloat, ty: CGFloat)?
    private var pinchBase: (dist: CGFloat, ip: CGPoint, scale: CGFloat)?
    private var tap: (x: CGFloat, y: CGFloat, moved: Bool)?
    private var paintMoved = false
    private var paintDownPoint: CGPoint?
    private var lastTap: (x: CGFloat, y: CGFloat, t: CFTimeInterval)?

    // view-info callback for the minimap
    var onView: ((MinimapView) -> Void)?
    private var lastViewKey = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
        isAccessibilityElement = false
        accessibilityContainerType = .semanticGroup
        engine.onNeedsDraw = { [weak self] in self?.dirty = true }
    }
    required init?(coder: NSCoder) { fatalError() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { startLoop() } else { stopLoop() }
    }

    private func startLoop() {
        guard link == nil else { return }
        let l = CADisplayLink(target: self, selector: #selector(tick))
        l.add(to: .main, forMode: .common)
        link = l
        fallback = Timer.scheduledTimer(withTimeInterval: 0.045, repeats: true) { [weak self] _ in
            guard let self, self.dirty else { return }
            self.dirty = false
            self.setNeedsDisplay()
        }
    }
    private func stopLoop() {
        link?.invalidate(); link = nil
        fallback?.invalidate(); fallback = nil
    }
    deinit { stopLoop() }

    @objc private func tick() {
        let animating = engine.advance(now: CACurrentMediaTime())
        if dirty || animating {
            dirty = false
            setNeedsDisplay()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard engine.data != nil, bounds.width > 0 else { return }
        let initial = engine.cssW == 0
        engine.layout(cssW: bounds.width, cssH: bounds.height, initial: initial)
        dirty = true
    }

    // MARK: - draw

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), engine.data != nil else { return }
        let data = engine.data!
        let t = engine.t
        let scale = t.scale
        let paperRect = CGRect(x: t.tx, y: t.ty, width: CGFloat(data.w) * scale, height: CGFloat(data.h) * scale)

        // paper with soft drop shadow
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 6), blur: 18, color: UIColor(white: 0.12, alpha: 0.18).cgColor)
        ctx.setFillColor(red: CGFloat(engine.paperRGB.0) / 255, green: CGFloat(engine.paperRGB.1) / 255, blue: CGFloat(engine.paperRGB.2) / 255, alpha: 1)
        ctx.fill(paperRect)
        ctx.restoreGState()

        // fill buffer (crisp, nearest-neighbor). The buffer is row-major top-first, but a
        // UIView draw context is y-flipped — so draw the bitmaps through a local flip,
        // otherwise they render vertically mirrored relative to the seams/numbers.
        if let img = engine.fillImage() { drawBitmap(img, in: paperRect, ctx: ctx) }

        // selected-color highlight (subtle pulse)
        let now = CACurrentMediaTime()
        if engine.selColor >= 0, let hl = engine.highlightImage() {
            let pulse = 0.22 + 0.12 * (0.5 + 0.5 * sin(now / 0.52))
            let alpha = engine.hintPulse > 0 ? min(0.75, pulse + Double(engine.hintPulse)) : pulse
            drawBitmap(hl, in: paperRect, ctx: ctx, alpha: CGFloat(alpha))
        }

        // boundaries (stroke under the image transform so widths scale naturally)
        ctx.saveGState()
        ctx.translateBy(x: t.tx, y: t.ty); ctx.scaleBy(x: scale, y: scale)
        ctx.addPath(engine.boundary)
        ctx.setLineWidth(max(0.5, 0.85 / scale))
        ctx.setStrokeColor(engine.seamColor)
        ctx.setLineJoin(.round); ctx.setLineCap(.round)
        ctx.strokePath()
        ctx.restoreGState()

        // numbers, fill rings, wrong-feedback — drawn in screen space
        if engine.showNumbers { drawNumbers(data: data, t: t) }
        drawRings(now: now, t: t)
        drawWrong(now: now, t: t)

        // notify the minimap when the viewport moved
        if let onView {
            let key = "\(Int(scale)):\(Int(t.tx)):\(Int(t.ty))"
            if key != lastViewKey {
                lastViewKey = key
                onView(MinimapView(scale: scale, tx: t.tx, ty: t.ty, w: data.w, h: data.h,
                                   cssW: bounds.width, cssH: bounds.height, fit: engine.fit,
                                   zoomed: scale > engine.fit * 1.12))
            }
        }
    }

    /// Draws a top-first RGBA bitmap upright into `rect` despite the y-flipped UIView context.
    private func drawBitmap(_ img: CGImage, in rect: CGRect, ctx: CGContext, alpha: CGFloat = 1) {
        ctx.saveGState()
        if alpha < 1 { ctx.setAlpha(alpha) }
        ctx.interpolationQuality = .none
        ctx.translateBy(x: rect.minX, y: rect.maxY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        ctx.restoreGState()
    }

    private func drawNumbers(data: PBNData, t: PaintCanvasEngine.Transform) {
        let scale = t.scale
        for r in 0..<data.regionCount {
            if engine.filled[r] != 0 { continue }
            let c = data.centroids[r]
            let screenR = CGFloat(c.r) * scale
            if screenR < 6.5 { continue }
            let sx = CGFloat(c.x) * scale + t.tx, sy = CGFloat(c.y) * scale + t.ty
            if sx < -16 || sx > bounds.width + 16 || sy < -16 || sy > bounds.height + 16 { continue }
            let cssFont = max(6, min(CGFloat(c.r) * scale * 0.95, 26))
            let isSel = Int(data.regionColor[r]) == engine.selColor
            let color = isSel ? UIColor(red: 60 / 255, green: 45 / 255, blue: 30 / 255, alpha: 0.95)
                              : UIColor(red: 120 / 255, green: 108 / 255, blue: 92 / 255, alpha: 0.62)
            let str = String(data.palette[Int(data.regionColor[r])].num)
            let font = UIFont.systemFont(ofSize: cssFont, weight: .semibold).rounded()
            let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            let size = (str as NSString).size(withAttributes: attr)
            (str as NSString).draw(at: CGPoint(x: sx - size.width / 2, y: sy - size.height / 2), withAttributes: attr)
        }
    }

    private func drawRings(now: CFTimeInterval, t: PaintCanvasEngine.Transform) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        for rg in engine.rings {
            let k = (now - rg.t) / 0.46
            let cx = rg.x * t.scale + t.tx, cy = rg.y * t.scale + t.ty
            let radius = rg.r * (0.4 + CGFloat(k) * 1.3) * t.scale
            ctx.saveGState()
            ctx.setAlpha(CGFloat((1 - k) * 0.6))
            ctx.setLineWidth(max(0.4, 2.2 * (1 - CGFloat(k))))
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.addEllipse(in: CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2))
            ctx.strokePath()
            ctx.restoreGState()
        }
    }

    private func drawWrong(now: CFTimeInterval, t: PaintCanvasEngine.Transform) {
        guard let ctx = UIGraphicsGetCurrentContext(), let w = engine.wrong else { return }
        let k = (now - w.t) / 0.42
        if k >= 1 { return }
        let cx = w.x * t.scale + t.tx, cy = w.y * t.scale + t.ty
        let s = 2.4 * t.scale
        ctx.saveGState()
        ctx.setAlpha(CGFloat(1 - k))
        ctx.setStrokeColor(UIColor(red: 0.847, green: 0.314, blue: 0.227, alpha: 1).cgColor)
        ctx.setLineWidth(1.6); ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: cx - s, y: cy - s)); ctx.addLine(to: CGPoint(x: cx + s, y: cy + s))
        ctx.move(to: CGPoint(x: cx + s, y: cy - s)); ctx.addLine(to: CGPoint(x: cx - s, y: cy + s))
        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: - accessibility (one element per visible, unfilled region)

    /// Each unfilled region on-screen is exposed as a button at its centroid so VoiceOver
    /// and UI automation can discover and activate it (the canvas itself draws imperatively).
    ///
    /// iOS caches accessibility elements by identity and re-queries this getter many times
    /// per tree snapshot — so the element INSTANCES must be stable. We build one persistent
    /// `RegionAXElement` per region once, then only update frames / filter visibility here.
    /// (Returning freshly-allocated elements each call makes iOS collapse them to one.)
    private var axElements: [RegionAXElement] = []
    private var axDataKey: ObjectIdentifier?

    override var accessibilityElements: [Any]? {
        get { currentAccessibilityElements() }
        set { }
    }

    private func currentAccessibilityElements() -> [Any] {
        guard let data = engine.data, bounds.width > 0 else { return [] }
        let key = ObjectIdentifier(data)
        if axDataKey != key || axElements.count != data.regionCount {
            axDataKey = key
            axElements = (0..<data.regionCount).map { r in
                let num = data.palette[Int(data.regionColor[r])].num
                let el = RegionAXElement(container: self, regionId: r) { [weak self] rid in
                    self?.engine.attemptFill(region: rid)
                    UIAccessibility.post(notification: .layoutChanged, argument: nil)
                }
                el.accessibilityLabel = "Region \(r + 1), color \(num)"
                el.accessibilityTraits = .button
                return el
            }
        }
        let t = engine.t
        var visible: [RegionAXElement] = []
        for el in axElements {
            let r = el.regionId
            let c = data.centroids[r]
            let sx = CGFloat(c.x) * t.scale + t.tx, sy = CGFloat(c.y) * t.scale + t.ty
            if sx < 0 || sx > bounds.width || sy < 0 || sy > bounds.height { continue }
            let side = max(28, CGFloat(c.r) * t.scale)
            el.accessibilityFrameInContainerSpace = CGRect(x: sx - side / 2, y: sy - side / 2, width: side, height: side)
            // reflect painted state so automation/VoiceOver can read the canvas
            el.accessibilityValue = engine.filled[r] != 0 ? "painted" : "unpainted"
            visible.append(el)
        }
        return visible
    }

    // MARK: - touches (port of the pointer gesture model)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { pts[touch] = touch.location(in: self) }
        engine.cancelTween()
        if pts.count == 2 {
            let p = Array(pts.values)
            let dx = p[0].x - p[1].x, dy = p[0].y - p[1].y
            let mid = CGPoint(x: (p[0].x + p[1].x) / 2, y: (p[0].y + p[1].y) / 2)
            pinchBase = (dist: hypot(dx, dy), ip: engine.imgPt(mid.x, mid.y), scale: engine.t.scale)
            gesture = .pinch; tap = nil
        } else if pts.count == 1, let touch = touches.first {
            let p = touch.location(in: self)
            if engine.mode == "paint" && brushEnabled {
                // Brush armed: one finger paints. (Painting begins on movement / tap-lift, so
                // resting a finger doesn't lay a stray dab.)
                gesture = .paint
                paintMoved = false
                paintDownPoint = p
                engine.brushDown(p.x, p.y)
            } else {
                // Tap mode, or paint mode with the brush off → one finger pans (and in tap
                // mode a stationary tap fills).
                gesture = .panTap
                panBase = (x: p.x, y: p.y, tx: engine.t.tx, ty: engine.t.ty)
                tap = (x: p.x, y: p.y, moved: false)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches where pts[touch] != nil { pts[touch] = touch.location(in: self) }
        if gesture == .pinch, pts.count >= 2, let base = pinchBase {
            let p = Array(pts.values)
            let dx = p[0].x - p[1].x, dy = p[0].y - p[1].y
            let dist = hypot(dx, dy)
            let mid = CGPoint(x: (p[0].x + p[1].x) / 2, y: (p[0].y + p[1].y) / 2)
            var ns = base.scale * (dist / base.dist)
            ns = max(engine.minScale, min(engine.maxScale, ns))
            engine.t.scale = ns
            engine.t.tx = mid.x - base.ip.x * ns
            engine.t.ty = mid.y - base.ip.y * ns
            engine.clampT(); dirty = true
        } else if gesture == .paint, let touch = touches.first ?? pts.keys.first {
            let p = touch.location(in: self)
            paintMoved = true
            engine.brushStroke(p.x, p.y)
        } else if gesture == .panTap, let base = panBase, let touch = pts.keys.first {
            let p = touch.location(in: self)
            let ddx = p.x - base.x, ddy = p.y - base.y
            if hypot(ddx, ddy) > 6 { tap?.moved = true }
            engine.pan(toTx: base.tx + ddx, ty: base.ty + ddy)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Tap-to-fill is instant (no double-tap-to-zoom, which used to also paint the region
        // under the first tap). Zoom is via pinch or the +/- buttons.
        if gesture == .panTap, let tp = tap, !tp.moved {
            if engine.mode == "paint" {
                // Paint-mode pan never fills, so double-tap freely zooms in/out here.
                let now = CACurrentMediaTime()
                if let lt = lastTap, now - lt.t < 0.30, hypot(tp.x - lt.x, tp.y - lt.y) < 32 {
                    engine.zoomAt(tp.x, tp.y, engine.t.scale < engine.fit * 2.2 ? 2.2 : 0.45)
                    lastTap = nil
                } else { lastTap = (x: tp.x, y: tp.y, t: now) }
            } else {
                // Tap mode: instant fill (no double-tap zoom, so taps never double-fire).
                engine.tryFillAt(tp.x, tp.y)
            }
        }
        for touch in touches { pts[touch] = nil }
        resolveAfterTouchEnd()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { pts[touch] = nil }
        resolveAfterTouchEnd()
    }

    private func resolveAfterTouchEnd() {
        if pts.isEmpty {
            if gesture == .paint {
                // A paint gesture that never moved is a tap — lay a single dab there.
                if !paintMoved, let p = paintDownPoint { engine.brushStroke(p.x, p.y) }
                engine.brushUp()
            }
            gesture = .none; panBase = nil; pinchBase = nil; tap = nil
            paintMoved = false; paintDownPoint = nil
        } else if pts.count == 1, gesture == .pinch, let p = pts.values.first {
            // Dropped from two fingers to one — resume painting (paint mode + brush on) or pan.
            panBase = (x: p.x, y: p.y, tx: engine.t.tx, ty: engine.t.ty)
            gesture = (engine.mode == "paint" && brushEnabled) ? .paint : .panTap
            if gesture == .paint { paintMoved = false; paintDownPoint = p; engine.brushDown(p.x, p.y) }
            else { tap = (x: p.x, y: p.y, moved: true) }
        }
    }
}

/// Viewport info forwarded to the minimap (mirrors pbn-canvas.jsx `onView`).
struct MinimapView: Equatable {
    var scale: CGFloat; var tx: CGFloat; var ty: CGFloat
    var w: Int; var h: Int; var cssW: CGFloat; var cssH: CGFloat
    var fit: CGFloat; var zoomed: Bool
}

private extension UIFont {
    func rounded() -> UIFont {
        guard let d = fontDescriptor.withDesign(.rounded) else { return self }
        return UIFont(descriptor: d, size: pointSize)
    }
}

/// An accessibility element standing in for one paintable region.
final class RegionAXElement: UIAccessibilityElement {
    let regionId: Int
    private let onActivate: (Int) -> Void
    init(container: Any, regionId: Int, onActivate: @escaping (Int) -> Void) {
        self.regionId = regionId
        self.onActivate = onActivate
        super.init(accessibilityContainer: container)
    }
    override func accessibilityActivate() -> Bool { onActivate(regionId); return true }
}
