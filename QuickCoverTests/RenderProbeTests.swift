import CoreGraphics
import Foundation
import ImageIO
import Testing
import Vision

@testable import QuickCover

/// Measures, judges nothing: what Vision still reads out of the frozen fixtures once the covers are
/// pressed in, by mosaic, blur and solid, next to the same picture exported without any cover.
/// Left out of the normal run; to measure, take the `.disabled` off and run
/// `--additional-options '-only-testing:QuickCoverTests/RenderProbeTests'`. The table comes out
/// between `===RENDER-PROBE===` and `===END===`.
struct RenderProbeTests {

    private final class BundleToken {}

    /// Where the fixtures were copied into the test bundle, found the way `BaselineTests` finds it.
    private static let fixtureDirectory: URL? = {
        let root = Bundle(for: BundleToken.self).bundleURL
        var found: URL?
        if let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator where url.pathExtension == "json" {
                if (try? JSONDecoder().decode(BaselineFixture.self, from: Data(contentsOf: url))) != nil {
                    found = url.deletingLastPathComponent()
                    break
                }
            }
        }
        return found
    }()

    /// What became of one truth value under one export.
    private enum Outcome: String {
        /// Vision read the whole value off the exported picture.
        case readable = "R"
        /// It read a run of six characters or more of it.
        case half = "H"
        case unreadable = "U"
    }

    private struct Line {
        let box: CGRect
        let text: String
    }

    /// The text without blanks, in the composed form Vision gives.
    private static func plain(_ s: String) -> String {
        String(s.precomposedStringWithCompatibilityMapping.unicodeScalars.filter { !$0.properties.isWhitespace })
    }

    /// The longest run of characters that both strings hold, one after the other.
    private static func longestSharedRun(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        var previous = [Int](repeating: 0, count: b.count + 1)
        var best = 0
        for x in a {
            var current = [Int](repeating: 0, count: b.count + 1)
            for (j, y) in b.enumerated() where x == y {
                current[j + 1] = previous[j] + 1
                best = max(best, current[j + 1])
            }
            previous = current
        }
        return best
    }

    /// How the truth fared: what Vision read on the lines lying over its boxes, in reading order.
    /// Readable is judged the way round that errs towards "it can be read": the whole value has to
    /// be in that text, which may hold more (a neighbouring line read as one with it).
    private static func outcome(of truth: String, over rects: [CGRect], in lines: [Line]) -> (Outcome, String) {
        let over = lines.filter { line in rects.contains { $0.intersects(line.box) } }
            .sorted { ($0.box.minY, $0.box.minX) < ($1.box.minY, $1.box.minX) }
        let read = plain(over.map(\.text).joined())
        let want = plain(truth)
        guard !want.isEmpty else { return (.unreadable, read) }
        if read.contains(want) { return (.readable, read) }
        return (longestSharedRun(want, read) >= 6 ? .half : .unreadable, read)
    }

    private static func cell(_ s: String) -> String {
        String(s.prefix(36))
    }

    @Test(.disabled("只量不判"))
    func whatVisionStillReadsUnderTheCovers() async throws {
        let directory = try #require(Self.fixtureDirectory, "the test bundle carries no fixtures")
        let fixtures: [(id: String, fixture: BaselineFixture)] = try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .map { (id: $0.deletingPathExtension().lastPathComponent,
                    fixture: try JSONDecoder().decode(BaselineFixture.self, from: Data(contentsOf: $0))) }
            .filter { !$0.fixture.text.isEmpty }
            .sorted { $0.id < $1.id }
        try #require(!fixtures.isEmpty, "no fixture carries text")

        // The way the editor and the export do it: a copy no longer than 2048 is read, the hits are
        // mapped to the picture's own pixels, and pressed in through the export's own way.
        let recognizer = Recognizer()
        // `Recognizer` keeps its request private; these are its settings.
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        let supported = Set(request.supportedRecognitionLanguages)
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"].map { Locale.Language(identifier: $0) }.filter(supported.contains)
        let styles: [MaskStyle] = [.mosaic, .blur, .solid]

        func read(_ source: PictureSource, findings: [Finding], style: MaskStyle?) async throws -> [Line] {
            // No style: the same export with nothing pressed in, to show what Vision reads at all.
            let file = try MaskRenderer.encode(source.source, orientation: source.orientation,
                                               findings: style == nil ? [] : findings, options: .init(style: style ?? .mosaic))
            let out = try #require(CGImageSourceCreateWithData(file as CFData, nil))
            let flat = try #require(CGImageSourceCreateImageAtIndex(out, 0, nil))
            let size = CGSize(width: flat.width, height: flat.height)
            return try await request.perform(on: flat, orientation: .up).map { line in
                let corners = [line.topLeft, line.topRight, line.bottomRight, line.bottomLeft]
                    .map { $0.toImageCoordinates(size, origin: .upperLeft) }
                return Line(box: Geometry.bounds(of: corners), text: line.transcript)
            }
        }

        var table = ["picture\trule\ttruth\tcovers\tnone\tmosaic\tblur\tsolid\tmosaic read\tblur read\tsolid read"]
        var counts: [MaskStyle: [Outcome: Int]] = [:]
        var covered: [MaskStyle: [Outcome: Int]] = [:]
        var uncovered: [Outcome: Int] = [:]
        var total = 0, touched = 0
        for (id, fixture) in fixtures {
            let source = try PictureSource(data: try Data(contentsOf: directory.appending(path: fixture.file)))
            guard let preview = source.thumbnail(maxLongSide: 2048) else { continue }
            let result = try await recognizer.recognize(preview)
            var scale = CGSize(width: source.size.width / max(result.size.width, 1),
                               height: source.size.height / max(result.size.height, 1))
            if result.size == .zero { scale = CGSize(width: 1, height: 1) }
            let findings = result.scaled(by: scale).findings
            let bare = try await read(source, findings: [], style: nil)
            var lines: [MaskStyle: [Line]] = [:]
            for style in styles { lines[style] = try await read(source, findings: findings, style: style) }

            for item in fixture.text {
                guard let truth = item.text, !truth.isEmpty, !item.rects.isEmpty else { continue }
                total += 1
                let rects = item.rects
                let covers = findings.filter { finding in rects.contains { $0.intersects(finding.box) } }.count
                if covers > 0 { touched += 1 }
                let bareRead = Self.outcome(of: truth, over: rects, in: bare)
                uncovered[bareRead.0, default: 0] += 1
                var row = [id, item.rule ?? "-", Self.cell(truth), String(covers), bareRead.0.rawValue]
                for style in styles {
                    let (outcome, read) = Self.outcome(of: truth, over: rects, in: lines[style] ?? [])
                    counts[style, default: [:]][outcome, default: 0] += 1
                    if covers > 0 { covered[style, default: [:]][outcome, default: 0] += 1 }
                    row.append(outcome.rawValue)
                }
                for style in styles { row.append(Self.cell(Self.outcome(of: truth, over: rects, in: lines[style] ?? []).1)) }
                table.append(row.joined(separator: "\t"))
            }
        }

        func line(_ name: String, _ c: [Outcome: Int]) -> String {
            "\(name)\t读得出 \(c[.readable, default: 0])\t读出一半 \(c[.half, default: 0])\t读不出 \(c[.unreadable, default: 0])"
        }
        var summary = ["全部 \(total) 个真值，\(fixtures.count) 张图；其中被遮盖压到 \(touched) 个"]
        summary.append("未遮（参考）\t读得出 \(uncovered[.readable, default: 0])\t读出一半 \(uncovered[.half, default: 0])\t读不出 \(uncovered[.unreadable, default: 0])")
        for style in styles { summary.append(line(style.rawValue, counts[style] ?? [:])) }
        summary.append("只算被遮盖压到的 \(touched) 个")
        for style in styles { summary.append(line(style.rawValue, covered[style] ?? [:])) }
        summary.append("R 读得出：整条真值都在盖后压到它框上的文字里；H 读出一半：有一段连续 ≥ 6 个字符被读到；U 读不出")
        let report = (table + [""] + summary).joined(separator: "\n")
        print("\n===RENDER-PROBE===\n" + report + "\n===END===")
        Attachment.record(report, named: "render-probe.tsv")
    }
}
