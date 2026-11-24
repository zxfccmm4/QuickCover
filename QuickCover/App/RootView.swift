import SwiftUI

/// The whole app (design.md §5): one `NavigationStack` whose root is the primer, the picker or the
/// editor; the picker and the export page are pushed; Review Each Item is a sheet. Always dark
/// (§11.1), the accent colour is the one of §2.
struct RootView: View {
    @State private var shell = ShellModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSelfCheck = false

    var body: some View {
        @Bindable var shell = shell
        NavigationStack(path: $shell.path) {
            root
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .picker: PickerScreen()
                    case .export: ExportScreen()
                    }
                }
        }
        .environment(shell)
        .environment(shell.editor)
        .sheet(isPresented: reviewShown) { ReviewSheet().environment(shell).environment(shell.editor) }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
        .task { await shell.start() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { shell.wentToBackground() }
        }
        .selfCheckEntrance(isPresented: $showSelfCheck)
    }

    /// The root page (design.md §5). Each picture gets its own editor, with none of the state of
    /// the last one (§7.3.1).
    @ViewBuilder
    private var root: some View {
        switch shell.page {
        case .primer:
            PrimerScreen()
        case .picker:
            PickerScreen()
        case .editor:
            EditorScreen().id(shell.editor.map { ObjectIdentifier($0) })
        case nil:
            Theme.page
        }
    }

    /// The sheet of Review Each Item is the editor's to show (`EditorModel.reviewShown`).
    private var reviewShown: Binding<Bool> {
        Binding(
            get: { shell.editor?.reviewShown ?? false },
            set: { shown in if !shown { shell.hideReview() } }
        )
    }
}

private extension View {
    /// The way into the self-check page, only in the build made for the owner's phone
    /// (`SelfCheck/SelfCheckView.swift`): hold the top edge of the screen for two seconds.
    #if SELF_CHECK
    func selfCheckEntrance(isPresented: Binding<Bool>) -> some View {
        self
            .overlay(alignment: .top) { SelfCheckHold { isPresented.wrappedValue = true } }
            .sheet(isPresented: isPresented) { SelfCheckView() }
    }
    #else
    func selfCheckEntrance(isPresented: Binding<Bool>) -> some View { self }
    #endif
}

#Preview {
    RootView()
        .preferredColorScheme(.dark)
}
