import SwiftUI

/// Home / studio. Continue in-progress work, start new, daily challenge, packs,
/// library, level. Port of screens.jsx `Gallery`.
struct GalleryView: View {
    let model: AppModel

    private var featured: Project? {
        model.projects.first { $0.progress > 0 && $0.progress < 1 } ?? model.projects.first
    }

    private let cols = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // header
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Kicker(text: "Numbra")
                        Text("Your studio")
                            .font(Theme.display(38))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                    }
                    Spacer()
                    LevelBadge(progress: model.progress) { model.achOpen = true }
                }
                .padding(.horizontal, 22)
                .padding(.top, 8).padding(.bottom, 8)

                if let daily = model.daily {
                    DailyBanner(sample: daily, done: Progression.dailyDone(), streak: model.progress.streak) {
                        model.startDaily()
                    }
                    .padding(.horizontal, 18).padding(.top, 14)
                }

                if let featured {
                    FeaturedCard(project: featured) { model.openProject(featured) }
                        .padding(.horizontal, 18).padding(.top, 18)
                }

                if !model.packs.isEmpty {
                    PacksRail(packs: model.packs) { model.openPack($0) }
                        .padding(.top, 6)
                }

                HStack {
                    Text("Library").font(Theme.display(22)).foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(model.projects.count) canvases").font(Theme.ui(13.5, weight: .semibold)).foregroundStyle(Theme.muted)
                }
                .padding(.horizontal, 22).padding(.top, 20).padding(.bottom, 12)

                LazyVGrid(columns: cols, spacing: 14) {
                    NewPaintingTile { model.goNew() }
                    ForEach(model.projects) { p in
                        ProjectTile(project: p, onTap: { model.openProject(p) },
                                    onReset: p.progress > 0 ? { model.resetProject(p) } : nil,
                                    onDelete: model.canDelete(p) ? { model.deleteProject(p) } : nil)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 40)
            }
        }
        .scrollIndicators(.hidden)
        // Let the scroll content inset below the status bar so the library section header
        // no longer slides under the clock / battery when scrolled.
    }
}

private struct FeaturedCard: View {
    let project: Project
    var onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                CoverImage(image: project.thumb)
                BottomScrim()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.progress >= 1 ? "REPLAY" : (project.progress > 0 ? "CONTINUE" : "FEATURED"))
                            .font(Theme.ui(12.5, weight: .bold)).tracking(0.08 * 12.5)
                            .foregroundStyle(.white.opacity(0.8))
                        Text(project.title).font(Theme.display(27)).foregroundStyle(.white).lineLimit(1)
                    }
                    Spacer()
                    ProgressRing(value: project.progress, size: 50, lineWidth: 5,
                                 track: .white.opacity(0.28), color: .white) {
                        Text("\(Int(project.progress * 100))%").font(Theme.ui(12, weight: .heavy)).foregroundStyle(.white)
                    }
                }
                .padding(18)
            }
            .aspectRatio(3.0/2.0, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: Color(red: 60/255, green: 40/255, blue: 25/255).opacity(0.16), radius: 17, y: 14)
        }
        .buttonStyle(PressableStyle())
    }
}

private struct NewPaintingTile: View {
    var onTap: () -> Void
    var body: some View {
        // Square card matching ProjectTile's footprint so the grid row aligns.
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Theme.terra.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Theme.terra.opacity(0.45), style: StrokeStyle(lineWidth: 2, dash: [6, 5])))
                VStack(spacing: 10) {
                    Icon(name: "plus", size: 26, color: .white, weight: .heavy)
                        .frame(width: 54, height: 54)
                        .background(RoundedRectangle(cornerRadius: 17, style: .continuous).fill(Theme.terra))
                        .shadow(color: Theme.terra.opacity(0.34), radius: 9, y: 8)
                    VStack(spacing: 1) {
                        Text("New painting").font(Theme.ui(14.5, weight: .bold)).foregroundStyle(Theme.terra)
                        Text("Photo or camera").font(Theme.ui(11.5, weight: .semibold)).foregroundStyle(Theme.terra.opacity(0.7))
                    }
                }
            }
            .aspectRatio(3.0/4.0, contentMode: .fit)
        }
        .buttonStyle(PressableStyle())
    }
}

private struct ProjectTile: View {
    let project: Project
    var onTap: () -> Void
    var onReset: (() -> Void)?
    var onDelete: (() -> Void)?
    var body: some View {
        Button(action: onTap) {
            // The overlay ZStack (sized by Color.clear + aspectRatio) defines the 3:4 cell; the
            // image goes in `.background`, which is sized to the cell and clips — so a square or
            // oversized photo can neither blow out the layout nor shove the labels off-edge.
            ZStack(alignment: .bottomLeading) {
                Color.clear
                BottomScrim(height: 0.5)

                if project.progress >= 1 {
                    Icon(name: "check", size: 15, color: .white, weight: .heavy)
                        .frame(width: 26, height: 26).background(Circle().fill(Theme.sage))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(9)
                }

                HStack(alignment: .bottom, spacing: 8) {
                    Text(project.title).font(Theme.ui(14.5, weight: .bold)).foregroundStyle(.white)
                        .lineLimit(2).multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    if project.progress > 0 && project.progress < 1 {
                        ProgressRing(value: project.progress, size: 30, lineWidth: 3.5,
                                     track: .white.opacity(0.3), color: .white) {
                            Text("\(Int(project.progress * 100))").font(Theme.ui(9, weight: .heavy)).foregroundStyle(.white)
                        }
                    }
                }
                .padding(13)
            }
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .background { CoverImage(image: project.thumb) }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1))
            .shadow(color: Color(red: 60/255, green: 40/255, blue: 25/255).opacity(0.16), radius: 14, y: 11)
        }
        .buttonStyle(PressableStyle())
        .contextMenu {
            if let onReset {
                Button(action: onReset) {
                    Label(project.progress >= 1 ? "Paint again" : "Reset painting", systemImage: "arrow.counterclockwise")
                }
            }
            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete from library", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Level badge (studio-extras.jsx)

struct LevelBadge: View {
    let progress: ProgressData
    var onTap: () -> Void
    var body: some View {
        let lv = Progression.levelFor(progress.xp)
        Button(action: onTap) {
            ProgressRing(value: lv.pct, size: 48, lineWidth: 4) {
                VStack(spacing: 0) {
                    Text("\(lv.level)").font(Theme.ui(15, weight: .heavy)).foregroundStyle(Theme.ink)
                    Text("LVL").font(Theme.ui(7.5, weight: .bold)).tracking(0.1 * 7.5).foregroundStyle(Theme.muted)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Daily challenge banner

struct DailyBanner: View {
    let sample: Project
    let done: Bool
    let streak: Int
    var onStart: () -> Void
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                CoverImage(image: sample.thumb).frame(width: 70, height: 70)
                if done {
                    Theme.sage.opacity(0.7)
                    Icon(name: "check", size: 28, color: .white, weight: .heavy)
                }
            }
            .frame(width: 70, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 7) {
                    Kicker(text: "Daily challenge", size: 11.5, tracking: 0.12 * 11.5)
                    if streak > 0 {
                        HStack(spacing: 3) {
                            Icon(name: "drop", size: 13, color: Color(hex: 0xf3a64b), weight: .bold)
                            Text("\(streak)").font(Theme.ui(12, weight: .heavy)).foregroundStyle(Color(hex: 0xf3a64b))
                        }
                    }
                }
                Text(done ? "Done for today" : sample.title).font(Theme.display(20)).foregroundStyle(.white)
            }
            Spacer()
            Button(action: { if !done { onStart() } }) {
                Text(done ? "✓" : "Start")
                    .font(Theme.ui(14, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(Capsule().fill(done ? Color.white.opacity(0.14) : Theme.terra))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.ink))
    }
}

// MARK: - Themed packs rail

struct PacksRail: View {
    let packs: [Pack]
    var onOpen: (Pack) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Themed packs").font(Theme.display(22)).foregroundStyle(Theme.ink)
                .padding(.horizontal, 22).padding(.top, 22).padding(.bottom, 12)
            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(packs) { p in
                        Button(action: { onOpen(p) }) {
                            VStack(alignment: .leading, spacing: 0) {
                                ZStack(alignment: .topTrailing) {
                                    HStack(spacing: 2) {
                                        ForEach(Array(p.covers.enumerated()), id: \.offset) { _, cv in
                                            CoverImage(image: cv).frame(maxWidth: .infinity)
                                        }
                                    }
                                    // gentle top vignette so the PLUS badge stays legible
                                    LinearGradient(colors: [Color.black.opacity(0.28), .clear],
                                                   startPoint: .top, endPoint: .init(x: 0.5, y: 0.5))
                                    if p.plus {
                                        HStack(spacing: 4) {
                                            Icon(name: "lock", size: 11, color: .white, weight: .bold)
                                            Text("PLUS").font(Theme.ui(10, weight: .heavy)).foregroundStyle(.white)
                                        }
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(Capsule().fill(Color.black.opacity(0.55)))
                                        .padding(8)
                                    }
                                }
                                .frame(width: 168, height: 112)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .shadow(color: Color(red: 60/255, green: 40/255, blue: 25/255).opacity(0.12), radius: 10, y: 8)

                                // Title + count below the artwork so they never clip over busy art.
                                Text(p.title).font(Theme.ui(15, weight: .bold)).foregroundStyle(Theme.ink)
                                    .lineLimit(1).minimumScaleFactor(0.8)
                                    .padding(.top, 8).padding(.horizontal, 2)
                                Text("\(p.count) scenes").font(Theme.ui(12.5, weight: .semibold)).foregroundStyle(Theme.muted)
                                    .padding(.top, 1).padding(.horizontal, 2)
                            }
                            .frame(width: 168)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.horizontal, 18).padding(.bottom, 4)
            }
            .scrollIndicators(.hidden)
        }
    }
}
