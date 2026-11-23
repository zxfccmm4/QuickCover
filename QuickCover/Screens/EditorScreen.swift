import SwiftUI

/// The editor (design.md §7.3), the root of the app: black, no navigation bar, the picture the only
/// bright thing, covered with `MaskRenderer` in `EditorModel.preferences.style`. `EditorTopButtons`
/// and `EditorGlassBar` in one `GlassEffectContainer`; the states of §7.3.1–§7.3.7 read from the
/// model: `recognition`, `found`, `showsOriginal`, `locateRequest`, `drawToolOn`, `retryRecognition()`.
///
/// The covers are the boxes as recognition gave them, `MaskItem.quads`, with no inset of the
/// UI's own (design.md §1); all of them appear together, in no order (§8). An item of two boxes
/// is covered as the two of them by its one switch; the outline of「locate」draws every box of the
/// item and the picture moves to `MaskItem.bounds`, the boxes together (§7.4.3).
///
/// Only declared here; the page is still to be built.
struct EditorScreen: View {
    @Environment(EditorModel.self) private var model
    @Environment(ShellModel.self) private var shell

    var body: some View {
        Theme.page.ignoresSafeArea()
    }
}
