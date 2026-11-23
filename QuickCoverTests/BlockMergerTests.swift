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
}
