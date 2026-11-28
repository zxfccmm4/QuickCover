import SwiftUI

/// Root navigation shell following Apple Photos & HIG: opens directly onto the adaptive Light/Dark
/// photo library grid, and transitions seamlessly into the focused pure-black photo studio when a
/// picture is selected for masking.
struct RootView: View {
    @State private var shell = ShellModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var showSelfCheck = false
    @State private var topSafeArea: CGFloat = 0

    private var showsDarkStudio: Bool {
        if let top = shell.path.last {
            return top == .editor
        }
        return shell.page == .editor
    }

    var body: some View {
        @Bindable var shell = shell
        NavigationStack(path: $shell.path) {
            root
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .picker:
                        PickerScreen()
                    case .editor:
                        if let editor = shell.editor {
                            EditorScreen()
                                .id(ObjectIdentifier(editor))
                                .navigationTitle("4.1.1")
                        }
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
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { topSafeArea = $0 }
        .task { await shell.start() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { shell.wentToBackground() }
        }
        .selfCheckEntrance(topSafeArea: topSafeArea, isPresented: $showSelfCheck)
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
    func selfCheckEntrance(topSafeArea: CGFloat, isPresented: Binding<Bool>) -> some View {
        self
            .overlay(alignment: .top) {
                SelfCheckHold(topSafeArea: topSafeArea) { isPresented.wrappedValue = true }
            }
            .sheet(isPresented: isPresented) { SelfCheckView() }
    }
    #else
    func selfCheckEntrance(topSafeArea: CGFloat, isPresented: Binding<Bool>) -> some View { self }
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
