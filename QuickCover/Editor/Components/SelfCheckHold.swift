import SwiftUI

/// Owner self-check trigger strip: a narrow centered target strictly inside the top status-bar /
/// Dynamic Island safe area (`y = 0 ..< stripHeight`). It never extends into the navigation bar
/// below `safeAreaInsets.top` and stays well clear of the top-left and top-right toolbar buttons
/// on every iPhone (including iPhone Air's 68 pt top safe area).
struct SelfCheckHold: View {
    let topSafeArea: CGFloat
    let action: () -> Void

    nonisolated static let stripWidth: CGFloat = 156
    nonisolated static let maxStripHeight: CGFloat = 44
    nonisolated static let clearanceAboveNavigationBar: CGFloat = 10

    /// Exact vertical height allocated inside the status-bar safe area. Returns `0` in landscape or
    /// when there isn't enough safe-area clearance above the navigation bar.
    nonisolated static func stripHeight(forTopSafeArea topSafeArea: CGFloat) -> CGFloat {
        max(0, min(maxStripHeight, topSafeArea - clearanceAboveNavigationBar))
    }

    var body: some View {
        let height = Self.stripHeight(forTopSafeArea: topSafeArea)
        if height > 0 {
            Color.clear
                .frame(width: Self.stripWidth, height: height)
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 2) { action() }
                // Pull the hit target into y = 0..<height strictly inside the top safe area so it
                // never overlaps the navigation bar starting at y = topSafeArea.
                .offset(y: -topSafeArea)
                .accessibilityHidden(true)
        }
    }
}
