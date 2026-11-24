import SwiftUI

/// The card at the bottom of the editor (design.md §7.3.4, §7.3.5, §6「提示卡」): Nothing Found
/// with the primary button 5.1.3, or Hasn't Been Checked with 5.2.3 and the plain text button
/// 5.2.4. The card reads its title and message as one text (§9.2); the buttons are the buttons.
struct EditorCallout: View {
    enum Kind: Equatable {
        case nothing
        case failed
    }

    let kind: Kind
    ///「手動框選」: the card goes, the picture comes back and the drawing tool goes on (§7.3.4).
    let draw: () -> Void
    ///「再試一次」: a fresh look (§7.3.5).
    let retry: () -> Void

    var body: some View {
        switch kind {
        case .nothing:
            CalloutCard(systemImage: "viewfinder", title: "5.1.1", message: "5.1.2", readsTogether: true) {
                PrimaryButton(title: "5.1.3", action: draw)
            }
        case .failed:
            CalloutCard(systemImage: "exclamationmark.triangle", tint: Theme.errorIcon, title: "5.2.1", message: "5.2.2",
                        readsTogether: true) {
                VStack(spacing: 0) {
                    PrimaryButton(title: "5.2.3", action: retry)
                    PlainTextButton(title: "5.2.4", action: draw)
                }
            }
        }
    }
}
