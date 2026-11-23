import CoreGraphics
import Foundation

struct BaselineFixture: Decodable {
    struct Item: Decodable {
        let rule: String?
        let kind: String?
        let text: String?
        let boxes: [[CGFloat]]?
        let box: [CGFloat]?

        var rects: [CGRect] {
            let raw = boxes ?? box.map { [$0] } ?? []
            return raw.compactMap { $0.count == 4 ? CGRect(x: $0[0], y: $0[1], width: $0[2], height: $0[3]) : nil }
        }
    }

    let id: String
    let file: String
    let category: String
    let variant: String
    let width: Int
    let height: Int
    let text: [Item]
    let shadow: [Item]?
    let faces: BaselineFaceList
    let codes: [Item]
}

/// A face is written either as a bare box `[x, y, w, h]` or as an item with a `box`; both read the same.
struct BaselineFaceList: Decodable {
    let items: [BaselineFixture.Item]

    init(from decoder: any Decoder) throws {
        if let list = try? [BaselineFixture.Item](from: decoder) { items = list; return }
        let raw = try [[CGFloat]](from: decoder)
        items = raw.map { BaselineFixture.Item(rule: nil, kind: nil, text: nil, boxes: nil, box: $0) }
    }
}

/// One picture as the recognizer saw it, and how long that took.
struct BaselineSeen {
    let fixture: BaselineFixture
    let result: RecognitionResult
    let milliseconds: Double
}

/// Brief §9.2: what the recognizer finds on the fake pictures, measured against their truth. The
/// rules as they stand, every hit apart. The simulator's baseline run and the self-check page on a
/// phone both count with this, so their numbers mean the same thing.
enum BaselineScore {

    /// Something in the truth counts as found when the masks together cover this much of its box.
    /// Until run 5 it was 60 % by one mask for text and 50 % for faces and codes, which let a number
    /// with its first digit showing count as hidden. Now all but a hair of the box must be covered.
    static let coveredShare: CGFloat = 0.95
    /// The old, loose share, kept only so one run can show both counts side by side.
    static let laxShare: CGFloat = 0.6

    struct Tally {
        var hit = 0, total = 0
        var value: Double { total > 0 ? Double(hit) / Double(total) : 1 }
    }


    static func area(_ r: CGRect) -> CGFloat { r.isNull ? 0 : r.width * r.height }

    static func rounded(_ v: Double, _ places: Double = 1000) -> Double { (v * places).rounded() / places }
    static func rounded(_ v: CGFloat) -> Double { (Double(v) * 10).rounded() / 10 }

    /// True when some box in `boxes` covers at least `share` of `target`.
    static func covers(_ target: CGRect, by boxes: [CGRect], share: CGFloat) -> Bool {
        boxes.contains { area($0.intersection(target)) >= share * max(area(target), 1) }
    }

    /// True when `box` hides at least half of something that should be hidden. Measured against
    /// the truth, not against the mask: a mask carries its line's margins on purpose (the space
    /// above the capitals, where the long strokes of h and l stand), so measured against its own
    /// area a true hit is called a false one as soon as it grows taller than its line.
    static func isTruePositive(_ box: CGRect, gt: [CGRect]) -> Bool {
        gt.contains { area(box.intersection($0)) >= 0.5 * max(area($0), 1) }
    }

    /// The share of `target` covered by the union of `boxes`, 0 to 1.
    static func unionCover(_ target: CGRect, _ boxes: [CGRect]) -> Double {
        guard area(target) > 0 else { return 0 }
        let clipped = boxes.map { $0.intersection(target) }.filter { !$0.isNull && $0.width > 0 && $0.height > 0 }
        let xs = Set(clipped.flatMap { [$0.minX, $0.maxX] }).sorted()
        guard xs.count > 1 else { return 0 }
        var covered: CGFloat = 0
        for (left, right) in zip(xs, xs.dropFirst()) {
            let mid = (left + right) / 2
            let spans = clipped.filter { $0.minX <= mid && mid <= $0.maxX }
                .map { (minY: $0.minY, maxY: $0.maxY) }
                .sorted { $0.minY < $1.minY }
            var length: CGFloat = 0
            var open: CGFloat?
            var close: CGFloat?
            for span in spans {
                if let o = open, let c = close {
                    if span.minY <= c { close = max(c, span.maxY) } else {
                        length += c - o
                        open = span.minY
                        close = span.maxY
                    }
                } else {
                    open = span.minY
                    close = span.maxY
                }
            }
            if let o = open, let c = close { length += c - o }
            covered += (right - left) * length
        }
        return Double(covered / area(target))
    }

    /// The report as a dictionary.
    static func score(_ seen: [BaselineSeen]) -> [String: Any] {
        var perImage: [[String: Any]] = []
        for s in seen {
            let scaled = s.result
            let fixture = s.fixture
            perImage.append([
                "id": fixture.id, "category": fixture.category, "variant": fixture.variant, "ms": (s.milliseconds * 10).rounded() / 10,
                "gt_text": fixture.text.count, "gt_faces": fixture.faces.items.count, "gt_codes": fixture.codes.count,
                "found_text": scaled.findings.filter { $0.kind == .text }.count,
                "found_faces": scaled.findings.filter { $0.kind == .face }.count,
                "found_codes": scaled.findings.filter { $0.kind == .code }.count,
                "lines": scaled.textLines.count,
                // What was read, for looking into a miss without the picture in front of you.
                "read": scaled.textLines.map { ["box": [$0.quad.map(\.x).min()!, $0.quad.map(\.y).min()!, $0.quad.map(\.x).max()! - $0.quad.map(\.x).min()!, $0.quad.map(\.y).max()! - $0.quad.map(\.y).min()!], "text": $0.text] },
            ])
        }

        // 1. The rules, every hit apart.
        var textRecall = Tally(), faceRecall = Tally(), codeRecall = Tally()
        var textTrue = 0, textFalse = 0
        var textLaxHit = 0
        var perRule: [String: Tally] = [:]
        var perCategory: [String: (text: Tally, faces: Tally, codes: Tally, fp: Int, tp: Int)] = [:]
        var falsePositives: [[String: Any]] = []
        var missed: [[String: Any]] = []
        var shadowDetail: [[String: Any]] = []
        var items: [[String: Any]] = []
        var split: [[String: Any]] = []
        var shadowHit = 0, shadowTotal = 0

        for s in seen {
            let fixture = s.fixture
            let id = fixture.id
            let hits = s.result.findings.filter { $0.kind == .text }
            let textBoxes = hits.map(\.box)
            let faceBoxes = s.result.findings.filter { $0.kind == .face }.map(\.box)
            let codeBoxes = s.result.findings.filter { $0.kind == .code }.map(\.box)
            let gtBoxes = fixture.text.flatMap(\.rects)
            var cat = perCategory[fixture.category] ?? (Tally(), Tally(), Tally(), 0, 0)

            for item in fixture.text {
                for box in item.rects {
                    textRecall.total += 1
                    cat.text.total += 1
                    let pieces = hits.filter { Self.area($0.box.intersection(box)) >= 0.15 * max(Self.area(box), 1) }
                    // All the text masks together must cover the whole box; how much of it they do cover is written down.
                    let cover = Self.unionCover(box, textBoxes)
                    let covered = cover >= Self.coveredShare
                    let byOne = Self.covers(box, by: textBoxes, share: Self.coveredShare)
                    if covered { textRecall.hit += 1; cat.text.hit += 1 }
                    else { missed.append(["id": id, "rule": item.rule ?? "?", "text": item.text ?? "", "box": [box.minX, box.minY, box.width, box.height]]) }
                    if Self.covers(box, by: textBoxes, share: Self.laxShare) { textLaxHit += 1 }
                    // Every hit apart, with the rule that hid it: a number called one thing in the truth
                    // may be hidden under another rule's name. That is the rule of the mask covering most of it.
                    let hider = hits.max { Self.area($0.box.intersection(box)) < Self.area($1.box.intersection(box)) }?.rule?.rawValue ?? "-"
                    items.append(["id": id, "rule": item.rule ?? "?", "text": item.text ?? "", "hit": covered,
                                  "cover": Self.rounded(cover), "by": hider])
                    // Caught only in pieces: digits may show between them.
                    if pieces.count >= 2 {
                        split.append(["id": id, "rule": item.rule ?? "?", "text": item.text ?? "", "pieces": pieces.count,
                                      "read": pieces.map(\.evidence).joined(separator: " | "),
                                      "covered": Self.rounded(Self.unionCover(box, pieces.map(\.box))), "by_one": byOne])
                    }
                    if let rule = item.rule {
                        var t = perRule[rule] ?? Tally()
                        t.total += 1
                        let sameRule = hits.filter { $0.rule?.rawValue == rule }.map(\.box)
                        if Self.unionCover(box, sameRule) >= Self.coveredShare { t.hit += 1 }
                        perRule[rule] = t
                    }
                }
            }
            for item in fixture.faces.items {
                for box in item.rects {
                    faceRecall.total += 1
                    cat.faces.total += 1
                    if Self.unionCover(box, faceBoxes) >= Self.coveredShare { faceRecall.hit += 1; cat.faces.hit += 1 }
                    else { missed.append(["id": id, "rule": "face", "text": "", "box": [box.minX, box.minY, box.width, box.height]]) }
                }
            }
            for item in fixture.codes {
                for box in item.rects {
                    codeRecall.total += 1
                    cat.codes.total += 1
                    if Self.unionCover(box, codeBoxes) >= Self.coveredShare { codeRecall.hit += 1; cat.codes.hit += 1 }
                    else { missed.append(["id": id, "rule": "code", "text": item.text ?? "", "box": [box.minX, box.minY, box.width, box.height]]) }
                }
            }
            for finding in hits {
                if Self.isTruePositive(finding.box, gt: gtBoxes) { textTrue += 1; cat.tp += 1 }
                else {
                    textFalse += 1
                    cat.fp += 1
                    falsePositives.append(["id": id, "rule": finding.rule?.rawValue ?? "?", "text": finding.evidence, "tolerant": finding.tolerant, "box": [finding.box.minX, finding.box.minY, finding.box.width, finding.box.height]])
                }
            }
            // 「所有文字都遮」 hides every line that was read, so that is what covers a name or an address.
            let everything = s.result.textLines.map { Geometry.bounds(of: $0.quad) } + faceBoxes + codeBoxes
            for item in fixture.shadow ?? [] {
                for box in item.rects {
                    shadowTotal += 1
                    let covered = Self.unionCover(box, everything) >= Self.coveredShare
                    if covered { shadowHit += 1 }
                    let near = s.result.textLines.filter { Self.area(Geometry.bounds(of: $0.quad).intersection(box)) > 0 }
                    shadowDetail.append(["id": id, "kind": item.kind ?? "?", "text": item.text ?? "", "covered": covered,
                                         "union": Self.rounded(Self.unionCover(box, everything)),
                                         "read": near.map(\.text)])
                }
            }
            perCategory[fixture.category] = cat
        }

        return [
            "images": perImage.count,
            "text_recall": Self.rounded(textRecall.value), "text_recall_hit": textRecall.hit, "text_recall_total": textRecall.total,
            "text_recall_lax_hit": textLaxHit, "covered_share": Double(coveredShare),
            "text_false_positive_rate": (textTrue + textFalse) > 0 ? Self.rounded(Double(textFalse) / Double(textTrue + textFalse)) : 0,
            "text_true": textTrue, "text_false": textFalse,
            "face_recall": Self.rounded(faceRecall.value), "face_recall_hit": faceRecall.hit, "face_recall_total": faceRecall.total,
            "code_recall": Self.rounded(codeRecall.value), "code_recall_hit": codeRecall.hit, "code_recall_total": codeRecall.total,
            "per_rule": perRule.mapValues { ["hit": $0.hit, "total": $0.total] },
            "per_category": perCategory.mapValues { ["text": Self.rounded($0.text.value), "faces": Self.rounded($0.faces.value), "codes": Self.rounded($0.codes.value), "fp": $0.fp, "tp": $0.tp] },
            "shadow_covered": shadowTotal > 0 ? Self.rounded(Double(shadowHit) / Double(shadowTotal)) : 0, "shadow_total": shadowTotal,
            "shadow_detail": shadowDetail, "items": items,
            "per_image": perImage, "false_positives": falsePositives, "missed": missed, "split": split,
        ]
    }
}
