import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import QuickCover

/// What the editor knows for Review Each Item: what was found, QR or barcode, the fixed order of
/// the rows, numbering, and starting over.
struct EditorModelChecklistTests {

    private func quad(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> [CGPoint] {
        [CGPoint(x: x, y: y), CGPoint(x: x + w, y: y), CGPoint(x: x + w, y: y + h), CGPoint(x: x, y: y + h)]
    }

    @MainActor
    private func makeModel() throws -> EditorModel {
        let source = try PictureSource(data: Sample.jpeg(Sample.text("13812345678", at: CGPoint(x: 20, y: 20))))
        let defaults = try #require(UserDefaults(suiteName: "EditorModelChecklistTests"))
        defaults.removePersistentDomain(forName: "EditorModelChecklistTests")
        return EditorModel(picture: source, previewLongSide: 300, defaults: defaults)
    }

    /// In preview pixels (300×150): a face, a phone number, a maybe-plate, a long code (a barcode)
    /// and a square one (a QR code), and two text lines no rule matched. One text line sits below
    /// the other, so reading order can be checked.
    private func result() -> RecognitionResult {
        RecognitionResult(
            size: CGSize(width: 300, height: 150),
            findings: [
                Finding(kind: .face, quad: quad(10, 10, 100, 100)),
                Finding(kind: .text, rule: .phone, quad: quad(10, 100, 150, 15)),
                Finding(kind: .text, rule: .plate, quad: quad(170, 100, 60, 15)),
                Finding(kind: .code, quad: quad(200, 20, 80, 40)),
                Finding(kind: .code, quad: quad(40, 20, 60, 60)),
            ],
            textLines: [
                TextLine(quad: quad(10, 125, 200, 15), text: "收货人张三"),
                TextLine(quad: quad(10, 60, 200, 15), text: "明天见"),
            ]
        )
    }

    private func kinds(_ items: [MaskItem]) -> [RowKind] {
        items.map(\.rowKind)
    }

    @Test
    func aSquareCodeIsAQRCodeAndALongOneIsABarcode() {
        #expect(MaskItem(id: 1, group: .code, origin: .suggestion, rule: nil, quad: quad(0, 0, 60, 60), isOn: true, evidence: "").codeKind == .qr)
        #expect(MaskItem(id: 1, group: .code, origin: .suggestion, rule: nil, quad: quad(0, 0, 61, 60), isOn: true, evidence: "").codeKind == .qr)
        #expect(MaskItem(id: 1, group: .code, origin: .suggestion, rule: nil, quad: quad(0, 0, 80, 40), isOn: true, evidence: "").codeKind == .barcode)
        #expect(MaskItem(id: 1, group: .code, origin: .suggestion, rule: nil, quad: quad(0, 0, 40, 80), isOn: true, evidence: "").codeKind == .barcode)
        #expect(MaskItem(id: 1, group: .face, origin: .suggestion, rule: nil, quad: quad(0, 0, 60, 60), isOn: true, evidence: "").codeKind == nil)
        #expect(MaskItem(id: 1, group: .text, origin: .textLine, rule: nil, quad: quad(0, 0, 60, 60), isOn: false, evidence: "").codeKind == nil)
    }

    @Test
    @MainActor
    func foundCountsWhatWasFoundWhetherOrNotItIsOn() throws {
        let model = try makeModel()
        #expect(model.found == FoundCounts())
        model.adopt(result())
        let found = model.found
        #expect(found == FoundCounts(faces: 1, textLines: 4, qrCodes: 1, barcodes: 1))
        #expect(!found.isEmpty)

        for item in model.items {
            model.setOn(item.id, false)
        }
        #expect(model.enabledItems.isEmpty)
        #expect(model.found == found, "switching things off changes nothing about what was found")

        model.addManualBox(CGRect(x: 0, y: 0, width: 100, height: 100))
        #expect(model.found == found, "a hand-drawn box isn't counted")
        #expect(model.checklistOrder.last?.rowKind == .manual)
    }

    @Test
    @MainActor
    func theChecklistIsInTheFixedOrderOfTheSpec() throws {
        let model = try makeModel()
        model.adopt(result())
        // Text lines are listed only once they are on; hand-drawn boxes after the codes. Of the
        // two codes the square one is a QR code and the long one a barcode (§7.1), in that order.
        #expect(kinds(model.checklistOrder) == [.face, .phone, .plate, .qrCode, .barcode])

        model.addManualBox(CGRect(x: 0, y: 0, width: 100, height: 100))
        #expect(kinds(model.checklistOrder) == [.face, .phone, .plate, .qrCode, .barcode, .manual])

        model.setAllText(true)
        #expect(kinds(model.checklistOrder) == [.face, .phone, .plate, .qrCode, .barcode, .manual, .text, .text])
        // Within a kind, reading order: top to bottom, then left to right. The plate is right of
        // the phone number on the same line; the first text line is the higher one.
        let texts = model.checklistOrder.filter { $0.rowKind == .text }
        #expect(texts.map(\.evidence) == ["明天见", "收货人张三"])
    }

    @Test
    @MainActor
    func aRowIsNumberedOnlyWhenItsKindHasSeveral() throws {
        let model = try makeModel()
        model.adopt(result())
        model.setAllText(true)
        for item in model.checklistOrder {
            switch item.rowKind {
            case .face, .phone, .plate, .qrCode, .barcode:
                #expect(model.ordinal(of: item) == nil, "\(item.rowKind) is alone")
            case .text:
                #expect(model.ordinal(of: item) != nil, "text lines are several")
            default:
                Issue.record("no \(item.rowKind) in this picture")
            }
        }
        let texts = model.checklistOrder.filter { $0.rowKind == .text }
        #expect(texts.map { model.ordinal(of: $0) } == [1, 2])
    }

    @Test
    @MainActor
    func textLinesAreThereOnlyWhenThereAreSome() throws {
        let model = try makeModel()
        #expect(!model.hasTextLines)
        #expect(!model.hasUncoveredTextLines)
        model.adopt(result())
        #expect(model.hasTextLines)
        #expect(model.hasUncoveredTextLines)
        model.setAllText(true)
        #expect(model.hasTextLines)
        #expect(!model.hasUncoveredTextLines)
        model.adopt(.empty)
        #expect(!model.hasTextLines)
    }

    @Test
    @MainActor
    func retryStartsOverFromNothing() throws {
        let model = try makeModel()
        model.adopt(result())
        model.addManualBox(CGRect(x: 0, y: 0, width: 100, height: 100))
        model.undo()
        model.showsOriginal = true
        model.drawToolOn = true
        model.requestLocate(model.items[0].id)
        model.cancelRecognition()

        model.retryRecognition()
        #expect(model.recognition == .running)
        #expect(model.items.isEmpty)
        #expect(!model.showsOriginal)
        #expect(!model.drawToolOn)
        #expect(model.locateRequest == nil)
        #expect(!model.canUndo)
        #expect(!model.canRedo)
        model.cancelRecognition()
    }

    @Test
    @MainActor
    func whatWasOnlyOnForTheMomentGoesOff() throws {
        let model = try makeModel()
        model.adopt(result())
        let items = model.items
        model.showsOriginal = true
        model.drawToolOn = true
        model.reviewShown = true
        model.resetTransientState()
        #expect(!model.showsOriginal)
        #expect(!model.drawToolOn)
        #expect(!model.reviewShown)
        #expect(model.items == items, "the picture's items are untouched")
    }

    @Test
    func rowKindsAreInTheOrderOfTheSpecAndNameThemselvesByNumber() {
        #expect(RowKind.allCases.map(\.rawValue) == [
            "4.5.01", "4.5.02", "4.5.03", "4.5.04", "4.5.05", "4.5.06", "4.5.07", "4.5.08", "4.5.09",
            "4.5.11", "4.5.12", "4.5.13", "4.5.10",
        ])
        #expect(RowKind.plate.footnoteKey == "4.5.14")
        #expect(RowKind.face.footnoteKey == nil)
        #expect(RowKind(of: MaskItem(id: 1, group: .text, origin: .manual, rule: nil, quad: quad(0, 0, 10, 10), isOn: true, evidence: "")) == .manual)
        #expect(RowKind(of: MaskItem(id: 1, group: .text, origin: .suggestion, rule: .bankCard, quad: quad(0, 0, 10, 10), isOn: true, evidence: "")) == .bankCard)
        #expect(RowKind(of: MaskItem(id: 1, group: .text, origin: .textLine, rule: nil, quad: quad(0, 0, 10, 10), isOn: true, evidence: "")) == .text)
    }

    // MARK: An item of several boxes (design.md §0, §5)

    @Test
    func aValueWrappedOntoTwoLinesIsTwoBoxesAndOneItem() {
        let top = quad(10, 10, 120, 14)
        let bottom = quad(10, 30, 80, 14)
        let item = MaskItem(id: 1, group: .text, origin: .suggestion, rule: .reference, quads: [top, bottom],
                            isOn: true, evidence: "1234 5678")
        #expect(item.quads == [top, bottom])
        #expect(item.quad == top, "the first box, for code written when an item was one")
        #expect(item.finding.quad == top)
        #expect(item.findings.map(\.quad) == [top, bottom], "the export gets one finding per box")
        #expect(item.findings.allSatisfy { $0.kind == .text && $0.rule == .reference && $0.evidence == "1234 5678" })
        #expect(item.bounds == CGRect(x: 10, y: 10, width: 120, height: 34), "locate goes by the boxes together")
        #expect(item.rowKind == .reference, "one row, whatever the number of boxes")

        let same = MaskItem(id: 1, group: .text, origin: .suggestion, rule: .reference, quads: [top, bottom],
                            isOn: true, evidence: "1234 5678")
        let oneBox = MaskItem(id: 1, group: .text, origin: .suggestion, rule: .reference, quad: top,
                              isOn: true, evidence: "1234 5678")
        #expect(item == same)
        #expect(item != oneBox, "two boxes are not one box")

        // Given as one box either way, it is the same item.
        #expect(oneBox == MaskItem(id: 1, group: .text, origin: .suggestion, rule: .reference, quads: [top],
                                   isOn: true, evidence: "1234 5678"))
        #expect(oneBox.quads == [top])
        #expect(oneBox.bounds == CGRect(x: 10, y: 10, width: 120, height: 14))
    }

    @Test
    func aCodeIsQRCodeOrBarcodeByAllItsBoxesTogether() {
        // Two square boxes side by side: together a long one, so a barcode.
        let item = MaskItem(id: 1, group: .code, origin: .suggestion, rule: nil,
                            quads: [quad(0, 0, 60, 60), quad(80, 0, 60, 60)], isOn: true, evidence: "")
        #expect(item.codeKind == .barcode)
        #expect(item.bounds == CGRect(x: 0, y: 0, width: 140, height: 60))
        // One above the other: together a tall one.
        let stacked = MaskItem(id: 1, group: .code, origin: .suggestion, rule: nil,
                               quads: [quad(0, 0, 60, 60), quad(0, 80, 60, 60)], isOn: true, evidence: "")
        #expect(stacked.codeKind == .barcode)
    }

    @Test
    func theSummaryCountsBoxesNotItemsAndNotRuleHits() {
        let items = [
            MaskItem(id: 1, group: .face, origin: .suggestion, rule: nil, quad: quad(0, 0, 60, 60), isOn: true, evidence: ""),
            // Two phone numbers stuck into one string: one box, one item, though two rules hit.
            MaskItem(id: 2, group: .text, origin: .suggestion, rule: .phone, quad: quad(0, 60, 120, 14), isOn: true, evidence: "1381234567813812345679"),
            // A long number wrapped onto two lines: two boxes, one item.
            MaskItem(id: 3, group: .text, origin: .suggestion, rule: .reference,
                     quads: [quad(0, 100, 120, 14), quad(0, 120, 80, 14)], isOn: true, evidence: ""),
            MaskItem(id: 4, group: .text, origin: .textLine, rule: nil, quad: quad(0, 80, 120, 14), isOn: false, evidence: ""),
            MaskItem(id: 5, group: .code, origin: .suggestion, rule: nil, quad: quad(0, 20, 60, 60), isOn: true, evidence: ""),
            MaskItem(id: 6, group: .text, origin: .manual, rule: nil, quad: quad(0, 140, 120, 14), isOn: true, evidence: ""),
        ]
        #expect(items.filter { $0.origin != .manual }.count == 5, "items")
        #expect(FoundCounts(counting: items) == FoundCounts(faces: 1, textLines: 4, qrCodes: 1, barcodes: 0), "boxes")
        #expect(FoundCounts(counting: []).isEmpty)
    }

    @Test
    @MainActor
    func findingsArriveAsOneItemPerFindingWithAllItsBoxes() throws {
        // Through the temporary Finding.quads, a finding is one box: one item of one box.
        let model = try makeModel()
        model.adopt(result())
        #expect(model.items.count == 7)
        #expect(model.items.allSatisfy { $0.quads.count == 1 })
        #expect(model.enabledItems.flatMap(\.findings).count == 5, "one finding per box, on ones only")
    }
}
