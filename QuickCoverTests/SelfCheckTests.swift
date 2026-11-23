#if SELF_CHECK
import Foundation
import ImageIO
import Testing
@testable import QuickCover

/// The self-check page's own steps, run here where they can be watched. The fixtures in the test
/// bundle stand in for the folder the self-check package carries, and the big picture is made and
/// run exactly as on a phone; what a phone adds is codes, real timings and the memory limit.
private final class Token {}

@Suite struct SelfCheckTests {

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

    @Test func fixturesReport() async throws {
        let fixtures = try SelfCheck.fixtures(in: SelfCheckTests.directory)
        #expect(fixtures.count == 30)
        var seen: [BaselineSeen] = []
        for fixture in fixtures {
            seen.append(try await SelfCheck.measure(fixture, in: SelfCheckTests.directory))
        }
        let report = BaselineScore.score(seen)
        let text = SelfCheckText.fixtures(report)
        print("===SELFCHECK-TEXT===\n\(text)\n===SELFCHECK-END===")
        let hit = report["text_recall_hit"] as? Int ?? 0
        let total = report["text_recall_total"] as? Int ?? 0
        #expect(total == 82, "the truth has 82 text items")
        #expect(hit >= 77, "run 5 on the simulator read \(hit)/\(total); lower is a regression")
        #expect(text.contains("人脸") && text.contains("漏遮") && text.contains("手机号"))
    }

    @Test func largePictureReport() async throws {
        let data = try SelfCheck.makeLargePicture()
        let source = try PictureSource(data: data)
        #expect(source.size == CGSize(width: 8064, height: 6048))
        let peak = PeakMemory()
        let steps = try await SelfCheck.runLargePicture(data, peak: peak)
        #expect(steps.map(\.name) == ["preview", "recognition", "export", "file"])
        let text = SelfCheckText.largePicture(steps, peak: peak.value)
        print("===SELFCHECK-48MP===\n\(text)\n===SELFCHECK-END===")
        #expect(text.contains("没有闪退"))
    }
}
#endif
