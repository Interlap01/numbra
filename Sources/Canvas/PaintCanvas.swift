import SwiftUI

/// Imperative handle so SwiftUI can drive the canvas (hint/magic/undo/zoom/fit/state)
/// without re-rendering — mirrors the ref methods exposed by pbn-canvas.jsx.
final class PaintCanvasHandle {
    weak var view: PaintCanvasUIView?
    func hint() { view?.engine.hint() }
    func hintBiggest() { view?.engine.hintBiggest() }
    func magicFill() { view?.engine.magicFill() }
    func undo() { view?.engine.undo() }
    func zoomBy(_ f: CGFloat) { view?.engine.zoomBy(f) }
    func fitView() { view?.engine.fitView() }
    func state() -> PaintCanvasEngine.State? { view?.engine.getState() }
}

/// SwiftUI bridge to the imperative paint canvas.
struct PaintCanvas: UIViewRepresentable {
    let data: PBNData
    var selColor: Int
    var mode: String
    var brushing: Bool = false   // paint mode: one-finger paints (true) vs one-finger pans (false)
    var paperRGB: (Int, Int, Int)
    var seamColor: CGColor
    var showNumbers: Bool
    var initialFilled: [UInt8]?
    let handle: PaintCanvasHandle

    var onFillChange: (PaintCanvasEngine.FillReport) -> Void = { _ in }
    var onComplete: () -> Void = {}
    var onWrong: () -> Void = {}
    var onFill: (Int) -> Void = { _ in }
    var onMagic: () -> Void = {}
    var onView: (MinimapView) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var dataRef: ObjectIdentifier?
        var selColor = -2
        var paperRGB: (Int, Int, Int) = (-1, -1, -1)
        var showNumbers = true
        var seamHex: String = ""
    }

    func makeUIView(context: Context) -> PaintCanvasUIView {
        let v = PaintCanvasUIView()
        let e = v.engine
        e.onFillChange = onFillChange
        e.onComplete = onComplete
        e.onWrong = onWrong
        e.onFill = onFill
        e.onMagic = onMagic
        v.onView = onView
        configure(v, context: context, initial: true)
        handle.view = v
        return v
    }

    func updateUIView(_ v: PaintCanvasUIView, context: Context) {
        // keep callbacks fresh (they capture SwiftUI state)
        v.engine.onFillChange = onFillChange
        v.engine.onComplete = onComplete
        v.engine.onWrong = onWrong
        v.engine.onFill = onFill
        v.engine.onMagic = onMagic
        v.onView = onView
        handle.view = v
        configure(v, context: context, initial: false)
    }

    private func configure(_ v: PaintCanvasUIView, context: Context, initial: Bool) {
        let e = v.engine
        let co = context.coordinator
        e.mode = mode
        v.brushEnabled = brushing

        let newData = initial || co.dataRef != ObjectIdentifier(data)
        if newData {
            co.dataRef = ObjectIdentifier(data)
            e.paperRGB = paperRGB
            e.seamColor = seamColor
            e.showNumbers = showNumbers
            e.selColor = selColor
            e.setup(data: data, initialFilled: initialFilled)
            co.selColor = selColor; co.paperRGB = paperRGB; co.showNumbers = showNumbers
            v.setNeedsLayout(); v.setNeedsDisplay()
            return
        }

        var needsRefresh = false
        if co.selColor != selColor { e.selColor = selColor; co.selColor = selColor; needsRefresh = true }
        if co.paperRGB != paperRGB { e.paperRGB = paperRGB; co.paperRGB = paperRGB; needsRefresh = true }
        if co.showNumbers != showNumbers { e.showNumbers = showNumbers; co.showNumbers = showNumbers; needsRefresh = true }
        e.seamColor = seamColor
        if needsRefresh { e.refreshForSelection() }
    }
}

private func == (a: (Int, Int, Int), b: (Int, Int, Int)) -> Bool { a.0 == b.0 && a.1 == b.1 && a.2 == b.2 }
private func != (a: (Int, Int, Int), b: (Int, Int, Int)) -> Bool { !(a == b) }
