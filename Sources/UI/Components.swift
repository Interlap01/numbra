import SwiftUI

// MARK: - Button (ui-kit.jsx `Btn`)

enum BtnVariant { case primary, dark, ghost, soft, sage }
enum BtnSize { case sm, md, lg }

struct NButton: View {
    let title: String
    var variant: BtnVariant = .primary
    var size: BtnSize = .md
    var icon: String?
    var fullWidth: Bool = false
    var disabled: Bool = false
    let action: () -> Void

    private var pad: (CGFloat, CGFloat) {
        switch size { case .sm: return (16, 9); case .md: return (22, 13); case .lg: return (26, 17) }
    }
    private var fontSize: CGFloat { switch size { case .sm: return 14; case .md: return 15.5; case .lg: return 17 } }
    private var iconSize: CGFloat { size == .lg ? 19 : 16 }

    private var bg: Color {
        switch variant {
        case .primary: return Theme.terra
        case .dark: return Theme.ink
        case .ghost: return .clear
        case .soft: return Theme.card2
        case .sage: return Theme.sage
        }
    }
    private var fg: Color {
        switch variant {
        case .primary, .sage: return .white
        case .dark: return Theme.paper
        case .ghost, .soft: return Theme.ink
        }
    }
    private var glow: Color {
        switch variant {
        case .primary: return Theme.terra.opacity(0.34)
        case .sage: return Theme.sage.opacity(0.32)
        default: return .clear
        }
    }

    var body: some View {
        Button(action: { if !disabled { action() } }) {
            HStack(spacing: 9) {
                if let icon { Icon(name: icon, size: iconSize, color: fg, weight: .bold) }
                Text(title).font(Theme.ui(fontSize, weight: .bold)).foregroundStyle(fg)
            }
            .padding(.horizontal, pad.0).padding(.vertical, pad.1)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(Capsule().fill(bg))
            .shadow(color: glow, radius: 9, y: 6)
        }
        .buttonStyle(PressableStyle())
        .opacity(disabled ? 0.45 : 1)
        .disabled(disabled)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Progress ring (ui-kit.jsx `Ring`)

struct ProgressRing<Content: View>: View {
    var value: Double
    var size: CGFloat = 40
    var lineWidth: CGFloat = 4
    var track: Color = Color.black.opacity(0.08)
    var color: Color = Theme.terra
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, value)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.4), value: value)
            content()
        }
        .frame(width: size, height: size)
    }
}

extension ProgressRing where Content == EmptyView {
    init(value: Double, size: CGFloat = 40, lineWidth: CGFloat = 4,
         track: Color = Color.black.opacity(0.08), color: Color = Theme.terra) {
        self.init(value: value, size: size, lineWidth: lineWidth, track: track, color: color) { EmptyView() }
    }
}

// MARK: - Segmented control (ui-kit.jsx `Segmented`)

struct SegOption: Identifiable { let value: String; let label: String; let icon: String?; var id: String { value } }

struct Segmented: View {
    @Binding var value: String
    let options: [SegOption]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options) { o in
                let active = o.value == value
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { value = o.value }
                } label: {
                    HStack(spacing: 7) {
                        if let icon = o.icon { Icon(name: icon, size: 17, color: active ? Theme.ink : Theme.muted, weight: .bold) }
                        Text(o.label).font(Theme.ui(14, weight: .bold))
                    }
                    .foregroundStyle(active ? Theme.ink : Theme.muted)
                    .frame(maxWidth: .infinity).padding(.vertical, 10).padding(.horizontal, 8)
                    .background(
                        Capsule().fill(active ? Theme.card : .clear)
                            .shadow(color: active ? .black.opacity(0.1) : .clear, radius: 4, y: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Theme.card2))
    }
}

// MARK: - PLUS lock badge

struct PlusBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Icon(name: "lock", size: 11, color: .white, weight: .bold)
            Text("PLUS").font(Theme.ui(9.5, weight: .heavy)).foregroundStyle(.white)
        }
        .padding(.leading, 6).padding(.trailing, 8).padding(.vertical, 3)
        .background(Capsule().fill(Theme.terra))
    }
}

// MARK: - Bottom sheet container (ui-kit.jsx `Sheet`)

struct BottomSheet<Content: View>: View {
    @Binding var isPresented: Bool
    var dark: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .bottom) {
            if isPresented {
                Color(red: 30/255, green: 24/255, blue: 18/255, opacity: 0.42)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { isPresented = false } }
                VStack(spacing: 0) {
                    Capsule().fill(Color.black.opacity(0.14)).frame(width: 40, height: 5).padding(.top, 12).padding(.bottom, 14)
                    content()
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity)
                .background((dark ? Color(hex: 0x1d1b18) : Theme.card).clipShape(SheetShape()))
                .transition(.move(edge: .bottom))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: isPresented)
        .ignoresSafeArea()
    }
}

/// Rounded top corners only.
struct SheetShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(roundedRect: rect, byRoundingCorners: [.topLeft, .topRight],
                          cornerRadii: CGSize(width: 30, height: 30)).cgPath)
    }
}
