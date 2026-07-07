import UIKit

/// Procedural sample "photos" so the app needs no external assets.
/// Faithful port of pbn-engine.jsx `makeSample` / `SAMPLE_FNS` + `addTexture`,
/// drawn with Core Graphics (UIKit's top-left, y-down coordinate space matches canvas).
enum PBNSamples {
    static let names = ["starry", "wave", "sunset", "lake", "bloom", "balloon"]

    /// Draws the named scene, roughens it with multi-octave texture, returns a CGImage.
    static func make(_ name: String, size: Int = 520) -> CGImage {
        let s = CGFloat(size)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: s, height: s),
                                               format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; f.opaque = true; return f }())
        let image = renderer.image { rc in
            let c = rc.cgContext
            (SAMPLE_FNS[name] ?? SAMPLE_FNS["sunset"]!)(c, s)
        }
        let amp: Double = name == "bloom" ? 15 : 22
        return addTexture(image.cgImage!, size: size, amp: amp)
    }

    // MARK: - drawing helpers (canvas-2D-like)

    private static func hex(_ h: String, _ a: CGFloat = 1) -> CGColor {
        var s = h; if s.hasPrefix("#") { s.removeFirst() }
        let v = UInt32(s, radix: 16) ?? 0
        return CGColor(red: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255,
                       blue: CGFloat(v & 255) / 255, alpha: a)
    }

    private static func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat) -> CGColor {
        CGColor(red: r / 255, green: g / 255, blue: b / 255, alpha: a)
    }

    private static func fillRect(_ c: CGContext, _ color: CGColor, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) {
        c.setFillColor(color); c.fill(CGRect(x: x, y: y, width: w, height: h))
    }

    private static func circle(_ c: CGContext, _ color: CGColor, _ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
        c.setFillColor(color); c.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
    }

    /// Rotated ellipse with separate radii (canvas ctx.ellipse).
    private static func ellipse(_ c: CGContext, _ color: CGColor, _ cx: CGFloat, _ cy: CGFloat,
                                _ rx: CGFloat, _ ry: CGFloat, _ rot: CGFloat) {
        c.saveGState(); c.setFillColor(color)
        c.translateBy(x: cx, y: cy); c.rotate(by: rot)
        c.scaleBy(x: rx, y: ry)
        c.fillEllipse(in: CGRect(x: -1, y: -1, width: 2, height: 2))
        c.restoreGState()
    }

    private static func linearV(_ c: CGContext, _ rect: CGRect, _ stops: [(CGFloat, CGColor)]) {
        c.saveGState(); c.clip(to: rect)
        let space = CGColorSpaceCreateDeviceRGB()
        let grad = CGGradient(colorsSpace: space, colors: stops.map { $0.1 } as CFArray,
                              locations: stops.map { $0.0 })!
        c.drawLinearGradient(grad, start: CGPoint(x: rect.minX, y: rect.minY),
                             end: CGPoint(x: rect.minX, y: rect.maxY), options: [])
        c.restoreGState()
    }

    private static func poly(_ c: CGContext, _ color: CGColor, _ pts: [CGPoint]) {
        guard let first = pts.first else { return }
        c.setFillColor(color); c.beginPath(); c.move(to: first)
        for p in pts.dropFirst() { c.addLine(to: p) }
        c.closePath(); c.fillPath()
    }

    private typealias Scene = (CGContext, CGFloat) -> Void

    private static let SAMPLE_FNS: [String: Scene] = [
        "sunset": { c, s in
            linearV(c, CGRect(x: 0, y: 0, width: s, height: s), [
                (0, hex("#33336b")), (0.3, hex("#7d4f86")), (0.55, hex("#d76a55")),
                (0.78, hex("#f0a64f")), (1, hex("#ffe09c"))])
            // glow
            c.saveGState()
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [hex("#fff3c8"), rgba(255, 220, 140, 0)] as CFArray, locations: [0, 1])!
            c.drawRadialGradient(grad, startCenter: CGPoint(x: s * 0.5, y: s * 0.5), startRadius: 6,
                                 endCenter: CGPoint(x: s * 0.5, y: s * 0.5), endRadius: s * 0.28, options: [])
            c.restoreGState()
            circle(c, hex("#fff0bd"), s * 0.5, s * 0.5, s * 0.1)
            let hills: [(String, CGFloat)] = [("#caa15a", 0.62), ("#9c7a6e", 0.7), ("#6f5a72", 0.78), ("#4a3f63", 0.86), ("#2f2a4d", 0.94)]
            for (k, item) in hills.enumerated() {
                c.setFillColor(hex(item.0)); c.beginPath(); c.move(to: CGPoint(x: 0, y: s * item.1))
                var x: CGFloat = 0
                while x <= s {
                    c.addLine(to: CGPoint(x: x, y: s * item.1 - sin(x * 0.01 + CGFloat(k) * 1.7) * s * 0.05 - CGFloat(k % 2) * s * 0.02))
                    x += s / 6
                }
                c.addLine(to: CGPoint(x: s, y: s)); c.addLine(to: CGPoint(x: 0, y: s)); c.closePath(); c.fillPath()
            }
            for (i, x) in [0.16, 0.27, 0.8, 0.9].enumerated() {
                ellipse(c, hex("#2b2540"), s * CGFloat(x), s * (0.74 + CGFloat(i) * 0.01), s * 0.022, s * 0.1, 0)
            }
        },
        "lake": { c, s in
            linearV(c, CGRect(x: 0, y: 0, width: s, height: s * 0.52), [(0, hex("#aedcee")), (1, hex("#f2ead9"))])
            circle(c, hex("#fbf0cf"), s * 0.74, s * 0.16, s * 0.06)
            let peaks: [(CGFloat, CGFloat, String)] = [(0.16, 0.2, "#8fa6bd"), (0.46, 0.12, "#7e95ad"), (0.78, 0.18, "#9aaec0")]
            for (px, top, col) in peaks {
                poly(c, hex(col), [CGPoint(x: s * (px - 0.2), y: s * 0.52), CGPoint(x: s * px, y: s * top), CGPoint(x: s * (px + 0.2), y: s * 0.52)])
                poly(c, rgba(40, 60, 90, 0.28), [CGPoint(x: s * px, y: s * top), CGPoint(x: s * (px + 0.2), y: s * 0.52), CGPoint(x: s * (px + 0.04), y: s * 0.52)])
                poly(c, hex("#f4f8fb"), [CGPoint(x: s * px, y: s * top), CGPoint(x: s * (px - 0.05), y: s * (top + 0.08)), CGPoint(x: s * px, y: s * (top + 0.05)), CGPoint(x: s * (px + 0.05), y: s * (top + 0.08))])
            }
            c.setFillColor(hex("#3f6f53"))
            for i in 0..<18 {
                let x = (CGFloat(i) / 18) * s + CGFloat(i % 2) * 6, hh = s * (0.05 + CGFloat(i % 3) * 0.012)
                c.beginPath(); c.move(to: CGPoint(x: x, y: s * 0.52)); c.addLine(to: CGPoint(x: x + s * 0.03, y: s * 0.52 - hh)); c.addLine(to: CGPoint(x: x + s * 0.06, y: s * 0.52)); c.closePath(); c.fillPath()
            }
            linearV(c, CGRect(x: 0, y: s * 0.52, width: s, height: s * 0.48), [(0, hex("#5d93a8")), (1, hex("#1f4a64"))])
            c.setFillColor(rgba(244, 248, 251, 0.5))
            for i in 0..<5 { c.fill(CGRect(x: s * (0.2 + CGFloat(i) * 0.02), y: s * (0.6 + CGFloat(i) * 0.07), width: s * 0.5, height: s * 0.012)) }
            poly(c, rgba(126, 149, 173, 0.4), [CGPoint(x: s * 0.26, y: s * 0.52), CGPoint(x: s * 0.46, y: s * 0.66), CGPoint(x: s * 0.66, y: s * 0.52)])
        },
        "bloom": { c, s in
            fillRect(c, hex("#efe6d4"), 0, 0, s, s)
            ellipse(c, rgba(150, 130, 100, 0.15), s * 0.5, s * 0.82, s * 0.34, s * 0.08, 0)
            let flowers: [(CGFloat, CGFloat, CGFloat, String, String)] = [
                (0.32, 0.4, 0.17, "#e8748c", "#c64f6e"), (0.64, 0.34, 0.14, "#f4a259", "#e07a3c"),
                (0.58, 0.62, 0.15, "#8e7bc4", "#6a55a0"), (0.28, 0.66, 0.12, "#7bb37a", "#4f8a5b"),
                (0.46, 0.26, 0.1, "#e3c34a", "#c89a2e"), (0.74, 0.56, 0.1, "#6fa8c4", "#4f86a8")]
            c.setStrokeColor(hex("#5d7e4f")); c.setLineWidth(s * 0.012); c.setLineCap(.round)
            for f in flowers { c.beginPath(); c.move(to: CGPoint(x: s * f.0, y: s * f.1)); c.addLine(to: CGPoint(x: s * 0.5, y: s * 0.8)); c.strokePath() }
            for (x, y, r) in [(0.42, 0.6, 0.7), (0.58, 0.7, -0.5), (0.5, 0.52, 0.2)] {
                ellipse(c, hex("#6aa06a"), s * CGFloat(x), s * CGFloat(y), s * 0.045, s * 0.13, CGFloat(r))
            }
            for f in flowers {
                for i in 0..<8 {
                    let a = (CGFloat(i) / 8) * .pi * 2
                    ellipse(c, hex(f.3), s * f.0 + cos(a) * s * f.2 * 0.62, s * f.1 + sin(a) * s * f.2 * 0.62, s * f.2 * 0.42, s * f.2 * 0.66, a)
                }
                circle(c, hex(f.4), s * f.0, s * f.1, s * f.2 * 0.46)
                circle(c, hex("#f4d06a"), s * f.0, s * f.1, s * f.2 * 0.22)
            }
        },
        "balloon": { c, s in
            linearV(c, CGRect(x: 0, y: 0, width: s, height: s), [(0, hex("#5fb4d8")), (0.6, hex("#bfe3ee")), (0.82, hex("#cfeae0")), (1, hex("#9ecb86"))])
            circle(c, hex("#fbf0cf"), s * 0.82, s * 0.16, s * 0.07)
            c.setFillColor(rgba(255, 255, 255, 0.9))
            for (x, y, r) in [(0.22, 0.22, 0.07), (0.7, 0.4, 0.055), (0.42, 0.58, 0.05)] {
                let rr = s * CGFloat(r)
                c.fillEllipse(in: CGRect(x: s * CGFloat(x) - rr, y: s * CGFloat(y) - rr, width: rr * 2, height: rr * 2))
                let r2 = rr * 0.8
                c.fillEllipse(in: CGRect(x: s * CGFloat(x) + rr - r2, y: s * CGFloat(y) + s * 0.008 - r2, width: r2 * 2, height: r2 * 2))
                let r3 = rr * 0.7
                c.fillEllipse(in: CGRect(x: s * CGFloat(x) - rr * 0.8 - r3, y: s * CGFloat(y) + s * 0.008 - r3, width: r3 * 2, height: r3 * 2))
            }
            func balloon(_ bx: CGFloat, _ by: CGFloat, _ br: CGFloat, _ cols: [String]) {
                let n = cols.count
                for i in 0..<n {
                    c.setFillColor(hex(cols[i])); c.beginPath(); c.move(to: CGPoint(x: bx, y: by))
                    c.addArc(center: CGPoint(x: bx, y: by), radius: br,
                             startAngle: -.pi / 2 + CGFloat(i) * (.pi * 2 / CGFloat(n)),
                             endAngle: -.pi / 2 + CGFloat(i + 1) * (.pi * 2 / CGFloat(n)), clockwise: false)
                    c.closePath(); c.fillPath()
                }
                poly(c, hex("#caa15a"), [CGPoint(x: bx - br * 0.5, y: by + br * 0.92), CGPoint(x: bx + br * 0.5, y: by + br * 0.92), CGPoint(x: bx, y: by + br * 1.35)])
                fillRect(c, hex("#7a5230"), bx - s * 0.025, by + br * 1.32, s * 0.05, s * 0.045)
            }
            balloon(s * 0.4, s * 0.36, s * 0.16, ["#e35d6a", "#f3a64b", "#4f9d8b", "#5a6fb0", "#e8c14b"])
            balloon(s * 0.72, s * 0.6, s * 0.1, ["#7b5ea8", "#e35d6a", "#4f9d8b", "#f3a64b"])
            balloon(s * 0.2, s * 0.66, s * 0.085, ["#4f9d8b", "#5a6fb0", "#e8c14b", "#e35d6a"])
            c.setFillColor(hex("#7fb06a")); c.beginPath(); c.move(to: CGPoint(x: 0, y: s)); c.addLine(to: CGPoint(x: 0, y: s * 0.9))
            var x: CGFloat = 0
            while x <= s { c.addLine(to: CGPoint(x: x, y: s * 0.9 - sin(x * 0.012) * s * 0.04)); x += s / 5 }
            c.addLine(to: CGPoint(x: s, y: s)); c.closePath(); c.fillPath()
        },
        "starry": { c, s in
            linearV(c, CGRect(x: 0, y: 0, width: s, height: s), [(0, hex("#1b2f6b")), (0.5, hex("#23408f")), (1, hex("#142457"))])
            let cx = s * 0.6, cy = s * 0.4
            var r = s * 0.34; var k = 0
            while r > 5 {
                c.beginPath(); c.addArc(center: CGPoint(x: cx, y: cy), radius: r, startAngle: 0, endAngle: .pi * 2, clockwise: false)
                c.setStrokeColor(k % 2 != 0 ? rgba(127, 168, 232, 0.85) : rgba(231, 192, 68, 0.6))
                c.setLineWidth(s * 0.034); c.strokePath()
                r -= s * 0.05; k += 1
            }
            circle(c, rgba(231, 192, 68, 0.3), s * 0.81, s * 0.17, s * 0.11)
            circle(c, hex("#f4dd86"), s * 0.81, s * 0.17, s * 0.06)
            for (x, y) in [(0.18, 0.16), (0.34, 0.3), (0.13, 0.5), (0.46, 0.13), (0.28, 0.6)] {
                circle(c, rgba(231, 192, 68, 0.28), s * CGFloat(x), s * CGFloat(y), s * 0.05)
                circle(c, hex("#f4dd86"), s * CGFloat(x), s * CGFloat(y), s * 0.02)
            }
            fillRect(c, hex("#172a52"), 0, s * 0.78, s, s * 0.22)
            c.setFillColor(hex("#0f3a20")); c.beginPath(); c.move(to: CGPoint(x: s * 0.14, y: s))
            c.addCurve(to: CGPoint(x: s * 0.1, y: s * 0.3), control1: CGPoint(x: s * 0.03, y: s * 0.58), control2: CGPoint(x: s * 0.17, y: s * 0.5))
            c.addCurve(to: CGPoint(x: s * 0.2, y: s), control1: CGPoint(x: s * 0.24, y: s * 0.56), control2: CGPoint(x: s * 0.21, y: s * 0.82))
            c.closePath(); c.fillPath()
            fillRect(c, hex("#26396a"), s * 0.32, s * 0.8, s * 0.62, s * 0.13)
            for i in 0..<5 { let x = s * (0.34 + CGFloat(i) * 0.115); poly(c, hex("#26396a"), [CGPoint(x: x, y: s * 0.8), CGPoint(x: x + s * 0.05, y: s * 0.74), CGPoint(x: x + s * 0.1, y: s * 0.8)]) }
            c.setFillColor(hex("#e7c044")); for i in 0..<5 { c.fill(CGRect(x: s * (0.37 + CGFloat(i) * 0.115), y: s * 0.84, width: s * 0.02, height: s * 0.035)) }
            fillRect(c, hex("#1a2c52"), s * 0.46, s * 0.66, s * 0.04, s * 0.16)
            poly(c, hex("#1a2c52"), [CGPoint(x: s * 0.45, y: s * 0.66), CGPoint(x: s * 0.48, y: s * 0.58), CGPoint(x: s * 0.51, y: s * 0.66)])
        },
        "wave": { c, s in
            linearV(c, CGRect(x: 0, y: 0, width: s, height: s), [(0, hex("#d8ceb2")), (1, hex("#f0e8d2"))])
            circle(c, hex("#efe0bd"), s * 0.7, s * 0.22, s * 0.09)
            poly(c, hex("#37566f"), [CGPoint(x: s * 0.54, y: s * 0.62), CGPoint(x: s * 0.74, y: s * 0.34), CGPoint(x: s * 0.94, y: s * 0.62)])
            poly(c, hex("#f4f1e6"), [CGPoint(x: s * 0.74, y: s * 0.34), CGPoint(x: s * 0.67, y: s * 0.44), CGPoint(x: s * 0.71, y: s * 0.46), CGPoint(x: s * 0.74, y: s * 0.41), CGPoint(x: s * 0.77, y: s * 0.46), CGPoint(x: s * 0.81, y: s * 0.44)])
            fillRect(c, hex("#1f4f78"), 0, s * 0.6, s, s * 0.4)
            c.setFillColor(hex("#173a5e")); c.beginPath(); c.move(to: CGPoint(x: 0, y: s * 0.62))
            c.addCurve(to: CGPoint(x: s * 0.56, y: s * 0.5), control1: CGPoint(x: s * 0.15, y: s * 0.33), control2: CGPoint(x: s * 0.42, y: s * 0.28))
            c.addCurve(to: CGPoint(x: s * 0.64, y: s * 0.25), control1: CGPoint(x: s * 0.42, y: s * 0.32), control2: CGPoint(x: s * 0.52, y: s * 0.18))
            c.addCurve(to: CGPoint(x: s * 0.3, y: s * 0.55), control1: CGPoint(x: s * 0.46, y: s * 0.27), control2: CGPoint(x: s * 0.52, y: s * 0.56))
            c.addCurve(to: CGPoint(x: s * 0.05, y: s * 0.66), control1: CGPoint(x: s * 0.4, y: s * 0.67), control2: CGPoint(x: s * 0.18, y: s * 0.8))
            c.closePath(); c.fillPath()
            c.setFillColor(hex("#2f6b94")); c.beginPath(); c.move(to: CGPoint(x: s * 0.1, y: s * 0.62))
            c.addCurve(to: CGPoint(x: s * 0.48, y: s * 0.54), control1: CGPoint(x: s * 0.22, y: s * 0.45), control2: CGPoint(x: s * 0.4, y: s * 0.42))
            c.addCurve(to: CGPoint(x: s * 0.18, y: s * 0.62), control1: CGPoint(x: s * 0.36, y: s * 0.46), control2: CGPoint(x: s * 0.3, y: s * 0.6))
            c.closePath(); c.fillPath()
            for (x, y, r) in [(0.14, 0.42, 0.045), (0.27, 0.34, 0.038), (0.4, 0.38, 0.042), (0.52, 0.46, 0.032), (0.62, 0.25, 0.03), (0.2, 0.5, 0.03)] {
                circle(c, hex("#f4f1e6"), s * CGFloat(x), s * CGFloat(y), s * CGFloat(r))
            }
            c.setFillColor(hex("#102a44")); c.beginPath(); c.move(to: CGPoint(x: 0, y: s * 0.82))
            c.addCurve(to: CGPoint(x: s, y: s * 0.78), control1: CGPoint(x: s * 0.3, y: s * 0.72), control2: CGPoint(x: s * 0.6, y: s * 0.84))
            c.addLine(to: CGPoint(x: s, y: s)); c.addLine(to: CGPoint(x: 0, y: s)); c.closePath(); c.fillPath()
        },
    ]

    // MARK: - texture

    private static func clampB(_ v: Double) -> UInt8 { UInt8(v < 0 ? 0 : v > 255 ? 255 : v) }

    /// Multi-octave sine "noise" roughens flat fills so quantization yields satisfying region counts.
    private static func addTexture(_ img: CGImage, size: Int, amp: Double) -> CGImage {
        let s = size
        var data = [UInt8](repeating: 0, count: s * s * 4)
        let space = CGColorSpaceCreateDeviceRGB()
        data.withUnsafeMutableBytes { raw in
            let ctx = CGContext(data: raw.baseAddress, width: s, height: s, bitsPerComponent: 8,
                                bytesPerRow: s * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: s, height: s))
        }
        for y in 0..<s {
            for x in 0..<s {
                let i = (y * s + x) * 4
                let fx = Double(x), fy = Double(y)
                let n = sin(fx * 0.017 + fy * 0.009) * 0.55
                    + sin(fx * 0.004 - fy * 0.021 + 1.3) * 0.5
                    + sin((fx + fy) * 0.012 + 2.1) * 0.42
                    + sin(fx * 0.031 + 0.7) * 0.32 * sin(fy * 0.024 + 0.4)
                    + sin((fx - fy) * 0.026 + 4.2) * 0.3
                    + sin(fx * 0.052 + fy * 0.041 + 1.7) * 0.26
                    + sin((fx + 2 * fy) * 0.047 + 3.1) * 0.2
                let v = n * amp
                data[i] = clampB(Double(data[i]) + v)
                data[i + 1] = clampB(Double(data[i + 1]) + v)
                data[i + 2] = clampB(Double(data[i + 2]) + v)
            }
        }
        return data.withUnsafeMutableBytes { raw -> CGImage in
            let ctx = CGContext(data: raw.baseAddress, width: s, height: s, bitsPerComponent: 8,
                                bytesPerRow: s * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            return ctx.makeImage()!
        }
    }
}
