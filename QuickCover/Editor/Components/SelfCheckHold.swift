#if SELF_CHECK
import SwiftUI

/// The way into the self-check page in the owner's build (see `SelfCheck/SelfCheckView.swift`): a
/// clear strip across the top 44 pt of the screen, which only the status bar covers. Holding it for
/// two seconds presents the page. Nothing else is up there, so nothing is taken away from a tap.
struct SelfCheckHold: View {
    let action: () -> Void

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .ignoresSafeArea(edges: .top)
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 2) { action() }
            .accessibilityHidden(true)
    }
}
#endif
