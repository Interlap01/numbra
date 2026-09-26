import SwiftUI

/// Numbra's root reads `numbra_onboarded` from UserDefaults to decide between the
/// onboarding flow and the studio. A preview machine has no defaults at all, so the
/// screen would always come up as a first launch. Seed it as a returning user so the
/// entry lands on the studio, the app's main screen.
@MainActor public func mobaiPreviewEnvironment<V: View>(_ root: @autoclosure () -> V) -> AnyView {
    UserDefaults.standard.set("1", forKey: "numbra_onboarded")
    UserDefaults.standard.set("1", forKey: "numbra_tut")
    return AnyView(root())
}
