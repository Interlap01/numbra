//  CoreGraphicsStandIn.swift — MobAI preview only. Never shipped.
//
//  WHY THIS EXISTS
//  The preview engine carries `CGImage` and `CGContext` as sealed, empty
//  placeholder classes: no pixels, no drawing, and an `internal` initializer,
//  so project code cannot even construct one. Numbra's data layer is built on
//  exactly those two types — PBNSamples draws every sample scene into a
//  CGContext, PBNEngine reads pixels back out of a CGImage, and thumbnails go
//  CGImage → UIImage → SwiftUI. Without a stand-in nothing below AppModel
//  compiles, so no screen previews at all.
//
//  Files here compile into the app's own module, so these declarations shadow
//  the engine's for every app file, with no import needed.
//
//  WHAT IS REAL: the shape, the buffer, and its dimensions. A context holds a
//  real RGBA buffer and `makeImage()` returns a real CGImage of the right size,
//  so the sample pipeline runs end to end without crashing (PBNSamples force
//  unwraps `CGContext(...)!`).
//
//  WHAT IS NOT: any drawing. Every fill, stroke, gradient, arc and transform
//  below is a no-op, because the engine ships no rasterizer to defer to.
//  Sample art therefore comes out FLAT, and a flat source quantizes to a
//  single region — so covers and canvases render blank in the preview while
//  layout, type, colour, chrome and navigation are the app's real ones.
//  Implementing these for real means writing a 2D rasterizer (paths, beziers,
//  clipping, linear and radial gradients, stroking); that is a deliberate
//  piece of work, not something to fake halfway.

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// The engine carries CGColor, CGColorSpace, CGPath and CGLineCap but not
/// CGGradient, and PBNSamples force unwraps one for every sky and glow.
public final class CGGradient {
    public init?(colorsSpace: CGColorSpace?, colors: CFArray, locations: [CGFloat]?) {}
}

public struct CGGradientDrawingOptions: OptionSet, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let drawsBeforeStartLocation = CGGradientDrawingOptions(rawValue: 1)
    public static let drawsAfterEndLocation = CGGradientDrawingOptions(rawValue: 2)
}

// MARK: - Bitmap types

/// Shadows the engine's empty `CGImage`. Carries the pixels the engine's does not.
public final class CGImage {
    public let width: Int
    public let height: Int
    public let pixels: [UInt8]

    init(width: Int, height: Int, pixels: [UInt8]) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    public func copy(maskingColorComponents: [CGFloat]) -> CGImage? { self }
}

/// Shadows the engine's empty `CGContext`: a real RGBA buffer, inert drawing.
public final class CGContext {
    public let width: Int
    public let height: Int
    private let bytesPerRow: Int
    private var buffer: [UInt8]

    /// The bitmap initializer PBNSamples, PBNEngine, PaintCanvasEngine and
    /// AppModel.painted all use. Never fails: those call sites force unwrap.
    public init?(data: UnsafeMutableRawPointer?, width: Int, height: Int,
                 bitsPerComponent: Int, bytesPerRow: Int,
                 space: Any?, bitmapInfo: UInt32) {
        guard width > 0, height > 0 else { return nil }
        self.width = width
        self.height = height
        self.bytesPerRow = bytesPerRow
        // The app hands in its own buffer and reads it back itself; mirror it
        // so `makeImage()` reflects whatever the app wrote directly.
        if let data {
            self.buffer = [UInt8](UnsafeRawBufferPointer(start: data, count: bytesPerRow * height))
        } else {
            self.buffer = [UInt8](repeating: 255, count: bytesPerRow * height)
        }
    }

    public func makeImage() -> CGImage? {
        CGImage(width: width, height: height, pixels: buffer)
    }

    // MARK: Inert drawing surface (see the header: no rasterizer to defer to)

    public func saveGState() {}
    public func restoreGState() {}
    public func translateBy(x: CGFloat, y: CGFloat) {}
    public func scaleBy(x: CGFloat, y: CGFloat) {}
    public func rotate(by angle: CGFloat) {}
    public func setFillColor(_ color: CGColor) {}
    public func setStrokeColor(_ color: CGColor) {}
    public func setLineWidth(_ width: CGFloat) {}
    public func setLineCap(_ cap: CGLineCap) {}
    public func setAlpha(_ alpha: CGFloat) {}
    public func beginPath() {}
    public func closePath() {}
    public func move(to point: CGPoint) {}
    public func addLine(to point: CGPoint) {}
    public func addLines(between points: [CGPoint]) {}
    public func addCurve(to end: CGPoint, control1: CGPoint, control2: CGPoint) {}
    public func addArc(center: CGPoint, radius: CGFloat, startAngle: CGFloat,
                       endAngle: CGFloat, clockwise: Bool) {}
    public func fillPath() {}
    public func strokePath() {}
    public func fill(_ rect: CGRect) {}
    public func fillEllipse(in rect: CGRect) {}
    public func clip() {}
    public func clip(to rect: CGRect) {}
    public func draw(_ image: CGImage, in rect: CGRect) {}
    public func drawLinearGradient(_ gradient: CGGradient, start: CGPoint, end: CGPoint,
                                   options: CGGradientDrawingOptions) {}
    public func drawRadialGradient(_ gradient: CGGradient, startCenter: CGPoint, startRadius: CGFloat,
                                   endCenter: CGPoint, endRadius: CGFloat,
                                   options: CGGradientDrawingOptions) {}
}

/// Shadows `UIGraphicsGetCurrentContext()` so PaintCanvasView keeps type
/// checking against the CGContext above. It draws through UIKit, which the
/// preview does not run, so there is no context to hand back.
public func UIGraphicsGetCurrentContext() -> CGContext? { nil }

// mobai-ir-declaration: CGImageAlphaInfo (shape from the engine's CoreGraphics SDK IR)
public enum CGImageAlphaInfo: UInt32, CaseIterable, Sendable {
    case none = 0
    case premultipliedLast = 1
    case premultipliedFirst = 2
    case last = 3
    case first = 4
    case noneSkipLast = 5
    case noneSkipFirst = 6
    case alphaOnly = 7
}

// MARK: - UIImage bridging

/// The CGImage a UIImage was built from, kept beside the instance: an
/// extension cannot add storage and the engine's UIImage has none to spare.
private final class PreviewImageBacking: @unchecked Sendable {
    static let shared = PreviewImageBacking()
    private let lock = NSLock()
    private var table: [ObjectIdentifier: CGImage] = [:]
    func set(_ image: CGImage, for owner: AnyObject) {
        lock.lock(); defer { lock.unlock() }
        table[ObjectIdentifier(owner)] = image
    }
    func get(_ owner: AnyObject) -> CGImage? {
        lock.lock(); defer { lock.unlock() }
        return table[ObjectIdentifier(owner)]
    }
}

extension UIImage {
    public convenience init(cgImage: CGImage) {
        self.init()
        PreviewImageBacking.shared.set(cgImage, for: self)
    }

    public var cgImage: CGImage? { PreviewImageBacking.shared.get(self) }

    /// ProjectStore persists canvases as PNG. There is no encoder behind the
    /// engine's UIImage, so nothing is written and nothing is read back —
    /// projects live for the length of the preview session, which is what
    /// AppModel does in memory anyway.
    public func pngData() -> Data? { nil }

    public convenience init?(contentsOfFile path: String) {
        self.init()
        return nil
    }
}

extension UIGraphicsImageRendererFormat {
    public var scale: CGFloat {
        get { 1 }
        set { _ = newValue }
    }
    public var opaque: Bool {
        get { true }
        set { _ = newValue }
    }
}

extension UIGraphicsImageRenderer {
    /// AppModel.normalized uses the format-taking initializer; the engine
    /// carries only `init(size:)`, and the format above is inert anyway.
    public convenience init(size: CGSize, format: UIGraphicsImageRendererFormat) {
        self.init(size: size)
    }
}

extension UIImagePickerController {
    /// OnboardingView and UploadView ask whether a camera exists before
    /// offering it. There is no camera behind a preview.
    public static func isSourceTypeAvailable(_ sourceType: SourceType) -> Bool { false }
}
