import SwiftUI
import Testing
import UIKit

@testable import QuickCover

/// Layout verification for the refactored concentric Liquid Glass `NoticeBar` and `SmallButton`
/// across all three languages and Dynamic Type sizes (Large through AX5).
@MainActor
struct NoticeBarLayoutTests {

    private let languages = ["zh-Hans", "zh-Hant", "en"]
    private let sizes: [(String, DynamicTypeSize)] = [
        ("large", .large), ("xLarge", .xLarge), ("xxLarge", .xxLarge), ("xxxLarge", .xxxLarge),
        ("AX1", .accessibility1), ("AX3", .accessibility3), ("AX5", .accessibility5),
    ]

    private func measured(
        _ key: LocalizedStringKey,
        language: String,
        typeSize: DynamicTypeSize,
        width: CGFloat,
        stacks: Bool = true
    ) -> CGSize {
        let bar = NoticeBar(
            systemImage: "exclamationmark.triangle.fill",
            tint: Theme.blurNoticeIcon,
            ground: Theme.blurNotice,
            text: key,
            stacksWhenTooWide: stacks
        ) {
            SmallButton(title: "6.3.2") {}
        }
        .environment(\.locale, Locale(identifier: language))
        .environment(\.dynamicTypeSize, typeSize)
        return UIHostingController(rootView: bar)
            .sizeThatFits(in: CGSize(width: width, height: 3000))
    }

    @Test(arguments: ["zh-Hans", "zh-Hant", "en"])
    func noticeBarRespectsOfferedWidthAcrossLanguagesAndTypeSizes(language: String) {
        for key in ["6.3.1", "6.3.3"] {
            for screen in [393, 375] {
                let offered = CGFloat(screen - 32)
                for (name, typeSize) in sizes {
                    let size = measured(LocalizedStringKey(key), language: language, typeSize: typeSize, width: offered)
                    #expect(size.width <= offered + 0.5, "\(key) \(language) \(screen) \(name): width \(size.width)")
                    #expect(size.height >= 44, "\(key) \(language) \(screen) \(name): height \(size.height)")
                }
            }
        }
    }

    @Test(arguments: ["zh-Hans", "zh-Hant", "en"])
    func mosaicWarningGrowsToHoldLongerCopyThanBlurWarning(language: String) {
        let width: CGFloat = 361
        let blur = measured("6.3.1", language: language, typeSize: .large, width: width)
        let mosaic = measured("6.3.3", language: language, typeSize: .large, width: width)
        #expect(mosaic.height > blur.height, "\(language): mosaic (\(mosaic.height)) taller than blur (\(blur.height))")
    }

    @Test(arguments: ["zh-Hans", "zh-Hant", "en"])
    func heightGrowsMonotonicallyWithDynamicType(language: String) {
        for key in ["6.3.1", "6.3.3"] {
            var previous: CGFloat = 0
            for (name, typeSize) in sizes {
                let size = measured(LocalizedStringKey(key), language: language, typeSize: typeSize, width: 361)
                #expect(size.height + 0.5 >= previous, "\(key) \(language) \(name): \(size.height) < \(previous)")
                previous = size.height
            }
        }
    }
}
