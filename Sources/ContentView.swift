import SwiftUI

/// Root router — the screen state machine + global overlays/sheets (app.jsx `App`).
struct ContentView: View {
    @State private var model = AppModel()

    var body: some View {
        Group {
            
            if !model.onboarded {
                OnboardingView(model: model) { model.finishOnboarding() }
            } else {
                rootShell
            }
        }
        .preferredColorScheme(.light)
        .task { model.bootstrap() }
    }

    @ViewBuilder private var rootShell: some View {
        @Bindable var m = model
        let fullBleed = model.screen == .paint

        ZStack {
            (fullBleed ? model.settings.canvasBg : Theme.paper).ignoresSafeArea()

            screenView

            // toast
            if let toast = model.toast {
                ToastView(toast: toast) { model.toast = nil }.zIndex(95)
            }

            // timelapse / share overlays
            if let overlay = model.overlay {
                switch overlay {
                case let .timelapse(data, order):
                    TimelapsePlayerView(data: data, order: order, paper: model.settings.paper) { model.overlay = nil }
                        .zIndex(92).transition(.opacity)
                case let .share(before, after):
                    ShareCardView(before: before, after: after, title: model.projTitle,
                                  time: model.complete?.time, pieces: model.complete?.pieces,
                                  isPlus: model.isPlus, onPaywall: { model.paywall = .generic }) { model.overlay = nil }
                        .zIndex(92).transition(.opacity)
                }
            }

            // achievements sheet
            BottomSheet(isPresented: $m.achOpen) {
                AchievementsSheetView(progress: model.progress)
            }
            .zIndex(80)

            // pack sheet
            BottomSheet(isPresented: Binding(get: { model.packSheet != nil }, set: { if !$0 { model.packSheet = nil } })) {
                if let pack = model.packSheet { PackSheetContent(model: model, pack: pack) }
            }
            .zIndex(81)

            // paywall sheet
            BottomSheet(isPresented: Binding(get: { model.paywall != nil }, set: { if !$0 { model.paywall = nil } })) {
                PaywallContent(model: model)
            }
            .zIndex(82)
        }
        .animation(.easeInOut(duration: 0.25), value: model.screen)
        .animation(.easeInOut(duration: 0.3), value: overlayKey)
    }

    private var overlayKey: Int {
        if model.overlay == nil { return 0 }
        if case .timelapse = model.overlay { return 1 }
        return 2
    }

    @ViewBuilder private var screenView: some View {
        switch model.screen {
        case .gallery: GalleryView(model: model)
        case .upload: UploadView(model: model)
        case .difficulty: DifficultyView(model: model)
        case .processing: ProcessingView(model: model)
        case .paint:
            if let data = model.data { PaintView(model: model, data: data) }
        case .complete:
            if let info = model.complete { CompleteView(model: model, info: info) }
        }
    }
}

#Preview {
    ContentView()
}
