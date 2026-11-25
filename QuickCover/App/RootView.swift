import SwiftUI

/// Root navigation shell following Apple HIG: respects system Light and Dark appearance across
/// onboarding, image picker, inspector sheet, and export screens, while letting the editor own a
/// focused dark photo-studio canvas.
struct RootView: View {
    @State private var shell = ShellModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var showSelfCheck = false

    private var showsDarkStudio: Bool {
        shell.page == .editor && shell.path.isEmpty
    }

    var body: some View {
        @Bindable var shell = shell
        NavigationStack(path: $shell.path) {
            root
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .picker:
                        PickerScreen()
                    case .export:
                        ExportScreen()
                    }
                }
        }
        .environment(shell)
        .environment(shell.editor)
        .environment(\.systemColorScheme, systemColorScheme)
        .preferredColorScheme(showsDarkStudio ? .dark : nil)
        .tint(Theme.accent)
        .task { await shell.start() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { shell.wentToBackground() }
        }
        .selfCheckEntrance(isPresented: $showSelfCheck)
    }

    @ViewBuilder
    private var root: some View {
        switch shell.page {
        case .primer:
            PrimerScreen()
        case .picker:
            PickerScreen()
        case .editor:
            EditorScreen()
                .id(shell.editor.map { ObjectIdentifier($0) })
                .navigationTitle("4.1.1")
        case nil:
            Theme.page.ignoresSafeArea()
        }
    }
}

private extension View {
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

#Preview("Light") {
    RootView()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    RootView()
        .preferredColorScheme(.dark)
}
