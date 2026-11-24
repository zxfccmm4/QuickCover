import Testing

@testable import QuickCover

/// Fix 5: the small piece a wrap leaves at the end of the line above, which no rule knows for what
/// it is on its own: a scheme cut inside its name, a country code, the first number of an address,
/// a scheme read with one slash too few. Read as one with the line under it, the piece is the head
/// of a whole value, and it goes with it. What only looks like such a piece stays as it was.
@Suite struct JunctionHeadTests {

    private func junction(_ lines: [String]) -> [JunctionMatch] {
        TextRuleMatcher.junctionMatches(lines: lines)
    }

    // MARK: A scheme cut inside its name

    @Test func schemeCutInsideItsName() {
        // "htt" over "ps://…" reads "https://…". The head is a letter run and the line under it
        // carries an address whole, where "link" over "example.com" is a label over an address:
        // what tells them apart is that the head is the start of the scheme the line under it
        // finishes, and a label sits before a scheme that is whole or before a bare host.
        #expect(junction(["详情见 htt", "ps://demo.example.org 明天前"])
            == [JunctionMatch(rule: .url, text: "https://demo.example.org", ranges: [4..<7, 0..<21])])
        #expect(junction(["文档 ht", "tps://drive.fictionbox.net/s/x9"])
            == [JunctionMatch(rule: .url, text: "https://drive.fictionbox.net/s/x9", ranges: [3..<5, 0..<31])])
        #expect(junction(["见 HTTP", "S://EXAMPLE.ORG/A"])
            == [JunctionMatch(rule: .url, text: "HTTPS://EXAMPLE.ORG/A", ranges: [2..<6, 0..<17])])
    }

    @Test func schemeCutInsideItsNameOverThreeLines() {
        #expect(junction(["见 ht", "tps://demo.example.o", "rg/x"])
            == [JunctionMatch(rule: .url, text: "https://demo.example.org/x", ranges: [2..<4, 0..<20, 0..<4])])
    }

    @Test func whatIsNotASchemeHead() {
        // A word over an address is a label, as before. (The suffix is one the URL rule knows, so
        // that the address under the label is a URL; "link" over "fict.io/…" is the case to tell from
        // "htt" over "ps://…".)
        #expect(junction(["链接见 link", "fict.io/coupon 今天"]).isEmpty)
        #expect(junction(["见 http", "www.example.org/a"]).isEmpty)
        #expect(junction(["见 http", "example.com 今天"]).isEmpty)
        // The head glued to a letter on its line is no head of a scheme: "xhtt" is a word.
        #expect(junction(["见xhtt", "ps://demo.example.org"]).isEmpty)
    }

    // MARK: A country code

    @Test func countryCodeAboveItsNumber() {
        // "+86" over a phone is one number with its country code.
        #expect(junction(["司机电话请拨 +86", "139 0000 1111，到了打我"])
            == [JunctionMatch(rule: .phone, text: "+86 139 0000 1111", ranges: [7..<10, 0..<13])])
        // The number printed without groups. The text kept is the reading with the space between
        // the two pieces, as for every value read across a cut; the number is the same one.
        #expect(junction(["打这个 +86", "13900001111"])
            == [JunctionMatch(rule: .phone, text: "+86 13900001111", ranges: [4..<7, 0..<11])])
    }

    @Test func aBarePlusAsItStands() {
        // A plus with no code after it, over a number, is glued to the number by the fix that came
        // before this one and covered with it: not what this fix changed, and not what the brief
        // would have (the plus staying). The two are not told apart here; this is written as it
        // stands and waits for the one who decides it.
        #expect(junction(["合计 +", "139 0000 1111，到了打我"])
            == [JunctionMatch(rule: .phone, text: "+139 0000 1111", ranges: [3..<4, 0..<13])])
    }

    @Test func whatIsNotACountryCode() {
        // Nothing under it that the code could be the head of.
        #expect(junction(["打这个 +86", "明天三点开会"]).isEmpty)
        #expect(junction(["打这个 +86", "400-800-1234 转 2"]).isEmpty)
        // Digits that are no code: without the plus they are glued to the phone, and no rule knows the run.
        #expect(junction(["编号 86", "139 0000 1111，到了打我"]).isEmpty)
        // A year over a phone is not glued to it.
        #expect(junction(["生于 1990", "139 0000 1111，到了打我"]).isEmpty)
    }

    // MARK: The first number of an address

    @Test func addressCutAfterItsFirstNumber() {
        // "192." over "168.0.1" is one address: the full stop that ends the line is the one after
        // the first number, not the end of a sentence.
        #expect(junction(["网关地址是 192.", "168.0.1，别改"])
            == [JunctionMatch(rule: .ipv4, text: "192.168.0.1", ranges: [6..<10, 0..<7])])
        #expect(junction(["服务器 10.", "0.0.1 端口 8080"])
            == [JunctionMatch(rule: .ipv4, text: "10.0.0.1", ranges: [4..<7, 0..<5])])
        // Cut twice.
        #expect(junction(["网关 192.", "168.0.", "1，别改"])
            == [JunctionMatch(rule: .ipv4, text: "192.168.0.1", ranges: [3..<7, 0..<6, 0..<1])])
    }

    @Test func whatIsNotTheFirstNumberOfAnAddress() {
        // The number of a list over three numbers that make no address: one of them is over 255.
        #expect(junction(["事项 3.", "168.0.999，别改"]).isEmpty)
        // A price with its full stop over a sum.
        #expect(junction(["共 19.", "20 元整，多退少补"]).isEmpty)
    }

    // MARK: A scheme read with one slash too few

    @Test func schemeReadWithOneSlashTooFew() {
        // "https:/1" over a host reads "https://host": the "1" stands for the slash Vision read as
        // another character, and the head of the address goes with the rest of it.
        #expect(junction(["详情见 https:/1", "demo.example.org/a/b", "88990011 之前"])
            == [JunctionMatch(rule: .url, text: "https://demo.example.org/a/b88990011", ranges: [4..<12, 0..<20, 0..<8])])
        #expect(junction(["http:/|", "example.org"])
            == [JunctionMatch(rule: .url, text: "http://example.org", ranges: [0..<7, 0..<11])])
        #expect(junction(["见 https:/l", "shop.example.net/cart"])
            == [JunctionMatch(rule: .url, text: "https://shop.example.net/cart", ranges: [2..<10, 0..<21])])
        #expect(junction(["见 https:/I", "docs.example.com/a"])
            == [JunctionMatch(rule: .url, text: "https://docs.example.com/a", ranges: [2..<10, 0..<18])])
    }

    @Test func whatIsNotASlash() {
        // A character that passes for no slash is read as itself, and nothing matches.
        #expect(junction(["见 https:/x", "demo.example.org"]).isEmpty)
        // The line under it begins no address: there is nothing to tell the character by.
        #expect(junction(["详情见 https:/1", "明天三点开会"]).isEmpty)
        #expect(junction(["详情见 https:/1", "88990011 之前"]).isEmpty)
    }
}
