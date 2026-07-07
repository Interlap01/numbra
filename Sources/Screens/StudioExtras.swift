import SwiftUI
import UIKit

// MARK: - Timelapse replay (studio-extras.jsx `TimelapsePlayer`)

struct TimelapsePlayerView: View {
    let data: PBNData
    let order: [Int32]?
    let paper: String
    var onClose: () -> Void

    @State private var idx = 0
    @State private var playing = true
    @State private var speed = 1
    @State private var last = Date.now
    @State private var acc: Double = 0
    @State private var frame: UIImage?

    private var seq: [Int32] {
        if let order, order.count == data.regionCount { return order }
        return (0..<data.regionCount).map { Int32($0) }
            .sorted { data.regionColor[Int($0)] != data.regionColor[Int($1)]
                ? data.regionColor[Int($0)] < data.regionColor[Int($1)] : $0 < $1 }
    }
    private var total: Int { data.regionCount }
    private var done: Bool { idx >= total }

    var body: some View {
        ZStack {
            Theme.chromeDark.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text("Timelapse").font(Theme.display(22)).foregroundStyle(.white)
                    Spacer()
                    Button(action: onClose) {
                        Icon(name: "close", size: 20, color: .white, weight: .bold)
                            .frame(width: 40, height: 40).background(Circle().fill(Color.white.opacity(0.14)))
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 16).padding(.top, 56).padding(.bottom, 8)

                TimelineView(.animation) { tl in
                    Group {
                        if let frame {
                            Image(uiImage: frame).interpolation(.none).resizable().aspectRatio(contentMode: .fit)
                        } else { Color.clear }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 8)
                    .onChange(of: tl.date) { _, now in step(now) }
                }

                VStack(spacing: 10) {
                    Slider(value: Binding(get: { Double(idx) }, set: { playing = false; idx = Int($0); render() }), in: 0...Double(max(1, total)))
                        .tint(Theme.terra)
                    HStack(spacing: 18) {
                        Button { idx = 0; playing = true; render() } label: {
                            Icon(name: "back", size: 20, color: .white, weight: .bold)
                                .frame(width: 46, height: 46).background(Circle().fill(Color.white.opacity(0.14)))
                        }.buttonStyle(.plain)
                        Button {
                            if done { idx = 0; playing = true; render() } else { playing.toggle() }
                        } label: {
                            Image(systemName: playing && !done ? "pause.fill" : "play.fill")
                                .font(.system(size: 24, weight: .bold)).foregroundStyle(.white)
                                .frame(width: 58, height: 58).background(Circle().fill(Theme.terra))
                        }.buttonStyle(.plain)
                        Button { speed = speed >= 4 ? 1 : speed * 2 } label: {
                            Text("\(speed)×").font(Theme.ui(14, weight: .heavy)).foregroundStyle(.white)
                                .frame(height: 46).padding(.horizontal, 14).background(Capsule().fill(Color.white.opacity(0.14)))
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 22).padding(.bottom, 28)
            }
        }
        .onAppear { render() }
    }

    private func step(_ now: Date) {
        guard playing, !done else { return }
        acc += now.timeIntervalSince(last) * 1000
        last = now
        let perStep = 26.0 / Double(speed)
        if acc >= perStep {
            let add = Int(acc / perStep); acc = acc.truncatingRemainder(dividingBy: perStep)
            idx = min(total, idx + add)
            if idx >= total { playing = false }
            render()
        } else {
            last = now
        }
    }

    /// Re-fills up to `idx` onto paper and strokes seams (renderUpTo in the design).
    private func render() {
        let up = 4
        let w = data.w, h = data.h
        let (pr, pg, pb) = Color.rgbTriple(paper)
        var px = [UInt8](repeating: 0, count: w * h * 4)
        px.withUnsafeMutableBufferPointer { d in
            for i in 0..<(w * h) { d[i*4] = UInt8(pr); d[i*4+1] = UInt8(pg); d[i*4+2] = UInt8(pb); d[i*4+3] = 255 }
            let k = min(idx, seq.count)
            for n in 0..<k {
                let r = Int(seq[n]); let c = data.palette[Int(data.regionColor[r])]
                for pp in data.regionPixels[r] {
                    let p = Int(pp); d[p*4] = UInt8(c.r); d[p*4+1] = UInt8(c.g); d[p*4+2] = UInt8(c.b); d[p*4+3] = 255
                }
            }
        }
        let space = CGColorSpaceCreateDeviceRGB()
        guard let small = px.withUnsafeMutableBytes({ raw -> CGImage? in
            CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w*4,
                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        }) else { return }

        guard let ctx = CGContext(data: nil, width: w*up, height: h*up, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        ctx.interpolationQuality = .none
        ctx.draw(small, in: CGRect(x: 0, y: 0, width: w*up, height: h*up))
        // seams
        ctx.scaleBy(x: CGFloat(up), y: CGFloat(up))
        let path = CGMutablePath()
        let seg = data.segments
        var i = 0
        while i < seg.count {
            path.move(to: CGPoint(x: CGFloat(seg[i]), y: CGFloat(seg[i+1])))
            path.addLine(to: CGPoint(x: CGFloat(seg[i+2]), y: CGFloat(seg[i+3])))
            i += 4
        }
        ctx.addPath(path)
        ctx.setStrokeColor(red: 60/255, green: 45/255, blue: 30/255, alpha: 0.22)
        ctx.setLineWidth(0.7); ctx.setLineJoin(.round); ctx.strokePath()
        if let out = ctx.makeImage() {
            // The fill buffer is top-row-first and the seam path is baked into `out` in the
            // same space, so the composed image is already upright — display it as-is. (The
            // earlier `.downMirrored` double-flipped it, playing the timelapse upside-down.)
            frame = UIImage(cgImage: out, scale: 1, orientation: .up)
        }
    }
}

// MARK: - Before / after share card (studio-extras.jsx `ShareCard`)

struct ShareCardView: View {
    let before: UIImage?
    let after: UIImage
    let title: String
    let time: String?
    let pieces: String?
    let isPlus: Bool
    var onPaywall: () -> Void
    var onClose: () -> Void

    var body: some View {
        ZStack {
            // Near-opaque scrim so the Complete screen's own buttons don't bleed through.
            Color(red: 20/255, green: 14/255, blue: 8/255, opacity: 0.86).ignoresSafeArea()
                .onTapGesture { onClose() }
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        frameCell(before, "Photo")
                        frameCell(after, "Painted")
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(Theme.ink)

                    VStack(alignment: .leading, spacing: 0) {
                        Kicker(text: "Numbra", size: 12, tracking: 0.14 * 12)
                        Text(title).font(Theme.display(26)).foregroundStyle(Theme.ink).padding(.top, 2)
                        HStack(spacing: 16) {
                            Text("⏱ \(time ?? "—")").font(Theme.ui(13, weight: .semibold))
                            Text("◧ \(pieces ?? "—") pieces").font(Theme.ui(13, weight: .semibold))
                        }
                        .foregroundStyle(Theme.muted).padding(.top, 8)
                        HStack(spacing: 10) {
                            NButton(title: "Share", variant: .soft, size: .md, icon: "share", fullWidth: true) { presentShare() }
                            NButton(title: isPlus ? "Save HD" : "HD · Plus", variant: isPlus ? .primary : .dark,
                                    size: .md, icon: isPlus ? "check" : "lock", fullWidth: true) {
                                if !isPlus { onPaywall() }
                            }
                        }
                        .padding(.top, 16)
                    }
                    .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 20)
                }
                .frame(width: 320)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .shadow(color: .black.opacity(0.4), radius: 30, y: 24)
                Spacer()
                Button("Close", action: onClose)
                    .font(Theme.ui(15, weight: .bold)).foregroundStyle(.white.opacity(0.85)).buttonStyle(.plain)
                    .padding(.bottom, 30)
            }
        }
    }

    private func frameCell(_ img: UIImage?, _ label: String) -> some View {
        ShareCardView.frameCell(img, label)
    }

    /// Both cells use the same square `.fill` crop so a non-square photo and its painted
    /// render share identical framing (otherwise they read as two different pictures).
    static func frameCell(_ img: UIImage?, _ label: String) -> some View {
        VStack(spacing: 6) {
            Group {
                if let img { Image(uiImage: img).interpolation(.none).resizable().aspectRatio(1, contentMode: .fill) }
                else { Color.white.aspectRatio(1, contentMode: .fill) }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.9), lineWidth: 4))
            Text(label.uppercased()).font(Theme.ui(11, weight: .bold)).tracking(0.08 * 11).foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - share

    /// Render the before/after card to an image and present the system share sheet.
    @MainActor private func presentShare() {
        let card = ShareCardImage(before: before, after: after, title: title, time: time, pieces: pieces)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        let image = renderer.uiImage ?? after
        let av = UIActivityViewController(activityItems: [image, "Painted with Numbra"], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              var top = scene.keyWindow?.rootViewController else { return }
        while let presented = top.presentedViewController { top = presented }
        av.popoverPresentationController?.sourceView = top.view
        av.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
        top.present(av, animated: true)
    }
}

/// A self-contained, headless render of the share card (no buttons / scrim) used by
/// `ImageRenderer` to produce the shared artifact.
private struct ShareCardImage: View {
    let before: UIImage?
    let after: UIImage
    let title: String
    let time: String?
    let pieces: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ShareCardView.frameCell(before, "Photo")
                ShareCardView.frameCell(after, "Painted")
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(Theme.ink)

            VStack(alignment: .leading, spacing: 0) {
                Kicker(text: "Numbra", size: 12, tracking: 0.14 * 12)
                Text(title).font(Theme.display(26)).foregroundStyle(Theme.ink).padding(.top, 2)
                HStack(spacing: 16) {
                    Text("⏱ \(time ?? "—")").font(Theme.ui(13, weight: .semibold))
                    Text("◧ \(pieces ?? "—") pieces").font(Theme.ui(13, weight: .semibold))
                }
                .foregroundStyle(Theme.muted).padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 20)
            .background(Theme.card)
        }
        .frame(width: 360)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

// MARK: - Achievements sheet (studio-extras.jsx `AchievementsSheet`)

struct AchievementsSheetView: View {
    let progress: ProgressData
    private let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        let lv = Progression.levelFor(progress.xp)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                ProgressRing(value: lv.pct, size: 58, lineWidth: 5, color: Theme.terra) {
                    Text("\(lv.level)").font(Theme.ui(20, weight: .heavy)).foregroundStyle(Theme.ink)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Level \(lv.level)").font(Theme.display(24)).foregroundStyle(Theme.ink)
                    Text("\(lv.into) / \(lv.need) XP to next · \(progress.completed) finished")
                        .font(Theme.ui(13, weight: .semibold)).foregroundStyle(Theme.muted)
                }
                Spacer()
                if progress.streak > 0 {
                    VStack(spacing: 2) {
                        Icon(name: "drop", size: 18, color: Theme.terra, weight: .regular)
                        Text("\(progress.streak)").font(Theme.ui(15, weight: .heavy)).foregroundStyle(Theme.ink)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.terra.opacity(0.1)))
                }
            }
            .padding(.bottom, 16)

            Text("ACHIEVEMENTS").font(Theme.ui(12.5, weight: .heavy)).tracking(0.1 * 12.5).foregroundStyle(Theme.muted)
                .padding(.bottom, 10)

            ScrollView {
                LazyVGrid(columns: cols, spacing: 10) {
                    ForEach(Progression.achievements) { a in
                        let got = progress.unlocked[a.id] != nil
                        HStack(spacing: 10) {
                            Icon(name: got ? a.icon : "lock", size: 20, color: .white, weight: .regular)
                                .frame(width: 38, height: 38)
                                .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(got ? Theme.sage : Color.black.opacity(0.12)))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(a.title).font(Theme.ui(13, weight: .bold)).foregroundStyle(Theme.ink).lineLimit(1)
                                Text(a.desc).font(Theme.ui(11)).foregroundStyle(Theme.muted).lineLimit(2)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .frame(minHeight: 62)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(got ? Theme.sage.opacity(0.12) : Theme.card2))
                        .opacity(got ? 1 : 0.6)
                    }
                }
                .padding(.bottom, 8)
            }
            .frame(maxHeight: 300)
        }
    }
}
