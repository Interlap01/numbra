import SwiftUI

/// Numbra Plus paywall sheet (app.jsx paywall). On purchase, resumes a pending
/// difficulty config if the paywall was opened mid-creation.
struct PaywallContent: View {
    let model: AppModel
    /// When set (onboarding's final step), both the subscribe and "Maybe later" actions
    /// call this to advance/finish onboarding instead of just dismissing a sheet.
    var onboardingFinish: (() -> Void)? = nil
    private let benefits = [
        "Turn your own photos into canvases",
        "Hard mode + premium themed packs",
        "HD exports · timelapse · no ads",
    ]

    var body: some View {
        VStack(spacing: 0) {
            Icon(name: "sparkle", size: 30, color: .white, weight: .regular)
                .frame(width: 60, height: 60)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.terra))
                .shadow(color: Theme.terra.opacity(0.36), radius: 12, y: 10)
                .padding(.bottom, 14)
            Text("Numbra Plus").font(Theme.display(28)).foregroundStyle(Theme.ink)
            Text("Transform any photo, unlock Hard mode & premium packs, save in HD, and paint without limits.")
                .font(Theme.ui(14.5)).foregroundStyle(Theme.muted).multilineTextAlignment(.center).lineSpacing(2)
                .padding(.horizontal, 24).padding(.top, 6).padding(.bottom, 16)

            VStack(alignment: .leading, spacing: 9) {
                ForEach(benefits, id: \.self) { f in
                    HStack(spacing: 10) {
                        Icon(name: "check", size: 13, color: .white, weight: .heavy)
                            .frame(width: 22, height: 22).background(Circle().fill(Theme.sage))
                        Text(f).font(Theme.ui(14.5, weight: .semibold)).foregroundStyle(Theme.ink)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 18)

            NButton(title: "Start free trial · then $4.99/mo", variant: .primary, size: .lg, fullWidth: true) {
                model.unlockPlus()
                let pending = model.paywall
                model.paywall = nil
                if case let .config(cfg) = pending {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { model.runEngine(cfg) }
                }
                onboardingFinish?()
            }
            // Onboarding gets an equal-weight free path so subscribing isn't forced.
            if onboardingFinish != nil {
                NButton(title: "Continue free", variant: .soft, size: .lg, fullWidth: true) {
                    model.paywall = nil; onboardingFinish?()
                }
                .padding(.top, 10)
            } else {
                Button("Maybe later") { model.paywall = nil }
                    .font(Theme.ui(14, weight: .semibold)).foregroundStyle(Theme.muted).buttonStyle(.plain)
                    .padding(.top, 12)
            }
        }
    }
}

/// Pack sheet — pick a scene from a pack to begin (app.jsx pack sheet).
struct PackSheetContent: View {
    let model: AppModel
    let pack: Pack
    private let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(pack.title).font(Theme.display(26)).foregroundStyle(Theme.ink)
            Text("Pick a scene to begin.").font(Theme.ui(13.5)).foregroundStyle(Theme.muted)
                .padding(.top, 4).padding(.bottom, 14)
            LazyVGrid(columns: cols, spacing: 12) {
                ForEach(pack.sceneIds, id: \.self) { id in
                    if let scene = model.sampleById(id) {
                        Button { model.startSceneFromPack(scene) } label: {
                            VStack(alignment: .leading, spacing: 0) {
                                CoverImage(image: scene.thumb).aspectRatio(1, contentMode: .fill)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .shadow(color: Color(red: 60/255, green: 40/255, blue: 25/255).opacity(0.14), radius: 8, y: 6)
                                Text(scene.title).font(Theme.ui(13.5, weight: .bold)).foregroundStyle(Theme.ink)
                                    .padding(.top, 7).padding(.horizontal, 2)
                            }
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
