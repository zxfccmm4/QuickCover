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
}
