import Foundation

/// The text rules of the brief (§7.2), in the order used to label a line.
/// `rawValue` is the tag the baseline ground truth uses.
enum TextRule: String, CaseIterable, Sendable, Codable {
    case phone
    case idNumber = "id"
    case bankCard = "bank"
    case email
    case url
    case ipv4
    case reference = "ref"
    case plate
}

/// One place in a recognized line where a rule matches.
struct RuleMatch: Equatable, Sendable {
    let rule: TextRule
    /// The matched characters, as the recognizer read them.
    let text: String
    /// The rule matched only after common OCR confusions were fixed (O for 0, l for 1 …).
    let tolerant: Bool
    /// Where the matched text sits in the line: scalar indices into its NFKC form, end exclusive.
    let start: Int
    let end: Int
}

extension RuleMatch {

    /// A rule can match part of one number, code or address: 16 digits of "R2026112300045678".
    /// Each match is grown to the whole run of characters it sits in, and runs that touch are
    /// joined: what is left showing still identifies, so all of it is hidden.
    static func grow(_ matches: [RuleMatch], in scalars: [Unicode.Scalar]) -> [RuleMatch] {
        func text(_ from: Int, _ to: Int) -> String { String(String.UnicodeScalarView(scalars[from..<to])) }
        var joined: [RuleMatch] = []
        for m in matches.sorted(by: { $0.start < $1.start }) {
            guard m.end > m.start, m.start >= 0, m.end <= scalars.count else { joined.append(m); continue }
            var start = m.start, end = m.end
            while start > 0, isRunCharacter(scalars[start - 1]) { start -= 1 }
            while end < scalars.count, isRunCharacter(scalars[end]) { end += 1 }
            if let last = joined.last, start <= last.end {
                joined[joined.count - 1] = RuleMatch(rule: last.rule, text: text(last.start, max(end, last.end)),
                                                     tolerant: last.tolerant, start: last.start, end: max(end, last.end))
            } else {
                joined.append(RuleMatch(rule: m.rule, text: text(start, end), tolerant: m.tolerant, start: start, end: end))
            }
        }
        return joined
    }

    /// A character that belongs to a number, code, address or Latin word: a letter that is not
    /// Chinese, Japanese or Korean, a digit, a sign, and the three marks that sit inside codes
    /// (the dash, the underscore, the full stop). Chinese characters, spaces and every other
    /// mark end the run: "卡号6222…" hides the number, not the word before it.
    static func isRunCharacter(_ s: Unicode.Scalar) -> Bool {
        if s.properties.isWhitespace { return false }
        switch s.value {
        case 0x2E80...0x9FFF, 0xAC00...0xD7AF, 0xF900...0xFAFF, 0xFE30...0xFE4F, 0xFF00...0xFFEF: return false
        default: break
        }
        switch s.properties.generalCategory {
        case .dashPunctuation, .connectorPunctuation: return true
        case .initialPunctuation, .finalPunctuation, .openPunctuation, .closePunctuation, .otherPunctuation:
            return s == "."
        default: return true
        }
    }
}

/// Decides which recognized text lines carry something that should be hidden.
///
/// Three rules ignore separators: a phone, ID or card number printed in groups still counts,
/// because spaces and hyphens between digits are dropped before those patterns run. `ref`
/// keeps every separator, so `400-800-1234`, `1,234,567,890` and `qc_support_2026` stay out.
enum TextRuleMatcher {

    static func matches(in line: String) -> [RuleMatch] {
        let v = views(for: line)
        if v.scalars.isEmpty { return [] }

        struct Candidate {
            let rule: TextRule
            let start: Int      // index into scalars
            let end: Int        // exclusive
            let tolerant: Bool
        }
        var candidates: [Candidate] = []

        func scan(_ pattern: NSRegularExpression, _ text: String, rule: TextRule, map: [Int]?, tolerant: Bool) {
            let ns = text as NSString
            for m in pattern.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                let location = m.range.location
                let length = m.range.length
                guard length > 0 else { continue }
                if let map {
                    candidates.append(Candidate(rule: rule, start: map[location], end: map[location + length - 1] + 1, tolerant: tolerant))
                } else {
                    candidates.append(Candidate(rule: rule, start: location, end: location + length, tolerant: tolerant))
                }
            }
        }

        let identity = Array(0..<v.scalars.count)
        scan(phonePattern, v.digits, rule: .phone, map: v.digitsMap, tolerant: false)
        scan(idPattern, v.digits, rule: .idNumber, map: v.digitsMap, tolerant: false)
        scan(bankPattern, v.digits, rule: .bankCard, map: v.digitsMap, tolerant: false)
        scan(emailPattern, v.folded, rule: .email, map: identity, tolerant: false)
        scan(urlPattern, v.folded, rule: .url, map: identity, tolerant: false)
        scan(ipv4Pattern, v.folded, rule: .ipv4, map: identity, tolerant: false)
        scan(referencePattern, v.folded, rule: .reference, map: identity, tolerant: false)
        scan(phonePattern, v.tolerant, rule: .phone, map: v.digitsMap, tolerant: true)
        scan(idPattern, v.tolerant, rule: .idNumber, map: v.digitsMap, tolerant: true)
        scan(bankPattern, v.tolerant, rule: .bankCard, map: v.digitsMap, tolerant: true)

        // Plates keep their Chinese province character, so they match on the full string, with the
        // dot and the province put in the spelling the pattern knows. One character becomes one
        // character, so a place in the mended text is the same place in the line.
        var plateScalars = String.UnicodeScalarView()
        plateScalars.append(contentsOf: v.normalized.unicodeScalars.map { plateSpelling[$0] ?? $0 })
        let plateText = String(plateScalars)
        let plateNS = plateText as NSString
        for m in platePattern.matches(in: plateText, range: NSRange(location: 0, length: plateNS.length)) {
            guard let range = Range(m.range, in: plateText) else { continue }
            let scalars = plateText.unicodeScalars
            let start = scalars.distance(from: scalars.startIndex, to: range.lowerBound)
            let end = scalars.distance(from: scalars.startIndex, to: range.upperBound)
            candidates.append(Candidate(rule: .plate, start: start, end: end, tolerant: false))
        }

        // Rule order breaks ties, then overlaps are dropped so each character is claimed once.
        let order = Dictionary(uniqueKeysWithValues: TextRule.allCases.enumerated().map { ($1, $0) })
        candidates.sort { lhs, rhs in
            let l = order[lhs.rule]!, r = order[rhs.rule]!
            if l != r { return l < r }
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            return lhs.end > rhs.end
        }
        var kept: [Candidate] = []
        for c in candidates where kept.allSatisfy({ k in c.end <= k.start || k.end <= c.start }) {
            kept.append(c)
        }
        kept.sort { $0.start < $1.start }
        return kept.map { c in
            let text = Self.string(Array(v.scalars[c.start..<c.end]))
            return RuleMatch(rule: c.rule, text: text, tolerant: c.tolerant, start: c.start, end: c.end)
        }
    }

    /// The rule that names the line: its first match in rule order.
    static func leadingRule(in line: String) -> TextRule? {
        matches(in: line).map(\.rule).min { order[$0]! < order[$1]! }
    }

    static func isFlagged(_ line: String) -> Bool {
        !matches(in: line).isEmpty
    }

    // MARK: - Internals

    private static let order = Dictionary(uniqueKeysWithValues: TextRule.allCases.enumerated().map { ($1, $0) })

    private struct Views {
        let normalized: String             // NFKC: full-width digits and letters become ASCII
        let scalars: [Unicode.Scalar]      // normalized, as scalars
        let folded: String                 // scalars with non-ASCII replaced, ASCII letters uppercased
        let digits: String                 // folded without spaces/hyphens between digits
        let digitsMap: [Int]               // digits index -> scalars index
        let tolerant: String               // digits with O->0, l->1, S->5 … next to a digit
    }

    private static let placeholder = Unicode.Scalar(0xE000)!
    private static let separators: Set<Unicode.Scalar> = [
        " ", "\u{00A0}", "-", "\u{2010}", "\u{2011}", "\u{2012}", "\u{2013}", "\u{2212}",
    ]
    private static let confusions: [Unicode.Scalar: Unicode.Scalar] = [
        "O": "0", "o": "0", "L": "1", "l": "1", "I": "1", "S": "5", "s": "5", "B": "8", "Z": "2", "z": "2",
    ]

    private static func isDigit(_ s: Unicode.Scalar) -> Bool { s.value >= 48 && s.value <= 57 }
    private static func isLetter(_ s: Unicode.Scalar) -> Bool {
        (s.value >= 65 && s.value <= 90) || (s.value >= 97 && s.value <= 122)
    }

    private static func string(_ scalars: [Unicode.Scalar]) -> String {
        var view = String.UnicodeScalarView()
        view.append(contentsOf: scalars)
        return String(view)
    }

    private static func views(for line: String) -> Views {
        let normalized = line.precomposedStringWithCompatibilityMapping
        let scalars = Array(normalized.unicodeScalars)
        var folded: [Unicode.Scalar] = []
        var digits: [Unicode.Scalar] = []
        var map: [Int] = []
        folded.reserveCapacity(scalars.count)
        for (i, s) in scalars.enumerated() {
            var f = s.isASCII ? s : placeholder
            if f.value >= 97 && f.value <= 122 { f = Unicode.Scalar(f.value - 32)! }
            folded.append(f)
            let previousIsDigit = i > 0 && isDigit(scalars[i - 1])
            let nextIsDigit = i + 1 < scalars.count && isDigit(scalars[i + 1])
            if previousIsDigit, nextIsDigit, separators.contains(s) { continue }
            digits.append(f)
            map.append(i)
        }
        var tolerant = digits
        for i in tolerant.indices {
            guard let digit = confusions[tolerant[i]] else { continue }
            let previousIsDigit = i > 0 && isDigit(tolerant[i - 1])
            let nextIsDigit = i + 1 < tolerant.count && isDigit(tolerant[i + 1])
            if previousIsDigit || nextIsDigit { tolerant[i] = digit }
        }
        return Views(
            normalized: normalized,
            scalars: scalars,
            folded: string(folded),
            digits: string(digits),
            digitsMap: map,
            tolerant: string(tolerant)
        )
    }

    // MARK: Patterns
    // Folded text is ASCII (non-ASCII became U+E000) and uppercased. Each scalar is one UTF-16
    // unit there, so an NSRange location is also a scalar index.

    nonisolated(unsafe) private static let phonePattern =
        try! NSRegularExpression(pattern: #"(?<![0-9])1[3-9][0-9]{9}(?![0-9])"#)
    nonisolated(unsafe) private static let idPattern =
        try! NSRegularExpression(pattern: #"(?<![0-9X])[0-9]{17}[0-9X](?![0-9X])"#)
    nonisolated(unsafe) private static let bankPattern =
        try! NSRegularExpression(pattern: #"(?<![0-9])[0-9]{16,19}(?![0-9])"#)
    nonisolated(unsafe) private static let emailPattern =
        try! NSRegularExpression(pattern: #"[A-Z0-9._%+\-]+@[A-Z0-9\-]+(?:\.[A-Z0-9\-]+)*\.[A-Z]{2,}"#)
    nonisolated(unsafe) private static let urlPattern =
        try! NSRegularExpression(pattern: #"[A-Z][A-Z0-9+.\-]*://[^\s\uE000]+|(?<![A-Z0-9.\-/])(?:[A-Z0-9\-]+\.)+(?:COM|CN|NET|ORG|JP|TW|HK|IO|CO|ME|INFO|BIZ|EDU|GOV|TOP|XYZ|APP|DEV|AI|CC|TV|US|UK|DE|FR|KR|SG|AU|CA|IN|RU|BR|EU|NL|SE|CH|AT|IT|ES|PL|NZ|CLUB|SITE|ONLINE|SHOP|STORE|TECH|CLOUD|WIKI|PRO|MOE|LINK|VIP|WORK|LIVE|FUN|ART|DESIGN|LTD|GROUP|TEAM|ONE|CYOU|BE|IM|LA|SO|TO|WS|NAME)(?![A-Z0-9\-])(?:/[^\s\uE000]*)?"#)
    nonisolated(unsafe) private static let ipv4Pattern =
        try! NSRegularExpression(pattern: #"(?<![0-9.])(?:(?:25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(?:25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])(?![0-9.])"#)
    /// Ten or more digits, or ten or more letters and digits that include both kinds. A long
    /// plain word is a word.
    nonisolated(unsafe) private static let referencePattern =
        try! NSRegularExpression(pattern: #"(?<![0-9A-Z])(?:[0-9]{10,}|(?=[0-9A-Z]{10,}(?![0-9A-Z]))(?=[0-9]*[A-Z])(?=[A-Z]*[0-9])[0-9A-Z]{10,})(?![0-9A-Z])"#)
    /// Mainland plate: province, city letter, five (or six for new energy) characters, optional
    /// suffix. The dot may be printed after the city letter or after the first character.
    nonisolated(unsafe) private static let platePattern =
        try! NSRegularExpression(pattern: #"[京津沪渝冀晋辽吉黑苏浙皖闽赣鲁豫鄂湘粤桂琼川贵云藏陕甘青蒙新宁使领][A-Z][·\- ]?[A-Z0-9][·\- ]?[A-Z0-9]{4,5}[挂学警港澳]?(?![A-Z0-9])"#)

    /// What a reader prints for a plate's dot and for a province in its older spelling, one
    /// character each, so the plate text is put right before the pattern sees it and nothing else
    /// is let through.
    nonisolated(unsafe) private static let plateSpelling: [Unicode.Scalar: Unicode.Scalar] = [
        "・": "·", "•": "·", "‧": "·", "∙": "·", "⋅": "·", "●": "·", "･": "·", ".": "·",
        "粵": "粤", "滬": "沪", "蘇": "苏", "閩": "闽", "贛": "赣", "魯": "鲁", "瓊": "琼", "貴": "贵", "雲": "云", "陝": "陕",
        "寧": "宁", "遼": "辽", "晉": "晋",
    ]
}
