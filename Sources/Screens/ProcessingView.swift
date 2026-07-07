import SwiftUI

/// Branded loader covering the engine run. A diagonal sheen sweep + a 4-step checklist
/// that advances every 520ms. Port of screens.jsx `ProcessingScreen`.
struct ProcessingView: View {
    let model: AppModel
    @State private var step = 0
    @State private var sheen: CGFloat = -1

    private let steps = ["Reading your image", "Choosing a palette", "Tracing regions", "Numbering pieces"]
    private let timer = Timer.publish(every: 0.52, on: .main, in: .common).autoconnect()

    private var label: String { (model.picked?.custom ?? false) ? "Transforming" : "Building canvas" }

    var body: some View {
        VStack(spacing: 0) {
            if let img = model.picked?.thumb {
                ZStack {
                    CoverImage(image: img).frame(width: 220, height: 220)
                    GeometryReader { g in
                        LinearGradient(colors: [.clear, .white.opacity(0.55), .clear],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                            .frame(width: g.size.width * 1.6)
                            .offset(x: sheen * g.size.width * 1.4)
                            .blendMode(.screen)
                    }
                }
                .frame(width: 220, height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .shadow(color: Color(red: 60/255, green: 40/255, blue: 25/255).opacity(0.22), radius: 22, y: 18)
            }

            Text(label).font(Theme.display(24)).foregroundStyle(Theme.ink).padding(.top, 34)

            VStack(alignment: .leading, spacing: 9) {
                ForEach(steps.indices, id: \.self) { i in
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(i < step ? Theme.sage : i == step ? Theme.terra : Theme.card2)
                                .frame(width: 22, height: 22)
                            if i < step {
                                Icon(name: "check", size: 14, color: .white, weight: .heavy)
                            } else {
                                Circle().fill(i == step ? Color.white : Theme.muted).frame(width: 7, height: 7)
                            }
                        }
                        Text(steps[i]).font(Theme.ui(14.5, weight: .semibold)).foregroundStyle(Theme.ink)
                    }
                    .opacity(i <= step ? 1 : 0.34)
                    .animation(.easeOut(duration: 0.3), value: step)
                }
            }
            .frame(width: 230, alignment: .leading)
            .padding(.top, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(timer) { _ in if step < steps.count - 1 { step += 1 } }
        .onAppear {
            withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) { sheen = 1 }
        }
    }
}
