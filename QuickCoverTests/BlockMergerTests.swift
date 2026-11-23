import CoreGraphics
import Foundation
import Testing

@testable import QuickCover

/// Brief §6: one checklist item is one block on the picture. Hits that sit close together on one
/// line are one block, so nothing shows between them; hits further apart stay two items.
struct BlockMergerTests {

    private func hit(_ x: CGFloat, _ text: String, rule: TextRule = .phone, y: CGFloat = 100, width: CGFloat = 120) -> Finding {
        Finding(kind: .text, rule: rule, quad: [
            CGPoint(x: x, y: y), CGPoint(x: x + width, y: y),
            CGPoint(x: x + width, y: y + 30), CGPoint(x: x, y: y + 30),
        ], evidence: text)
    }

    private func face(_ y: CGFloat) -> Finding {
        Finding(kind: .face, quad: [
            CGPoint(x: 0, y: y), CGPoint(x: 80, y: y), CGPoint(x: 80, y: y + 90), CGPoint(x: 0, y: y + 90),
        ])
    }

    @Test
    func closeHitsAreOneBlock() {
        // 15 px apart on one line: half a line height.
        let out = BlockMerger.merge([hit(100, "13800138000"), hit(235, "1101011990", rule: .idNumber)])
        #expect(out.count == 1)
        #expect(out[0].kind == .text)
        #expect(out[0].box.minX == 100 && out[0].box.maxX == 355 && out[0].box.height == 30)
        #expect(out[0].evidence == "13800138000 1101011990")
        // Two kinds of thing in one block: the checklist calls it text.
        #expect(out[0].rule == nil)
    }

    @Test
    func sameKindKeepsItsName() {
        let out = BlockMerger.merge([hit(100, "13800138000"), hit(228, "13900139000")])
        #expect(out.count == 1)
        #expect(out[0].rule == .phone)
    }

    @Test
    func farApartStayTwoItems() {
        // 70 px apart: more than two line heights.
        let out = BlockMerger.merge([hit(100, "13800138000"), hit(290, "13900139000")])
        #expect(out.count == 2)
        #expect(out.map(\.evidence) == ["13800138000", "13900139000"])
    }

    @Test
    func otherLinesAreLeftAlone() {
        // Same column of the page, the line below.
        let out = BlockMerger.merge([hit(100, "13800138000"), hit(228, "13900139000", y: 140)])
        #expect(out.count == 2)
    }

    @Test
    func aChainIsOneBlock() {
        let out = BlockMerger.merge([hit(100, "13800138000"), hit(228, "13900139000"), hit(350, "a@b.cn", rule: .email)])
        #expect(out.count == 1)
        #expect(out[0].box.minX == 100 && out[0].box.maxX == 470)
        #expect(out[0].evidence == "13800138000 13900139000 a@b.cn")
    }

    @Test
    func facesCodesAndOrderStay() {
        let a = hit(100, "13800138000"), b = hit(235, "1101011990", rule: .idNumber)
        let f = face(300)
        let out = BlockMerger.merge([f, a, b])
        #expect(out.count == 2)
        #expect(out[0].kind == .face)
        #expect(out[1].kind == .text && out[1].box.maxX == 355)
        #expect(BlockMerger.merge([a, b], options: .off).count == 2)
    }

    @Test
    func joinedWhateverTheirOrder() {
        let a = hit(100, "13800138000"), b = hit(235, "1101011990", rule: .idNumber)
        let groups = BlockMerger.groups([b, a])
        #expect(groups.count == 1)
        let block = BlockMerger.block(groups[0])
        #expect(block.evidence == "13800138000 1101011990")
        #expect(block.quad.map(\.x) == [100, 355, 355, 100])
    }

    private func quad(_ rect: CGRect) -> [CGPoint] {
        [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
         CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)]
    }

    /// A card a wrap cut: 「6222 0210」 on one line, 「0110 8867 123」 under it, one item.
    private func wrappedCard() -> (finding: Finding, upper: [CGPoint], lower: [CGPoint]) {
        let upper = quad(CGRect(x: 10, y: 100, width: 100, height: 30))
        let lower = quad(CGRect(x: 300, y: 150, width: 50, height: 30))
        let finding = Finding(kind: .text, rule: .bankCard, pieces: [upper, lower], evidence: "6222 0210 0110 8867 123")
        return (finding, upper, lower)
    }

    @Test
    func wrappedValueKeepsItsOtherLineWhenJoined() {
        // Beside the first line of the card a URL stands, close enough to join: the block is the
        // two boxes on that line, and the card's second line rides along as a part.
        let (card, _, lower) = wrappedCard()
        let url = Finding(kind: .text, rule: .url, quad: quad(CGRect(x: 115, y: 100, width: 60, height: 30)), evidence: "https://a.cn")
        for out in [BlockMerger.merge([card, url]), BlockMerger.merge([url, card])] {
            #expect(out.count == 1)
            #expect(out[0].quad == [CGPoint(x: 10, y: 100), CGPoint(x: 175, y: 100), CGPoint(x: 175, y: 130), CGPoint(x: 10, y: 130)])
            #expect(out[0].parts == [lower])
            #expect(out[0].boxes.count == 2)
            #expect(out[0].box == CGRect(x: 10, y: 100, width: 340, height: 80))
            // Two kinds of thing in one block: the checklist calls it text.
            #expect(out[0].rule == nil)
            #expect(out[0].evidence.split(separator: " ").count == 6)
        }
    }

    @Test
    func linesDoNotJoinThroughAUnionBox() {
        // Beside the card's second line a phone stands, close to that line. It is not on the
        // card's first line, so it does not join, although the card's bounds reach down to it.
        let (card, _, _) = wrappedCard()
        let phone = Finding(kind: .text, rule: .phone, quad: quad(CGRect(x: 370, y: 150, width: 60, height: 30)), evidence: "13800138000")
        let out = BlockMerger.merge([card, phone])
        #expect(out.count == 2)
        #expect(out.contains(card) && out.contains(phone))
    }
}
