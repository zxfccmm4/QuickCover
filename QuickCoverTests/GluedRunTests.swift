import Testing

@testable import QuickCover

/// Brief Part A, and the addendum of 21:05: a run of digits the rules could not know whole, two
/// table columns read as one line or a sum glued to a phone, is cut into its values. The cut
/// comes after the growing, so the pieces stay apart.
@Suite struct GluedRunTests {

    private func runs(_ line: String) -> [RuleMatch] { TextRuleMatcher.runs(in: line) }

    /// What a match spans in the line, read by its indices.
    private func spanned(_ line: String, _ m: RuleMatch) -> String {
        let scalars = Array(line.precomposedStringWithCompatibilityMapping.unicodeScalars)
        return String(String.UnicodeScalarView(scalars[m.start..<m.end]))
    }

    /// Every match lies over exactly its text in the line.
    private func spansMatch(_ line: String, _ out: [RuleMatch]) -> Bool {
        out.allSatisfy { spanned(line, $0) == $0.text }
    }

    @Test func cardGluedToIDNumber() {
        // 19 digits of a card and the 18 of the neighbour's ID number, 37 in one run.
        let line = "卡号6222021001108867123420261123000045678"
        let out = runs(line)
        #expect(out.count == 2)
        #expect(out.map(\.rule) == [.bankCard, .idNumber])
        #expect(out.map(\.text) == ["6222021001108867123", "420261123000045678"])
        #expect(spansMatch(line, out))
        #expect(out[0].end == out[1].start)
    }

    @Test func phoneThenCard() {
        // 11 digits and 19, 30 in one run: the split where both are known wins over a card of 19 cut out of the start.
        let line = "138001380006222021501234567890"
        let out = runs(line)
        #expect(out.count == 2)
        #expect(out.map(\.rule) == [.phone, .bankCard])
        #expect(out.map(\.text) == ["13800138000", "6222021501234567890"])
        #expect(spansMatch(line, out))
    }

    @Test func loneTwentyDigitsIsOneReference() {
        // An order number: a card of 19 with one digit over it is not a card. Unchanged.
        let line = "订单20261123000456789012"
        let out = runs(line)
        #expect(out.map(\.rule) == [.reference])
        #expect(out.map(\.text) == ["20261123000456789012"])
        #expect(spansMatch(line, out))
    }

    @Test func cardGluedToOtherDigits() {
        // A 19-digit card and 13 digits nobody knows: a reference over the rest.
        let line = "62220210011088671235555666677778"
        let out = runs(line)
        #expect(out.count == 2)
        #expect(out.map(\.rule) == [.bankCard, .reference])
        #expect(out.map(\.text) == ["6222021001108867123", "5555666677778"])
        #expect(spansMatch(line, out))
    }

    @Test func cardInGroupsWithTenDigitsAfterIt() {
        // The separators between digits are gone from the digits view: the groups and the number
        // beside them are one run of 29 digits, and the cut sees the card at the start.
        let line = "6222 0210 0110 8867 123 4567890123"
        let out = runs(line)
        #expect(out.count == 2)
        #expect(out.map(\.rule) == [.bankCard, .reference])
        #expect(out.map(\.text) == ["6222 0210 0110 8867 123", "4567890123"])
        #expect(spansMatch(line, out))
    }

    @Test func cardInGroupsWithAShortNumberAfterIt() {
        // 24 digits in groups: the rest beside a card of 19 is too short to pass for a reference,
        // so the run is hidden whole as one, where before nothing in it matched at all.
        let line = "6222 0210 0110 8867 1234 5678"
        let out = runs(line)
        #expect(out.map(\.rule) == [.reference])
        #expect(out.map(\.text) == ["6222 0210 0110 8867 1234 5678"])
        #expect(spansMatch(line, out))
    }

    @Test func sumGluedToAPhone() {
        // 「消费1590.0015900467381」: the full stop is not a separator, so the digits view holds
        // 1590 and then 0015900467381, 13 digits. The last 11 are a phone; the two digits before
        // it are a reference, joined to what the reference rule had grown over before them.
        let line = "消费1590.0015900467381"
        let out = runs(line)
        #expect(out.count == 2)
        #expect(out.map(\.rule) == [.reference, .phone])
        #expect(out.last?.text == "15900467381")
        #expect(out.first?.start == 2 && out.first?.end == out.last?.start)
        #expect(spansMatch(line, out))
        #expect(out.first.map { spanned(line, $0).hasSuffix("00") } == true)
    }

    @Test func phoneWithDigitsAfterIt() {
        // The same from the other end: a phone of 11 and two digits after it.
        let line = "1590046738100"
        let out = runs(line)
        #expect(out.count == 2)
        #expect(out.map(\.rule) == [.phone, .reference])
        #expect(out.map(\.text) == ["15900467381", "00"])
        #expect(spansMatch(line, out))
    }

    @Test func thirteenDigitsNobodyKnowsStayAsTheyWere() {
        let line = "1234567890123"
        let scalars = Array(line.precomposedStringWithCompatibilityMapping.unicodeScalars)
        let before = RuleMatch.grow(TextRuleMatcher.matches(in: line), in: scalars)
        #expect(before.map(\.rule) == [.reference])
        #expect(runs(line) == before)
    }

    @Test func longRunNobodyKnowsIsOneReference() {
        let line = "1234567890123456789012"
        let out = runs(line)
        #expect(out.map(\.rule) == [.reference])
        #expect(out.map(\.text) == ["1234567890123456789012"])
        #expect(spansMatch(line, out))
    }

    @Test func aCardAloneIsNotCut() {
        // A card the bank rule knows whole, 16 or 19 digits: nothing is cut out of it.
        for line in ["6222021001108867", "6222021001108867123"] {
            #expect(runs(line).map(\.rule) == [.bankCard], "for \(line)")
            #expect(runs(line).map(\.text) == [line], "for \(line)")
        }
    }

    @Test func aLoneIDNumberStaysWhole() {
        // 18 digits are an ID number, which the ID rule knows whole: it is not a run to cut either.
        let line = "622202100110886712"
        #expect(runs(line).map(\.rule) == [.idNumber])
        #expect(runs(line).map(\.text) == [line])
    }

    @Test func lettersGluedToARunMakeOneCode() {
        // A waybill number holds a phone's digits; the SF before it makes the whole one code.
        let codes = [("SF1398867001234", "SF1398867001234"),
                     ("顺丰单号SF1398867001234，到了放驿站", "SF1398867001234"),
                     ("se1398867001234", "se1398867001234")]
        for (line, code) in codes {
            #expect(runs(line).map(\.rule) == [.reference], "for \(line)")
            #expect(runs(line).map(\.text) == [code], "for \(line)")
        }
    }

    @Test func piecesOfOneRunAreNotMergedByGrowing() {
        // Growing alone joins touching matches; the cut comes after it, so the pieces stay apart.
        let line = "138001380006222021501234567890"
        let scalars = Array(line.precomposedStringWithCompatibilityMapping.unicodeScalars)
        let grown = RuleMatch.grow([
            RuleMatch(rule: .phone, text: "13800138000", tolerant: false, start: 0, end: 11),
            RuleMatch(rule: .bankCard, text: "6222021501234567890", tolerant: false, start: 11, end: 30),
        ], in: scalars)
        #expect(grown.count == 1)
        #expect(runs(line).count == 2)
    }
}
