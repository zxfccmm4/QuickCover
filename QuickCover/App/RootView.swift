import SwiftUI

/// Root navigation shell following Apple Photos & HIG:
/// presents a native 3-tab Liquid Glass `TabView` (`Library`, `Stitch`, `About`) when photo access
/// is initialized, with `.tabBarMinimizeBehavior(.onScrollDown)` and full-screen pushed dark studio
/// editing & export screens.
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
        Group {
            switch shell.page {
            case .primer:
                NavigationStack(path: $shell.path) {
                    PrimerScreen()
                        .navigationDestination(for: Route.self) { destination(for: $0) }
                }
            case .picker:
                TabView(selection: $shell.selectedTab) {
                    Tab("tab.library", systemImage: "photo.on.rectangle.angled", value: AppTab.library) {
                        NavigationStack(path: pathBinding(for: .library)) {
                            PickerScreen()
                                .navigationDestination(for: Route.self) { destination(for: $0) }
                        }
                    }

                    Tab("tab.stitch", systemImage: "rectangle.split.1x2", value: AppTab.stitch) {
                        NavigationStack(path: pathBinding(for: .stitch)) {
                            LongScreenshotHubView(
                                onComplete: { shell.open($0) },
                                onCompleteForExport: { shell.openForExport($0) }
                            )
                            .navigationDestination(for: Route.self) { destination(for: $0) }
                        }
                    }

                    Tab("tab.about", systemImage: "info.circle", value: AppTab.about) {
                        NavigationStack(path: pathBinding(for: .about)) {
                            AboutScreen()
                        }
                    }
                }
                .tabBarMinimizeBehavior(.onScrollDown)
                .sensoryFeedback(.selection, trigger: shell.selectedTab)
            case .editor:
                NavigationStack(path: $shell.path) {
                    EditorScreen()
                        .id(shell.editor.map { ObjectIdentifier($0) })
                        .navigationTitle("4.1.1")
                        .navigationDestination(for: Route.self) { destination(for: $0) }
                }
            case nil:
                Theme.page.ignoresSafeArea()
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
        .onOpenURL { url in
            shell.handleOpenURL(url)
        }
        .sheet(
            item: $shell.whatsNewPresentation,
            onDismiss: { shell.dismissWhatsNew() }
        ) { presentation in
            WhatsNewSheet(presentation: presentation) {
                shell.dismissWhatsNew()
            }
        }
        #if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: .quickCoverShowWhatsNew)) { _ in
            shell.presentWhatsNewManually()
        }
        #endif
        .selfCheckEntrance(topSafeArea: topSafeArea, isPresented: $showSelfCheck)
    }

    private func pathBinding(for tab: AppTab) -> Binding<[Route]> {
        Binding(
            get: { shell.selectedTab == tab ? shell.path : [] },
            set: { newValue in
                if shell.selectedTab == tab {
                    shell.path = newValue
                }
            }
        )
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .picker:
            PickerScreen()
        case .editor:
            if let editor = shell.editor {
                EditorScreen()
                    .id(ObjectIdentifier(editor))
                    .navigationTitle("4.1.1")
                    .toolbar(.hidden, for: .tabBar)
            }
        case .export:
            ExportScreen()
                .toolbar(.hidden, for: .tabBar)
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
