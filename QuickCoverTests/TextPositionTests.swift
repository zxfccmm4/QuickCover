import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import QuickCover

/// A rule usually matches part of a line, and its mask has to sit on the characters it matched.
/// Where they sit comes from Vision when it boxes them, and from character widths when it does
/// not. On the frozen baseline pictures the widths put the digits of an ID number 75 pixels to
/// the right of where they are printed, since on that card a digit is wider than the Chinese
/// label before it; Vision's own box is within a few pixels.
@Suite struct TextPositionTests {

    private final class Token {}
    private static let directory: URL = {
        var found: URL?
        let root = Bundle(for: Token.self).bundleURL
        if let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator where url.pathExtension == "json" {
                if (try? JSONDecoder().decode(BaselineFixture.self, from: Data(contentsOf: url))) != nil {
                    found = url.deletingLastPathComponent()
                    break
                }
            }
        }
        return found ?? root
    }()

    /// A number wide on its card, one after an English label, one in five groups with spaces,
    /// one after a Chinese label in a web page.
    private static let cases: [(picture: String, rule: String, text: String)] = [
        ("doc_01_idcard", "id", "310115199203084216"),
        ("chat_04_compressed", "ref", "A8821304567"),
        ("chat_02_group", "bank", "6222 0210 0110 8867 123"),
        ("web_01_log", "email", "ops@example.com"),
        ("plate_01_clear", "plate", "粤B8S6Q0"),
    ]

    @Test func maskSitsOnTheCharacters() async throws {
        let recognizer = Recognizer()
        for c in Self.cases {
            let fixture = try JSONDecoder().decode(BaselineFixture.self, from: Data(contentsOf: Self.directory.appending(path: c.picture + ".json")))
            let image = try #require(PictureSource(data: try Data(contentsOf: Self.directory.appending(path: fixture.file))).thumbnail(maxLongSide: 2048))
            let sx = CGFloat(image.width) / CGFloat(fixture.width), sy = CGFloat(image.height) / CGFloat(fixture.height)
            guard let item = fixture.text.first(where: { $0.text == c.text && $0.rule == c.rule }) else {
                Issue.record("\(c.picture) has no \(c.rule) '\(c.text)'")
                continue
            }
            let result = try await recognizer.recognize(image)
            let ofRule = result.findings.filter { $0.kind == .text && $0.rule?.rawValue == c.rule }
            // What a mask is named by is what Vision read, a plate's province character perhaps
            // in its older spelling, so a number is looked for in it but a plate is taken by its rule.
            let digits = c.text.filter { !$0.isWhitespace }
            var masks = ofRule.filter { $0.evidence.contains(digits) }.map(\.box)
            if masks.isEmpty { masks = ofRule.map(\.box) }
            #expect(!masks.isEmpty, "\(c.picture): no \(c.rule) mask for '\(c.text)'")
            for truth in item.rects {
                let box = CGRect(x: truth.minX * sx, y: truth.minY * sy, width: truth.width * sx, height: truth.height * sy)
                let cover = BaselineScore.unionCover(box, masks)
                #expect(cover >= BaselineScore.coveredShare,
                        "\(c.picture) '\(c.text)': masks cover \(Int(cover * 100)) % of the truth")
            }
        }
    }
}
