import Foundation

/// XP, levels, streaks, daily challenge, achievements. Port of progression.jsx,
/// persisted to UserDefaults (key `numbra_progress_v1`).
struct ProgressData: Codable {
    var xp = 0
    var completed = 0
    var totalPieces = 0
    var perfectRuns = 0
    var streak = 0
    var maxStreak = 0
    var lastPlayDay: String?
    var dailyDoneDay: String?
    var customMade = 0
    var hardDone = 0
    var unlocked: [String: String] = [:]
}

struct LevelInfo { let level: Int; let into: Int; let need: Int; let pct: Double }

struct Achievement: Identifiable {
    let id: String
    let title: String
    let desc: String
    let icon: String
    let test: (ProgressData) -> Bool
}

enum Progression {
    private static let key = "numbra_progress_v1"

    static func today() -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private static func parse(_ s: String) -> Date? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)
    }

    private static func dayDiff(_ a: String?, _ b: String?) -> Int {
        guard let a, let b, let da = parse(a), let db = parse(b) else { return .max }
        return Int((db.timeIntervalSince(da) / 86_400).rounded())
    }

    static func load() -> ProgressData {
        guard let data = UserDefaults.standard.data(forKey: key),
              let p = try? JSONDecoder().decode(ProgressData.self, from: data) else { return ProgressData() }
        return p
    }

    static func save(_ p: ProgressData) {
        if let data = try? JSONEncoder().encode(p) { UserDefaults.standard.set(data, forKey: key) }
    }

    static func reset() { UserDefaults.standard.removeObject(forKey: key) }

    static func levelFor(_ xp: Int) -> LevelInfo {
        var lvl = 1, need = 120, rem = xp
        while rem >= need { rem -= need; lvl += 1; need = 120 * lvl }
        return LevelInfo(level: lvl, into: rem, need: need, pct: Double(rem) / Double(need))
    }

    static let achievements: [Achievement] = [
        Achievement(id: "first", title: "First Strokes", desc: "Finish your first canvas", icon: "brush") { $0.completed >= 1 },
        Achievement(id: "flawless", title: "Flawless", desc: "Finish with zero mistakes", icon: "check") { $0.perfectRuns >= 1 },
        Achievement(id: "collector", title: "Collector", desc: "Complete 5 canvases", icon: "grid") { $0.completed >= 5 },
        Achievement(id: "marathon", title: "Marathon", desc: "Paint 1,000 pieces", icon: "palette") { $0.totalPieces >= 1000 },
        Achievement(id: "onfire", title: "On a Roll", desc: "3-day streak", icon: "drop") { $0.maxStreak >= 3 },
        Achievement(id: "devoted", title: "Devoted", desc: "7-day streak", icon: "star") { $0.maxStreak >= 7 },
        Achievement(id: "lvl5", title: "Rising Artist", desc: "Reach level 5", icon: "sparkle") { levelFor($0.xp).level >= 5 },
        Achievement(id: "transformer", title: "Alchemist", desc: "Transform your own photo", icon: "image") { $0.customMade >= 1 },
        Achievement(id: "master", title: "Master Hand", desc: "Finish a Hard canvas", icon: "wand") { $0.hardDone >= 1 },
    ]

    /// Called when the app opens — resets a broken streak.
    @discardableResult
    static func touchOpen() -> ProgressData {
        var p = load()
        let d = dayDiff(p.lastPlayDay, today())
        if p.lastPlayDay != nil && d > 1 { p.streak = 0 }
        save(p)
        return p
    }

    /// Marks today as played (a session started) — maintains streak continuity.
    @discardableResult
    static func play() -> ProgressData {
        var p = load()
        let d = dayDiff(p.lastPlayDay, today())
        if p.lastPlayDay == nil { p.streak = 1 }
        else if d == 1 { p.streak += 1 }
        else if d > 1 { p.streak = 1 }
        p.maxStreak = max(p.maxStreak, p.streak)
        p.lastPlayDay = today()
        save(p)
        return p
    }

    struct CompletionResult { let xpGain: Int; let leveledUp: Bool; let level: Int; let newly: [Achievement]; let progress: ProgressData }

    static func recordCompletion(pieces: Int, mistakes: Int, isCustom: Bool, isHard: Bool, isDaily: Bool) -> CompletionResult {
        var p = load()
        let gain = 50 + min(70, pieces) + (mistakes == 0 ? 30 : 0) + (isDaily ? 25 : 0)
        let beforeLvl = levelFor(p.xp).level
        p.xp += gain
        p.completed += 1
        p.totalPieces += pieces
        if mistakes == 0 { p.perfectRuns += 1 }
        if isCustom { p.customMade += 1 }
        if isHard { p.hardDone += 1 }
        if isDaily { p.dailyDoneDay = today() }
        var newly = [Achievement]()
        for a in achievements where p.unlocked[a.id] == nil && a.test(p) {
            p.unlocked[a.id] = today()
            newly.append(a)
        }
        save(p)
        let afterLvl = levelFor(p.xp).level
        return CompletionResult(xpGain: gain, leveledUp: afterLvl > beforeLvl, level: afterLvl, newly: newly, progress: p)
    }

    /// Deterministic per-date pick from a list length (hash of YYYYMMDD).
    static func dailyIndex(_ n: Int) -> Int {
        let s = today().replacingOccurrences(of: "-", with: "")
        var h: UInt32 = 0
        for c in s.unicodeScalars { h = (h &* 31 &+ c.value) }
        return Int(h % UInt32(n))
    }

    static func dailyDone() -> Bool { load().dailyDoneDay == today() }
}
