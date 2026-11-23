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

    // MARK: Round four: what the lines carry whole

    @Test func digitsUnderAPieceAreTheRestOfIt() {
        // The piece is no whole number by its shape, so whatever else stands on the last line, the
        // digits under it are its rest: an order number over a line that goes on with a phone.
        #expect(junction(["订单号5820193", "74462，周三送到，收货电话137 6240 8853。"])
            == [JunctionMatch(rule: .reference, text: "582019374462", ranges: [3..<10, 0..<5])])
        // A card in groups over a line that ends in a date. The word Vision glued to the last
        // group is a run character, so the reading carries it, as on the line itself.
        #expect(junction(["card 6228 4800", "5510 3927on 2026-11-23."])
            == [JunctionMatch(rule: .bankCard, text: "6228 4800 5510 3927on", ranges: [5..<14, 0..<11])])
        // Under a number that was whole already, the digits are a row of their own.
        #expect(junction(["卡号 6226 0211 0033 8867", "123 元"])
            == [JunctionMatch(rule: .bankCard, text: "6226 0211 0033 8867 123", ranges: [3..<22, 0..<3])])
        #expect(junction(["卡号 6226 0211 0033 8867", "123 2026-11-23"]).isEmpty)
    }

    @Test func wholeCodeOverAWordIsNotCut() {
        // The code is whole on its line, and the line under it starts a sentence in capitals.
        #expect(junction(["TRACKING： 1ZFICT8A0304821762", "DELIVERY LINK（tracking page）： https://"]).isEmpty)
        // A whole phone over a word is not lengthened either.
        #expect(junction(["电话 13800138000", "Mobile shows it"]).isEmpty)
        // The first ten characters of a code cut in two are whole for ref, not for a wrap.
        #expect(junction(["： 44030119870", "3124916"])
            == [JunctionMatch(rule: .idNumber, text: "44030119870 3124916", ranges: [2..<13, 0..<7])])
    }

    @Test func aDateUnderAWholeCodeIsNotItsRest() {
        // A code whole for ref on its line, over a line that starts with a date (web_01_log): the date
        // is the head of a number of its own, not the rest of the code.
        #expect(junction(["id=8f14e45fceea167a5a36dedd4bea2543", "2026-11-23 09:41:22.410 INFO notify mail to ops@example.com"]).isEmpty)
        // What stops it is the date, not the code being whole for ref: the rest of a code cut again
        // two characters before its end is no date, and the digits under it do not stop the wrap.
        #expect(junction(["id=8f14e45fceea167a5a36dedd4bea25", "43 2026-11-23"])
            == [JunctionMatch(rule: .reference, text: "id=8f14e45fceea167a5a36dedd4bea2543", ranges: [0..<33, 0..<2])])
    }

    @Test func schemeCutAtItsSlashesIsMended() {
        // Vision drops one slash at the cut; the line under it starts with the host.
        #expect(junction(["链接 https:/", "fict.ly/8Kd2Qz 提取码 482916"])
            == [JunctionMatch(rule: .url, text: "https://fict.ly/8Kd2Qz", ranges: [3..<10, 0..<14])])
        #expect(junction(["链接 https:", "fict.ly/8Kd2Qz"]).map(\.text) == ["https://fict.ly/8Kd2Qz"])
        // Where the line under it starts with a slash the scheme is whole already.
        #expect(junction(["链接 https:/", "/fict.ly/8Kd2Qz"]).map(\.text) == ["https://fict.ly/8Kd2Qz"])
        #expect(junction(["链接 http:/", "example.com/path"]).map(\.text) == ["http://example.com/path"])
    }

    @Test func aLetterBeforeTheDomainEndIsNotAnAddress() {
        // The local part is a dotted name cut at its full stop, a letter left before the at sign.
        #expect(junction(["Forwarding was set to ou.yang. f@fict-mail.c", "n by an admin"])
            == [JunctionMatch(rule: .email, text: "ou.yang.f@fict-mail.cn", ranges: [22..<43, 0..<1])])
        // The same on one line: the space before the letter is not the address's. The ranges are in
        // the line as read, the space left out; `reading(of:)` tells where it stood.
        #expect(TextRuleMatcher.matches(in: "set to ou.yang. f@fict-mail.cn").map(\.text) == ["ou.yang.f@fict-mail.cn"])
        #expect(TextRuleMatcher.matches(in: "set to ou.yang. f@fict-mail.cn").first?.start == 7)
        #expect(TextRuleMatcher.reading(of: "set to ou.yang. f@fict-mail.cn") == ("set to ou.yang.f@fict-mail.cn", [15]))
        #expect(TextRuleMatcher.reading(of: "daniel.park@example.com").dropped.isEmpty)
    }

    @Test func idCutBeforeItsLastDigit() {
        // Seventeen digits and an X: the rule of the whole length, an ID number, not a card.
        #expect(junction(["身份证3205851990", "1122663X收件要用"])
            == [JunctionMatch(rule: .idNumber, text: "3205851990 1122663X", ranges: [3..<13, 0..<8])])
    }

    @Test func wholeByItself() {
        #expect(TextRuleMatcher.whole("13800138000") && TextRuleMatcher.wholeByShape("13800138000"))
        #expect(TextRuleMatcher.whole("SF139886700123") && !TextRuleMatcher.wholeByShape("SF139886700123"))
        #expect(TextRuleMatcher.whole("https://fict.ly/8Kd2Qz") && TextRuleMatcher.whole("zhang.wei@example.com"))
        // A scheme takes any host at all: the host must be whole on its own, its last label two
        // letters or more, and the address must not stop where its path would go on.
        #expect(!TextRuleMatcher.whole("https://shop.example.c") && !TextRuleMatcher.whole("https://") && !TextRuleMatcher.whole("6228 4800"))
        #expect(!TextRuleMatcher.whole("https://docs.example.com/") && TextRuleMatcher.whole("https://fict-express.com/t/1Z8A03"))
        // An address ends before the mark that closes its sentence.
        let m = TextRuleMatcher.matches(in: "see fict-express.com/help, or call")
        #expect(m.map(\.text) == ["fict-express.com/help"])
        #expect(m.first?.start == 4 && m.first?.end == 25)
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
