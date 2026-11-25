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
