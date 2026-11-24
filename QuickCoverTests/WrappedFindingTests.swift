import CoreGraphics
import Foundation
import Testing

@testable import QuickCover

/// Addendum of 20:35: a value wrapped onto two lines is one item with two boxes, and what lies
/// between the two boxes on the picture is not the item's.
struct WrappedFindingTests {

    private func quad(_ rect: CGRect) -> [CGPoint] {
        [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
         CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)]
    }

    private let upper = CGRect(x: 10, y: 100, width: 100, height: 30)
    private let lower = CGRect(x: 10, y: 150, width: 50, height: 30)

    private var wrapped: Finding {
        Finding(kind: .text, rule: .bankCard, pieces: [quad(upper), quad(lower)], evidence: "6222 0210 0110 8867 123")
    }

    @Test func twoPiecesAreOneItem() {
        let f = wrapped
        #expect(f.quads == [quad(upper), quad(lower)])
        #expect(f.quad == quad(upper))
        #expect(f.parts == [quad(lower)])
        #expect(f.boxes == [upper, lower])
        // The bounds of both: what lies between them included.
        #expect(f.box == CGRect(x: 10, y: 100, width: 100, height: 80))
        // The line the item stands on: the first piece alone.
        #expect(f.lineBox == upper)
        #expect(f.rule == .bankCard && f.kind == .text && f.evidence == "6222 0210 0110 8867 123")
    }

    @Test func scalingCarriesEveryPiece() {
        let g = wrapped.scaled(by: CGSize(width: 2, height: 3))
        #expect(g.quads == [quad(CGRect(x: 20, y: 300, width: 200, height: 90)), quad(CGRect(x: 20, y: 450, width: 100, height: 90))])
        #expect(g.boxes == [CGRect(x: 20, y: 300, width: 200, height: 90), CGRect(x: 20, y: 450, width: 100, height: 90)])
        #expect(g.box == CGRect(x: 20, y: 300, width: 200, height: 240))
        #expect(g.rule == .bankCard)
    }

    @Test func labellingCarriesEveryPiece() {
        // A number cut across two lines is named by its whole length.
        let g = wrapped.labelled(.phone)
        #expect(g.rule == .phone)
        #expect(g.quad == quad(upper))
        #expect(g.parts == [quad(lower)])
        #expect(g.boxes == [upper, lower])
        #expect(g.box == wrapped.box)
    }

    @Test func oneBoxHasNoParts() {
        let f = Finding(kind: .text, rule: .url, quad: quad(upper), evidence: "https://a.cn")
        #expect(f.parts.isEmpty)
        #expect(f.quads == [quad(upper)])
        #expect(f.boxes == [upper])
        #expect(f.box == upper && f.lineBox == upper)
        let face = Finding(kind: .face, quad: quad(lower))
        #expect(face.parts.isEmpty && face.quads.count == 1 && face.boxes == [lower])
    }
}

/// Addendum of 20:35, test 4: what lies between the two pieces of a wrapped value is neither
/// covered by the finding nor a false positive of its own.
struct WrappedScoreTests {

    private func quad(_ rect: CGRect) -> [CGPoint] {
        [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
         CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)]
    }

    /// A chat bubble: 「电话 150」 over 「9122 3047」, the phone cut after 150.
    private let upper = CGRect(x: 50, y: 100, width: 90, height: 30)
    private let lower = CGRect(x: 50, y: 150, width: 80, height: 30)

    private func score(text: String, findings: [Finding]) throws -> [String: Any] {
        let fixture = try JSONDecoder().decode(BaselineFixture.self, from: Data("""
        {"id": "wrapped", "file": "wrapped.png", "category": "chat", "variant": "plain",
         "width": 600, "height": 300, "text": \(text), "faces": [], "codes": []}
        """.utf8))
        let result = RecognitionResult(size: CGSize(width: 600, height: 300), findings: findings, textLines: [])
        return BaselineScore.score([BaselineSeen(fixture: fixture, result: result, milliseconds: 0)])
    }

    private var finding: Finding {
        Finding(kind: .text, rule: .phone, pieces: [quad(upper), quad(lower)], evidence: "150 9122 3047")
    }

    @Test func controlSpanBetweenThePiecesIsNotAFalsePositive() throws {
        // The truth is the phone in its two boxes. Between them, to the right of the second line,
        // a harmless word stands that no piece reaches: the finding is one true hit and no false one.
        let report = try score(text: #"[{"rule": "phone", "text": "15091223047", "boxes": [[50, 100, 90, 30], [50, 150, 80, 30]]}]"#, findings: [finding])
        #expect(report["text_recall_total"] as? Int == 2)
        #expect(report["text_recall_hit"] as? Int == 2)
        #expect(report["text_true"] as? Int == 1)
        #expect(report["text_false"] as? Int == 0)
        #expect((report["false_positives"] as? [[String: Any]])?.isEmpty == true)
        #expect(report["text_recall"] as? Double == 1)
    }

    @Test func spanBetweenThePiecesDoesNotCountAsCovered() throws {
        // Something else to hide that lies between the two pieces, under the finding's bounds but
        // under neither piece: it is missed, not covered by the span between the pieces.
        let report = try score(
            text: #"[{"rule": "phone", "text": "15091223047", "boxes": [[50, 100, 90, 30], [50, 150, 80, 30]]}, {"rule": "name", "text": "王芳", "box": [60, 125, 40, 20]}]"#,
            findings: [finding])
        #expect(report["text_recall_total"] as? Int == 3)
        #expect(report["text_recall_hit"] as? Int == 2)
        #expect((report["missed"] as? [[String: Any]])?.count == 1)
        #expect((report["missed"] as? [[String: Any]])?.first?["text"] as? String == "王芳")
    }

    @Test func boundsThatHoldTheTruthDoNotMakeThePiecesTrue() throws {
        // Something to hide that lies between the two pieces, under the finding's bounds but under
        // neither piece: the finding hides none of it, so it is a false hit, and the truth is missed.
        let report = try score(text: #"[{"rule": "name", "text": "王芳", "box": [60, 132, 40, 16]}]"#, findings: [finding])
        #expect(report["text_recall_total"] as? Int == 1)
        #expect(report["text_recall_hit"] as? Int == 0)
        #expect((report["missed"] as? [[String: Any]])?.count == 1)
        #expect(report["text_true"] as? Int == 0)
        #expect(report["text_false"] as? Int == 1)
        #expect((report["false_positives"] as? [[String: Any]])?.count == 1)
    }
}
