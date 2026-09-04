//  SwiftUIStandIn.swift — MobAI preview only. Never shipped.
//
//  SwiftUI views the preview engine does not carry. Same rule as the
//  CoreGraphics stand-in beside this file: real shape, no drawing.

import SwiftUI

/// `Canvas` is used by Sources/FX/Confetti.swift for the completion burst.
/// The engine has no immediate-mode drawing surface, so the renderer closure
/// is accepted and never run: confetti is absent in the preview, everything
/// underneath it is the app's own.
public struct Canvas<Symbols: View>: View {
    private let symbols: Symbols
    private let renderer: (inout GraphicsContext, CGSize) -> Void

    public init(opaque: Bool = false,
                colorMode: ColorRenderingMode = .nonLinear,
                rendersAsynchronously: Bool = false,
                renderer: @escaping (inout GraphicsContext, CGSize) -> Void,
                @ViewBuilder symbols: () -> Symbols) {
        self.renderer = renderer
        self.symbols = symbols()
    }

    public var body: some View { Color.clear }
}

extension Canvas where Symbols == EmptyView {
    public init(opaque: Bool = false,
                colorMode: ColorRenderingMode = .nonLinear,
                rendersAsynchronously: Bool = false,
                renderer: @escaping (inout GraphicsContext, CGSize) -> Void) {
        self.init(opaque: opaque, colorMode: colorMode,
                  rendersAsynchronously: rendersAsynchronously,
                  renderer: renderer, symbols: { EmptyView() })
    }
}

extension GraphicsContext {
    /// Confetti sets a per-particle alpha. The engine's GraphicsContext has no
    /// opacity of its own and nothing here draws, so this only has to exist
    /// and read back what was written.
    public var opacity: Double {
        get { 1 }
        set { _ = newValue }
    }

    /// The engine keeps its transform hooks `package`-internal, so the app
    /// cannot reach them. Inert, like everything else on this path.
    public func translateBy(x: CGFloat, y: CGFloat) {}
    public func rotate(by angle: Angle) {}
    public func scaleBy(x: CGFloat, y: CGFloat) {}

    /// The engine carries `Shading` but no filling to spend it on.
    public func fill(_ path: Path, with shading: Shading, style: FillStyle = FillStyle()) {}
    public func stroke(_ path: Path, with shading: Shading, lineWidth: CGFloat = 1) {}
    public func stroke(_ path: Path, with shading: Shading, style: StrokeStyle) {}
}

extension GraphicsContext.Shading {
    /// The engine's Shading has no constructors; nothing below draws, so a
    /// colour shading only has to be nameable.
    public static func color(_ color: Color) -> GraphicsContext.Shading {
        GraphicsContext.Shading()
    }
}

extension GraphicsContext.Shading {
    /// OnboardingView paints its slide motifs with gradient shadings.
    public static func linearGradient<G>(_ gradient: G,
                                      startPoint: CGPoint,
                                      endPoint: CGPoint) -> GraphicsContext.Shading {
        GraphicsContext.Shading()
    }

    public static func radialGradient<G>(_ gradient: G,
                                      center: CGPoint,
                                      startRadius: CGFloat,
                                      endRadius: CGFloat) -> GraphicsContext.Shading {
        GraphicsContext.Shading()
    }
}

/// Target of the `large` rule in rewrites.json. `ProgressView().controlSize(.large)`
/// in OnboardingView does not resolve against this engine — `.large` comes back
/// ambiguous — so the rewrite points that one member access here, where the type
/// is stated outright. Preview-only: the app's own source is never touched.
extension ControlSize {
    public static var mobaiPreviewLarge: ControlSize { ControlSize.large }
}
