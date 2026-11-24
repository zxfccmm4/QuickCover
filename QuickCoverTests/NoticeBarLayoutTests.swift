import SwiftUI
import Testing
import UIKit

@testable import QuickCover

/// A stand-in for `SmallButton` (title 6.3.2) that lays out as it does, so a test can measure the
/// bar around it and know where the button lies. `theStandInLaysOutLikeTheSmallButton` keeps the
/// two the same size.
struct RedButton: View {
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Text("6.3.2")
            .font(.smallButtonText)
            .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
            .minimumScaleFactor(typeSize.isAccessibilitySize ? 1 : 0.85)
            .multilineTextAlignment(typeSize.isAccessibilitySize ? .center : .leading)
            .fixedSize(horizontal: false, vertical: typeSize.isAccessibilitySize)
            .padding(.horizontal, 14)
            .padding(.vertical, typeSize.isAccessibilitySize ? 8 : 0)
            .frame(minHeight: 36)
            .padding(.vertical, 4)
            .padding(.vertical, -4)
    }
}

private struct ButtonFrame: PreferenceKey {
    static let defaultValue: CGRect? = nil
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) { value = nextValue() ?? value }
}

/// Where the words of the notice lie, how many lines they take, and where the button stands: all
/// of it measured by laying the real views out, nothing read from the source and nothing from pixels.
@MainActor
enum NoticeBarDrawing {

    /// The notice the export page shows about the style: `text` (6.3.1 or 6.3.3) with the button.
    struct Drawn {
        /// The bar.
        var size: CGSize
        /// The ground of the button, in the bar.
        var button: CGRect?
        /// Whether the words share a line with the button: the button then fills the row, 8 under the top.
        var beside: Bool { button.map { abs($0.minY - 8) < 0.01 && $0.minX > 45 + 1 } ?? false }
    }

    static func notice(_ text: LocalizedStringKey, language: String, typeSize: DynamicTypeSize, barWidth: CGFloat,
                       stacks: Bool = true) -> Drawn {
        let button = Box()
        let bar = NoticeBar(systemImage: "exclamationmark.triangle", tint: .black, ground: .black, text: text,
                            stacksWhenTooWide: stacks) {
            RedButton().background(GeometryReader { g in
                Color.clear.preference(key: ButtonFrame.self, value: g.frame(in: .named("bar")))
            })
        }
        .coordinateSpace(name: "bar")
        .onPreferenceChange(ButtonFrame.self) { button.frame = $0 }
        .environment(\.locale, Locale(identifier: language))
        .environment(\.dynamicTypeSize, typeSize)
        return Drawn(size: size(bar, width: barWidth, button: button), button: button.frame)
    }

    /// The width of the words' line in the bar: after the 12, the symbol and the 8, before the 8.
    static func wordsWidth(symbol: CGFloat, barWidth: CGFloat) -> CGFloat { barWidth - 12 - symbol - 8 - 8 }

    /// The symbol at `typeSize`.
    static func symbol(_ typeSize: DynamicTypeSize) -> CGSize {
        ideal(Image(systemName: "exclamationmark.triangle").font(.noticeIcon), language: "en", typeSize: typeSize)
    }

    /// `text` in the notice's font on `width`, with at most `limit` lines (nil: every line it takes).
    static func words(_ text: LocalizedStringKey, language: String, typeSize: DynamicTypeSize, width: CGFloat?,
                      limit: Int? = nil) -> CGSize {
        size(wordsView(text, language: language, typeSize: typeSize, width: width, limit: limit), width: width ?? 10_000)
    }

    /// How many lines `text` takes on `width`.
    static func lines(_ text: LocalizedStringKey, language: String, typeSize: DynamicTypeSize, width: CGFloat) -> Int {
        let every = words(text, language: language, typeSize: typeSize, width: width).height
        for limit in 1...20 where abs(words(text, language: language, typeSize: typeSize, width: width, limit: limit).height - every) < 0.01 {
            return limit
        }
        return 21
    }

    /// Whether the words fit whole beside the button: the insets, the symbol, the three 8 and both.
    static func fitsBeside(_ text: LocalizedStringKey, language: String, typeSize: DynamicTypeSize, barWidth: CGFloat) -> Bool {
        let one = words(text, language: language, typeSize: typeSize, width: nil, limit: 1).width
        // 12, the symbol, 8, the words, 8, the spacer's least (0), 8, the button, 8.
        let total = 12 + symbol(typeSize).width + 8 + one + 8 + 8 + ideal(RedButton(), language: language, typeSize: typeSize).width + 8
        return total <= barWidth + 0.01
    }

    static func ideal<V: View>(_ view: V, language: String, typeSize: DynamicTypeSize = .large) -> CGSize {
        size(view.fixedSize(), width: 10_000, language: language, typeSize: typeSize)
    }

    static func size<V: View>(_ view: V, width: CGFloat, language: String = "en", typeSize: DynamicTypeSize = .large) -> CGSize {
        UIHostingController(rootView: view.environment(\.locale, Locale(identifier: language))
            .environment(\.dynamicTypeSize, typeSize)).sizeThatFits(in: CGSize(width: width, height: 3000))
    }

    private final class Box {
        var frame: CGRect?
    }

    private static func wordsView(_ text: LocalizedStringKey, language: String, typeSize: DynamicTypeSize, width: CGFloat?,
                                  limit: Int?) -> some View {
        Text(text)
            .font(.footnote)
            .lineLimit(limit)
            .frame(width: width, alignment: .leading)
            .environment(\.locale, Locale(identifier: language))
            .environment(\.dynamicTypeSize, typeSize)
    }

    /// Laid out in a window, so the button's frame is reported: the preference is read during the
    /// layout. The window is 200 taller than the bar, so the bar is offered more height than it
    /// needs, as on the page (in a window of its own height the safe area presses on it and the
    /// words are cut to one line), and its origin falls on a whole point, so nothing rounds.
    private static func size<V: View>(_ view: V, width: CGFloat, button: Box) -> CGSize {
        let host = UIHostingController(rootView: view)
        let fitted = host.sizeThatFits(in: CGSize(width: width, height: 3000))
        let w = Int(max(fitted.width, width).rounded(.up))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: CGFloat(w), height: fitted.height + 200))
        window.rootViewController = host
        window.isHidden = false
        host.view.frame = window.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        window.isHidden = true
        window.rootViewController = nil
        return fitted
    }
}

/// 导出页那条提醒的排法（规格 1.6，`NoticeBar.stacksWhenTooWide`）：量的是排出来的大小和位置，不是读源码。
/// 一屏宽 393 或 375、两边各留 16，是 `ExportScreen` 给它的地方。数是 iOS 上量的，不是样机上的：
/// 默认字号 `.footnote` 一行 15.67 高，图标 25 宽 22.67 高，按钮 36 高。
@MainActor
struct NoticeBarLayoutTests {

    private let languages = ["zh-Hans", "zh-Hant", "en"]
    private let sizes: [(String, DynamicTypeSize)] = [("large", .large), ("xLarge", .xLarge), ("xxLarge", .xxLarge), ("xxxLarge", .xxxLarge),
                                                       ("AX1", .accessibility1), ("AX3", .accessibility3), ("AX5", .accessibility5)]

    @Test(arguments: ["zh-Hans", "zh-Hant", "en"])
    func theStandInLaysOutLikeTheSmallButton(language: String) {
        for (_, typeSize) in sizes {
            #expect(NoticeBarDrawing.ideal(RedButton(), language: language, typeSize: typeSize)
                    == NoticeBarDrawing.ideal(SmallButton(title: "6.3.2") {}, language: language, typeSize: typeSize), "\(language) \(typeSize)")
        }
    }

    /// 条永远和页面给它的一样宽，哪种排法都是。
    @Test(arguments: ["zh-Hans", "zh-Hant", "en"])
    func theBarIsAsWideAsThePageGivesIt(language: String) {
        for key in ["6.3.1", "6.3.3"] {
            for screen in [393, 375] {
                for (_, typeSize) in sizes {
                    let d = NoticeBarDrawing.notice(LocalizedStringKey(key), language: language, typeSize: typeSize, barWidth: CGFloat(screen - 32))
                    #expect(d.size.width == CGFloat(screen - 32), "\(key) \(screen) \(typeSize)")
                    #expect(d.button != nil, "\(key) \(screen) \(typeSize): the button is placed")
                }
            }
        }
    }

    /// 并排的时候：按钮撑满这一行（上 8 下 8），右缘离条右边 8，字一行。
    private func expectBeside(_ d: NoticeBarDrawing.Drawn, _ what: String) {
        #expect(d.beside, "\(what): beside, the button is at \(d.button.map { "\($0)" } ?? "nil")")
        #expect(abs(d.button!.height - 36) < 0.01 && abs(d.button!.minY - 8) < 0.01, "\(what): the button fills the row")
        #expect(abs(d.button!.maxX - (d.size.width - 8)) < 0.01, "\(what): the button ends 8 from the right edge")
        #expect(abs(d.size.height - 52) < 0.01, "\(what): \(d.size.height) high")
    }

    /// 上下排的时候：按钮的底离条底 8，左缘落在字上（12 ＋ 图标 ＋ 8；大字号那支是条的最左 12），字下面空 `gap`。
    private func expectUnder(_ d: NoticeBarDrawing.Drawn, _ text: LocalizedStringKey, _ language: String, _ typeSize: DynamicTypeSize,
                             _ what: String, gap: CGFloat) {
        #expect(!d.beside, "\(what): stacked")
        let symbol = NoticeBarDrawing.symbol(typeSize)
        let wordsWidth = NoticeBarDrawing.wordsWidth(symbol: symbol.width, barWidth: d.size.width)
        let lines = NoticeBarDrawing.lines(text, language: language, typeSize: typeSize, width: wordsWidth)
        let wordsHeight = max(symbol.height, NoticeBarDrawing.words(text, language: language, typeSize: typeSize, width: wordsWidth).height)
        #expect(abs(d.button!.maxY - (d.size.height - 8)) < 0.5, "\(what): the button ends 8 over the bottom edge")
        // Within a third of a point: the symbol measured alone (`ideal`) comes out a third wider than in the bar.
        let left = typeSize.isAccessibilitySize ? 12 : 12 + symbol.width + 8
        #expect(abs(d.button!.minX - left) < 0.5, "\(what): the button's left edge \(d.button!.minX), expected \(left)")
        // The bar is exactly as tall as the words (every line of them), the gap, the button and the 8 above and below.
        #expect(abs(d.size.height - (8 + wordsHeight + gap + d.button!.height + 8)) < 0.01,
                "\(what): \(d.size.height) high, its parts come to \(8 + wordsHeight + gap + d.button!.height + 8) over \(lines) lines")
    }

    /// 6.3.1：字和按钮一行放得下的语言并排（简体、繁体），条 52 高、和屏一样宽。
    @Test(arguments: ["zh-Hans", "zh-Hant", "en"])
    func theBlurNoticeBesideOrUnderByWhatFits(language: String) {
        for screen in [393, 375] {
            let width = CGFloat(screen - 32)
            let d = NoticeBarDrawing.notice("6.3.1", language: language, typeSize: .large, barWidth: width)
            let what = "6.3.1 \(language) \(screen)"
            let fits = NoticeBarDrawing.fitsBeside("6.3.1", language: language, typeSize: .large, barWidth: width)
            if fits {
                expectBeside(d, what)
            } else {
                // English: the words on one line over the full width, the button 6 under them.
                expectUnder(d, "6.3.1", language, .large, what, gap: 6)
                #expect(NoticeBarDrawing.lines("6.3.1", language: language, typeSize: .large,
                                              width: NoticeBarDrawing.wordsWidth(symbol: NoticeBarDrawing.symbol(.large).width, barWidth: width)) == 1, "\(what): one line")
                #expect(abs(d.size.height - 80.67) < 0.01, "\(what): \(d.size.height) high")
            }
        }
    }

    /// 简体、繁体放得下，英文放不下：量出来的，不是定的。
    @Test
    func whichLanguagesFitBeside() {
        #expect(NoticeBarDrawing.fitsBeside("6.3.1", language: "zh-Hans", typeSize: .large, barWidth: 361))
        #expect(NoticeBarDrawing.fitsBeside("6.3.1", language: "zh-Hant", typeSize: .large, barWidth: 361))
        #expect(!NoticeBarDrawing.fitsBeside("6.3.1", language: "en", typeSize: .large, barWidth: 361))
        for language in languages {
            #expect(!NoticeBarDrawing.fitsBeside("6.3.3", language: language, typeSize: .large, barWidth: 361), "\(language)")
        }
    }

    /// 6.3.3 三种语言都是两行：上下排，条高 91.67（两行 33.67 ＋ 6 ＋ 按钮 36 ＋ 上下 16），按钮在字下面 6、左缘对齐。
    @Test(arguments: ["zh-Hans", "zh-Hant", "en"])
    func theMosaicNoticeStacksTwoLinesOverTheButton(language: String) {
        for screen in [393, 375] {
            let width = CGFloat(screen - 32)
            let d = NoticeBarDrawing.notice("6.3.3", language: language, typeSize: .large, barWidth: width)
            expectUnder(d, "6.3.3", language, .large, "6.3.3 \(language) \(screen)", gap: 6)
            #expect(abs(d.size.height - 91.67) < 0.01, "6.3.3 \(language) \(screen): \(d.size.height) high")
            #expect(NoticeBarDrawing.lines("6.3.3", language: language, typeSize: .large,
                                          width: NoticeBarDrawing.wordsWidth(symbol: NoticeBarDrawing.symbol(.large).width, barWidth: width)) == 2,
                    "6.3.3 \(language) \(screen): two lines")
        }
    }

    /// 默认字号往上：字号越大条越高；放得下就并排，放不下上下排，条正好装下字的所有行、间距和按钮（没截字）。
    @Test(arguments: ["zh-Hans", "zh-Hant", "en"])
    func atLargerSizesTheBarHoldsEveryLine(language: String) {
        for key in ["6.3.1", "6.3.3"] {
            var last: CGFloat = 0
            for (name, typeSize) in sizes {
                let d = NoticeBarDrawing.notice(LocalizedStringKey(key), language: language, typeSize: typeSize, barWidth: 361)
                let what = "\(key) \(language) \(name)"
                #expect(d.size.height >= last, "\(what): not lower than the size before")
                last = d.size.height
                let fits = NoticeBarDrawing.fitsBeside(LocalizedStringKey(key), language: language, typeSize: typeSize, barWidth: 361)
                if d.beside {
                    #expect(fits, "\(what): beside only when the words fit")
                    #expect(abs(d.size.height - 52) < 0.01, "\(what): \(d.size.height) high")
                } else {
                    // From AX1 on the button stands 12 under the text (design.md §9.5), otherwise 6.
                    expectUnder(d, LocalizedStringKey(key), language, typeSize, what, gap: typeSize.isAccessibilitySize ? 12 : 6)
                    if !typeSize.isAccessibilitySize {
                        #expect(!fits, "\(what): stacked only when the words do not fit beside the button")
                    }
                }
            }
        }
    }
}
