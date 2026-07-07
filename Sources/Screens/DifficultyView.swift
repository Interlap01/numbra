import SwiftUI

/// Pick Easy / Medium / Hard. Hard (and custom photos) are Plus-gated.
/// Port of screens.jsx `DifficultyScreen`.
struct DifficultyView: View {
    let model: AppModel
    @State private var diff = "medium"

    private var requiresPlus: Bool { model.picked?.custom ?? false }
    private var needsPlus: Bool { (requiresPlus || diff == "hard") && !model.isPlus }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        CircleBackButton { model.screen = requiresPlus ? .upload : .gallery }
                        Text("Difficulty").font(Theme.display(28)).foregroundStyle(Theme.ink)
                    }
                    .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 6)

                    if let img = model.picked?.thumb {
                        CoverImage(image: img)
                            .aspectRatio(16.0/10.0, contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                            .shadow(color: Color(red: 60/255, green: 40/255, blue: 25/255).opacity(0.16), radius: 17, y: 14)
                            .padding(.horizontal, 22).padding(.top, 14)
                    }

                    VStack(spacing: 12) {
                        ForEach(Difficulty.all) { d in
                            row(d)
                        }
                    }
                    .padding(.horizontal, 18).padding(.top, 22)
                }
            }
            .scrollIndicators(.hidden)

            NButton(title: needsPlus ? "Unlock & create canvas" : "Create canvas",
                    variant: .primary, size: .lg, icon: "brush", fullWidth: true) {
                let cfg = Difficulty.all.first { $0.id == diff }!
                if needsPlus { model.paywall = .config(cfg) } else { model.runEngine(cfg) }
            }
            .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 20)
        }
    }

    private func row(_ d: Difficulty) -> some View {
        let active = d.id == diff
        return Button { diff = d.id } label: {
            HStack(spacing: 16) {
                // difficulty bar glyph
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        let on = (d.id == "easy" && i < 1) || (d.id == "medium" && i < 2) || d.id == "hard"
                        Capsule().fill(on ? Theme.terra : Theme.card2)
                            .frame(width: 6, height: 22 + CGFloat(i) * 6)
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(d.label).font(Theme.ui(17, weight: .heavy)).foregroundStyle(Theme.ink)
                    Text(d.sub).font(Theme.ui(13)).foregroundStyle(Theme.muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(d.colors) colors").font(Theme.ui(13.5, weight: .bold)).foregroundStyle(Theme.ink)
                    Text(d.pieces).font(Theme.ui(12)).foregroundStyle(Theme.muted)
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(active ? Theme.terra : Theme.line, lineWidth: 2.5))
            )
            .shadow(color: active ? Theme.terra.opacity(0.16) : .clear, radius: 11, y: 8)
            .overlay(alignment: .topTrailing) {
                if d.id == "hard" && !model.isPlus { PlusBadge().padding(.top, 10).padding(.trailing, 12) }
            }
        }
        .buttonStyle(.plain)
    }
}
