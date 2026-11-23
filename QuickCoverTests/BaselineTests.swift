import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import QuickCover

/// The ground truth of one fixture, in the shape `tools/baseline/FIXTURES.md` defines.
/// Boxes are `[x, y, w, h]` in the picture's pixels, top-left origin.
private final class BundleToken {}

/// Brief §9.2: what the phone's built-in recognition finds on the 30 fake pictures, measured
/// against the ground truth, before any rule is tuned for it. Skipped in the normal test run
/// (`runtest <id> --script baseline` runs it alone). The rules as they stand are counted by
/// `BaselineScore`, the same measure the self-check page runs on a phone.
///
/// On top of that the report has two parts. The pairs of hits that sit side by side on one line,
/// with what lies between them, which is what decides how close is "close" when hits are joined
/// into one block. And the numbers again at each joining width.
struct BaselineTests {

    private static func isWide(_ s: Unicode.Scalar) -> Bool {
        switch s.value {
        case 0x1100...0x115F, 0x2E80...0xA4CF, 0xAC00...0xD7A3, 0xF900...0xFAFF, 0xFE30...0xFE4F,
             0xFF00...0xFF60, 0xFFE0...0xFFE6: true
        default: false
        }
    }

    /// What is written between two x positions of the line they lie on, estimated from character
    /// widths: a Chinese character is about as wide as the line is tall, the rest about half.
    private static func textBetween(_ x1: CGFloat, and x2: CGFloat, in lines: [TextLine]) -> String {
        var best: (TextLine, CGFloat)?
        for line in lines {
            let box = Geometry.bounds(of: line.quad)
            guard box.width > 0, box.minX <= x1, x2 <= box.maxX else { continue }
            let span = box.width - (x2 - x1)
            if best.map({ span < $0.1 }) ?? true { best = (line, span) }
        }
        guard let best else { return "?" }
        let line = best.0
        let box = Geometry.bounds(of: line.quad)
        // The line's box carries its padding; the characters sit inside it.
        let inner: CGFloat = (box.height - 2) / 1.3 >= 13.3 ? (box.height - 2) / 1.3 : box.height - 6
        let pad = (box.height - inner) / 2
        let scalars = Array(line.text.unicodeScalars)
        let weights = scalars.map { s -> CGFloat in s == " " ? 0.3 : (isWide(s) ? 1 : 0.55) }
        let total = weights.reduce(0, +)
        guard total > 0 else { return "" }
        var out = ""
        var x = box.minX + pad
        for (s, w) in zip(scalars, weights) {
            let width = (box.width - 2 * pad) * w / total
            let mid = x + width / 2
            if mid > x1 && mid < x2 { out.unicodeScalars.append(s) }
            x += width
        }
        return out
    }

    @Test
    func baseline() async throws {
        let ids = Self.fixtureIDs()
        try #require(!ids.isEmpty, "no fixtures in the test bundle")
        var seen: [BaselineSeen] = []

        // Recognition as the rules give it, every hit apart. Joining hits into blocks comes after.
        let recognizer = Recognizer(options: .init(mergeGapEm: 0))
        for id in ids {
            let fixture = try Self.fixture(id)
            let source = try PictureSource(data: try Self.data(fixture.file))
            let thumb = try #require(source.thumbnail(maxLongSide: 2048))
            let clock = ContinuousClock()
            let start = clock.now
            let result = try await recognizer.recognize(thumb)
            let elapsed = start.duration(to: clock.now).components
            let ms = Double(elapsed.seconds) * 1000 + Double(elapsed.attoseconds) / 1e15
            let scale = CGSize(width: CGFloat(fixture.width) / result.size.width, height: CGFloat(fixture.height) / result.size.height)
            let scaled = result.scaled(by: scale)
            seen.append(BaselineSeen(fixture: fixture, result: scaled, milliseconds: ms))
        }
        // 1. The rules, every hit apart.
        var report = BaselineScore.score(seen)
        // 2. Hits that sit side by side on one line, nearest first, and what lies between them.
        var pairs: [(em: Double, row: [String: Any])] = []
        var apart = 0
        for s in seen {
            let hits = s.result.findings.filter { $0.kind == .text }.sorted { $0.box.minX < $1.box.minX }
            apart += hits.count
            let gt = s.fixture.text.flatMap(\.rects)
            let shadow = (s.fixture.shadow ?? []).flatMap(\.rects)
            let anyDistance = BlockMerger.Options(maxGapEm: .greatestFiniteMagnitude)
            for (index, a) in hits.enumerated() {
                var nearest: (Finding, CGFloat)?
                for b in hits.dropFirst(index + 1) where b.box.minX >= a.box.maxX {
                    if let gap = BlockMerger.joinGap(a.box, b.box, anyDistance), nearest.map({ gap < $0.1 }) ?? true {
                        nearest = (b, gap)
                    }
                }
                guard let nearest else { continue }
                let b = nearest.0
                let gap = nearest.1
                let em = (a.box.height + b.box.height) / 2
                let strip = CGRect(x: a.box.maxX, y: min(a.box.minY, b.box.minY), width: gap, height: max(a.box.maxY, b.box.maxY) - min(a.box.minY, b.box.minY))
                let sensitive = gt.contains { BaselineScore.area($0.intersection(strip)) > 0 }
                pairs.append((BaselineScore.rounded(gap / em, 100), [
                    "id": s.fixture.id, "em": BaselineScore.rounded(gap / em, 100), "gap": BaselineScore.rounded(gap), "px_height": BaselineScore.rounded(em),
                    "a": "\(a.rule?.rawValue ?? "?"):\(a.evidence)", "b": "\(b.rule?.rawValue ?? "?"):\(b.evidence)",
                    "between": gap > 0 ? Self.textBetween(a.box.maxX, and: b.box.minX, in: s.result.textLines) : "",
                    "sensitive_between": sensitive,
                    "shadow_between": shadow.contains { BaselineScore.area($0.intersection(strip)) > 0 },
                ]))
            }
        }
        pairs.sort { $0.em < $1.em }
        let pairRows = pairs.map(\.row)

        // 3. The same pictures with hits joined into blocks, at each width.
        var sweep: [[String: Any]] = []
        let widths: [CGFloat] = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 2, 2.5, 3]
        for em in widths {
            let options = BlockMerger.Options(maxGapEm: em)
            var recall = BaselineScore.Tally(), tp = 0, fp = 0, blocks = 0
            var onGT: CGFloat = 0, offGT: CGFloat = 0
            var covered = 0, total = 0
            for s in seen {
                let boxes = BlockMerger.groups(s.result.findings, options: options).map { BlockMerger.block($0).box }
                let gt = s.fixture.text.flatMap(\.rects)
                blocks += boxes.count
                for item in s.fixture.text {
                    for box in item.rects {
                        recall.total += 1
                        if BaselineScore.covers(box, by: boxes, share: 0.6) { recall.hit += 1 }
                    }
                }
                for box in boxes {
                    let share = BaselineScore.unionCover(box, gt)
                    onGT += BaselineScore.area(box) * share
                    offGT += BaselineScore.area(box) * (1 - share)
                    if BaselineScore.isTruePositive(box, gt: gt) { tp += 1 } else { fp += 1 }
                }
                for item in s.fixture.shadow ?? [] {
                    for box in item.rects where BaselineScore.covers(box, by: boxes, share: 0.5) { covered += 1 }
                    total += item.rects.count
                }
            }
            sweep.append([
                "em": em, "text_recall": BaselineScore.rounded(recall.value), "hit": recall.hit, "total": recall.total,
                "fp_rate": (tp + fp) > 0 ? BaselineScore.rounded(Double(fp) / Double(tp + fp)) : 0, "fp": fp, "tp": tp,
                "blocks": blocks, "joined": apart - blocks,
                "area_on_gt": BaselineScore.rounded(onGT / 1000), "area_off_gt_kpx2": BaselineScore.rounded(offGT / 1000),
                "shadow_covered": covered, "shadow_total": total,
            ])
        }
        report["adjacent_pairs"] = pairRows
        report["join_sweep"] = sweep
        let json = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        print("\n===BASELINE-JSON===\n" + String(decoding: json, as: UTF8.self) + "\n===END===")
        Attachment.record(json, named: "baseline-report.json")
        func count(_ key: String) -> Int { report[key] as? Int ?? 0 }
        print("===BASELINE-SUMMARY=== images=\(count("images")) textRecall=\(count("text_recall_hit"))/\(count("text_recall_total")) (lax60=\(count("text_recall_lax_hit"))) textFP=\(count("text_false"))/\(count("text_true") + count("text_false")) faceRecall=\(count("face_recall_hit"))/\(count("face_recall_total")) codeRecall=\(count("code_recall_hit"))/\(count("code_recall_total")) split=\((report["split"] as? [[String: Any]])?.count ?? 0) pairs=\(pairs.count) ===")
        #expect(count("text_recall_total") + count("face_recall_total") + count("code_recall_total") > 0, "ground truth is empty")
    }

    private static let fixtureDirectory: URL? = {
        let root = Bundle(for: BundleToken.self).bundleURL
        var found: URL?
        if let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator where url.pathExtension == "json" {
                if (try? fixture(at: url)) != nil { found = url.deletingLastPathComponent(); break }
            }
        }
        if found == nil {
            // Say what the bundle holds, so a copying problem is visible in the log.
            var names: [String] = []
            if let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) {
                for case let url as URL in enumerator { names.append(url.path) }
            }
            FileHandle.standardError.write(Data("no fixture json in \(root.path); bundle holds:\n\(names.joined(separator: "\n"))\n".utf8))
        }
        return found
    }()

    /// Every ground-truth `*.json` next to the pictures, in name order.
    private static func fixtureIDs() -> [String] {
        guard let directory = fixtureDirectory,
              let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return [] }
        return files
            .filter { $0.pathExtension == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .filter { id in (try? fixture(id)) != nil }
            .sorted()
    }

    private static func data(_ name: String) throws -> Data {
        let directory = try #require(fixtureDirectory, "the test bundle carries no fixtures")
        return try Data(contentsOf: directory.appending(path: name))
    }

    private static func fixture(at url: URL) throws -> BaselineFixture {
        try JSONDecoder().decode(BaselineFixture.self, from: try Data(contentsOf: url))
    }

    private static func fixture(_ id: String) throws -> BaselineFixture {
        let directory = try #require(fixtureDirectory, "the test bundle carries no fixtures")
        return try fixture(at: directory.appending(path: id + ".json"))
    }
}
