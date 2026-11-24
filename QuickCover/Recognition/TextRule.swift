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

    /// Whether the rule matches digits through and through (an ID number's X aside): a phone, an ID
    /// number, a card, an address of the IP kind. A word glued to such a value is not part of it
    /// unless in capitals, which make a code of them.
    var isDigitsOnly: Bool {
        switch self {
        case .phone, .idNumber, .bankCard, .ipv4: true
        default: false
        }
    }
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

/// A value a line wrap cut in two or three: what a rule matches when the lines are read as one.
struct JunctionMatch: Equatable, Sendable {
    let rule: TextRule
    /// The matched characters, the lines read as one.
    let text: String
    /// Where the matched characters sit on each line the value was read from, one entry per
    /// line: scalar indices into that line's NFKC form, or nil for a line the match does not reach.
    let ranges: [Range<Int>?]
}

extension JunctionMatch {

    /// One match per value. Where two matches overlap on a line and one's range there holds the
    /// other's, and so on every line the other reaches, the other is the same value read again or
    /// a piece of it, and it goes: the larger range stays. Two that only cross partly, neither
    /// holding the other on every line it reaches, both stay.
    static func distinct(_ found: [JunctionMatch]) -> [JunctionMatch] {
        var kept: [JunctionMatch] = []
        for m in found {
            if kept.contains(where: { holds($0, over: m) }) { continue }
            kept.removeAll { holds(m, over: $0) }
            kept.append(m)
        }
        return kept
    }

    /// Whether `a` reaches every line `b` reaches, with a range that holds `b`'s there.
    private static func holds(_ a: JunctionMatch, over b: JunctionMatch) -> Bool {
        var shared = false
        for (i, range) in b.ranges.enumerated() {
            guard let range else { continue }
            guard i < a.ranges.count, let holder = a.ranges[i],
                  holder.lowerBound <= range.lowerBound, range.upperBound <= holder.upperBound else { return false }
            shared = true
        }
        return shared
    }
}

extension RuleMatch {

    /// A rule can match part of one number, code or address: 16 digits of "R2026112300045678".
    /// Each match is grown to the whole run of characters it sits in, and runs that touch are
    /// joined: what is left showing still identifies, so all of it is hidden. A phone, an ID number,
    /// a card and an IP address are digits through and through (an ID number's X aside), and the
    /// small letters glued to such a value are of two kinds. A run of them that reads as digits
    /// through and through, "5510 3927oz", may be digits Vision read as letters: a digit left
    /// showing is worse than a letter hidden, so the run goes with the value. Any other run, "5510
    /// 3927on" after it or "tel" before it, is a word of its own and stays showing whole, sign and
    /// all. A capital glued to the value makes a code of them, "R2026112300045678", and goes with it.
    static func grow(_ matches: [RuleMatch], in scalars: [Unicode.Scalar]) -> [RuleMatch] {
        /// The small letters a reader takes for digits: the small keys of the matcher's `confusions`.
        let passesForADigit: Set<Unicode.Scalar> = ["o", "l", "s", "z"]
        /// Whether the small letters that open `scalars[from..<to]` are a word: one of them reads as no
        /// digit. A capital ends them; what stands after them is neither asked about nor cut.
        func isWord(from: Int, to: Int) -> Bool {
            var i = from
            while i < to, isSmallLetter(scalars[i]) {
                if !passesForADigit.contains(scalars[i]) { return true }
                i += 1
            }
            return false
        }
        func text(_ from: Int, _ to: Int) -> String { String(String.UnicodeScalarView(scalars[from..<to])) }
        var joined: [RuleMatch] = []
        for m in matches.sorted(by: { $0.start < $1.start }) {
            guard m.end > m.start, m.start >= 0, m.end <= scalars.count else { joined.append(m); continue }
            var start = m.start, end = m.end
            while start > 0, isRunCharacter(scalars[start - 1]) { start -= 1 }
            while end < scalars.count, isRunCharacter(scalars[end]) { end += 1 }
            if m.rule.isDigitsOnly {
                if start < m.start, isWord(from: start, to: m.start) { start = m.start }
                if end > m.end, isWord(from: m.end, to: end) { end = m.end }
            }
            if let last = joined.last, start <= last.end {
                joined[joined.count - 1] = RuleMatch(rule: last.rule, text: text(last.start, max(end, last.end)),
                                                     tolerant: last.tolerant, start: last.start, end: max(end, last.end))
            } else {
                joined.append(RuleMatch(rule: m.rule, text: text(start, end), tolerant: m.tolerant, start: start, end: end))
            }
        }
        return joined
    }

    /// A small Latin letter: of a word, "on", "ok", and not of a code, whose letters are printed in
    /// capitals.
    static func isSmallLetter(_ s: Unicode.Scalar) -> Bool { ("a"..."z").contains(s) }

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

    /// The line as the rules read it: NFKC, and with the space Vision puts into an address whose
    /// local part is a dotted name cut at its full stop left out: "ou.yang. f@fict-mail.cn" reads
    /// "ou.yang.f@fict-mail.cn", which is the address, where a letter on its own is not one.
    /// `dropped` tells where in the NFKC line each space left out stood, as scalar indices, so
    /// that the characters after it can still be placed on the picture.
    static func reading(of line: String) -> (text: String, dropped: [Int]) {
        let normalized = line.precomposedStringWithCompatibilityMapping
        guard let cut = try? NSRegularExpression(pattern: #"(?<=[0-9A-Za-z]\.)\s(?=[0-9A-Za-z]@)"#) else { return (normalized, []) }
        let matches = cut.matches(in: normalized, range: NSRange(location: 0, length: (normalized as NSString).length))
        guard !matches.isEmpty else { return (normalized, []) }
        let cuts = Set(matches.map(\.range.location))
        var text = String.UnicodeScalarView()
        var dropped: [Int] = []
        var utf16 = 0, scalar = 0
        for s in normalized.unicodeScalars {
            if cuts.contains(utf16) { dropped.append(scalar) } else { text.append(s) }
            utf16 += String(s).utf16.count
            scalar += 1
        }
        return (String(text), dropped)
    }

    static func matches(in line: String) -> [RuleMatch] {
        scan(views(for: line))
    }

    /// Whether `text` is a value whole on its own line, by any rule. `ref` counts: ten characters
    /// or more that the rules know as a code are one. An address with a scheme is whole only when
    /// its host is: the scheme form takes any host at all, "https://shop.example.c" included, which
    /// is a domain cut before its end.
    static func whole(_ text: String) -> Bool { covers(text, named: false) }

    /// The same by the rules that know a value by its shape alone: a phone, an ID number, a card,
    /// an address, an IP address or a plate. A code by `ref` is not whole by itself, since the rule
    /// takes the first ten characters of a longer code just as well as a whole one.
    static func wholeByShape(_ text: String) -> Bool { covers(text, named: true) }

    private static func covers(_ text: String, named: Bool) -> Bool {
        let n = reading(of: text).text.unicodeScalars.count
        return matches(in: text).contains { m in
            guard m.start == 0, m.end == n, !named || m.rule != .reference else { return false }
            return m.rule != .url || hostIsWhole(text)
        }
    }

    /// Whether an address is whole as it stands. The scheme form takes any host at all,
    /// "https://shop.example.c" included, which is a domain cut before its end: the host must end
    /// in a label of two letters or more. And the address must not stop where its path would go on,
    /// at a slash, a question mark or the like.
    private static func hostIsWhole(_ text: String) -> Bool {
        let address = reading(of: text).text
        guard let cut = address.range(of: "://") else { return true }
        let after = Array(address[cut.upperBound...].unicodeScalars)
        let stop = after.firstIndex(where: { "/?#:".unicodeScalars.contains($0) }) ?? after.count
        let scalars = Array(after[..<stop])
        // The last label of the host, or the whole of it when it has no full stop.
        let dot = scalars.lastIndex(of: ".")
        let label = scalars[(dot.map { $0 + 1 } ?? 0)...]
        let letters = label.filter { $0.properties.isAlphabetic }.count
        let open: Set<Unicode.Scalar> = ["/", "?", "#", "=", "&", "."]
        return letters >= 2 && letters == label.count && !(after.last.map(open.contains) ?? true)
    }

    /// What a line carries to hide: its matches, each grown to the whole run of characters it
    /// sits in, and then a run of digits long enough to be two values glued by a table's columns
    /// cut into them. The cut comes after the growing, which would join the pieces again.
    static func runs(in line: String) -> [RuleMatch] {
        let v = views(for: line)
        return cutGlued(RuleMatch.grow(scan(v), in: v.scalars), views: v)
    }

    private static func scan(_ v: Views) -> [RuleMatch] {
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
            let scalars = Array(text.unicodeScalars)
            for m in pattern.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                let location = m.range.location
                var length = m.range.length
                guard length > 0 else { continue }
                // An address ends before the mark that closes the sentence it stands in: "…/help,"
                // hides the address, not the comma. (The fold is one UTF-16 unit a scalar.)
                if rule == .url, scalars.count == ns.length {
                    while length > 1, closingMarks.contains(scalars[location + length - 1]) { length -= 1 }
                }
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

        // Rule order breaks ties; then, of two readings of one rule from one place, the one that
        // matches as read comes before the one that matches only by taking a letter for a digit:
        // "5510 3927on" is a card to its digits, not a digit longer by an o. Then the longer one.
        // Overlaps are dropped, so each character is claimed once.
        let order = Dictionary(uniqueKeysWithValues: TextRule.allCases.enumerated().map { ($1, $0) })
        candidates.sort { lhs, rhs in
            let l = order[lhs.rule]!, r = order[rhs.rule]!
            if l != r { return l < r }
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            if lhs.tolerant != rhs.tolerant { return !lhs.tolerant }
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

    // MARK: - Glued digits

    /// The least digits a run must have for a cut to be tried on it: the shortest value cut out
    /// of a run is a phone of 11 digits, so 12 is a phone with one digit glued to it.
    private static let gluedRunDigits = 12

    /// The least digits a run nobody recognizes at either end must have to be hidden whole as a
    /// reference. Under it, 12 to 15 digits, the reference rule decides as it does today.
    private static let wholeRunDigits = 16

    /// What must be left of a run beside a card-shaped or ID-shaped piece for that piece to be
    /// cut out: a card is any 16 to 19 digits, so a run of 20 with one digit over it is one order
    /// number, not a card. A phone is told by its first two digits, and is cut out of anything.
    private static let restDigits = 10

    /// The length of the piece tried at an end of a run, longest first: a card of 19, 18, 17 or
    /// 16 digits, an ID number of 18, then a phone of 11.
    private static let pieceLengths = [19, 18, 17, 16, 11]

    /// Cuts into its values every run of digits the rules could not know whole. The separators
    /// between digits are gone from the `digits` view, so a card printed in groups and the number
    /// beside it are one run there, and a sum glued to a phone is one run with the phone at its
    /// end. The full stop and the comma stay, so a sum and the number after it are two runs. The
    /// cut comes after the growing, which would join the pieces again.
    private static func cutGlued(_ matches: [RuleMatch], views v: Views) -> [RuleMatch] {
        let d = Array(v.digits.unicodeScalars)
        var out = matches
        var i = 0
        while i < d.count {
            guard isDigit(d[i]) else { i += 1; continue }
            var j = i
            while j < d.count, isDigit(d[j]) { j += 1 }
            let digits = j - i
            // An ID number ends in X: the letter belongs to the last value of the run.
            if j < d.count, d[j].value == 88 { j += 1 }
            // A letter glued to the run makes one code of them, SF1398867001234, which the reference
            // rule hides whole: the run is not two values, whatever shape its digits make.
            let oneCode = (i > 0 && isLetter(d[i - 1])) || (j < d.count && isLetter(d[j]))
            if digits >= gluedRunDigits, !oneCode { cut(d[i..<j], from: i, views: v, into: &out) }
            i = j
        }
        return out.sorted { $0.start < $1.start }
    }

    /// Cuts one run of the `digits` view, which starts at `i` there, into its place in the line.
    private static func cut(_ run: ArraySlice<Unicode.Scalar>, from i: Int, views v: Views, into out: inout [RuleMatch]) {
        let j = i + run.count
        let from = v.digitsMap[i], to = v.digitsMap[j - 1] + 1
        func piece(_ rule: TextRule, _ start: Int, _ end: Int) -> RuleMatch {
            RuleMatch(rule: rule, text: Self.string(Array(v.scalars[start..<end])), tolerant: false, start: start, end: end)
        }
        // What stands over the run already. A rule other than reference knows the digits for part
        // of something it hides whole, an address: the run is not two values.
        let over = out.filter { $0.start < to && $0.end > from }
        if over.contains(where: { $0.rule != .reference }) { return }

        guard let split = shapes(run) else {
            // Nobody knows an end. A long enough run is one reference, over the run and whatever
            // a reference beside it had grown over, so nothing that was hidden is shown again.
            guard run.filter(isDigit).count >= wholeRunDigits else { return }
            if over.contains(where: { $0.start <= from && $0.end >= to }) { return }
            let left = min(from, over.map(\.start).min() ?? from), right = max(to, over.map(\.end).max() ?? to)
            out.removeAll { $0.start < to && $0.end > from }
            out.append(piece(.reference, left, right))
            return
        }
        var pieces = split.map { piece($0.rule, v.digitsMap[i + $0.start], v.digitsMap[i + $0.end - 1] + 1) }
        // What a reference beside the run had grown over, the sum and its point before a phone,
        // stays hidden: joined to a reference piece at the end of the run it touches, or apart.
        let left = over.map(\.start).min(), right = over.map(\.end).max()
        out.removeAll { $0.start < to && $0.end > from }
        if let left, left < from {
            if pieces[0].rule == .reference { pieces[0] = piece(.reference, left, pieces[0].end) }
            else { out.append(piece(.reference, left, from)) }
        }
        if let right, right > to {
            let last = pieces.count - 1
            if pieces[last].rule == .reference { pieces[last] = piece(.reference, pieces[last].start, right) }
            else { out.append(piece(.reference, to, right)) }
        }
        out.append(contentsOf: pieces)
    }

    /// The two values of a run of digits, as offsets into the run, the first at the start. A
    /// split where both are shapes a rule knows wins, provided one is a phone or an ID number:
    /// those are told by their shape alone, where 16 to 19 digits could be anything. Otherwise
    /// one end is a known shape and the rest passes for a reference when it has no shape. The
    /// piece at the start is tried before the piece at the end, each length longest first.
    /// Nil when neither end is a known shape.
    private static func shapes(_ run: ArraySlice<Unicode.Scalar>) -> [(rule: TextRule, start: Int, end: Int)]? {
        let r = Array(run)
        let n = r.count
        func shape(_ a: Int, _ b: Int) -> TextRule? { a >= 0 && b <= n && b > a ? Self.shape(r[a..<b]) : nil }
        func named(_ rule: TextRule?) -> Bool { rule == .phone || rule == .idNumber }
        func halves(_ first: TextRule, _ a: Int, _ b: Int, _ second: TextRule?, _ c: Int, _ d: Int) -> [(rule: TextRule, start: Int, end: Int)] {
            [(first, a, b), (second ?? .reference, c, d)].sorted { $0.start < $1.start }
        }
        var rest: [(rule: TextRule, start: Int, end: Int)]?
        for atStart in [true, false] {
            for length in pieceLengths where length < n {
                var a = 0, b = length, c = length, d = n
                if !atStart { a = n - length; b = n; c = 0; d = n - length }
                guard let first = shape(a, b) else { continue }
                let second = shape(c, d)
                if let second, named(first) || named(second) { return halves(first, a, b, second, c, d) }
                if rest == nil, first == .phone || d - c >= restDigits { rest = halves(first, a, b, second, c, d) }
            }
        }
        return rest
    }

    /// The rule a piece follows by its shape alone: a phone is 11 digits starting with 1[3-9],
    /// an ID number is 17 digits and a digit or an X, a card is 16 to 19 digits.
    private static func shape(_ piece: ArraySlice<Unicode.Scalar>) -> TextRule? {
        let p = Array(piece)
        guard let first = p.first, let last = p.last else { return nil }
        let digits = p.filter(isDigit).count
        if p.count == 11, digits == 11, first.value == 49, (51...57).contains(p[1].value) { return .phone }
        if p.count == 18, digits >= 17, p.dropLast().allSatisfy(isDigit), isDigit(last) || last.value == 88 { return .idNumber }
        if (16...19).contains(p.count), digits == p.count { return .bankCard }
        return nil
    }

    // MARK: - Wrapped values

    /// The matches that cross from one line to the next once the lines, two or three that a wrap
    /// cut, are read as one, each place the wrap cut taken both as clean and as parted with a
    /// space. No piece of such a value matches alone, so a match that stays inside one line is
    /// not new and is left out. One value is told once: see `JunctionMatch.distinct`.
    static func junctionMatches(lines: [String]) -> [JunctionMatch] {
        let read = lines.map { Array(reading(of: $0).text.unicodeScalars) }
        guard (2...3).contains(read.count) else { return [] }
        // The readings with spaces first, so that the text kept for a value is the one a reader sees.
        var readings: [Int: [(match: RuleMatch, places: [Range<Int>?])]] = [:]
        var found: [JunctionMatch] = []
        for parted in stride(from: (1 << (read.count - 1)) - 1, through: 0, by: -1) {
            let items = reading(read, parted: parted)
            readings[parted] = items
            for item in items {
                let ranges = item.places
                let crossing = (1..<read.count).contains { ranges[$0 - 1] != nil && ranges[$0] != nil }
                guard crossing else { continue }
                let match = JunctionMatch(rule: item.match.rule, text: item.match.text, ranges: ranges)
                guard !glued(match, parted: parted, lines: read, readings: readings) else { continue }
                found.append(match)
            }
        }
        return JunctionMatch.distinct(found)
    }

    /// The lines read as one, a space at the cuts named in `parted` and the slashes of a scheme
    /// Vision lost at a cut put back: what the reading matches, and where each match sits on each
    /// line, as scalar indices into that line, or nil for a line the match does not reach. The
    /// characters put back belong to no line, so a match that spans them still reaches a character
    /// of the line on either side.
    private static func reading(_ lines: [[Unicode.Scalar]], parted: Int) -> [(match: RuleMatch, places: [Range<Int>?])] {
        let space: Unicode.Scalar = " "
        var joined: [Unicode.Scalar] = []
        var starts: [Int] = []
        for (i, line) in lines.enumerated() {
            if i > 0 {
                if (parted & (1 << (i - 1))) != 0 { joined.append(space) }
                joined += Self.mend(from: lines[i - 1], to: line)
            }
            starts.append(joined.count)
            joined += line
        }
        return RuleMatch.grow(matches(in: Self.string(joined)), in: joined).map { m in
            (m, lines.indices.map { i in
                // Where the piece sits on its own line, not on the joined text: two readings that
                // differ only by a separator then tell the same value the same way.
                let from = max(m.start, starts[i]) - starts[i], to = min(m.end, starts[i] + lines[i].count) - starts[i]
                return from < to ? from..<to : nil
            })
        }
    }

    /// The slashes to put back where a line ends in the scheme of an address and the line under
    /// it begins without them: "https:/" over "fict.ly/…" and "https:" over "fict.ly". Where the
    /// line under it starts with a slash the scheme is whole already.
    private static func mend(from upper: [Unicode.Scalar], to lower: [Unicode.Scalar]) -> [Unicode.Scalar] {
        let slash: Unicode.Scalar = "/"
        let tail = String(String.UnicodeScalarView(upper.filter { !$0.properties.isWhitespace })).lowercased()
        let missing: Int
        if tail.hasSuffix("https:/") || tail.hasSuffix("http:/") { missing = 1 }
        else if tail.hasSuffix("https:") || tail.hasSuffix("http:") { missing = 2 }
        else { return [] }
        guard let first = lower.first, first != slash else { return [] }
        return Array(repeating: slash, count: missing)
    }

    /// Whether a match that crosses a cut read without a space is not a value the wrap cut, but
    /// what stands next to a value glued onto it. A wrap has a shape: the value runs to the end of
    /// the line it is cut from, and the last line of a number that was whole already carries no
    /// other digits, as the row under a phone does. What a line carries whole is not lengthened by
    /// a word either: a label over an address, a sentence under one, a word in lower case before a
    /// number, and a whole value over a line that starts with a letter.
    private static func glued(_ m: JunctionMatch, parted: Int, lines: [[Unicode.Scalar]],
                              readings: [Int: [(match: RuleMatch, places: [Range<Int>?])]]) -> Bool {
        let reached = m.ranges.indices.filter { m.ranges[$0] != nil }
        guard let first = reached.first, let last = reached.last, let head = m.ranges[first], let tail = m.ranges[last] else { return true }
        let rest = { (line: Int, from: Int) in lines[line].dropFirst(from) }
        func text(_ line: Int, _ range: Range<Int>) -> String { String(String.UnicodeScalarView(lines[line][range])) }
        // The value runs to the end of the line it is cut from, a mark aside.
        if rest(first, head.upperBound).contains(where: { !$0.properties.isWhitespace && !isMark($0) }) { return true }
        // The last line of a number that was whole already holds no other digits: the digits under a
        // whole number are a row of their own. A piece that is no whole number by its shape, "5820193"
        // or "6228 4800", is the start of one, whatever stands under it on the last line. The piece
        // on the last line is the end of the value; where digits run on from it through a mark, "2026"
        // of "2026-11-23", it is the head of a number of its own, for a code keeps its marks out, and
        // the digits under the line are a row of their own as well.
        if m.rule == .phone || m.rule == .idNumber || m.rule == .bankCard || m.rule == .reference,
           reached.count >= 2, let above = m.ranges[reached[reached.count - 2]],
           wholeByShape(text(reached[reached.count - 2], above)) || runsOn(lines[last][tail]),
           rest(last, tail.upperBound).contains(where: { isDigit($0) }) { return true }
        for j in 0..<(lines.count - 1) where (parted & (1 << j)) == 0 {
            guard let upper = m.ranges[j], let lower = m.ranges[j + 1] else { continue }
            let above = Array(lines[j][upper]), below = Array(lines[j + 1][lower])
            // A word over an address that the line under it carries whole is a label. A piece that
            // starts with a mark was cut where it was: "zhang" over ".wei@example.com" is one address.
            if m.rule == .email || m.rule == .url, above.allSatisfy({ isLetter($0) }),
               below.first.map({ isLetter($0) || isDigit($0) }) ?? false,
               readings[parted | (1 << j)]?.contains(where: { item in
                   item.places[j + 1].map { $0.lowerBound <= lower.lowerBound && lower.upperBound <= $0.upperBound } ?? false
               }) == true {
                return true
            }
            // A whole value over a line that starts with a letter was not cut: the value ends where
            // it is, and what is under it is a sentence, "1ZFICT8A0304821762" over "DELIVERY LINK…".
            // Only where the value starts: the middle line of an address over three lines is whole
            // by itself too, "example.com/path" under "https://", and is no end of the address. And
            // not where the line under it carries a value whole, "onbox.net/shared/fol" under
            // "https://drive.ficti": a sentence does not read as a value, and a cut address does.
            if j == first, whole(String(String.UnicodeScalarView(above))), let b = below.first, isLetter(b),
               !whole(String(String.UnicodeScalarView(below))) { return true }
            // A word before a number or a code is the end of a sentence, not the start of a code,
            // whose start, SE or SF, is in capitals. Growing may have named the whole after the
            // number, a phone with "ok" before it, so the rule does not tell them apart: both go.
            if m.rule != .email, m.rule != .url, above.allSatisfy({ isLetter($0) }), !above.allSatisfy({ $0.value < 97 }) { return true }
            // A sentence under an address starts in capitals where the address ended in small letters.
            if let a = above.last, let b = below.first, isLetter(a), a.value >= 97, isLetter(b), b.value < 97 { return true }
        }
        return false
    }

    /// Whether the piece a value leaves on its last line is the head of a number that goes on past
    /// it: "2026" of "2026-11-23", digits that run on through a mark. The end of a value stops where
    /// the value stops, and a code has no mark in it.
    private static func runsOn(_ piece: ArraySlice<Unicode.Scalar>) -> Bool {
        var digits = false, mark = false
        for s in piece {
            if isDigit(s) {
                if mark, digits { return true }
                digits = true
                mark = false
            } else if digits, isMark(s), !s.properties.isWhitespace {
                mark = true
            } else {
                return false
            }
        }
        return false
    }

    /// A mark: punctuation or a sign, what is neither a letter nor a digit nor space.
    private static func isMark(_ s: Unicode.Scalar) -> Bool {
        !s.properties.isAlphabetic && !isDigit(s)
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
    /// The marks a sentence closes with, which an address before them does not carry.
    private static let closingMarks: Set<Unicode.Scalar> = [".", ",", ";", ":", "!", "?"]
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
        let normalized = reading(of: line).text
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
