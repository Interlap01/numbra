// MobAI curated stand-in: QuartzCore
// Managed by the engine while unchanged; edit it and it is yours.
// curated-key: 7898b082160306bd
//
// Core Animation for a still preview: the names an app reaches for around
// its custom views, held but never animated. Layers keep their properties
// and draw nothing (a SwiftUI screen's own drawing is what the preview
// paints); timing functions, transactions and animations compile and do
// nothing. CADisplayLink and CACurrentMediaTime come from the engine's own
// UIKit shims and are visible everywhere, so they are not declared here.

import Foundation
import CoreGraphics

public typealias CFTimeInterval = Double

open class CALayer {
    public var frame = CGRect.zero
    public var bounds = CGRect.zero
    public var position = CGPoint.zero
    public var anchorPoint = CGPoint(x: 0.5, y: 0.5)
    public var opacity: Float = 1
    public var isHidden = false
    public var cornerRadius: CGFloat = 0
    public var borderWidth: CGFloat = 0
    public var masksToBounds = false
    public var contentsScale: CGFloat = 1
    public var zPosition: CGFloat = 0
    public var name: String?
    public var contents: Any?
    public var backgroundColor: CGColor?
    public var borderColor: CGColor?
    public var shadowColor: CGColor?
    public var shadowOpacity: Float = 0
    public var shadowRadius: CGFloat = 3
    public var shadowOffset = CGSize(width: 0, height: -3)
    public var transform = CATransform3DIdentity
    public var mask: CALayer?
    public var sublayers: [CALayer]?
    public weak var superlayer: CALayer?
    public var needsDisplayOnBoundsChange = false
    public weak var delegate: AnyObject?
    public init() {}
    public init(layer: Any) {}
    open func addSublayer(_ layer: CALayer) {
        sublayers = (sublayers ?? []) + [layer]
        layer.superlayer = self
    }
    open func insertSublayer(_ layer: CALayer, at index: UInt32) { addSublayer(layer) }
    open func removeFromSuperlayer() {
        superlayer?.sublayers?.removeAll { $0 === self }
        superlayer = nil
    }
    open func setNeedsDisplay() {}
    open func setNeedsDisplay(_ rect: CGRect) {}
    open func setNeedsLayout() {}
    open func layoutIfNeeded() {}
    open func display() {}
    open func draw(in ctx: CGContext) {}
    open func layoutSublayers() {}
    open func render(in ctx: CGContext) {}
    open func add(_ animation: CAAnimation, forKey key: String?) {}
    open func removeAnimation(forKey key: String) {}
    open func removeAllAnimations() {}
    open func animation(forKey key: String) -> CAAnimation? { nil }
    open func contains(_ point: CGPoint) -> Bool { bounds.contains(point) }
    open func convert(_ point: CGPoint, from layer: CALayer?) -> CGPoint { point }
    open func convert(_ point: CGPoint, to layer: CALayer?) -> CGPoint { point }
    open func convert(_ rect: CGRect, from layer: CALayer?) -> CGRect { rect }
    open func convert(_ rect: CGRect, to layer: CALayer?) -> CGRect { rect }
}

open class CAShapeLayer: CALayer {
    public var path: CGPath?
    public var fillColor: CGColor?
    public var strokeColor: CGColor?
    public var lineWidth: CGFloat = 1
    public var lineCap: CAShapeLayerLineCap = .butt
    public var lineJoin: CAShapeLayerLineJoin = .miter
    public var lineDashPattern: [NSNumber]?
    public var strokeStart: CGFloat = 0
    public var strokeEnd: CGFloat = 1
    public var fillRule: CAShapeLayerFillRule = .nonZero
    public override init() { super.init() }
    public override init(layer: Any) { super.init(layer: layer) }
}

public struct CAShapeLayerLineCap: RawRepresentable, Equatable, Sendable {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let butt = CAShapeLayerLineCap(rawValue: "butt")
    public static let round = CAShapeLayerLineCap(rawValue: "round")
    public static let square = CAShapeLayerLineCap(rawValue: "square")
}

public struct CAShapeLayerLineJoin: RawRepresentable, Equatable, Sendable {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let miter = CAShapeLayerLineJoin(rawValue: "miter")
    public static let round = CAShapeLayerLineJoin(rawValue: "round")
    public static let bevel = CAShapeLayerLineJoin(rawValue: "bevel")
}

public struct CAShapeLayerFillRule: RawRepresentable, Equatable, Sendable {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let nonZero = CAShapeLayerFillRule(rawValue: "non-zero")
    public static let evenOdd = CAShapeLayerFillRule(rawValue: "even-odd")
}

open class CAGradientLayer: CALayer {
    public var colors: [Any]?
    public var locations: [NSNumber]?
    public var startPoint = CGPoint(x: 0.5, y: 0)
    public var endPoint = CGPoint(x: 0.5, y: 1)
    public var type: CAGradientLayerType = .axial
    public override init() { super.init() }
    public override init(layer: Any) { super.init(layer: layer) }
}

public struct CAGradientLayerType: RawRepresentable, Equatable, Sendable {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let axial = CAGradientLayerType(rawValue: "axial")
    public static let radial = CAGradientLayerType(rawValue: "radial")
    public static let conic = CAGradientLayerType(rawValue: "conic")
}

open class CATextLayer: CALayer {
    public var string: Any?
    public var fontSize: CGFloat = 36
    public var foregroundColor: CGColor?
    public var alignmentMode: CATextLayerAlignmentMode = .natural
    public var isWrapped = false
    public override init() { super.init() }
    public override init(layer: Any) { super.init(layer: layer) }
}

public struct CATextLayerAlignmentMode: RawRepresentable, Equatable, Sendable {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let natural = CATextLayerAlignmentMode(rawValue: "natural")
    public static let left = CATextLayerAlignmentMode(rawValue: "left")
    public static let right = CATextLayerAlignmentMode(rawValue: "right")
    public static let center = CATextLayerAlignmentMode(rawValue: "center")
    public static let justified = CATextLayerAlignmentMode(rawValue: "justified")
}

public struct CATransform3D: Equatable, Sendable {
    public var m11: CGFloat = 1, m12: CGFloat = 0, m13: CGFloat = 0, m14: CGFloat = 0
    public var m21: CGFloat = 0, m22: CGFloat = 1, m23: CGFloat = 0, m24: CGFloat = 0
    public var m31: CGFloat = 0, m32: CGFloat = 0, m33: CGFloat = 1, m34: CGFloat = 0
    public var m41: CGFloat = 0, m42: CGFloat = 0, m43: CGFloat = 0, m44: CGFloat = 1
    public init() {}
}
public let CATransform3DIdentity = CATransform3D()
public func CATransform3DMakeScale(_ sx: CGFloat, _ sy: CGFloat, _ sz: CGFloat) -> CATransform3D {
    var t = CATransform3D(); t.m11 = sx; t.m22 = sy; t.m33 = sz; return t
}
public func CATransform3DMakeTranslation(_ tx: CGFloat, _ ty: CGFloat, _ tz: CGFloat) -> CATransform3D {
    var t = CATransform3D(); t.m41 = tx; t.m42 = ty; t.m43 = tz; return t
}
public func CATransform3DMakeRotation(_ angle: CGFloat, _ x: CGFloat, _ y: CGFloat, _ z: CGFloat) -> CATransform3D {
    CATransform3D()
}
public func CATransform3DMakeAffineTransform(_ m: CGAffineTransform) -> CATransform3D {
    var t = CATransform3D()
    t.m11 = m.a; t.m12 = m.b; t.m21 = m.c; t.m22 = m.d; t.m41 = m.tx; t.m42 = m.ty
    return t
}
public func CATransform3DIsIdentity(_ t: CATransform3D) -> Bool { t == CATransform3DIdentity }

open class CAAnimation {
    public var duration: CFTimeInterval = 0.25
    public var beginTime: CFTimeInterval = 0
    public var repeatCount: Float = 0
    public var autoreverses = false
    public var timingFunction: CAMediaTimingFunction?
    public var isRemovedOnCompletion = true
    public var fillMode: CAMediaTimingFillMode = .removed
    public weak var delegate: AnyObject?
    public init() {}
}
open class CAPropertyAnimation: CAAnimation {
    public var keyPath: String?
    public var isAdditive = false
    public var isCumulative = false
    public init(keyPath: String?) { self.keyPath = keyPath; super.init() }
}
open class CABasicAnimation: CAPropertyAnimation {
    public var fromValue: Any?
    public var toValue: Any?
    public var byValue: Any?
}
open class CAKeyframeAnimation: CAPropertyAnimation {
    public var values: [Any]?
    public var keyTimes: [NSNumber]?
    public var path: CGPath?
}
open class CAAnimationGroup: CAAnimation {
    public var animations: [CAAnimation]?
}
open class CASpringAnimation: CABasicAnimation {
    public var mass: CGFloat = 1
    public var stiffness: CGFloat = 100
    public var damping: CGFloat = 10
    public var initialVelocity: CGFloat = 0
    public var settlingDuration: CFTimeInterval { 0.5 }
}
open class CATransition: CAAnimation {
    public var type: CATransitionType = .fade
    public var subtype: CATransitionSubtype?
}
public struct CATransitionType: RawRepresentable, Equatable, Sendable {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let fade = CATransitionType(rawValue: "fade")
    public static let moveIn = CATransitionType(rawValue: "moveIn")
    public static let push = CATransitionType(rawValue: "push")
    public static let reveal = CATransitionType(rawValue: "reveal")
}
public struct CATransitionSubtype: RawRepresentable, Equatable, Sendable {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let fromRight = CATransitionSubtype(rawValue: "fromRight")
    public static let fromLeft = CATransitionSubtype(rawValue: "fromLeft")
    public static let fromTop = CATransitionSubtype(rawValue: "fromTop")
    public static let fromBottom = CATransitionSubtype(rawValue: "fromBottom")
}
public struct CAMediaTimingFillMode: RawRepresentable, Equatable, Sendable {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let forwards = CAMediaTimingFillMode(rawValue: "forwards")
    public static let backwards = CAMediaTimingFillMode(rawValue: "backwards")
    public static let both = CAMediaTimingFillMode(rawValue: "both")
    public static let removed = CAMediaTimingFillMode(rawValue: "removed")
}

open class CAMediaTimingFunction {
    public let name: CAMediaTimingFunctionName?
    public init(name: CAMediaTimingFunctionName) { self.name = name }
    public init(controlPoints c1x: Float, _ c1y: Float, _ c2x: Float, _ c2y: Float) { name = nil }
}
public struct CAMediaTimingFunctionName: RawRepresentable, Equatable, Sendable {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let linear = CAMediaTimingFunctionName(rawValue: "linear")
    public static let easeIn = CAMediaTimingFunctionName(rawValue: "easeIn")
    public static let easeOut = CAMediaTimingFunctionName(rawValue: "easeOut")
    public static let easeInEaseOut = CAMediaTimingFunctionName(rawValue: "easeInEaseOut")
    public static let `default` = CAMediaTimingFunctionName(rawValue: "default")
}

public enum CATransaction {
    public static func begin() {}
    public static func commit() {}
    public static func flush() {}
    public static func setDisableActions(_ flag: Bool) {}
    public static func setAnimationDuration(_ duration: CFTimeInterval) {}
    public static func setCompletionBlock(_ block: (() -> Void)?) { block?() }
    public static func setAnimationTimingFunction(_ function: CAMediaTimingFunction?) {}
}
