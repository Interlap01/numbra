import SwiftUI
import PhotosUI

/// "New painting" = pick a source (library or camera) → straight to the difficulty selector.
/// No starter-scene grid here (those live in the library) and no "select then confirm" step.
/// Custom photos remain Plus-gated. Port/rework of screens.jsx `UploadScreen`.
struct UploadView: View {
    let model: AppModel

    @State private var showLibrary = false
    @State private var showCamera = false
    @State private var photoItem: PhotosPickerItem?

    private var cameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                CircleBackButton { model.screen = .gallery }
                Text("New painting").font(Theme.display(28)).foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 6)

            Spacer()

            VStack(spacing: 0) {
                Kicker(text: "Turn a photo into a canvas")
                Text("Pick a photo\nto paint")
                    .font(Theme.display(38, weight: .medium)).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center).lineSpacing(0).padding(.top, 8)
                Text("Numbra traces it into numbered, paintable regions. Then you choose a difficulty.")
                    .font(Theme.ui(15)).foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center).lineSpacing(3)
                    .frame(maxWidth: 320).padding(.top, 12).padding(.bottom, 28)

                VStack(spacing: 12) {
                    sourceRow(icon: "image", title: "Choose from library", subtitle: "Use one of your photos", dark: true,
                              action: chooseLibrary)
                    sourceRow(icon: "camera", title: "Take a photo",
                              subtitle: cameraAvailable ? "Use your camera" : "Camera unavailable here",
                              dark: false, disabled: !cameraAvailable, action: chooseCamera)
                }
                .padding(.horizontal, 22)

                if !model.isPlus {
                    HStack(spacing: 8) {
                        Icon(name: "sparkle", size: 15, color: Theme.terra, weight: .regular)
                        Text("Your own photos are a Numbra Plus feature.")
                            .font(Theme.ui(12.5, weight: .semibold)).foregroundStyle(Theme.ink)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.terra.opacity(0.08)))
                    .padding(.top, 18)
                }
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .bottom)
        .photosPicker(isPresented: $showLibrary, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    await MainActor.run { use(img) }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { img in
                showCamera = false
                if let img { use(img) }
            }
            .ignoresSafeArea()
        }
    }

    private func chooseLibrary() { if model.isPlus { showLibrary = true } else { model.paywall = .generic } }
    private func chooseCamera() { if model.isPlus { showCamera = true } else { model.paywall = .generic } }

    private func use(_ ui: UIImage) {
        guard let cg = Painter.normalized(ui) else { return }
        model.pickImage(Picked(image: cg, title: "My photo", custom: true, id: nil))
    }

    private func sourceRow(icon: String, title: String, subtitle: String, dark: Bool,
                           disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: { if !disabled { action() } }) {
            HStack(spacing: 14) {
                Icon(name: icon, size: 24, color: dark ? Theme.paper : Theme.ink, weight: .regular)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(Theme.ui(15.5, weight: .bold)).foregroundStyle(dark ? Theme.paper : Theme.ink)
                    Text(subtitle).font(Theme.ui(12.5)).foregroundStyle(dark ? Theme.paper.opacity(0.6) : Theme.muted)
                }
                Spacer()
                if !model.isPlus { PlusBadge() }
                else { Icon(name: "arrow-right", size: 17, color: dark ? Theme.paper.opacity(0.7) : Theme.muted, weight: .bold) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18).padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(dark ? Theme.ink : Theme.card)
                    .overlay(dark ? nil : RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.line, lineWidth: 1.5))
            )
        }
        .buttonStyle(PressableStyle())
        .opacity(disabled ? 0.45 : 1)
    }
}
