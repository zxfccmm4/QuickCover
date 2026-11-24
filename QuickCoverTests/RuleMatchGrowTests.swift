import Testing
@testable import QuickCover

/// A match grows to the whole run of characters it sits in, so no identifying character is left
/// showing at the edge of a mask.
@Suite struct RuleMatchGrowTests {

    private func grown(_ line: String) -> [String] {
        let scalars = Array(line.precomposedStringWithCompatibilityMapping.unicodeScalars)
        return RuleMatch.grow(TextRuleMatcher.matches(in: line), in: scalars).map(\.text)
    }

    @Test func digitsInsideALongerCode() {
        #expect(grown("流水R2026112300045678元") == ["R2026112300045678"])
    }

    @Test func chineseBeforeAndAfterStays() {
        #expect(grown("我卡号6222021234567890123回头转你") == ["6222021234567890123"])
    }

    @Test func punctuationEndsTheRun() {
        #expect(grown("ID:A8821304567;备注") == ["A8821304567"])
    }

    @Test func touchingMatchesJoinIntoOne() {
        #expect(grown("编号13800138000911310108MA01AB2C3X") == ["13800138000911310108MA01AB2C3X"])
    }

    @Test func signThatJoinsIsPartOfTheRun() {
        #expect(grown("单号SF-1398867001234件") == ["SF-1398867001234"])
    }

    @Test func plainLineHasNothing() {
        #expect(grown("明天下午三点开会") == [])
    }

    //
    // A word in small letters glued to a value of digits is a word of its own and stays showing.
    //

    @Test func smallLettersGluedAfterACardStay() {
        #expect(grown("卡号6228 4800 5510 3927on下次") == ["6228 4800 5510 3927"])
    }

    @Test func labelInSmallLettersGluedBeforeAPhoneStays() {
        #expect(grown("tel13800138000") == ["13800138000"])
    }

    @Test func smallLettersAtBothEndsStay() {
        #expect(grown("xid420261123000045678kg") == ["420261123000045678"])
    }

    @Test func capitalGluedToTheDigitsIsOneCode() {
        #expect(grown("卡号6228480055103927ON") == ["6228480055103927ON"])
        #expect(grown("流水R2026112300045678元") == ["R2026112300045678"])
    }

    //
    // Small letters that pass for digits are another matter: a digit Vision read as a letter is
    // worse left showing than a letter hidden. A run of small letters glued to the value that reads
    // as digits through and through goes with it; one letter of it that reads as no digit makes the
    // whole run a word.
    //

    @Test func aLetterThatPassesForADigitStaysWithTheValue() {
        // 16 digits as read and an o after them: the o may be a 0, the card's seventeenth digit.
        #expect(grown("卡号6228 4800 5510 3927o下次") == ["6228 4800 5510 3927o"])
        // Two such letters after a phone: they may be a 0 and a 2.
        #expect(grown("转13800138000oz元") == ["13800138000oz"])
        // Before the value as well.
        #expect(grown("转o13800138000元") == ["o13800138000"])
    }

    @Test func aCardWithTwoSuchLettersWasCoveredAlready() {
        // "3927oz" reads as 18 digits, 02 for oz, and the ID number rule comes before the card's:
        // the whole of it was hidden before the rule above, by that reading.
        #expect(grown("卡号6228 4800 5510 3927oz下次") == ["6228 4800 5510 3927oz"])
    }

    @Test func oneLetterThatReadsAsNoDigitMakesTheRunAWord() {
        #expect(grown("卡号6228 4800 5510 3927on下次") == ["6228 4800 5510 3927"])
        #expect(grown("卡号6228 4800 5510 3927ok下次") == ["6228 4800 5510 3927"])
        // A label that ends in a sign is a word still.
        #expect(grown("id:420261123000045678") == ["420261123000045678"])
    }

    @Test func anAddressTooStopsAtASmallLetter() {
        #expect(grown("地址10.36.88.152in") == ["10.36.88.152"])
        #expect(grown("地址10.36.88.152IN") == ["10.36.88.152IN"])
    }

    //
    // Of two readings of one value from one place, the one that matches as read comes first. A
    // digit read as a letter is still found where nothing matches as read.
    //

    @Test func aLetterTakenForADigitDoesNotLengthenAValue() {
        // 16 digits as read, and 17 with the o taken for a 0: the card is the 16.
        let out = TextRuleMatcher.matches(in: "卡号6228 4800 5510 3927on下次")
        #expect(out.map(\.text) == ["6228 4800 5510 3927"])
        #expect(out.allSatisfy { !$0.tolerant })
    }

    @Test func aDigitReadAsALetterIsStillFound() {
        // 17 digits and an s: as a card of 17, or an ID number of 18 by the s taken for a 5. The
        // ID number is the rule that comes first.
        #expect(grown("证件42026112300004567s") == ["42026112300004567s"])
    }
}
