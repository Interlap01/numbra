//  CanvasStandIn.swift — MobAI preview only. Never shipped.
//
//  Stands in for the two files excluded.txt keeps out of the preview build,
//  Sources/Canvas/PaintCanvasView.swift and Sources/Canvas/PaintCanvas.swift.
//  They are native UIKit — a UIView with @objc CADisplayLink selectors and
//  UIAccessibilityElement — which the engine cannot compile on Linux.
//
//  Everything the canvas actually does (fill, hit test, undo, magic fill,
//  timelapse) lives in PaintCanvasEngine.swift, which is NOT excluded and
//  compiles for real. What is missing here is only the UIKit view that draws
//  it and the SwiftUI bridge around it.
//
//  So: the paint screen does not preview. It shows the placeholder below,
//  labelled as such, so it can never be mistaken for the real canvas. Every
//  other screen — gallery, difficulty, processing, complete, the sheets and
//  overlays — is the app's own code.

import SwiftUI

/// Verbatim from PaintCanvasView.swift. A plain value type that happens to be
/// declared in the excluded file; the screens read it for the minimap.
struct MinimapView: Equatable {
    var scale: CGFloat; var tx: CGFloat; var ty: CGFloat
    var w: Int; var h: Int; var cssW: CGFloat; var cssH: CGFloat
    var fit: CGFloat; var zoomed: Bool
}

/// The imperative handle PaintView holds. Wired to nothing: there is no view.
final class PaintCanvasHandle {
    func hint() {}
    func hintBiggest() {}
    func magicFill() {}
    func undo() {}
    func zoomBy(_ f: CGFloat) {}
    func fitView() {}
    func state() -> PaintCanvasEngine.State? { nil }
}

/// Placeholder for the SwiftUI bridge. Same stored properties as the real
/// `PaintCanvas` so PaintView and OnboardingView type check unchanged.
struct PaintCanvas: View {
    let data: PBNData
    var selColor: Int
    var mode: String
    var brushing: Bool = false
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

    var body: some View {
        ZStack {
            Rectangle().fill(.gray.opacity(0.12))
            VStack(spacing: 6) {
                Text("PAINT CANVAS")
                    .font(.system(size: 11, weight: .semibold)).tracking(1.5)
                Text("not available in preview")
                    .font(.system(size: 12))
            }
            .foregroundStyle(.secondary)
        }
    }
}
