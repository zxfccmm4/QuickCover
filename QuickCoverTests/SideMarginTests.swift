import CoreGraphics
import Testing
@testable import QuickCover

/// The side margins of a piece stop at the ink written beside it on its line, read off the picture:
/// "13800138000，" keeps its comma showing where the margin had covered it. The margin never cuts
/// into the box of the piece's own glyphs, and the edge of a glyph hanging over its box is no stop.
/// A piece alone on its line keeps its margin: a plate in a photo has picture, not text, beside it.
@Suite struct SideMarginTests {

    /// A box from 100 to 160 for glyphs from 120 to 140: margins of 20 on either side.
    private let box = CGRect(x: 100, y: 200, width: 60, height: 40)
    private let range = CGRect(x: 120, y: 210, width: 20, height: 20)
    private let quad = [CGPoint(x: 100, y: 200), CGPoint(x: 160, y: 200), CGPoint(x: 160, y: 240), CGPoint(x: 100, y: 240)]
    private let own = [CGPoint(x: 120, y: 210), CGPoint(x: 140, y: 210), CGPoint(x: 140, y: 230), CGPoint(x: 120, y: 230)]

    /// Ink in the given columns of the box, counted from its left edge, and nowhere else.
    private func ink(_ columns: [Int]) -> [Bool] {
        (0..<60).map { columns.contains($0) }
    }

    private func kept(_ ink: [Bool]) -> CGRect {
        Recognizer.clearOfInk(box, range: range, origin: 100, ink: ink)
    }

    @Test func stopsAPixelShortOfTheInkBesideTheValue() {
        let kept = kept(ink([50, 51, 52, 53]))
        #expect(kept.minX == 100 && kept.maxX == 149)
    }

    @Test func onTheLeftAsWell() {
        let kept = kept(ink([6, 7, 8, 9]))
        #expect(kept.minX == 110 && kept.maxX == 160)
    }

    @Test func onBothSides() {
        let kept = kept(ink([6, 7, 8, 9, 50, 51, 52, 53]))
        #expect(kept.minX == 110 && kept.maxX == 149)
    }

    @Test func theEdgeOfAGlyphOverItsBoxIsNoStop() {
        // Ink in the columns just past the box of the glyphs is their own edge: the stop is the ink after a gap.
        let kept = self.kept(ink([40, 41, 50, 51]))
        #expect(kept.maxX == 149)
    }

    @Test func theMarginNeverCutsIntoTheGlyphs() {
        // A gap, then ink at once: the margin ends at the edge of the glyphs, and no closer.
        let kept = self.kept(ink([41, 42]))
        #expect(kept.maxX == 140)
    }

    @Test func inkAllThroughTheMarginLeavesIt() {
        #expect(kept(ink(Array(40..<60))) == box)
    }

    @Test func noInkLeavesTheMargin() {
        #expect(kept(ink([])) == box)
    }

    @Test func aBandThatStartsRightOfTheGlyphsIsNoStop() {
        // The picture was read only from x 130 on: nothing is known of the columns before, and the
        // ink at 150 is still a stop.
        let kept = Recognizer.clearOfInk(box, range: range, origin: 130, ink: ink([20, 21]))
        #expect(kept.minX == 100 && kept.maxX == 149)
    }

    @Test func theTwoCornersOfAnEdgeMoveWithIt() {
        let kept = Recognizer.clearOfInk(quad, range: own, beside: true, line: CGRect(x: 0, y: 200, width: 1000, height: 40)) { _ in (100, ink([50, 51])) }
        #expect(kept == [CGPoint(x: 100, y: 200), CGPoint(x: 149, y: 200), CGPoint(x: 149, y: 240), CGPoint(x: 100, y: 240)])
    }

    @Test func aPieceAloneOnItsLineKeepsItsMargin() {
        let kept = Recognizer.clearOfInk(quad, range: own, beside: false, line: CGRect(x: 0, y: 200, width: 1000, height: 40)) { _ in (100, ink([50, 51])) }
        #expect(kept == quad)
    }

    @Test func withoutThePictureTheMarginStands() {
        let kept = Recognizer.clearOfInk(quad, range: own, beside: true, line: CGRect(x: 0, y: 200, width: 1000, height: 40), inkColumns: nil)
        #expect(kept == quad)
    }

    @Test func theInkIsReadInTheRowsOfTheLineAlone() {
        // What is written on the lines over and under the piece is no neighbour: a box that runs
        // into their rows is read in the rows of its line alone.
        let tall = [CGPoint(x: 100, y: 180), CGPoint(x: 160, y: 180), CGPoint(x: 160, y: 250), CGPoint(x: 100, y: 250)]
        var bands: [CGRect] = []
        _ = Recognizer.clearOfInk(tall, range: own, beside: true, line: CGRect(x: 0, y: 200, width: 1000, height: 40)) { band in
            bands.append(band)
            return nil
        }
        #expect(bands == [CGRect(x: 100, y: 200, width: 60, height: 40)])
    }

    private let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
    private let black = CGColor(red: 0, green: 0, blue: 0, alpha: 1)

    /// A picture of `paper` with a bar of `inkPrint` four columns wide and thirty rows tall from
    /// (70, 10), and, with `hairline`, a line one pixel thick across its row 55.
    private func picture(paper: CGColor, inkPrint: CGColor, hairline: Bool = true) throws -> CGImage {
        let context = try #require(CGImage.rgbaContext(width: 120, height: 60))
        // A bitmap context's y runs up from its last row: the picture here is drawn from its top.
        context.translateBy(x: 0, y: 60)
        context.scaleBy(x: 1, y: -1)
        context.setFillColor(paper)
        context.fill(CGRect(x: 0, y: 0, width: 120, height: 60))
        context.setFillColor(inkPrint)
        context.fill(CGRect(x: 70, y: 10, width: 4, height: 30))
        if hairline { context.fill(CGRect(x: 0, y: 55, width: 120, height: 1)) }
        return try #require(context.makeImage())
    }

    @Test func theColumnsOfInkOfADrawnPicture() throws {
        let image = try picture(paper: white, inkPrint: black)
        let whole = CGRect(x: 0, y: 0, width: 120, height: 60)
        let columns = try #require(Ink.columns(in: whole, of: image))
        #expect(columns.origin == 0 && columns.ink.count == 120)
        // The hairline is one pixel in a column, and no ink: a column needs two.
        #expect(columns.ink.indices.filter { columns.ink[$0] } == [70, 71, 72, 73])
        // Under the bar the lowest row of ink is its last, 39; elsewhere it is the hairline, 55.
        #expect(Ink.bottom(in: CGRect(x: 60, y: 0, width: 40, height: 50), of: image) == 40)
        #expect(Ink.bottom(in: whole, of: image) == 56)
    }

    @Test func inkIsReadAgainstThePaperOfTheBand() throws {
        let image = try picture(paper: black, inkPrint: white, hairline: false)
        let columns = try #require(Ink.columns(in: CGRect(x: 0, y: 0, width: 120, height: 60), of: image))
        #expect(columns.ink.indices.filter { columns.ink[$0] } == [70, 71, 72, 73])
        #expect(Ink.bottom(in: CGRect(x: 0, y: 0, width: 120, height: 60), of: image) == 40)
    }

    @Test func aBandTellsWhereItsColumnsStart() throws {
        let image = try picture(paper: white, inkPrint: black, hairline: false)
        let columns = try #require(Ink.columns(in: CGRect(x: 60, y: 5, width: 20, height: 50), of: image))
        #expect(columns.origin == 60 && columns.ink.count == 20)
        #expect(columns.ink == (0..<20).map { (10...13).contains($0) })
    }

    @Test func aBandWithNothingInItHasNoInk() throws {
        let image = try picture(paper: white, inkPrint: black, hairline: false)
        let band = CGRect(x: 0, y: 0, width: 60, height: 60)
        #expect(Ink.bottom(in: band, of: image) == nil)
        #expect(Ink.columns(in: band, of: image)?.ink.allSatisfy { !$0 } == true)
    }

    @Test func aBandOffThePictureHasNone() throws {
        let image = try picture(paper: white, inkPrint: black)
        #expect(Ink.columns(in: CGRect(x: 200, y: 0, width: 10, height: 10), of: image) == nil)
        #expect(Ink.bottom(in: CGRect(x: 200, y: 0, width: 10, height: 10), of: image) == nil)
    }
}
