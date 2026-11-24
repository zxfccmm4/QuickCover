import SwiftUI
import Testing

@testable import QuickCover

/// The size of the editor's two top glass capsules (`GlassLabelButton`, design.md §6, §9.5),
/// measured through `UIHostingController`, not read off the source. With only the symbol a capsule
/// is a fixed 44×44 circle, as `GlassIconButton` is, whatever the symbol's own width and the text
/// size; with the title it is 44 high and as wide as the title makes it.
@MainActor
struct GlassButtonLayoutTests {

    /// The symbols `EditorTopButtons` gives the left and the right button.
    private static let symbols = ["photo.on.rectangle", "list.bullet"]

    private func measured(_ symbol: String, titleHidden: Bool, at typeSize: DynamicTypeSize) -> CGSize {
        let button = GlassLabelButton(systemImage: symbol, title: "3.1.8", titleHidden: titleHidden) {}
            .environment(\.dynamicTypeSize, typeSize)
        return UIHostingController(rootView: button).sizeThatFits(in: CGSize(width: 1000, height: 1000))
    }

    private func is44Circle(_ size: CGSize) -> Bool {
        abs(size.width - 44) <= 0.5 && abs(size.height - 44) <= 0.5
    }

    @Test
    func withoutATitleItIsA44CircleAtEveryTextSize() {
        for symbol in Self.symbols {
            for typeSize in DynamicTypeSize.allCases {
                let size = measured(symbol, titleHidden: true, at: typeSize)
                #expect(is44Circle(size), "\(symbol), title hidden, \(typeSize): \(size)")
            }
        }
    }

    @Test
    func atAccessibilitySizesItIsA44Circle() {
        for symbol in Self.symbols {
            for typeSize in DynamicTypeSize.allCases where typeSize.isAccessibilitySize {
                let size = measured(symbol, titleHidden: false, at: typeSize)
                #expect(is44Circle(size), "\(symbol), \(typeSize): \(size)")
            }
        }
    }

    @Test
    func withTheTitleItIs44HighAndWiderThan44() {
        for symbol in Self.symbols {
            let size = measured(symbol, titleHidden: false, at: .large)
            #expect(abs(size.height - 44) <= 0.5, "\(symbol): \(size)")
            #expect(size.width > 44, "\(symbol): \(size)")
        }
    }
}
