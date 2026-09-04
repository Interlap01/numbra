// Stand-in for QuartzCore, supplied by this project for the MobAI preview
// engine. Not in the MobAI adapter catalogue, so it is written here.
//
// Sources/Canvas/PaintCanvasEngine.swift reaches for QuartzCore only as a
// clock: every transient canvas effect (rings, wrong-feedback, the zoom tween,
// hint fade, magic fill) stamps CACurrentMediaTime() and `advance(now:)` steps
// them against it. So this has to be a REAL monotonic clock, not a stub
// returning 0 — a frozen clock leaves every effect stuck at t=0.
//
// CADisplayLink (Sources/Canvas/PaintCanvasView.swift) is deliberately absent:
// that file is a UIKit UIView the preview does not run. Add it here only if a
// previewed screen starts needing it.

import Foundation

private let mobaiPreviewClockOrigin = DispatchTime.now().uptimeNanoseconds

/// Seconds since the preview process started, monotonic, matching the
/// semantics PaintCanvasEngine relies on (a steadily increasing timebase).
public func CACurrentMediaTime() -> Double {
    Double(DispatchTime.now().uptimeNanoseconds &- mobaiPreviewClockOrigin) / 1_000_000_000
}
