import CoreGraphics

/// One palette color in the generated paint-by-numbers data.
/// Ported from pbn-engine.jsx `palette` entries.
struct PaletteColor: Equatable {
    var r: Int
    var g: Int
    var b: Int
    var hex: String
    /// True when the color is light enough that numbers/checks should be drawn dark.
    var light: Bool
    /// 1-based display number (palette is sorted light→dark, so num follows that order).
    var num: Int

    var color: CGColor {
        CGColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }
}

/// A region's label anchor: nearest interior pixel to the centroid plus a size hint.
struct Centroid: Equatable {
    var x: Double
    var y: Double
    /// Crude inscribed radius (sqrt(area/π)) — drives label font sizing & culling.
    var r: Double
}

/// The full output of `PBNEngine.generate`. Platform-agnostic; the canvas renders it.
/// Mirrors the object returned by pbn-engine.jsx `generate()`.
final class PBNData {
    let w: Int
    let h: Int
    let palette: [PaletteColor]
    /// Number of regions per palette color (so finished colors can be detected/dropped).
    let colorCounts: [Int]
    /// Region id per pixel, row-major. Length == w*h. Used for O(1) hit testing.
    let labels: [Int32]
    /// Palette index per region.
    let regionColor: [Int32]
    /// Pixel indices per region (for fills/timelapse).
    let regionPixels: [[Int32]]
    let regionCount: Int
    /// Label anchor + size hint per region, in image coordinates.
    let centroids: [Centroid]
    /// Boundary edges (x1,y1,x2,y2,…) between differing labels, for seam stroking.
    let segments: [Float]

    init(w: Int, h: Int, palette: [PaletteColor], colorCounts: [Int],
         labels: [Int32], regionColor: [Int32], regionPixels: [[Int32]],
         regionCount: Int, centroids: [Centroid], segments: [Float]) {
        self.w = w; self.h = h
        self.palette = palette
        self.colorCounts = colorCounts
        self.labels = labels
        self.regionColor = regionColor
        self.regionPixels = regionPixels
        self.regionCount = regionCount
        self.centroids = centroids
        self.segments = segments
    }
}
