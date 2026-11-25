import SwiftUI

/// Studio callout for empty ("Nothing Found") or failed ("Hasn't Been Checked") recognition states.
struct EditorCallout: View {
    enum Kind: Equatable {
        case nothing
        case failed
    }

    let kind: Kind
    let draw: () -> Void
    let retry: () -> Void

    var body: some View {
        switch kind {
        case .nothing:
            CalloutCard(
                systemImage: "viewfinder",
                tint: Theme.accentOnBlack,
                title: "5.1.1",
                message: "5.1.2",
                readsTogether: true
            ) {
                PrimaryButton(title: "5.1.3", systemImage: "rectangle.dashed", action: draw)
            }
        case .failed:
            CalloutCard(
                systemImage: "exclamationmark.triangle",
                tint: Theme.errorIcon,
                title: "5.2.1",
                message: "5.2.2",
                readsTogether: true
            ) {
                VStack(spacing: 6) {
                    PrimaryButton(title: "5.2.3", systemImage: "arrow.clockwise", action: retry)
                    PlainTextButton(title: "5.2.4", action: draw)
                }
            }
        }
    }
}
