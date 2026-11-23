import SwiftUI

/// The export page (design.md §7.5, copy.md §6.1–§6.4): pushed by「匯出」, the system navigation bar
/// with 6.1.1 and「‹ 編輯」. The covered picture from `EditorModel.exportData()` as the page shows it
/// (`MaskRenderer`), 6.1.2, the switch 6.2.1 (`EditorModel.setStripMetadata`), the line 6.2.4, and
/// pinned to the bottom the primary button 6.1.3 and the secondary buttons 6.1.4 and 6.1.5 side by
/// side. The notices 6.3.x and 6.4.x, and the toast.
///
/// Only declared here; the page is still to be built.
struct ExportScreen: View {
    @Environment(EditorModel.self) private var model

    var body: some View {
        Theme.page.ignoresSafeArea()
    }
}
