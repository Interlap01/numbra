import CoreGraphics
import ImageIO

/// Turns any image into paint-by-numbers data. Faithful port of pbn-engine.jsx:
/// median-cut quantization → nearest-color index map → 3×3 majority smoothing →
/// connected-component regions → small-region merging → per-region color,
/// centroid, pixel lists, and a boundary segment list.
enum PBNEngine {

    struct Options {
        var colors: Int = 16
        var detail: Int = 90   // long-side px of the working buffer
        var minSize: Int?      // regions below this merge into a neighbor
    }

    // MARK: - small helpers

    private static func toHex(_ r: Int, _ g: Int, _ b: Int) -> String {
        String(format: "#%02x%02x%02x", r, g, b)
    }
    /// Perceived luminance 0..255.
    private static func luma(_ r: Int, _ g: Int, _ b: Int) -> Double {
        0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)
    }

    // MARK: - downscale into a small RGBA buffer

    private struct Buffer { var data: [UInt8]; var w: Int; var h: Int }

    private static func downscale(_ src: CGImage, targetLong: Int) -> Buffer {
        let sw = src.width, sh = src.height
        let scale = Double(targetLong) / Double(max(sw, sh))
        let w = max(8, Int((Double(sw) * scale).rounded()))
        let h = max(8, Int((Double(sh) * scale).rounded()))
        let bytesPerRow = w * 4
        var data = [UInt8](repeating: 0, count: h * bytesPerRow)
        let space = CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        data.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h,
                                      bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                      space: space, bitmapInfo: info) else { return }
            ctx.interpolationQuality = .high
            ctx.draw(src, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return Buffer(data: data, w: w, h: h)
    }

    // MARK: - median cut quantization

    private static func medianCut(_ data: [UInt8], _ w: Int, _ h: Int, _ n: Int) -> [[Int]] {
        var px = [[Int]]()
        px.reserveCapacity(w * h)
        for i in 0..<(w * h) {
            px.append([Int(data[i * 4]), Int(data[i * 4 + 1]), Int(data[i * 4 + 2])])
        }
        var boxes: [[[Int]]] = [px]

        func channelRange(_ box: [[Int]]) -> [Int] {
            var mn = [255, 255, 255], mx = [0, 0, 0]
            for p in box {
                for c in 0..<3 {
                    if p[c] < mn[c] { mn[c] = p[c] }
                    if p[c] > mx[c] { mx[c] = p[c] }
                }
            }
            return [mx[0] - mn[0], mx[1] - mn[1], mx[2] - mn[2]]
        }

        while boxes.count < n {
            var bi = -1, best = -1, bc = 0
            for i in 0..<boxes.count {
                if boxes[i].count < 2 { continue }
                let r = channelRange(boxes[i])
                let m = max(r[0], r[1], r[2])
                if m > best { best = m; bi = i; bc = r.firstIndex(of: m)! }
            }
            if bi < 0 { break }
            var box = boxes[bi]
            box.sort { $0[bc] < $1[bc] }
            let mid = box.count >> 1
            boxes.remove(at: bi)
            boxes.append(Array(box[0..<mid]))
            boxes.append(Array(box[mid...]))
        }

        return boxes.map { box in
            var r = 0, g = 0, b = 0
            for p in box { r += p[0]; g += p[1]; b += p[2] }
            let k = max(1, box.count)
            return [Int((Double(r) / Double(k)).rounded()),
                    Int((Double(g) / Double(k)).rounded()),
                    Int((Double(b) / Double(k)).rounded())]
        }
    }

    /// Nearest palette index for a color.
    private static func nearest(_ pal: [[Int]], _ r: Int, _ g: Int, _ b: Int) -> Int {
        var bi = 0, bd = Int.max
        for i in 0..<pal.count {
            let dr = pal[i][0] - r, dg = pal[i][1] - g, db = pal[i][2] - b
            let d = dr * dr + dg * dg + db * db
            if d < bd { bd = d; bi = i }
        }
        return bi
    }

    /// 3×3 majority filter over the index map to remove single-pixel speckle.
    private static func smooth(_ idx: [Int], _ w: Int, _ h: Int, _ palCount: Int) -> [Int] {
        var out = idx
        var counts = [Int](repeating: 0, count: max(1, palCount))
        for y in 0..<h {
            for x in 0..<w {
                for i in 0..<counts.count { counts[i] = 0 }
                var bestC = idx[y * w + x], bestN = -1
                for dy in -1...1 {
                    let yy = y + dy; if yy < 0 || yy >= h { continue }
                    for dx in -1...1 {
                        let xx = x + dx; if xx < 0 || xx >= w { continue }
                        let c = idx[yy * w + xx]
                        counts[c] += 1
                        if counts[c] > bestN { bestN = counts[c]; bestC = c }
                    }
                }
                out[y * w + x] = bestC
            }
        }
        return out
    }

    // MARK: - connected components (4-connectivity, iterative stack)

    private struct Regions {
        var labels: [Int32]
        var regionColor: [Int]
        var regionPixels: [[Int32]]
        var count: Int
    }

    private static func label(_ idx: [Int], _ w: Int, _ h: Int) -> Regions {
        var labels = [Int32](repeating: -1, count: w * h)
        var stack = [Int32](repeating: 0, count: w * h)
        var next = 0
        var regionColor = [Int]()
        var regionPixels = [[Int32]]()
        for s in 0..<(w * h) {
            if labels[s] != -1 { continue }
            let color = idx[s]
            let id = Int32(next); next += 1
            var sp = 0
            stack[sp] = Int32(s); sp += 1
            labels[s] = id
            var pix = [Int32]()
            while sp > 0 {
                sp -= 1
                let p = Int(stack[sp])
                pix.append(Int32(p))
                let x = p % w, y = p / w
                if x > 0 { let q = p - 1; if labels[q] == -1 && idx[q] == color { labels[q] = id; stack[sp] = Int32(q); sp += 1 } }
                if x < w - 1 { let q = p + 1; if labels[q] == -1 && idx[q] == color { labels[q] = id; stack[sp] = Int32(q); sp += 1 } }
                if y > 0 { let q = p - w; if labels[q] == -1 && idx[q] == color { labels[q] = id; stack[sp] = Int32(q); sp += 1 } }
                if y < h - 1 { let q = p + w; if labels[q] == -1 && idx[q] == color { labels[q] = id; stack[sp] = Int32(q); sp += 1 } }
            }
            regionColor.append(color)
            regionPixels.append(pix)
        }
        return Regions(labels: labels, regionColor: regionColor, regionPixels: regionPixels, count: next)
    }

    /// The dominant adjacent region (most shared border) for region `rid`.
    private static func dominantNeighbor(_ labels: [Int32], _ w: Int, _ h: Int, _ pix: [Int32], _ rid: Int32) -> Int32 {
        var tally = [Int32: Int]()
        for pp in pix {
            let p = Int(pp)
            let x = p % w, y = p / w
            if x > 0 { let l = labels[p - 1]; if l != rid { tally[l, default: 0] += 1 } }
            if x < w - 1 { let l = labels[p + 1]; if l != rid { tally[l, default: 0] += 1 } }
            if y > 0 { let l = labels[p - w]; if l != rid { tally[l, default: 0] += 1 } }
            if y < h - 1 { let l = labels[p + w]; if l != rid { tally[l, default: 0] += 1 } }
        }
        var best: Int32 = -1, bn = -1
        for (l, c) in tally where c > bn { bn = c; best = l }
        return best
    }

    /// Merge regions smaller than `minSize` into their dominant neighbor, then compact ids.
    private static func mergeSmall(_ reg: Regions, _ w: Int, _ h: Int, _ minSize: Int) -> Regions {
        var labels = reg.labels
        var regionPixels = reg.regionPixels
        let regionColor = reg.regionColor
        var alive = [Bool](repeating: true, count: reg.count)

        var order = Array(0..<reg.count)
        order.sort { regionPixels[$0].count < regionPixels[$1].count }
        for rid in order {
            if !alive[rid] { continue }
            if regionPixels[rid].count >= minSize { continue }
            let nb = dominantNeighbor(labels, w, h, regionPixels[rid], Int32(rid))
            if nb < 0 || !alive[Int(nb)] { continue }
            for pp in regionPixels[rid] { labels[Int(pp)] = nb }
            regionPixels[Int(nb)].append(contentsOf: regionPixels[rid])
            regionPixels[rid] = []
            alive[rid] = false
        }

        // compact ids
        var remap = [Int32](repeating: -1, count: reg.count)
        var n = 0
        var newColor = [Int](), newPix = [[Int32]]()
        for i in 0..<reg.count {
            if !alive[i] || regionPixels[i].isEmpty { continue }
            remap[i] = Int32(n)
            newColor.append(regionColor[i])
            newPix.append(regionPixels[i])
            n += 1
        }
        for p in 0..<labels.count { labels[p] = remap[Int(labels[p])] }
        return Regions(labels: labels, regionColor: newColor, regionPixels: newPix, count: n)
    }

    /// Boundary segments between differing labels, in image coords.
    private static func boundaries(_ labels: [Int32], _ w: Int, _ h: Int) -> [Float] {
        var seg = [Float]()
        for y in 0..<h {
            for x in 0..<w {
                let l = labels[y * w + x]
                if x == w - 1 || labels[y * w + x + 1] != l {
                    seg.append(contentsOf: [Float(x + 1), Float(y), Float(x + 1), Float(y + 1)])
                }
                if y == h - 1 || labels[(y + 1) * w + x] != l {
                    seg.append(contentsOf: [Float(x), Float(y + 1), Float(x + 1), Float(y + 1)])
                }
                if x == 0 { seg.append(contentsOf: [0, Float(y), 0, Float(y + 1)]) }
                if y == 0 { seg.append(contentsOf: [Float(x), 0, Float(x + 1), 0]) }
            }
        }
        return seg
    }

    /// Representative interior point + a label-size hint per region.
    private static func centroids(_ w: Int, _ regionPixels: [[Int32]]) -> [Centroid] {
        regionPixels.map { pix in
            var sx = 0.0, sy = 0.0
            for pp in pix { let p = Int(pp); sx += Double(p % w); sy += Double(p / w) }
            let cx = sx / Double(pix.count), cy = sy / Double(pix.count)
            var best = pix[0], bd = Double.greatestFiniteMagnitude
            for pp in pix {
                let p = Int(pp)
                let x = Double(p % w), y = Double(p / w)
                let d = (x - cx) * (x - cx) + (y - cy) * (y - cy)
                if d < bd { bd = d; best = pp }
            }
            let r = (Double(pix.count) / Double.pi).squareRoot()
            let bp = Int(best)
            return Centroid(x: Double(bp % w) + 0.5, y: Double(bp / w) + 0.5, r: r)
        }
    }

    // MARK: - main entry

    static func generate(_ src: CGImage, options opts: Options) -> PBNData {
        let colors = opts.colors
        let detail = opts.detail
        // Floor raised from 4→6px so the very smallest 1–5px slivers (nearly untappable at
        // fit-zoom, and a source of degenerate a11y bounds) merge into a neighbor.
        let minSize = opts.minSize ?? max(6, Int((Double(detail * detail) / 2400).rounded()))

        let buf = downscale(src, targetLong: detail)
        let w = buf.w, h = buf.h
        let pal = medianCut(buf.data, w, h, colors)

        var idx = [Int](repeating: 0, count: w * h)
        for i in 0..<(w * h) {
            idx[i] = nearest(pal, Int(buf.data[i * 4]), Int(buf.data[i * 4 + 1]), Int(buf.data[i * 4 + 2]))
        }
        idx = smooth(idx, w, h, pal.count)

        var reg = label(idx, w, h)
        reg = mergeSmall(reg, w, h, minSize)
        // a second gentle pass for stragglers created by merging
        reg = mergeSmall(reg, w, h, max(5, minSize - 1))

        let cents = centroids(w, reg.regionPixels)
        let seg = boundaries(reg.labels, w, h)

        // sort the palette light→dark so numbering feels natural, then remap
        let palOrder = (0..<pal.count)
            .sorted { luma(pal[$0][0], pal[$0][1], pal[$0][2]) > luma(pal[$1][0], pal[$1][1], pal[$1][2]) }
        var palRemap = [Int](repeating: 0, count: pal.count)
        for (newI, oldI) in palOrder.enumerated() { palRemap[oldI] = newI }
        let palette: [PaletteColor] = palOrder.enumerated().map { newI, oldI in
            let c = pal[oldI]
            return PaletteColor(r: c[0], g: c[1], b: c[2], hex: toHex(c[0], c[1], c[2]),
                                light: luma(c[0], c[1], c[2]) > 150, num: newI + 1)
        }

        var regionColor = [Int32](repeating: 0, count: reg.count)
        for i in 0..<reg.count { regionColor[i] = Int32(palRemap[reg.regionColor[i]]) }

        var colorCounts = [Int](repeating: 0, count: palette.count)
        for i in 0..<reg.count { colorCounts[Int(regionColor[i])] += 1 }

        return PBNData(w: w, h: h, palette: palette, colorCounts: colorCounts,
                       labels: reg.labels, regionColor: regionColor, regionPixels: reg.regionPixels,
                       regionCount: reg.count, centroids: cents, segments: seg)
    }
}
