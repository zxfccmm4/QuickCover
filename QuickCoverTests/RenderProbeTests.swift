import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
import Vision

@testable import QuickCover

/// Measures, judges nothing: what Vision still reads out of the frozen fixtures once the covers are
/// pressed in, by mosaic, blur and solid, next to the same picture exported without any cover.
/// Left out of the normal run; to measure, take the `.disabled` off and run
/// `--additional-options '-only-testing:QuickCoverTests/RenderProbeTests'`. The table comes out
/// between `===RENDER-PROBE===` and `===END===`.
///
/// Besides the shipped blur it reads a ladder of other blur grains (`ladder`), lighter and heavier,
/// and tells of every truth the longest run of its characters that came out one after the other.
///
/// For looking at the blur with the eye, patches of the blurred pictures come out as PNG in
/// base64, between `===PROBE-IMAGE blur-… begin` and `end`.
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

    /// The other blur grains read besides the shipped one, the lighter first: the ladder the shipped
    /// one was picked off by measurement.
    private static let ladder: [MaskRenderer.BlurGrain] = [
        .init(divisor: 8, floor: 10), .init(divisor: 6, floor: 12), .init(divisor: 5, floor: 14),
        .init(divisor: 4, floor: 16), .init(divisor: 4, floor: 20), .init(divisor: 3, floor: 20),
        .init(divisor: 3, floor: 24), .init(divisor: 2, floor: 24), .init(divisor: 2, floor: 32),
    ].filter { $0 != .default }

    /// The patches that come out as pictures: which truth of which picture to put in the middle.
    private static let patches: [(picture: String, rule: String)] = [
        ("chat_02_group", "email"), ("chat_02_group", "url"), ("doc_01_idcard", "id"),
    ]
    private static let patchSize = CGSize(width: 900, height: 420)

    /// What became of one truth value under one way of exporting.
    private enum Outcome: String {
        /// Vision read the whole value off the exported picture.
        case readable = "R"
        /// It read a run of six characters or more of it.
        case half = "H"
        case unreadable = "U"
    }

    private struct Verdict {
        let outcome: Outcome
        /// What Vision read on the lines lying over the truth's boxes.
        let read: String
        /// The longest run of the truth's characters, blanks left out, that came out one after the other.
        let run: Int
    }

    /// One way of exporting the picture that is measured: a style, and for the blur its grain.
    private struct Series {
        /// `nil`: the same export with nothing pressed in, to show what Vision reads at all.
        let style: MaskStyle?
        /// The blur's grain when it is not the shipped one.
        let grain: MaskRenderer.BlurGrain?

        var name: String {
            guard let style else { return "none" }
            guard let grain else { return style.rawValue }
            return "blur(" + String(format: "%g:%g", grain.divisor, grain.floor) + ")"
        }
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
    private static func verdict(on truth: String, rects: [CGRect], in lines: [Line]) -> Verdict {
        let over = lines.filter { line in rects.contains { $0.intersects(line.box) } }
            .sorted { ($0.box.minY, $0.box.minX) < ($1.box.minY, $1.box.minX) }
        let read = plain(over.map(\.text).joined())
        let want = plain(truth)
        guard !want.isEmpty else { return Verdict(outcome: .unreadable, read: read, run: 0) }
        let run = longestSharedRun(want, read)
        let outcome: Outcome = read.contains(want) ? .readable : (run >= 6 ? .half : .unreadable)
        return Verdict(outcome: outcome, read: read, run: run)
    }

    private static func cell(_ s: String) -> String {
        String(s.prefix(36))
    }

    /// The part of `image` inside `rect` (top-left pixels), as a picture of its own.
    private static func crop(_ image: CGImage, to rect: CGRect) -> CGImage? {
        let width = Int(rect.width.rounded()), height = Int(rect.height.rounded())
        guard let context = CGImage.rgbaContext(width: width, height: height) else { return nil }
        // A bitmap's first row is its top (the way `flatten` reads its pixels), so the picture's top
        // is `height - image.height` above the canvas's bottom; the slide puts `rect`'s top-left
        // corner there. Whole pixels only, so nothing is resampled.
        context.translateBy(x: -rect.minX.rounded(), y: CGFloat(height - image.height) + rect.minY.rounded())
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()
    }

    private static func png(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    /// `size` around the middle of `around`, kept inside the picture.
    private static func patch(around around: CGRect, size: CGSize, in picture: CGSize) -> CGRect {
        let x = around.midX - size.width / 2, y = around.midY - size.height / 2
        return CGRect(x: min(max(0, x), picture.width - size.width).rounded(),
                      y: min(max(0, y), picture.height - size.height).rounded(),
                      width: size.width, height: size.height)
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
        let shipped: [Series] = [.init(style: nil, grain: nil), .init(style: .mosaic, grain: nil),
                                 .init(style: .blur, grain: nil), .init(style: .solid, grain: nil)]
        let series = shipped + Self.ladder.map { Series(style: .blur, grain: $0) }

        func read(_ source: PictureSource, findings: [Finding], series: Series) async throws -> (lines: [Line], flat: CGImage) {
            var options = MaskRenderer.Options()
            options.style = series.style ?? .mosaic
            if let grain = series.grain { options.blurGrain = grain }
            let file = try MaskRenderer.encode(source.source, orientation: source.orientation,
                                               findings: series.style == nil ? [] : findings, options: options)
            let out = try #require(CGImageSourceCreateWithData(file as CFData, nil))
            let flat = try #require(CGImageSourceCreateImageAtIndex(out, 0, nil))
            let size = CGSize(width: flat.width, height: flat.height)
            let lines = try await request.perform(on: flat, orientation: .up).map { line in
                let corners = [line.topLeft, line.topRight, line.bottomRight, line.bottomLeft]
                    .map { $0.toImageCoordinates(size, origin: .upperLeft) }
                return Line(box: Geometry.bounds(of: corners), text: line.transcript)
            }
            return (lines, flat)
        }

        /// What became of every truth value under every way of exporting, in the order of `series`.
        var verdicts: [[(picture: String, rule: String, truth: String, verdict: Verdict, covered: Bool)]] = series.map { _ in [] }
        var table = ["picture\trule\ttruth\tcovers\t" + series.map { $0.name + " 读/连续" }.joined(separator: "\t")]
        var reads = ["picture\trule\ttruth\t" + series.map { $0.name + " 读到" }.joined(separator: "\t")]
        var blurred: [String: (CGImage, CGRect)] = [:]
        for (id, fixture) in fixtures {
            let source = try PictureSource(data: try Data(contentsOf: directory.appending(path: fixture.file)))
            guard let preview = source.thumbnail(maxLongSide: 2048) else { continue }
            let result = try await recognizer.recognize(preview)
            var scale = CGSize(width: source.size.width / max(result.size.width, 1),
                               height: source.size.height / max(result.size.height, 1))
            if result.size == .zero { scale = CGSize(width: 1, height: 1) }
            let findings = result.scaled(by: scale).findings
            var lines: [[Line]] = []
            // The shipped blur of a picture with a patch in it is kept for the patches.
            let keys = Self.patches.filter { $0.picture == id }.map { "\($0.picture)-\($0.rule)" }
            for way in series {
                let (readLines, flat) = try await read(source, findings: findings, series: way)
                lines.append(readLines)
                if way.style == .blur, way.grain == nil { for key in keys { blurred[key] = (flat, .null) } }
            }
            for item in fixture.text {
                guard let truth = item.text, !truth.isEmpty, !item.rects.isEmpty else { continue }
                let rects = item.rects
                let covers = findings.filter { finding in rects.contains { $0.intersects(finding.box) } }.count
                var row = [id, item.rule ?? "-", Self.cell(truth), String(covers)]
                var readRow = [id, item.rule ?? "-", Self.cell(truth)]
                for (index, way) in series.enumerated() {
                    let verdict = Self.verdict(on: truth, rects: rects, in: lines[index])
                    verdicts[index].append((id, item.rule ?? "-", truth, verdict, covers > 0))
                    row.append("\(verdict.outcome.rawValue)/\(verdict.run)")
                    readRow.append(Self.cell(verdict.read))
                }
                table.append(row.joined(separator: "\t"))
                reads.append(readRow.joined(separator: "\t"))
                if let key = keys.first(where: { $0 == "\(id)-\(item.rule ?? "")" }), let kept = blurred[key] {
                    blurred[key] = (kept.0, rects.reduce(kept.1) { $0.union($1) })
                }
            }
        }

        func summary(_ way: Series, _ all: [(picture: String, rule: String, truth: String, verdict: Verdict, covered: Bool)]) -> String {
            let runs = all.map(\.verdict.run)
            var histogram = [Int](repeating: 0, count: 7)
            for run in runs { histogram[min(run, 6)] += 1 }
            let count = { (outcome: Outcome) in all.filter { $0.verdict.outcome == outcome }.count }
            return "\(way.name)\t读得出 \(count(.readable))\t读出一半 \(count(.half))\t读不出 \(count(.unreadable))\t最长连续 \(runs.max() ?? 0)\t连续 0 1 2 3 4 5 ≥6: \(histogram.map(String.init).joined(separator: " "))"
        }
        let total = verdicts.first?.count ?? 0
        let coveredCount = verdicts.first?.filter { $0.covered }.count ?? 0
        var out = ["全部 \(total) 个真值，\(fixtures.count) 张图；其中被遮盖压到 \(coveredCount) 个", ""] + table + [""]
        out.append("汇总（全部 \(total) 个）")
        for (index, way) in series.enumerated() { out.append(summary(way, verdicts[index])) }
        out.append("汇总（只算被遮盖压到的 \(coveredCount) 个）")
        for (index, way) in series.enumerated() { out.append(summary(way, verdicts[index].filter { $0.covered })) }
        out.append("读得出：整条真值都在盖后压到它框上的文字里；读出一半：有一段连续 ≥ 6 个字符被读到；连续：按真值去空格后逐位对，被读出的最长一段")
        out.append("读到连续 3 个字符及以上的：")
        for (index, way) in series.enumerated() where way.style != nil {
            for entry in verdicts[index] where entry.verdict.run >= 3 {
                out.append("\(way.name)\t\(entry.picture) \(entry.rule) \(entry.truth)\t连续 \(entry.verdict.run)\t读到 \(entry.verdict.read)")
            }
        }
        out.append("盖后各条读到的文字：")
        out.append(contentsOf: reads)
        let report = out.joined(separator: "\n")
        print("\n===RENDER-PROBE===\n" + report + "\n===END===")
        Attachment.record(report, named: "render-probe.tsv")

        for (name, kept) in blurred.sorted(by: { $0.key < $1.key }) {
            guard !kept.1.isNull else { continue }
            let rect = Self.patch(around: kept.1, size: Self.patchSize,
                                  in: CGSize(width: kept.0.width, height: kept.0.height))
            guard let image = Self.crop(kept.0, to: rect), let file = Self.png(image) else { continue }
            let base64 = file.base64EncodedString()
            print("===PROBE-IMAGE blur-\(name) begin\t\(rect)\t\(image.width)×\(image.height)\t\(file.count) bytes")
            let chars = Array(base64)
            for start in stride(from: 0, to: chars.count, by: 120) {
                print(String(chars[start..<min(start + 120, chars.count)]))
            }
            print("===PROBE-IMAGE blur-\(name) end")
        }
    }
}
