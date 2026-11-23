import SwiftUI

/// The primer (design.md §7.2, copy.md §3.2): the first page while photos haven't been allowed yet.
/// Icon artwork (§10.2), 3.2.1 as the centred bold title, 3.2.2 as the body, the primary button
/// 3.2.3「允許取用照片」(`ShellModel.allowAccess()`), the plain text button 3.2.4「先選一張圖」
/// (`ShellModel.showPicker()`), and under them the small text 3.2.6.
///
/// Only declared here; the page is still to be built.
struct PrimerScreen: View {
    @Environment(ShellModel.self) private var shell

    var body: some View {
        Theme.page.ignoresSafeArea()
    }
}
