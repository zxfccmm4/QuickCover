import SwiftUI
import Testing
import UIKit

@testable import QuickCover

/// Regression tests verifying that `SelfCheckHold` stays strictly inside the top status-bar /
/// Dynamic Island safe area and never blocks the top-left or top-right navigation bar buttons on
/// iPhone Air (`safeAreaInsets.top == 68`) or any other iPhone.
@MainActor
struct TopBarHitTestTests {

    private func samplePicture() throws -> PictureSource {
        try PictureSource(data: Sample.jpeg(Sample.text("13812345678", at: CGPoint(x: 40, y: 120))))
    }

    @Test
    func selfCheckStripStaysStrictlyAboveNavigationBar() {
        // iPhone Air (68 pt), iPhone 16/17 Pro (62 pt), iPhone 15 (59 pt), iPhone SE (20 pt), landscape (0 pt)
        for topInset in [CGFloat(68), 62, 59, 54, 47, 20, 0] {
            let height = SelfCheckHold.stripHeight(forTopSafeArea: topInset)
            #expect(height >= 0)
            if topInset > SelfCheckHold.clearanceAboveNavigationBar {
                #expect(height <= topInset - SelfCheckHold.clearanceAboveNavigationBar)
                #expect(height <= SelfCheckHold.maxStripHeight)
            } else {
                #expect(height == 0)
            }
        }
    }

    @Test
    func topLeftAndTopRightButtonsRemainHittableWithSelfCheckOverlay() async throws {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = try #require(scene.windows.first)

        let pic = try samplePicture()
        let shell = ShellModel(
            authorization: { .authorized },
            requestAccess: { .full },
            latestScreenshot: { pic }
        )
        shell.open(pic)
        for _ in 0..<40 {
            if shell.editor?.recognition != .running { break }
            try await Task.sleep(for: .milliseconds(50))
        }

        let topSafeArea = window.safeAreaInsets.top

        let editorRoot = NavigationStack(path: Binding(get: { shell.path }, set: { shell.path = $0 })) {
            EditorScreen()
                .id(shell.editor.map { ObjectIdentifier($0) })
                .navigationTitle("4.1.1")
        }
        .environment(shell)
        .environment(shell.editor)
        .environment(\.systemColorScheme, .light)
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
        .overlay(alignment: .top) {
            SelfCheckHold(topSafeArea: topSafeArea) {}
        }

        let host = UIHostingController(rootView: editorRoot)
        window.rootViewController = host
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(500))
        window.layoutIfNeeded()

        let navBar = try #require(findView(ofType: UINavigationBar.self, in: window))
        let buttons = findToolbarButtons(in: navBar)
        #expect(buttons.count >= 3, "Expected top-left + top-right toolbar buttons, found \(buttons.count)")

        for button in buttons {
            let rect = button.convert(button.bounds, to: window)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let hit = window.hitTest(center, with: nil)
            let isInsideNavBar = hit.map { $0.isDescendant(of: navBar) } ?? false
            #expect(isInsideNavBar, "Button at \(rect) was obstructed by \(String(describing: hit))")
        }
    }

    @Test
    func pickerBottomFilterDockShieldsUnderlyingPhotoGridFromStrayTaps() async throws {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = try #require(scene.windows.first)

        let bottomInset = window.safeAreaInsets.bottom

        // Render a photo grid behind PickerScreen's exact bottom dock + home-indicator shield pattern
        // and verify UIKit hit-testing across both the dock band and bottom safe area never falls
        // through to the underlying UIScrollView.
        let harness = NavigationStack {
            ZStack {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                        ForEach(0..<45, id: \.self) { idx in
                            Button {} label: {
                                Color.teal.opacity(0.35)
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay(Text(verbatim: "\(idx)"))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 24)
                }
                .scrollEdgeEffectStyle(.soft, for: .all)
            }
            .overlay(alignment: .bottom) {
                if bottomInset > 0 {
                    BottomSafeAreaTouchShield()
                        .frame(maxWidth: .infinity)
                        .frame(height: bottomInset)
                        .ignoresSafeArea(.container, edges: .bottom)
                }
            }
            .safeAreaBar(edge: .bottom, spacing: 0) {
                PickerBottomDockShieldProbe()
            }
        }

        let host = UIHostingController(rootView: harness)
        window.rootViewController = host
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(500))
        window.layoutIfNeeded()

        let scrollView = try #require(findView(ofType: UIScrollView.self, in: window))
        let scrollRect = scrollView.convert(scrollView.bounds, to: window)
        let w = window.bounds.width
        let h = window.bounds.height

        // Confirm the scroll view really extends behind the bottom dock area (full-bleed Apple Photos style).
        #expect(scrollRect.maxY >= h - bottomInset - 10, "Expected full-bleed scrollView, got \(scrollRect)")

        // Points right across the bottom dock band (pill center, left/right segment edges,
        // gap between buttons, side margins, and low rim below pill) must NOT hit the underlying UIScrollView.
        let dockY = h - bottomInset - 30
        let shieldedPoints = [
            CGPoint(x: w * 0.50, y: dockY),          // center gap between All Photos / Screenshots
            CGPoint(x: w * 0.38, y: dockY),          // left button padding
            CGPoint(x: w * 0.62, y: dockY),          // right button padding
            CGPoint(x: w * 0.50, y: dockY - 18),     // upper rim of dock
            CGPoint(x: w * 0.14, y: dockY),          // left margin beside pill
            CGPoint(x: w * 0.86, y: dockY),          // right margin beside pill
            CGPoint(x: w * 0.50, y: h - bottomInset + 6), // below pill inside bottom safe area
        ]
        for pt in shieldedPoints {
            let hit = window.hitTest(pt, with: nil)
            #expect(hit != nil, "Expected dock shield to capture hit at \(pt)")
            let hitsScrollView = hit.map { $0.isDescendant(of: scrollView) } ?? false
            #expect(!hitsScrollView, "Dock point \(pt) bled through into underlying photo ScrollView (\(String(describing: hit)))")
        }

        // Meanwhile, photo tiles clearly above the bottom dock must still hit the UIScrollView cleanly.
        let gridPoint = CGPoint(x: w * 0.5, y: h * 0.45)
        let gridHit = window.hitTest(gridPoint, with: nil)
        let hitsGrid = gridHit.map { $0.isDescendant(of: scrollView) } ?? false
        #expect(hitsGrid, "Photo grid above dock should remain directly tappable")
    }

    private func findView<T: UIView>(ofType type: T.Type, in root: UIView) -> T? {
        if let match = root as? T { return match }
        for sub in root.subviews {
            if let found = findView(ofType: type, in: sub) { return found }
        }
        return nil
    }

    private func findToolbarButtons(in root: UIView) -> [UIView] {
        var result: [UIView] = []
        let cls = String(describing: type(of: root))
        if cls == "_UIButtonBarButton", root.bounds.width >= 20, root.bounds.height >= 20 {
            result.append(root)
            return result
        }
        for sub in root.subviews {
            result.append(contentsOf: findToolbarButtons(in: sub))
        }
        return result
    }
}

private struct PickerBottomDockShieldProbe: View {
    @State private var filter: PhotoLibraryFilter = .all

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(.rect)
                .onTapGesture {}
                .ignoresSafeArea(.container, edges: .bottom)

            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 3) {
                    ForEach(PhotoLibraryFilter.allCases) { option in
                        let isSelected = filter == option
                        Button {
                            filter = option
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: option.systemImage)
                                Text(LocalizedStringKey(option.titleKey))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .frame(minHeight: 38)
                            .background {
                                if isSelected {
                                    Capsule().fill(Theme.accentButton)
                                } else {
                                    Capsule().fill(Color.clear)
                                }
                            }
                            .contentShape(.capsule)
                        }
                        .buttonStyle(.plain)
                        .contentShape(.capsule)
                    }
                }
                .padding(4)
                .background {
                    Color.clear
                        .contentShape(.capsule)
                        .onTapGesture {}
                }
                .glassEffect(.regular.interactive(), in: .capsule)
                .contentShape(.capsule)
            }
            .padding(.horizontal, Metrics.pageInset)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
    }
}
