import UIKit

/// Disk persistence for the library. Project metadata and paint sessions are one JSON
/// index; custom source images are lossless PNGs alongside it. `PBNData` itself is never
/// serialized — the engine is pure and deterministic, so a session stores the engine
/// options it was generated with and the region data is regenerated on resume.
enum ProjectStore {
    struct SavedSession: Codable {
        var colors: Int
        var detail: Int
        var filled: Data
        var order: [Int32]
        var elapsed: TimeInterval
        var isHard: Bool
    }

    struct SavedProject: Codable {
        var id: String
        var title: String
        var colors: Int
        var progress: Double
        var session: SavedSession?
    }

    private static let dir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NumbraLibrary", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    private static var indexURL: URL { dir.appendingPathComponent("library.json") }

    static func load() -> [SavedProject] {
        guard let d = try? Data(contentsOf: indexURL),
              let saved = try? JSONDecoder().decode([SavedProject].self, from: d) else { return [] }
        return saved
    }

    static func save(_ projects: [SavedProject]) {
        guard let d = try? JSONEncoder().encode(projects) else { return }
        try? d.write(to: indexURL, options: .atomic)
    }

    /// PNG (lossless) so the reloaded pixels regenerate the exact same regions.
    static func saveImage(_ image: CGImage, id: String) {
        guard let png = UIImage(cgImage: image).pngData() else { return }
        try? png.write(to: dir.appendingPathComponent("\(id).png"), options: .atomic)
    }

    static func loadImage(id: String) -> CGImage? {
        UIImage(contentsOfFile: dir.appendingPathComponent("\(id).png").path)?.cgImage
    }

    static func deleteImage(id: String) {
        try? FileManager.default.removeItem(at: dir.appendingPathComponent("\(id).png"))
    }
}
