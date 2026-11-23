import CoreGraphics
import Testing

@testable import QuickCover

/// Brief Part B and the addenda of 20:35 and 21:05: a value a line wrap cut in two or three
/// matches when the lines are read as one, and only what crosses the cut is new.
@Suite struct JunctionMatchTests {

    private func junction(_ lines: [String]) -> [JunctionMatch] {
        TextRuleMatcher.junctionMatches(lines: lines)
    }

    // MARK: What crosses the cut

    @Test func cardCutInsideItsGroups() {
        let out = junction(["卡号 6222 0210", "0110 8867 123"])
        #expect(out == [JunctionMatch(rule: .bankCard, text: "6222 0210 0110 8867 123", ranges: [3..<12, 0..<13])])
    }

    @Test func emailCutInsideTheDomain() {
        let out = junction(["zhang.wei@example.c", "om"])
        #expect(out == [JunctionMatch(rule: .email, text: "zhang.wei@example.com", ranges: [0..<19, 0..<2])])
    }

    @Test func urlOverThreeLines() {
        // Cut twice: the scheme alone on the first line, the whole of the second and third lines in the match.
        let out = junction(["https://", "example.com/path", "more"])
        #expect(out.count == 1)
        #expect(out.first?.rule == .url)
        #expect(out.first?.ranges == [0..<8, 0..<16, 0..<4] as [Range<Int>?])
        #expect(out.first?.text == "https://example.com/pathmore")
    }

    @Test func phoneOverThreeLines() {
        let out = junction(["电话 150", "9122", "3047"])
        #expect(out.count == 1)
        #expect(out.first?.rule == .phone)
        #expect(out.first?.ranges == [3..<6, 0..<4, 0..<4] as [Range<Int>?])
    }

    @Test func urlCutAfterTheScheme() {
        let out = junction(["https://", "example.com/path"])
        #expect(out.count == 1)
        #expect(out.first?.rule == .url)
        #expect(out.first?.ranges == [0..<8, 0..<16] as [Range<Int>?])
    }

    @Test func nothingCrossesTheCut() {
        // Two short numbers: 1380 and 0000 make nothing.
        #expect(junction(["合计 1380", "0000 元"]).isEmpty)
    }

    @Test func wholeValueInsideOneLineIsNotNew() {
        #expect(junction(["卡号 6222 0210 8867 123", "合计 100 元"]).isEmpty)
        #expect(junction(["电话 13800138000", "明天见"]).isEmpty)
        #expect(junction(["收货人 王芳", "身份证 110101199001011234"]).isEmpty)
    }

    @Test func emptyLinesGiveNothing() {
        #expect(junction(["", ""]).isEmpty)
        #expect(junction(["卡号 6222 0210", ""]).isEmpty)
        #expect(junction(["", "0110 8867 123"]).isEmpty)
        #expect(junction(["电话 150", "", "9122 3047"]).isEmpty)
    }

    @Test func oneLineOrFourAreNotAWrap() {
        #expect(junction(["卡号 6222 0210"]).isEmpty)
        #expect(junction(["https://", "exa", "mple.com", "/path"]).isEmpty)
    }

    // MARK: A wrap, and what only looks like one

    @Test func sentenceUnderAnAddressIsNotItsTail() {
        // The address is whole on the first line: the sentence under it is not its end.
        #expect(junction(["邮箱 zhang.wei@example.com", "Thanks."]).isEmpty)
        #expect(junction(["看这里 https://example.com/page", "Thanks a lot"]).isEmpty)
    }

    @Test func rowUnderANumberIsNotItsTail() {
        // A phone whole on its line, and the date under it: its digits are a row of their own.
        #expect(junction(["13800138000", "2026年1月5日 交费"]).isEmpty)
        // The last line of a number may end in a unit or in words.
        #expect(junction(["合计 13800138000", "1234 元"]).map(\.text) == ["138001380001234"])
        // A number cut in two is still found when its last line goes on with a character.
        #expect(junction(["身份证 110101199001011", "234号"]) == [JunctionMatch(rule: .idNumber, text: "110101199001011 234", ranges: [4..<19, 0..<3])])
    }

    @Test func wordBeforeACodeIsNotPartOfIt() {
        // "ok" and "number" end a line in lower case; the start of a code, SE and SF, is in capitals.
        #expect(junction(["2026-11-23 09:00:02 login ok", "13800138000"]).isEmpty)
        #expect(junction(["number", "1Z999AA10123456784"]).isEmpty)
        #expect(junction(["SE", "13988670012", "34"]).map(\.text) == ["SE1398867001234"])
        #expect(junction(["SF", "1398867001234"]).map(\.text) == ["SF1398867001234"])
    }

    @Test func labelOverAnAddressIsNotPartOfIt() {
        #expect(junction(["Email", "chenwei@example.com"]).isEmpty)
        #expect(junction(["INFO", "anna.1i@example.com"]).isEmpty)
        #expect(junction(["to", "daniel.park@example.com"]).isEmpty)
        #expect(junction(["link", "example.com/post/1"]).isEmpty)
        // An address cut inside itself is found: the piece under it starts with a mark, or the one
        // over it is not a word.
        #expect(junction(["联系 zhang", ".wei@example.com"]).map(\.text) == ["zhang.wei@example.com"])
        #expect(junction(["https://shop.example.c", "om/orders/88213045"]).map(\.text) == ["https://shop.example.com/orders/88213045"])
    }

    // MARK: One value, told once

    @Test func cleanAndPartedReadingsAreToldOnce() {
        // The card matches with and without a space at the cut: one match.
        #expect(junction(["卡号 6222 0210", "0110 8867 123"]).count == 1)
        #expect(junction(["电话 150", "9122 3047"]).count == 1)
    }

    @Test func containedCopyGoes() {
        // Read over three lines, the URL holds the match the last two lines give alone, on every
        // line that match reaches: the smaller one goes, whichever comes first.
        let whole = JunctionMatch(rule: .url, text: "https://example.com/pathmore", ranges: [0..<8, 0..<16, 0..<4])
        let lastTwo = JunctionMatch(rule: .url, text: "xample.com/pathmore", ranges: [nil, 1..<16, 0..<4])
        let firstTwo = JunctionMatch(rule: .url, text: "https://example.com/path", ranges: [0..<8, 0..<16, nil])
        #expect(JunctionMatch.distinct([firstTwo, whole]) == [whole])
        #expect(JunctionMatch.distinct([whole, lastTwo]) == [whole])
        #expect(JunctionMatch.distinct([lastTwo, firstTwo, whole]) == [whole])
        #expect(JunctionMatch.distinct([firstTwo, firstTwo, firstTwo]) == [firstTwo])
    }

    @Test func partialInterleaveKeepsBoth() {
        // Crossed on both lines, neither holding the other: both stay, in the order they came.
        let a = JunctionMatch(rule: .email, text: "zhang@example.com", ranges: [0..<7, 0..<11])
        let b = JunctionMatch(rule: .url, text: "example.com/path", ranges: [5..<9, 0..<17])
        #expect(JunctionMatch.distinct([a, b]) == [a, b])
        #expect(JunctionMatch.distinct([b, a]) == [b, a])
        // Holding on one line and only crossing on the other is not enough to drop one.
        let c = JunctionMatch(rule: .url, text: "https://example.com/path", ranges: [0..<9, 0..<9, nil])
        #expect(JunctionMatch.distinct([c, a]) == [c, a])
        #expect(JunctionMatch.distinct([a, c]) == [a, c])
    }

    // MARK: Where a wrap is

    private func line(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, height: CGFloat = 30) -> CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    @Test func chatBubbleIsAWrap() {
        // 「电话 150」 over 「9122」: the next line of the bubble, the left edge within a character, a pitch of 1.1 heights.
        #expect(WrapGeometry.wraps(from: line(100, 100, 90), characters: 6, to: line(112, 133, 44)))
        // The bubble need not reach the right edge of its column: the upper line may be the narrower one.
        #expect(WrapGeometry.wraps(from: line(100, 100, 44), characters: 4, to: line(100, 133, 200)))
    }

    @Test func tableRowIsNotAWrap() {
        // 2.2 line heights under: a table row or a new paragraph.
        #expect(!WrapGeometry.wraps(from: line(100, 100, 90), characters: 6, to: line(100, 166, 44)))
    }

    @Test func nextColumnIsNotAWrap() {
        // The same pitch, but the left edge two characters to the right.
        #expect(!WrapGeometry.wraps(from: line(100, 100, 300), characters: 6, to: line(250, 133, 200)))
    }

    @Test func linesAboveOrSidewaysAreNotAWrap() {
        #expect(!WrapGeometry.wraps(from: line(100, 133, 44), characters: 4, to: line(100, 100, 90)))
        #expect(!WrapGeometry.wraps(from: line(100, 100, 44), characters: 4, to: line(100, 100, 90)))
    }
}
