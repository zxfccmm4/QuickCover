import CoreGraphics
import Foundation
import Testing

@testable import QuickCover

/// The editor's pure pieces: where the picture goes (design.md §7.3.2, §7.3.7, §7.4.3), the covers
/// as one patch per box, the once-only hint of §7.3.3, and what Review Each Item lists (§7.4.3).
struct EditorGeometryTests {

    private func close(_ a: CGFloat, _ b: CGFloat, accuracy: CGFloat = 0.001) -> Bool {
        abs(a - b) <= accuracy
    }

    // MARK: Fitting

    @Test
    func landscapePictureFillsTheWidthAndIsCentred() {
        let area = CGSize(width: 402, height: 700)
        let fitted = EditorGeometry.fitted(size: CGSize(width: 3000, height: 1500), in: area)
        #expect(fitted.width == 402)
        #expect(fitted.height == 201)
        #expect(fitted.minX == 0)
        #expect(fitted.minY == 249)
    }

    @Test
    func tallPictureFillsTheHeightAndLeavesTheSides() {
        let area = CGSize(width: 402, height: 700)
        let fitted = EditorGeometry.fitted(size: CGSize(width: 1000, height: 2000), in: area)
        #expect(fitted.width == 350)
        #expect(fitted.height == 700)
        #expect(fitted.minX == 26)
        #expect(fitted.minY == 0)
    }

    @Test
    func nothingFitsNowhere() {
        #expect(EditorGeometry.fitted(size: .zero, in: CGSize(width: 402, height: 700)) == .zero)
        #expect(EditorGeometry.fitted(size: CGSize(width: 10, height: 10), in: .zero) == .zero)
    }

    // MARK: Zoom

    @Test
    func zoomStaysBetweenOneAndFour() {
        #expect(EditorGeometry.clampedZoom(0.2) == 1)
        #expect(EditorGeometry.clampedZoom(2.5) == 2.5)
        #expect(EditorGeometry.clampedZoom(9) == 4)
    }

    @Test
    func locateZoomStopsAtThree() {
        #expect(EditorGeometry.clampedZoom(3.9, range: EditorGeometry.locateZoomRange) == 3)
        #expect(EditorGeometry.clampedZoom(0.5, range: EditorGeometry.locateZoomRange) == 1)
    }

    @Test
    func zoomingAboutTheCentreScalesTheOffset() {
        let centre = CGPoint(x: 201, y: 350)
        let offset = EditorGeometry.offset(zoomingFrom: 1, to: 2, anchor: centre, areaCentre: centre, offset: CGSize(width: 30, height: -20))
        #expect(close(offset.width, 60) && close(offset.height, -40))
    }

    @Test
    func zoomingKeepsThePointUnderTheFingersWhereItIs() {
        let area = CGSize(width: 402, height: 700)
        let fitted = EditorGeometry.fitted(size: CGSize(width: 3000, height: 1500), in: area)
        let centre = CGPoint(x: 201, y: 350)
        let fingers = CGPoint(x: 100, y: 120)
        let before = EditorGeometry.picturePoint(of: fingers, fitted: fitted, zoom: 1, offset: .zero, areaCentre: centre)
        let offset = EditorGeometry.offset(zoomingFrom: 1, to: 3, anchor: fingers, areaCentre: centre, offset: .zero)
        let after = EditorGeometry.picturePoint(of: fingers, fitted: fitted, zoom: 3, offset: offset, areaCentre: centre)
        #expect(close(before.x, after.x) && close(before.y, after.y))
        // The same place of the picture, now three times as far from the centre.
        #expect(close(offset.width, (fingers.x - centre.x) * -2) && close(offset.height, (fingers.y - centre.y) * -2))
    }

    // MARK: Keeping the picture over the visible part

    @Test
    func offsetNeverLetsAnEdgeInsideTheVisiblePart() {
        let picture = CGSize(width: 402, height: 700)
        let centre = CGPoint(x: 201, y: 350)
        let visible = CGRect(x: 0, y: 0, width: 402, height: 700)
        // At zoom 1 the picture is exactly the visible part: it cannot move.
        #expect(EditorGeometry.clamped(CGSize(width: 50, height: -80), picture: picture, zoom: 1, areaCentre: centre, visible: visible) == .zero)
        // At zoom 2 it can go half a screen each way.
        let far = EditorGeometry.clamped(CGSize(width: 500, height: -500), picture: picture, zoom: 2, areaCentre: centre, visible: visible)
        #expect(close(far.width, 201) && close(far.height, -350))
        let near = EditorGeometry.clamped(CGSize(width: -500, height: 500), picture: picture, zoom: 2, areaCentre: centre, visible: visible)
        #expect(close(near.width, -201) && close(near.height, 350))
        // What is allowed is left alone.
        let ok = CGSize(width: 40, height: -60)
        #expect(EditorGeometry.clamped(ok, picture: picture, zoom: 2, areaCentre: centre, visible: visible) == ok)
    }

    @Test
    func narrowerPictureIsCentredOnTheVisiblePart() {
        let picture = CGSize(width: 350, height: 700)
        let centre = CGPoint(x: 201, y: 350)
        let visible = CGRect(x: 0, y: 0, width: 402, height: 700)
        let clamped = EditorGeometry.clamped(CGSize(width: 90, height: 0), picture: picture, zoom: 1, areaCentre: centre, visible: visible)
        #expect(clamped.width == 0)
        #expect(clamped.height == 0)
    }

    @Test
    func visiblePartOverTheSheetKeepsTheBottomEdgeOnTheSheet() {
        // The sheet's edge is 300 from the top of an 874 screen: the picture is seen down to there.
        let picture = CGSize(width: 402, height: 201)
        let centre = CGPoint(x: 201, y: 350)
        let visible = CGRect(x: 0, y: 0, width: 402, height: 150)
        // The picture is 603 high at zoom 3. Pulled down, its top edge may come to y = 0, no lower;
        // pulled up, its bottom edge may come to y = 150, no higher.
        let down = EditorGeometry.clamped(CGSize(width: 0, height: 900), picture: picture, zoom: 3, areaCentre: centre, visible: visible)
        #expect(close(down.height, 0 + 603 / 2 - 350))
        let up = EditorGeometry.clamped(CGSize(width: 0, height: -900), picture: picture, zoom: 3, areaCentre: centre, visible: visible)
        #expect(close(up.height, 150 - 603 / 2 - 350))
    }

    // MARK: Locate (§7.4.3)

    @Test
    func locatePutsTheItemInTheMiddleOfTheVisiblePart() {
        let area = CGSize(width: 402, height: 700)
        let fitted = EditorGeometry.fitted(size: CGSize(width: 3000, height: 1500), in: area)
        let centre = CGPoint(x: 201, y: 350)
        let visible = CGRect(x: 0, y: 0, width: 402, height: 240)
        let item = CGRect(x: 60, y: 30, width: 80, height: 40)   // in fitted points
        let framing = EditorGeometry.locate(item: item, fitted: fitted, areaCentre: centre, visible: visible)
        let itemCentre = EditorGeometry.picturePoint(of: CGPoint(x: visible.midX, y: visible.midY), fitted: fitted,
                                                     zoom: framing.zoom, offset: framing.offset, areaCentre: centre)
        #expect(close(itemCentre.x, item.midX, accuracy: 0.01))
        #expect(close(itemCentre.y, item.midY, accuracy: 0.01))
        #expect(framing.zoom == 3)
    }

    @Test
    func locateFillsAtMostThreeFifthsOfTheVisibleWidth() {
        let area = CGSize(width: 402, height: 700)
        let fitted = EditorGeometry.fitted(size: CGSize(width: 3000, height: 1500), in: area)
        let centre = CGPoint(x: 201, y: 350)
        let visible = CGRect(x: 0, y: 0, width: 402, height: 240)
        let wide = CGRect(x: 0, y: 0, width: 100, height: 40)
        let framing = EditorGeometry.locate(item: wide, fitted: fitted, areaCentre: centre, visible: visible)
        // 62% of the visible width over the item's width, the smaller of the two.
        #expect(close(framing.zoom, 0.62 * 402 / 100, accuracy: 0.001))
        let tall = CGRect(x: 100, y: 0, width: 20, height: 40)
        let framing2 = EditorGeometry.locate(item: tall, fitted: fitted, areaCentre: centre, visible: visible)
        // Half the visible height over the item's height, but never past 3.
        #expect(close(framing2.zoom, 3, accuracy: 0.001))
    }

    @Test
    func locateNeverGoesBelowOne() {
        let area = CGSize(width: 402, height: 700)
        let fitted = EditorGeometry.fitted(size: CGSize(width: 3000, height: 1500), in: area)
        let framing = EditorGeometry.locate(item: CGRect(x: 0, y: 0, width: 2000, height: 1000), fitted: fitted,
                                            areaCentre: CGPoint(x: 201, y: 350), visible: CGRect(x: 0, y: 0, width: 402, height: 240))
        #expect(framing.zoom == 1)
    }

    // MARK: Drawing (§7.3.7)

    @Test
    func dragShorterThanTwelvePointsIsNotABox() {
        #expect(EditorGeometry.drawnBox(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 21, y: 60)) == nil)
        #expect(EditorGeometry.drawnBox(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 60, y: 21)) == nil)
        let box = EditorGeometry.drawnBox(from: CGPoint(x: 50, y: 70), to: CGPoint(x: 12, y: 22))
        #expect(box == CGRect(x: 12, y: 22, width: 38, height: 48))
    }

    @Test
    func pictureRectAndPointAgree() {
        let area = CGSize(width: 402, height: 700)
        let fitted = EditorGeometry.fitted(size: CGSize(width: 3000, height: 1500), in: area)
        let centre = CGPoint(x: 201, y: 350)
        let zoom: CGFloat = 2
        let offset = CGSize(width: 40, height: -30)
        let rect = CGRect(x: 20, y: 30, width: 100, height: 50)
        let asPicture = EditorGeometry.pictureRect(of: rect, fitted: fitted, zoom: zoom, offset: offset, areaCentre: centre)
        #expect(close(asPicture.width, 50) && close(asPicture.height, 25))
        let origin = EditorGeometry.picturePoint(of: rect.origin, fitted: fitted, zoom: zoom, offset: offset, areaCentre: centre)
        #expect(close(asPicture.minX, origin.x) && close(asPicture.minY, origin.y))
        // The middle of the rect is the middle in the picture.
        let middle = EditorGeometry.picturePoint(of: CGPoint(x: rect.midX, y: rect.midY), fitted: fitted, zoom: zoom, offset: offset, areaCentre: centre)
        #expect(close(middle.x, asPicture.midX) && close(middle.y, asPicture.midY))
    }
}

/// One patch per box, where the box is (`CoverPainter`).
struct CoverPainterTests {

    private func quad(_ rect: CGRect) -> [CGPoint] {
        [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
         CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)]
    }

    private func item(_ id: Int, _ rects: [CGRect], on: Bool = true, origin: MaskItem.Origin = .suggestion) -> MaskItem {
        MaskItem(id: id, group: .face, origin: origin, rule: nil, quads: rects.map(quad), isOn: on, evidence: "")
    }

    @Test
    func patchIsTheBoxAndTheMarginInWholePixels() throws {
        let preview = Sample.solid(width: 100, height: 60, fill: Sample.white)
        // The preview is half the picture's size.
        let patches = CoverPainter.patches(items: [item(1, [CGRect(x: 40, y: 20, width: 20, height: 20)])],
                                           style: .solid, preview: preview, scale: CGSize(width: 2, height: 2))
        let patch = try #require(patches.first)
        #expect(patches.count == 1)
        #expect(patch.id == "1.0")
        // (20 − 4, 10 − 4, 10 + 8, 10 + 8)
        #expect(patch.frame == CGRect(x: 16, y: 6, width: 18, height: 18))
        #expect(patch.image.width == 18 && patch.image.height == 18)
    }

    @Test
    func patchStopsAtThePicture() {
        let preview = Sample.solid(width: 100, height: 60, fill: Sample.white)
        let patches = CoverPainter.patches(items: [item(1, [CGRect(x: 0, y: 0, width: 10, height: 10)])],
                                           style: .solid, preview: preview, scale: CGSize(width: 1, height: 1))
        #expect(patches.first?.frame == CGRect(x: 0, y: 0, width: 14, height: 14))
        let edge = CoverPainter.patches(items: [item(2, [CGRect(x: 98, y: 58, width: 10, height: 10)])],
                                        style: .solid, preview: preview, scale: CGSize(width: 1, height: 1))
        #expect(edge.first?.frame == CGRect(x: 94, y: 54, width: 6, height: 6))
    }

    @Test
    func twoBoxesMakeTwoPatchesOfOneItem() {
        let preview = Sample.solid(width: 100, height: 60, fill: Sample.white)
        let items = [item(7, [CGRect(x: 10, y: 10, width: 20, height: 10), CGRect(x: 10, y: 30, width: 20, height: 10)])]
        let patches = CoverPainter.patches(items: items, style: .mosaic, preview: preview, scale: CGSize(width: 1, height: 1))
        #expect(patches.map(\.id) == ["7.0", "7.1"])
    }

    @Test
    func switchedOffItemsDrawNothing() {
        let preview = Sample.solid(width: 100, height: 60, fill: Sample.white)
        let items = [item(1, [CGRect(x: 10, y: 10, width: 20, height: 10)], on: false),
                     item(2, [CGRect(x: 50, y: 10, width: 20, height: 10)])]
        let patches = CoverPainter.patches(items: items, style: .solid, preview: preview, scale: CGSize(width: 1, height: 1))
        #expect(patches.map(\.id) == ["2.0"])
        #expect(CoverKey(items: items, style: .solid).items.map(\.id) == [2])
    }

    @Test
    func nothingOutsideThePicture() {
        let preview = Sample.solid(width: 100, height: 60, fill: Sample.white)
        let patches = CoverPainter.patches(items: [item(1, [CGRect(x: 200, y: 200, width: 20, height: 20)])],
                                           style: .solid, preview: preview, scale: CGSize(width: 1, height: 1))
        #expect(patches.isEmpty)
        #expect(CoverPainter.patches(items: [item(1, [CGRect(x: 0, y: 0, width: 20, height: 20)])],
                                     style: .solid, preview: preview, scale: .zero).isEmpty)
    }

    @Test
    func solidPatchCoversItsBoxInBlack() throws {
        let preview = Sample.solid(width: 100, height: 60, fill: Sample.white)
        let patches = CoverPainter.patches(items: [item(1, [CGRect(x: 40, y: 20, width: 20, height: 20)])],
                                           style: .solid, preview: preview, scale: CGSize(width: 1, height: 1))
        let image = try #require(patches.first?.image)
        let context = try #require(CGImage.rgbaContext(width: image.width, height: image.height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = context.data!.assumingMemoryBound(to: UInt8.self)
        let pixel = { (x: Int, y: Int) in Int(bytes[y * context.bytesPerRow + x * 4]) }
        let alpha = { (x: Int, y: Int) in Int(bytes[y * context.bytesPerRow + x * 4 + 3]) }
        // The middle of the patch is the box, black and opaque; the corner is the margin outside
        // the box, which stays clear so that overlapping crops don't repaint a neighbour's cover.
        #expect(pixel(image.width / 2, image.height / 2) == 0)
        #expect(alpha(image.width / 2, image.height / 2) == 255)
        #expect(alpha(0, 0) == 0)
    }

    @Test
    func aNeighbourCropLeavesAnEarlierCoverAlone() throws {
        // Two boxes two points apart: the second one's crop (the box and 4 around it) reaches over
        // the first one's right edge, where the picture would be painted again over its cover.
        let preview = Sample.solid(width: 100, height: 60, fill: Sample.white)
        let items = [item(1, [CGRect(x: 10, y: 10, width: 20, height: 20)]),
                     item(2, [CGRect(x: 32, y: 10, width: 20, height: 20)])]
        let patches = CoverPainter.patches(items: items, style: .solid, preview: preview, scale: CGSize(width: 1, height: 1))
        #expect(patches.count == 2)
        let context = try #require(CGImage.rgbaContext(width: 100, height: 60))
        context.draw(preview, in: CGRect(x: 0, y: 0, width: 100, height: 60))
        for patch in patches { context.draw(patch.image, in: patch.frame) }
        let bytes = context.data!.assumingMemoryBound(to: UInt8.self)
        let pixel = { (x: Int, y: Int) in Int(bytes[(60 - 1 - y) * context.bytesPerRow + x * 4]) }
        #expect(pixel(29, 20) == 0)
        #expect(pixel(42, 20) == 0)
        #expect(pixel(31, 20) == 255)
    }
}

/// The sheet's height is measured against what was asked (`SheetGeometry.addition`).
struct SheetGeometryTests {

    @Test
    func theAdditionIsTheSystemsOwn() {
        // First time: asked to end 300 under the top, the edge comes out at 284: 16 added.
        #expect(SheetGeometry.addition(sheetTop: 300, extraBefore: 0, top: 284) == 16)
        // Next time the 16 is already off the height, so the edge comes out at 300: still 16.
        #expect(SheetGeometry.addition(sheetTop: 300, extraBefore: 16, top: 300) == 16)
    }

    @Test
    func nothingAddedStaysNothing() {
        #expect(SheetGeometry.addition(sheetTop: 300, extraBefore: 0, top: 300) == 0)
        #expect(SheetGeometry.addition(sheetTop: 300, extraBefore: 0, top: 320) == 0)
    }
}

/// The hint 4.8.4 comes once per phone (design.md §7.3.3).
struct HoldHintTests {

    @Test
    func dueUntilMarkedSeen() throws {
        let defaults = try #require(UserDefaults(suiteName: "HoldHintTests"))
        defaults.removePersistentDomain(forName: "HoldHintTests")
        #expect(HoldHint.isDue(defaults: defaults))
        HoldHint.markSeen(defaults: defaults)
        #expect(!HoldHint.isDue(defaults: defaults))
        #expect(defaults.bool(forKey: HoldHint.key))
    }
}

/// What the cards of Review Each Item hold, and in what order (design.md §7.4.3).
struct ReviewSheetSectionsTests {

    private func quad(_ rect: CGRect) -> [CGPoint] {
        [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
         CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)]
    }

    private func item(_ id: Int, _ rect: CGRect, kind: MaskItem.Group = .text, origin: MaskItem.Origin = .suggestion,
                      rule: TextRule? = nil, on: Bool = true) -> MaskItem {
        MaskItem(id: id, group: kind, origin: origin, rule: rule, quad: quad(rect), isOn: on, evidence: "")
    }

    @Test
    func textLinesAreListedAlsoWhenOff() {
        let items = [item(1, CGRect(x: 0, y: 0, width: 10, height: 10), kind: .face),
                     item(2, CGRect(x: 0, y: 20, width: 10, height: 10), origin: .textLine, on: false),
                     item(3, CGRect(x: 0, y: 40, width: 10, height: 10), origin: .textLine, on: true)]
        #expect(ReviewSheetSections.textLines(in: items).map(\.id) == [2, 3])
        #expect(ReviewSheetSections.suggestions(in: items).map(\.id) == [1])
    }

    @Test
    func suggestionsGoByKindThenReadingOrder() {
        let items = [item(1, CGRect(x: 0, y: 100, width: 10, height: 10), rule: .phone),     // phone, lower
                     item(2, CGRect(x: 50, y: 50, width: 10, height: 10), rule: .phone),      // phone, right
                     item(3, CGRect(x: 0, y: 0, width: 10, height: 10), kind: .face),         // face, top
                     item(4, CGRect(x: 0, y: 50, width: 10, height: 10), origin: .manual),    // hand-drawn, left
                     item(5, CGRect(x: 0, y: 200, width: 10, height: 10), rule: .idNumber)]   // ID
        #expect(ReviewSheetSections.suggestions(in: items).map(\.id) == [3, 2, 1, 5, 4])
    }

    @Test
    func textLinesGoTopToBottomThenLeftToRight() {
        let items = [item(1, CGRect(x: 60, y: 10, width: 10, height: 10), origin: .textLine),
                     item(2, CGRect(x: 10, y: 10, width: 10, height: 10), origin: .textLine),
                     item(3, CGRect(x: 10, y: 80, width: 10, height: 10), origin: .textLine)]
        #expect(ReviewSheetSections.textLines(in: items).map(\.id) == [2, 1, 3])
    }

    @Test
    func nothingGivesNoCards() {
        #expect(ReviewSheetSections.textLines(in: []).isEmpty)
        #expect(ReviewSheetSections.suggestions(in: []).isEmpty)
    }
}
