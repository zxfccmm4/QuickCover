import SwiftUI

/// The picker (design.md §7.1, copy.md §3.1): the root without full photo access, and pushed over
/// the editor by「換一張」. A large navigation title 3.1.1, the explanatory line 3.1.2, one card of
/// four `PickerRow`s in a fixed order (選螢幕快照 3.1.9, 選照片 3.1.3, 選檔案 3.1.4, 貼上圖片 3.1.5),
/// the last one unusable with 3.1.6 under the card when the clipboard has no image. What is picked
/// goes to `ShellModel.open(_:)`. The system alert 3.1.7 / 3.1.8 when a file can't be opened.
///
/// Only declared here; the page is still to be built.
struct PickerScreen: View {
    @Environment(ShellModel.self) private var shell

    var body: some View {
        Theme.page.ignoresSafeArea()
    }
}
