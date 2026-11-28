import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation
import ImageIO
import Testing
import UIKit
import UniformTypeIdentifiers

@testable import QuickCover

struct MaskRendererTests {

    private func quad(_ rect: CGRect) -> [CGPoint] {
        [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
         CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)]
    }

    /// RGBA bytes of the whole picture, rows packed, from the top.
    private func bytes(_ image: CGImage) -> [UInt8] {
        let context = CGImage.rgbaContext(width: image.width, height: image.height)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let stride = context.bytesPerRow
        let buffer = context.data!.assumingMemoryBound(to: UInt8.self)
        var out = [UInt8](repeating: 0, count: image.width * image.height * 4)
        for row in 0..<image.height {
            let from = row * stride
            let to = (image.height - 1 - row) * image.width * 4
            out.replaceSubrange(to..<(to + image.width * 4), with: UnsafeBufferPointer(start: buffer + from, count: image.width * 4))
        }
        return out
    }

    private func darkPixels(_ image: CGImage, in rect: CGRect) -> Int {
        let data = bytes(image)
        var count = 0
        for y in Int(rect.minY)..<Int(rect.maxY) {
            for x in Int(rect.minX)..<Int(rect.maxX) {
                let i = ((image.height - 1 - y) * image.width + x) * 4
                if data[i] < 64 { count += 1 }
            }
        }
        return count
    }

    @Test
    func solidCoverIsBlackAndSizeIsKept() {
        let image = Sample.text("13812345678", at: CGPoint(x: 20, y: 20))
        let flat = MaskRenderer.flatten(image, findings: [Finding(kind: .text, quad: quad(CGRect(x: 0, y: 0, width: 600, height: 300)))], style: .solid)
        #expect(flat.width == image.width)
        #expect(flat.height == image.height)
        #expect(Sample.brightness(flat, x: 100, y: 40) < 0.05)
        #expect(Sample.brightness(flat, x: 500, y: 250) < 0.05)
    }

    @Test
    func noFindingsLeavesThePictureAlone() {
        let image = Sample.solid(width: 20, height: 20, fill: Sample.white)
        #expect(MaskRenderer.flatten(image, findings: [], style: .mosaic) === image)
    }

    @Test
    func mosaicSmearsDigitsAndKeepsTheRest() {
        let image = Sample.text("13812345678", at: CGPoint(x: 20, y: 20))
        let cover = CGRect(x: 15, y: 15, width: 300, height: 55)
        let before = darkPixels(image, in: cover)
        let flat = MaskRenderer.flatten(image, findings: [Finding(kind: .text, quad: quad(cover))], style: .mosaic)
        let after = darkPixels(flat, in: cover)
        #expect(before > 2000)
        #expect(after * 3 < before)
        // Outside the cover nothing changes.
        let a = bytes(image), b = bytes(flat)
        let row = 200 * 4 * 600
        #expect(Array(a[row..<(row + 600 * 4)]) == Array(b[row..<(row + 600 * 4)]))
    }

    @Test
    func blurSmearsDigits() {
        let image = Sample.text("13812345678", at: CGPoint(x: 20, y: 20))
        let cover = CGRect(x: 15, y: 15, width: 300, height: 55)
        let before = darkPixels(image, in: cover)
        let flat = MaskRenderer.flatten(image, findings: [Finding(kind: .text, quad: quad(cover))], style: .blur)
        let after = darkPixels(flat, in: cover)
        #expect(after * 2 < before)
    }

    private func jpegWithMetadata() throws -> (Data, CGImageSource) {
        let image = Sample.text("13812345678", at: CGPoint(x: 20, y: 20))
        let data = Sample.jpeg(image, orientation: 6, metadata: true)
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        return (data, source)
    }

    @Test
    func exportIsUprightWithOriginalPixelSize() throws {
        let (_, source) = try jpegWithMetadata()
        let encoded = try MaskRenderer.encode(source, orientation: .right, findings: [], options: .init())
        let out = try #require(CGImageSourceCreateWithData(encoded as CFData, nil))
        let img = try #require(CGImageSourceCreateImageAtIndex(out, 0, nil))
        // Stored 600×300 with the "right" tag: the file must come out upright as 300×600.
        #expect(img.width == 300)
        #expect(img.height == 600)
    }

    @Test
    func metadataIsDroppedByDefaultAndKeptOnRequest() throws {
        let (_, source) = try jpegWithMetadata()
        let stripped = try MaskRenderer.encode(source, orientation: .right, findings: [], options: .init())
        let kept = try MaskRenderer.encode(source, orientation: .right, findings: [], options: .init(stripMetadata: false))
        func properties(_ data: Data) throws -> [CFString: Any] {
            let src = try #require(CGImageSourceCreateWithData(data as CFData, nil))
            return try #require(CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any])
        }
        let a = try properties(stripped)
        // ImageIO writes a small Exif block of its own (pixel size, colour space); what must be gone
        // is everything that came from the original: location, date, rotation.
        #expect(a[kCGImagePropertyGPSDictionary] == nil)
        let exif = a[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        #expect(exif[kCGImagePropertyExifDateTimeOriginal] == nil)
        #expect(exif[kCGImagePropertyExifLensModel] == nil)
        #expect(((a[kCGImagePropertyOrientation] as? NSNumber)?.uint32Value ?? 1) == 1)
        let b = try properties(kept)
        #expect(b[kCGImagePropertyGPSDictionary] != nil)
        let tiff = b[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        #expect(tiff?[kCGImagePropertyTIFFOrientation] as? Int == 1)
    }

    @Test
    func exportPressesTheCoverIntoTheFile() throws {
        let (_, source) = try jpegWithMetadata()
        let findings = [Finding(kind: .text, quad: quad(CGRect(x: 0, y: 0, width: 600, height: 300)))]
        let encoded = try MaskRenderer.encode(source, orientation: .up, findings: findings, options: .init(style: .solid))
        let out = try #require(CGImageSourceCreateWithData(encoded as CFData, nil))
        let img = try #require(CGImageSourceCreateImageAtIndex(out, 0, nil))
        #expect(Sample.brightness(img, x: 100, y: 40) < 0.05)
    }

    @Test
    func twoPieceFindingCoversBothPiecesAndNotWhatIsBetween() {
        // 「电话 150」 over 「9122 3047」: one finding of two boxes, the row between them left as it is.
        let image = Sample.text("150 9122 3047", at: CGPoint(x: 50, y: 95))
        let upper = CGRect(x: 50, y: 100, width: 90, height: 30), lower = CGRect(x: 50, y: 150, width: 80, height: 30)
        let finding = Finding(kind: .text, rule: .phone, pieces: [quad(upper), quad(lower)], evidence: "150 9122 3047")
        let between = (x: 100, y: 140)   // inside the finding's bounds, outside both boxes
        for style in MaskStyle.allCases {
            let flat = MaskRenderer.flatten(image, findings: [finding], style: style)
            #expect(flat.width == image.width && flat.height == image.height)
            if style == .solid {
                // Under both pieces the picture is black.
                #expect(Sample.brightness(flat, x: 100, y: 115) < 0.05, "\(style)")
                #expect(Sample.brightness(flat, x: 125, y: 165) < 0.05, "\(style)")
            } else {
                // The digits under the first piece are smeared, not left as they were.
                #expect(Sample.brightness(flat, x: 60, y: 112) != Sample.brightness(image, x: 60, y: 112), "\(style)")
            }
            // Between the pieces nothing is touched.
            #expect(Sample.brightness(flat, x: between.x, y: between.y) == Sample.brightness(image, x: between.x, y: between.y), "\(style)")
            #expect(Sample.brightness(flat, x: between.x, y: between.y) > 0.9, "\(style)")
        }
    }
    // MARK: - 遮盖取的是哪一块（修「小画布里只有框左下角那几个像素」）

    /// The box under test: 100×40 at (10, 10) in a 120×60 picture, covered as a face is
    /// (`MaskRenderer.grid`: the one rule that did not change). A sixth of its height is under the
    /// floor, so the mosaic's `cell` is 12 and it has 9 × 4 cells; the blur's grain is 12 too
    /// (`BlurGrain.default`), so 9 × 4 as well. What the cells are over is not what these tests are
    /// about; text, codes and boxes drawn by hand are cut by `grid`, tested under「格子按什么切」.
    private static let coverBox = CGRect(x: 10, y: 10, width: 100, height: 40)

    private var cover: [Finding] { [Finding(kind: .face, quad: quad(Self.coverBox))] }

    /// A white picture with `paint` added to it, drawn in UIKit's top-left coordinates.
    private func picture(size: CGSize = CGSize(width: 120, height: 60),
                         _ paint: (UIGraphicsRendererContext) -> Void) -> CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            paint(context)
        }.cgImage!
    }

    /// A 120×60 picture of black and white stripes 2 pixels wide all over: finer than the strokes of
    /// small print are wide next to a 12-pixel cell.
    private func fineStripes() -> CGImage {
        picture { context in
            UIColor.black.setFill()
            for x in stride(from: 0, to: 120, by: 4) { context.fill(CGRect(x: x, y: 0, width: 2, height: 60)) }
        }
    }

    /// Red 0…255 of every pixel, `[y][x]`, counted from the top-left corner. Read the way
    /// `Sample.brightness` reads one pixel: the picture is drawn into a CoreGraphics context (origin
    /// bottom-left, y up) shifted so that the row asked for falls on the one row of a 1-pixel-high
    /// canvas, so which end of the buffer is up never comes into it.
    private func reds(_ image: CGImage) -> [[Int]] {
        let width = CGFloat(image.width), height = CGFloat(image.height)
        return (0..<image.height).map { y in
            let context = CGImage.rgbaContext(width: image.width, height: 1)!
            context.translateBy(x: 0, y: -(height - 1 - CGFloat(y)))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            let buffer = context.data!.assumingMemoryBound(to: UInt8.self)
            return (0..<image.width).map { Int(buffer[$0 * 4]) }
        }
    }

    /// Red of every pixel inside cell `column`, `row` of a `columns × rows` grid over `box`, two pixels
    /// in from the cell's edges so its neighbours, and the seam to them, are left out.
    private func cell(_ column: Int, _ row: Int, columns: Int, rows: Int, of box: CGRect, in red: [[Int]]) -> [Int] {
        let width = box.width / CGFloat(columns), height = box.height / CGFloat(rows)
        let x0 = Int((box.minX + CGFloat(column) * width).rounded(.up)) + 2
        let x1 = Int((box.minX + CGFloat(column + 1) * width).rounded(.down)) - 3
        let y0 = Int((box.minY + CGFloat(row) * height).rounded(.up)) + 2
        let y1 = Int((box.minY + CGFloat(row + 1) * height).rounded(.down)) - 3
        return (y0...y1).flatMap { red[$0][x0...x1] }
    }

    /// The most that two neighbouring pixels differ inside `box`, across or down, two pixels in from
    /// its edge so the cover's own rim is not counted.
    private func steepestStep(_ red: [[Int]], inside box: CGRect) -> Int {
        var step = 0
        for y in Int(box.minY) + 2..<(Int(box.maxY) - 2) {
            for x in Int(box.minX) + 2..<(Int(box.maxX) - 2) {
                step = max(step, abs(red[y][x + 1] - red[y][x]), abs(red[y + 1][x] - red[y][x]))
            }
        }
        return step
    }

    @Test
    func mosaicCellsTakeTheColourOfTheirOwnPiece() {
        // Black from the middle of the cover box to the picture's right edge: the box's left half
        // lies over white, its right half over black.
        let image = picture { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 60, y: 0, width: 60, height: 60))
        }
        let flat = MaskRenderer.flatten(image, findings: cover, style: .mosaic)
        let red = reds(flat), own = reds(image)
        for row in 0..<4 {
            for column in 0..<9 {
                let values = cell(column, row, columns: 9, rows: 4, of: Self.coverBox, in: red)
                #expect(values.max()! - values.min()! <= 1, "cell (\(column), \(row)) is one colour")
                // The edge at x = 60 falls inside column 4; that one is only held to being one colour.
                if column < 4 { #expect(values.min()! >= 240, "cell (\(column), \(row)) lies over white") }
                if column > 4 { #expect(values.max()! <= 15, "cell (\(column), \(row)) lies over black") }
            }
        }
        // The strips left and right of the cover, above and under it, are the picture's own.
        #expect(red[5] == own[5], "the row above the cover")
        #expect(red[55] == own[55], "the row under the cover")
        #expect(red.map { $0[5] } == own.map { $0[5] }, "the column left of the cover")
        #expect(red.map { $0[115] } == own.map { $0[115] }, "the column right of the cover")
    }

    @Test
    func mosaicCellIsTheMeanOfItsOwnPieceAndNothingElse() {
        // The box of `mosaicCellsTakeTheColourOfTheirOwnPiece`, 9 columns of 100 / 9 px, and a 4-pixel
        // black bar from x = 20: it lies over columns 0 and 1 only. Column 0 is [10, 21.1), the pixels
        // 10…20, one of them black → 10 / 11 white → 232. Column 1 is [21.1, 32.2), the pixels 21…31,
        // three of them black → 8 / 11 white → 185. Every other column is the white around the bar:
        // a cell's neighbours must not bleed into it, and its mean is taken over its pixels alone.
        let image = picture { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 20, y: 0, width: 4, height: 60))
        }
        let red = reds(MaskRenderer.flatten(image, findings: cover, style: .mosaic))
        for row in 0..<4 {
            for column in 0..<9 {
                let values = cell(column, row, columns: 9, rows: 4, of: Self.coverBox, in: red)
                let expected = [0: 232, 1: 185][column] ?? 255
                #expect(values.allSatisfy { $0 == expected },
                        "cell (\(column), \(row)) is the mean of its own piece: \(values.first ?? -1), wanted \(expected)")
            }
        }
    }

    @Test
    func mosaicIsNotTurnedUpsideDown() {
        // A face's cover 100×50 at (10, 5): `cell` is still 12, so five rows of cells. Black from the middle
        // of it down to the picture's bottom edge: the cells above the middle lie over white, those
        // under it over black, and the row the edge cuts through is one mixed colour of its own.
        let box = CGRect(x: 10, y: 5, width: 100, height: 50)
        let image = picture { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 30, width: 120, height: 30))
        }
        let own = reds(image)
        // The reader itself reads the picture the way it was drawn.
        #expect(own[5][60] == 255, "white at the top")
        #expect(own[55][60] == 0, "black at the bottom")
        let findings = [Finding(kind: .face, quad: quad(box))]
        let red = reds(MaskRenderer.flatten(image, findings: findings, style: .mosaic))
        for row in 0..<5 {
            for column in 0..<9 {
                let values = cell(column, row, columns: 9, rows: 5, of: box, in: red)
                #expect(values.max()! - values.min()! <= 1, "cell (\(column), \(row)) is one colour")
                if row < 2 { #expect(values.min()! >= 240, "cell (\(column), \(row)) lies over white") }
                if row > 2 { #expect(values.max()! <= 15, "cell (\(column), \(row)) lies over black") }
            }
        }
    }

    @Test
    func mosaicHidesFineStripes() {
        let red = reds(MaskRenderer.flatten(fineStripes(), findings: cover, style: .mosaic))
        for row in 0..<4 {
            for column in 0..<9 {
                let values = cell(column, row, columns: 9, rows: 4, of: Self.coverBox, in: red)
                #expect(values.max()! - values.min()! <= 1, "cell (\(column), \(row)) is one colour")
                // Half of every cell is black and half white, so its colour is the mix: never a stripe's own.
                #expect(values.min()! >= 64, "cell (\(column), \(row)) is not white: the stripes are mixed in")
                #expect(values.max()! <= 191, "cell (\(column), \(row)) is not black: the white is mixed in")
            }
        }
    }

    @Test
    func blurHidesFineStripes() {
        let image = fineStripes()
        #expect(steepestStep(reds(image), inside: Self.coverBox) == 255, "the stripes step from black to white")
        let red = reds(MaskRenderer.flatten(image, findings: cover, style: .blur))
        // The blur's grain is never under 12 pixels (`BlurGrain.default`'s floor), so the steepest
        // thing a picture holds, black next to white, is spread over at least 12 pixels: 255 / 12
        // ≈ 21 a pixel. Stretching the grains is interpolated and rings a little at a hard step, so
        // twice that.
        #expect(steepestStep(red, inside: Self.coverBox) <= 42)
    }

    @Test
    func exportPressesEachCellsOwnPieceIntoTheFile() throws {
        // The picture of `mosaicCellsTakeTheColourOfTheirOwnPiece`, through the export's own way:
        // a JPEG is opened, encoded with the cover pressed in, and decoded again.
        let image = picture { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 60, y: 0, width: 60, height: 60))
        }
        let source = try #require(CGImageSourceCreateWithData(Sample.jpeg(image) as CFData, nil))
        let encoded = try MaskRenderer.encode(source, orientation: .up, findings: cover, options: .init(style: .mosaic))
        let out = try #require(CGImageSourceCreateWithData(encoded as CFData, nil))
        let flat = try #require(CGImageSourceCreateImageAtIndex(out, 0, nil))
        let red = reds(flat)
        for row in 0..<4 {
            for column in 0..<9 {
                let values = cell(column, row, columns: 9, rows: 4, of: Self.coverBox, in: red)
                if column == 4 {
                    // The edge runs through this column: half of each cell white, half black. JPEG rings
                    // around a hard edge, so it is only held to being the mix of the two.
                    #expect(values.min()! >= 64, "cell (\(column), \(row)) is the mix: some white")
                    #expect(values.max()! <= 191, "cell (\(column), \(row)) is the mix: some black")
                    continue
                }
                // Twice through JPEG leaves a flat cell flat within a step or two.
                #expect(values.max()! - values.min()! <= 4, "cell (\(column), \(row)) is one colour")
                if column < 4 { #expect(values.min()! >= 240, "cell (\(column), \(row)) lies over white") }
                if column > 4 { #expect(values.max()! <= 15, "cell (\(column), \(row)) lies over black") }
            }
        }
    }

    @Test
    func coverFlushWithThePictureEdgeCoversAllOfItsCells() {
        // A face's cover flush with the picture's top and right edges: 100×40 at (20, 0). Its cells
        // must still each be the mix of what lies under them, with none of the picture showing through.
        let box = CGRect(x: 20, y: 0, width: 100, height: 40)
        let flat = MaskRenderer.flatten(fineStripes(), findings: [Finding(kind: .face, quad: quad(box))], style: .mosaic)
        let red = reds(flat)
        for row in 0..<4 {
            for column in 0..<9 {
                let values = cell(column, row, columns: 9, rows: 4, of: box, in: red)
                #expect(values.max()! - values.min()! <= 1, "cell (\(column), \(row)) is one colour")
                #expect(values.min()! >= 64, "cell (\(column), \(row)) is not white: the stripes are mixed in")
                #expect(values.max()! <= 191, "cell (\(column), \(row)) is not black: the white is mixed in")
            }
        }
    }

    // MARK: - 模糊的档位（修「模糊下机器还能读出 4–5 个连续字符」）

    /// A white picture with black and white bands `band` pixels tall all over, stacked from the top
    /// of the box under test: a blur grain exactly two bands tall averages to the same grey.
    private func bands(_ band: CGFloat, height: CGFloat) -> CGImage {
        picture(size: CGSize(width: 120, height: height)) { context in
            UIColor.black.setFill()
            for top in stride(from: 10, to: height, by: 2 * band) {
                context.fill(CGRect(x: 0, y: top, width: 120, height: band))
            }
        }
    }

    /// Red of every pixel two or more inside `box`, away from the clip's edge.
    private func inside(_ box: CGRect, of red: [[Int]]) -> [Int] {
        red[(Int(box.minY) + 2)..<(Int(box.maxY) - 2)].flatMap { $0[(Int(box.minX) + 2)..<(Int(box.maxX) - 2)] }
    }

    /// Pixels of row `y` inside `box` that are neither white nor black: the softer an edge, the more.
    private func middles(inRow y: Int, of box: CGRect, in red: [[Int]]) -> Int {
        red[y][(Int(box.minX) + 2)..<(Int(box.maxX) - 2)].filter { (64..<191).contains($0) }.count
    }

    /// `box` covered as a face is blurred: a face is the one thing `blurGrain` still sizes.
    private func blurred(_ image: CGImage, box: CGRect, grain: MaskRenderer.BlurGrain = .default) -> [[Int]] {
        reds(MaskRenderer.flatten(image, findings: [Finding(kind: .face, quad: quad(box))], style: .blur, blurGrain: grain))
    }

    @Test
    func shippedBlurGrainIsTheMosaicsNumbersOverAFace() {
        #expect(MaskRenderer.BlurGrain.default == MaskRenderer.BlurGrain(divisor: 6, floor: 12))
        let grain = MaskRenderer.BlurGrain.default
        #expect(grain.cell(forHeight: 8) == 12, "a low thing gets the floor")
        #expect(grain.cell(forHeight: 72) == 12, "a sixth of 72 is the floor")
        #expect(grain.cell(forHeight: 300) == 50, "a tall thing gets a sixth of its height")
    }

    @Test(arguments: [(CGFloat(60), CGFloat(6)), (CGFloat(72), CGFloat(6))])
    func blurOfALowFaceIsGrainedNoFinerThanTheFloor(height: CGFloat, band: CGFloat) {
        // A face 100×60 and one 100×72 at (10, 10): up to 72 tall the floor rules (a sixth is under it or just
        // 12), so rows of 12 pixels, 5 and 6 of them. Bands 6 pixels tall stack two to a row and the
        // blur comes out one flat grey. Any other number of rows leaves the bands' alternation in it:
        // the old tenth makes 6 and 8 rows, a fifth 5 of 14 pixels in the taller box.
        let box = CGRect(x: 10, y: 10, width: 100, height: height)
        let grey = inside(box, of: blurred(bands(band, height: height + 20), box: box))
        #expect(grey.min()! >= 126, "one grey")
        #expect(grey.max()! <= 130, "one grey")
    }

    @Test
    func blurOfATallFaceIsGrainedASixthOfItsHeight() {
        // A face 100×120: a sixth is 20, over the floor, so 6 rows of 20 pixels; bands 10 pixels tall vanish
        // the same way. The floor alone (12: 10 rows), a tenth (15: 8), a fifth (24: 5) or a quarter
        // (30: 4) would leave them showing.
        let box = CGRect(x: 10, y: 10, width: 100, height: 120)
        let grey = inside(box, of: blurred(bands(10, height: 140), box: box))
        #expect(grey.min()! >= 126, "one grey")
        #expect(grey.max()! <= 130, "one grey")
    }

    @Test
    func blurGrainPassedInIsTheOneUsed() {
        // `coverBox`, its left half white and its right half black. One grain for the whole box: flat
        // at their mean. Grains of 2 pixels: the edge between the halves stays sharp, while the
        // shipped grain spreads it over about ten pixels.
        let image = picture { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 60, y: 0, width: 60, height: 60))
        }
        let one = inside(Self.coverBox, of: blurred(image, box: Self.coverBox, grain: .init(divisor: 1, floor: 100)))
        #expect(one.min()! >= 126)
        #expect(one.max()! <= 130)
        #expect(middles(inRow: 30, of: Self.coverBox, in: blurred(image, box: Self.coverBox)) >= 6, "the shipped grain softens the edge")
        let fine = blurred(image, box: Self.coverBox, grain: .init(divisor: 1_000, floor: 2))
        #expect(fine[30][30] >= 250, "white stays white")
        #expect(fine[30][90] <= 5, "black stays black")
        #expect(middles(inRow: 30, of: Self.coverBox, in: fine) <= 2, "the edge stays sharp")
    }

    // MARK: - 格子按什么切（规格 1.6，`MaskRenderer.grid`）

    private func rect(_ width: CGFloat, _ height: CGFloat) -> CGRect {
        CGRect(x: 0, y: 0, width: width, height: height)
    }

    /// Text the recognizer read over `box`, its tallest piece `height` pixels tall before the padding.
    private func read(_ box: CGRect, height: CGFloat?) -> Finding {
        Finding(kind: .text, quad: quad(box), textHeight: height)
    }

    /// A box drawn by hand over `box`.
    private func drawn(_ box: CGRect) -> Finding { Finding(kind: .text, quad: quad(box), drawnByHand: true) }

    private func code(_ box: CGRect) -> Finding { Finding(kind: .code, quad: quad(box)) }

    private func face(_ box: CGRect) -> Finding { Finding(kind: .face, quad: quad(box)) }

    private func cut(_ finding: Finding, style: MaskStyle = .mosaic,
                     blurGrain: MaskRenderer.BlurGrain = .default) -> MaskRenderer.Grid {
        MaskRenderer.grid(over: finding.box, hiding: finding, style: style, blurGrain: blurGrain)
    }

    @Test
    func textIsCutByTheHeightOfItsLetters() {
        // 300×55, letters 40: the base is the letter, one row is all that fits whole, seven cells across.
        #expect(cut(read(rect(300, 55), height: 40)) == MaskRenderer.Grid(columns: 7, rows: 1))
        #expect(MaskRenderer.base(over: rect(300, 55), textHeight: 40) == 40)
        // Two lines, 300×100, letters 40: half the box is taller than a letter, so the base is 50: two rows, six across.
        #expect(cut(read(rect(300, 100), height: 40)) == MaskRenderer.Grid(columns: 6, rows: 2))
        // Letters 60 in a box 90 tall: one row, cells 60 and more wide.
        #expect(cut(read(rect(300, 90), height: 60)) == MaskRenderer.Grid(columns: 5, rows: 1))
        // Small letters in a low box, 100×20: the base is the floor, 12: eight across, the one row 20 tall.
        #expect(cut(read(rect(100, 20), height: 6)) == MaskRenderer.Grid(columns: 8, rows: 1))
        // 24 tall: half of it is the floor; two rows of 12, four across.
        #expect(cut(read(rect(50, 24), height: 8)) == MaskRenderer.Grid(columns: 4, rows: 2))
    }

    /// 列数按底数算：一块占了三行字以上，格子跟着变宽，不是按字高数。
    @Test
    func columnsAreCountedByTheBase() {
        // 300×150, letters 40: three lines. The base is half the box, 75, not the letter: four cells
        // across and two down, 75 × 75. Counted by the letter there would be seven across.
        let box = rect(300, 150), grid = cut(read(box, height: 40))
        #expect(MaskRenderer.base(over: box, textHeight: 40) == 75)
        #expect(grid == MaskRenderer.Grid(columns: 4, rows: 2))
        #expect(grid.grain(in: box) == CGSize(width: 75, height: 75))
        // 300×100, letters 60: the letter is the base, five across, one row.
        #expect(cut(read(rect(300, 100), height: 60)) == MaskRenderer.Grid(columns: 5, rows: 1))
        // 1200×100, letters 55: 21 whole ones across (21 × 55 = 1155), the 22nd would not fit.
        #expect(cut(read(rect(1200, 100), height: 55)) == MaskRenderer.Grid(columns: 21, rows: 1))
    }

    /// 预览图是原图缩小的，按像素算的下限跟着缩：同一个框在预览上切出来的行列数，和在文件里的一样。
    @Test
    func shrunkPictureShrinksWhatIsCountedInPixels() {
        // The file: 100 × 20, letters 6 — the base is the floor, 12: eight across, the one row.
        // Over the preview, the picture shrunk by two: 50 × 10, letters 3. The floor goes to 6
        // with it and it is the same eight cells; kept at 12 there would be four.
        let whole = MaskRenderer.onShrunkPicture(shrink: CGSize(width: 1, height: 1))
        #expect(whole.floor == MaskRenderer.mosaicFloor && whole.blurGrain == .default)
        let half = MaskRenderer.onShrunkPicture(shrink: CGSize(width: 2, height: 2))
        #expect(half.floor == 6 && half.blurGrain == MaskRenderer.BlurGrain(divisor: 6, floor: 6))
        let small = read(rect(50, 10), height: 3)
        #expect(MaskRenderer.grid(over: small.box, hiding: small, style: .mosaic, floor: half.floor)
                == MaskRenderer.Grid(columns: 8, rows: 1))
        #expect(MaskRenderer.grid(over: small.box, hiding: small, style: .mosaic)
                == MaskRenderer.Grid(columns: 4, rows: 1))
        // Shrunk unevenly, by the way it is shrunk less: never finer than in the file.
        #expect(MaskRenderer.onShrunkPicture(shrink: CGSize(width: 4, height: 2)).floor == 6)
    }

    /// 每格高不小于字高、行数不超过 2、格子把盖框正好分完：(盖框宽, 盖框高, 字高)。
    @Test(arguments: [(CGFloat(300), CGFloat(55), CGFloat(40)), (300, 100, 40), (300, 90, 60), (100, 20, 6), (50, 24, 8),
                       (300, 150, 40), (1200, 30, 22), (75, 102, 74), (874, 66, 50), (139, 36, 9)])
    func noCellIsLowerThanALetterAndTheyFillTheBox(width: CGFloat, height: CGFloat, letter: CGFloat) {
        let box = rect(width, height)
        for style in [MaskStyle.mosaic, .blur] {
            let grid = cut(read(box, height: letter), style: style), grain = grid.grain(in: box)
            #expect(grain.height >= letter, "\(style): a cell is never lower than a letter")
            #expect((1...2).contains(grid.rows), "\(style): one row or two")
            #expect(abs(CGFloat(grid.columns) * grain.width - width) < 1e-9, "\(style): the cells fill the box across")
            #expect(abs(CGFloat(grid.rows) * grain.height - height) < 1e-9, "\(style): and down")
            // …unless it is the only one across, in a box narrower than the base.
            #expect(grid.columns == 1 || grain.width >= MaskRenderer.base(over: box, textHeight: letter) - 1e-9,
                    "\(style): and none is narrower than the base")
        }
    }

    @Test
    func withoutTheHeightOfTheLettersHalfTheBoxStandsIn() {
        // 300×100: half of it, 50, stands in for the letter: six across, two down, the same as a code.
        #expect(cut(read(rect(300, 100), height: nil)) == MaskRenderer.Grid(columns: 6, rows: 2))
        #expect(cut(code(rect(300, 100))) == MaskRenderer.Grid(columns: 6, rows: 2))
    }

    /// 码按盖框高一半、两行。
    @Test
    func codesAreCutByHalfTheirHeight() {
        // A square code 200×100: base 50, four across, two down. A barcode 400×40: base 20, twenty across, two down.
        #expect(cut(code(rect(200, 100))) == MaskRenderer.Grid(columns: 4, rows: 2))
        #expect(cut(code(rect(400, 40))) == MaskRenderer.Grid(columns: 20, rows: 2))
        // 60×24: half of it is the floor, 12: five across, two down.
        #expect(cut(code(rect(60, 24))) == MaskRenderer.Grid(columns: 5, rows: 2))
        // A thin strip 300×14: half is under the floor, so 12: one row of 25 cells, each 12 × 14.
        #expect(cut(code(rect(300, 14))) == MaskRenderer.Grid(columns: 25, rows: 1))
    }

    /// 自己框的（手画的框）一行格：格高 = 盖框高，列数 = floor(盖框宽 / max(盖框高, 12))。
    @Test
    func aBoxDrawnByHandGetsOneRow() {
        // 300×40 round one line of text: seven cells, each the box's height every way (300 / 7 ≈ 42.9 × 40).
        let line = rect(300, 40), grid = cut(drawn(line))
        #expect(grid == MaskRenderer.Grid(columns: 7, rows: 1))
        #expect(grid.grain(in: line) == CGSize(width: 300.0 / 7, height: 40))
        // 300×8, a thin one: the floor, 12, is wider than it is tall: 25 cells of 12 × 8.
        #expect(cut(drawn(rect(300, 8))) == MaskRenderer.Grid(columns: 25, rows: 1))
        // 20×100, a tall narrow one: a single cell.
        #expect(cut(drawn(rect(20, 100))) == MaskRenderer.Grid(columns: 1, rows: 1))
        // However tall the letters beside it would be, nothing is read under it.
        #expect(cut(drawn(rect(300, 40)), blurGrain: .init(divisor: 1, floor: 1)) == MaskRenderer.Grid(columns: 7, rows: 1))
    }

    /// 人脸不动：块高 / 6，下限 12，列数照原来的算法（不够一格的补一格）。
    @Test
    func aFaceIsCutAsItAlwaysWas() {
        // 300×120: a sixth is 20, 15 × 6. 100×40: the floor, 12, 9 × 4. 40×8: 4 × 1.
        #expect(cut(face(rect(300, 120))) == MaskRenderer.Grid(columns: 15, rows: 6))
        #expect(cut(face(Self.coverBox)) == MaskRenderer.Grid(columns: 9, rows: 4))
        #expect(cut(face(rect(40, 8))) == MaskRenderer.Grid(columns: 4, rows: 1))
    }

    /// 模糊跟着各自的数：文字、码用马赛克的底数，手画的框用盖框高；只有人脸还看 `blurGrain`。
    @Test
    func theBlurFollowsTheMosaicOfEverythingButAFace() {
        for finding in [read(rect(300, 100), height: 40), read(rect(300, 55), height: nil), code(rect(400, 40)), drawn(rect(300, 40))] {
            #expect(cut(finding, style: .blur) == cut(finding, style: .mosaic), "\(finding.kind), drawn by hand: \(finding.drawnByHand)")
            #expect(cut(finding, style: .blur, blurGrain: .init(divisor: 1_000, floor: 2)) == cut(finding, style: .mosaic),
                    "the grain passed in is not the one used")
        }
        // A face: a sixth of its height and never under 12; the grain passed in is the one used.
        #expect(cut(face(rect(300, 120)), style: .blur) == MaskRenderer.Grid(columns: 15, rows: 6))
        #expect(cut(face(rect(300, 120)), style: .blur, blurGrain: .init(divisor: 10, floor: 10)) == MaskRenderer.Grid(columns: 25, rows: 10))
    }

    @Test
    func solidHasNoGrains() {
        for finding in [read(rect(300, 100), height: 40), code(rect(200, 100)), drawn(rect(300, 40)), face(rect(300, 120))] {
            #expect(cut(finding, style: .solid) == MaskRenderer.Grid(columns: 1, rows: 1))
        }
    }

    @Test
    func theHeightOfTheLettersReachesTheCells() {
        // `mosaicCellsTakeTheColourOfTheirOwnPiece`'s picture under text 40 tall: the base is the
        // letter, so two cells 50 × 40, one over white and one over black, the edge at x = 60 their seam.
        let image = picture { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 60, y: 0, width: 60, height: 60))
        }
        let tall = reds(MaskRenderer.flatten(image, findings: [read(Self.coverBox, height: 40)], style: .mosaic))
        #expect(Set(cell(0, 0, columns: 2, rows: 1, of: Self.coverBox, in: tall)) == [255])
        #expect(Set(cell(1, 0, columns: 2, rows: 1, of: Self.coverBox, in: tall)) == [0])
        // Letters 6 tall: half the box is the base, 20, so 5 × 2; the cell the edge cuts through is one grey of its own.
        let small = reds(MaskRenderer.flatten(image, findings: [read(Self.coverBox, height: 6)], style: .mosaic))
        #expect(Set(cell(0, 0, columns: 5, rows: 2, of: Self.coverBox, in: small)) == [255])
        #expect(Set(cell(4, 1, columns: 5, rows: 2, of: Self.coverBox, in: small)) == [0])
        #expect(cell(2, 0, columns: 5, rows: 2, of: Self.coverBox, in: small).allSatisfy { (100..<160).contains($0) })
    }

    @Test
    func theBlurOverTextIsSqueezedThroughItsMosaicsGrains() {
        let image = picture { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 60, y: 0, width: 60, height: 60))
        }
        // However fine a grain is passed in, the blur goes through the mosaic's 2 × 1 grains, so the
        // edge is spread (a face would keep it sharp: `blurGrainPassedInIsTheOneUsed`), and each end
        // keeps its own colour.
        let blur = reds(MaskRenderer.flatten(image, findings: [read(Self.coverBox, height: 40)], style: .blur,
                                             blurGrain: .init(divisor: 1_000, floor: 2)))
        #expect(middles(inRow: 30, of: Self.coverBox, in: blur) >= 6)
        #expect(blur[30][12] >= 250 && blur[30][107] <= 5)
    }

    // MARK: - New Styles, Colors, Strength & Anti-Theft Watermark

    @Test
    func concealMatchesSurroundingBackgroundAndErasesText() {
        let image = Sample.text("13812345678", at: CGPoint(x: 20, y: 20))
        let cover = CGRect(x: 15, y: 15, width: 300, height: 55)
        let before = darkPixels(image, in: cover)
        let flat = MaskRenderer.flatten(image, findings: [Finding(kind: .text, quad: quad(cover))], style: .conceal)
        let after = darkPixels(flat, in: cover)
        #expect(before > 2000)
        #expect(after == 0, "conceal completely erases dark text into white paper background")
        #expect(Sample.brightness(flat, x: 100, y: 40) > 0.95)
    }

    @Test
    func stripesAlternatesBlackAndMosaicInsideCoverWithoutTouchingOutside() {
        let image = Sample.solid(width: 120, height: 60, fill: Sample.white)
        let flat = MaskRenderer.flatten(image, findings: cover, style: .stripes)
        let values = inside(Self.coverBox, of: reds(flat))
        #expect(values.contains(where: { $0 < 10 }), "stripes includes black diagonal bands")
        #expect(values.contains(where: { $0 > 240 }), "stripes alternates with mosaic white cells")
        #expect(reds(flat)[5] == reds(image)[5], "pixels outside the cover are untouched")
    }

    @Test
    func emojiCoverCompletelyReplacesTextWithoutTouchingOutside() {
        let image = Sample.text("13812345678", at: CGPoint(x: 20, y: 20))
        let cover = CGRect(x: 15, y: 15, width: 300, height: 55)
        let appearance = MaskAppearance(style: .emoji, emoji: "😎")
        let flat = MaskRenderer.flatten(image, findings: [Finding(kind: .text, quad: quad(cover))], appearance: appearance)
        #expect(flat.width == image.width && flat.height == image.height)
        // Pixels outside the cover are untouched.
        let a = bytes(image), b = bytes(flat)
        let row = 200 * 4 * 600
        #expect(Array(a[row..<(row + 600 * 4)]) == Array(b[row..<(row + 600 * 4)]))
    }

    @Test
    func solidColorPresetAndStrengthAndWatermarkWorkEndToEnd() throws {
        let image = Sample.solid(width: 240, height: 160, fill: Sample.white)
        let box = CGRect(x: 20, y: 20, width: 80, height: 40)

        // Teal solid fill preset
        let tealFlat = MaskRenderer.flatten(
            image,
            findings: [Finding(kind: .text, quad: quad(box))],
            appearance: MaskAppearance(style: .solid, solidColor: .teal)
        )
        let tealRed = reds(tealFlat)
        #expect(tealRed[40][60] < 30, "teal has very low red channel")
        #expect(tealRed[10][10] > 240, "outside remains white")

        // Coarse strength produces fewer (coarser) columns than fine strength.
        let faceFinding = face(rect(300, 120))
        let fineGrid = MaskRenderer.grid(over: faceFinding.box, hiding: faceFinding, style: .mosaic, strength: .fine)
        let coarseGrid = MaskRenderer.grid(over: faceFinding.box, hiding: faceFinding, style: .mosaic, strength: .coarse)
        #expect(coarseGrid.columns < fineGrid.columns)

        // Anti-theft watermark alters pixels across the canvas when enabled and is a no-op when disabled.
        let off = MaskRenderer.flatten(image, findings: [], appearance: MaskAppearance(watermark: .off))
        #expect(off === image)

        let wm = WatermarkOptions(isEnabled: true, text: "FOR VERIFICATION ONLY", opacity: 0.4, density: .dense, tint: .red)
        let watermarked = MaskRenderer.flatten(image, findings: [], appearance: MaskAppearance(watermark: wm))
        #expect(bytes(watermarked) != bytes(image), "active watermark visibly paints diagonal text")

        // PNG export format encodes as PNG even when source is JPEG.
        let source = try #require(CGImageSourceCreateWithData(Sample.jpeg(image) as CFData, nil))
        let pngData = try MaskRenderer.encode(
            source,
            orientation: .up,
            findings: [],
            options: .init(watermark: wm, format: .png)
        )
        let pngSource = try #require(CGImageSourceCreateWithData(pngData as CFData, nil))
        #expect((CGImageSourceGetType(pngSource) as String?) == UTType.png.identifier)
    }

    @Test
    func magicEraseSmoothlyInterpolatesGradientBackgroundWithZeroTextTrace() {
        // Vertical gradient from dark blue top (y=0) to light sky bottom (y=120), with a black bar in the middle.
        let image = picture(size: CGSize(width: 120, height: 120)) { ctx in
            let space = CGColorSpaceCreateDeviceRGB()
            let colors = [UIColor(red: 0.1, green: 0.2, blue: 0.5, alpha: 1).cgColor,
                          UIColor(red: 0.85, green: 0.92, blue: 0.98, alpha: 1).cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: 120), options: [])
            UIColor.black.setFill()
            ctx.fill(CGRect(x: 35, y: 45, width: 50, height: 30))
        }
        let coverRect = CGRect(x: 30, y: 40, width: 60, height: 40)
        let erased = MaskRenderer.flatten(
            image,
            findings: [Finding(kind: .text, quad: quad(coverRect))],
            style: .conceal
        )
        let red = reds(erased)
        // Top of erased region should be noticeably darker than bottom (smooth vertical gradient preserved!).
        let topR = red[44][60]
        let bottomR = red[75][60]
        #expect(topR > 40, "black text inside box is completely erased")
        #expect(bottomR > topR + 15, "vertical background gradient is reconstructed across erased region")
    }

    @Test
    func coloredMosaicAndCustomSolidAndColoredStripesRenderDistinctColors() {
        let image = Sample.solid(width: 160, height: 100, fill: Sample.white)
        let box = CGRect(x: 20, y: 20, width: 120, height: 60)
        let finding = Finding(kind: .face, quad: quad(box))

        // Rose-tinted mosaic should be strongly reddish rather than neutral white/gray.
        let roseMosaic = MaskRenderer.flatten(
            image,
            findings: [finding],
            appearance: MaskAppearance(style: .mosaic, mosaicTint: .color(.preset(.rose)))
        )
        let roseBytes = bytes(roseMosaic)
        let centerIdx = ((100 - 1 - 50) * 160 + 80) * 4
        #expect(roseBytes[centerIdx] > 180, "rose mosaic has high red channel")
        #expect(roseBytes[centerIdx + 1] < 130, "rose mosaic has lower green channel")

        // Custom RGB solid fill renders the exact chosen RGB color.
        let customGreen = CustomColorRGB(red: 0.12, green: 0.78, blue: 0.42)
        let customSolid = MaskRenderer.flatten(
            image,
            findings: [finding],
            appearance: MaskAppearance(style: .solid, customSolidColor: customGreen)
        )
        let solidBytes = bytes(customSolid)
        #expect(solidBytes[centerIdx] < 45)
        #expect(solidBytes[centerIdx + 1] > 180)

        // Indigo-tinted diagonal stripes include indigo-colored bars (high blue, low red) instead of pure black.
        let indigoStripes = MaskRenderer.flatten(
            image,
            findings: [finding],
            appearance: MaskAppearance(style: .stripes, mosaicTint: .color(.preset(.indigo)))
        )
        let stripeBytes = bytes(indigoStripes)
        var foundIndigoBarPixel = false
        for x in 30..<130 {
            let idx = ((100 - 1 - 50) * 160 + x) * 4
            if Int(stripeBytes[idx + 2]) - Int(stripeBytes[idx]) > 80 {
                foundIndigoBarPixel = true
                break
            }
        }
        #expect(foundIndigoBarPixel, "indigo stripes paint colored diagonal bars")
    }

    @Test
    func longScreenshotSmartOverlapDeduplicatesSharedContentAndDirectAppendConcatenates() throws {
        // Two 300x360 synthetic scrolling screenshots with fixed 40px top/bottom chrome and a shared
        // textured band that scrolled upward by 140px between frame 1 and frame 2.
        func scrollingShot(offsetY: CGFloat) -> CGImage {
            picture(size: CGSize(width: 300, height: 360)) { ctx in
                // Background
                UIColor(white: 0.96, alpha: 1).setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 300, height: 360))

                // Unique high-contrast content stripes indexed across y = 0...600 in virtual page space
                for row in stride(from: 0, to: 600, by: 28) {
                    let screenY = CGFloat(row) - offsetY
                    guard screenY > -28 && screenY < 360 else { continue }
                    let hue = CGFloat((row / 28) % 5) * 0.16
                    UIColor(hue: hue, saturation: 0.85, brightness: 0.72, alpha: 1).setFill()
                    ctx.fill(CGRect(x: 24, y: screenY, width: CGFloat(120 + (row % 3) * 50), height: 14))
                }

                // Identical fixed top bar (status + navigation)
                UIColor(white: 0.92, alpha: 1).setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 300, height: 40))
                UIColor(white: 0.25, alpha: 1).setFill()
                ctx.fill(CGRect(x: 110, y: 14, width: 80, height: 12))

                // Identical fixed bottom tab bar
                UIColor(white: 0.92, alpha: 1).setFill()
                ctx.fill(CGRect(x: 0, y: 320, width: 300, height: 40))
                UIColor(white: 0.25, alpha: 1).setFill()
                ctx.fill(CGRect(x: 40, y: 334, width: 220, height: 10))
            }
        }

        let shot1 = scrollingShot(offsetY: 0)
        let shot2 = scrollingShot(offsetY: 140)

        let smart = try LongScreenshotStitcher.stitch(images: [shot1, shot2], options: .init(smartOverlap: true))
        #expect(smart.frameCount == 2)
        #expect(smart.stitchedOverlapCount == 1)
        #expect(smart.image.width == 300)
        #expect(smart.image.height < 600, "overlapping scrolled content and fixed chrome are deduplicated (got \(smart.image.height))")
        #expect(smart.image.height >= 450, "keeps full non-overlapping height (~500px, got \(smart.image.height))")

        let direct = try LongScreenshotStitcher.stitch(images: [shot1, shot2], options: .init(smartOverlap: false))
        #expect(direct.stitchedOverlapCount == 0)
        #expect(direct.image.height == 720)

        let spacedVertical = try LongScreenshotStitcher.stitch(
            images: [shot1, shot2],
            options: .init(direction: .vertical, smartOverlap: false, spacing: .narrow)
        )
        #expect(spacedVertical.image.height == 720 + 16)

        let horizontal = try LongScreenshotStitcher.stitch(
            images: [shot1, shot2],
            options: .init(direction: .horizontal, spacing: .wide)
        )
        #expect(horizontal.image.width == 600 + 36)
        #expect(horizontal.image.height == 360)
    }

    @Test
    func longScreenshotSmartOverlapHandlesRealWorldChromeClockFloatingButtonReverseOrderAndDuplicates() throws {
        // Simulates realistic iPhone white-background scrolling screenshots (600x1200) containing:
        // - Live changing status-bar clock digits ("17:25", "17:26", "17:27")
        // - Slightly shifting translucent Liquid Glass top nav bar & bottom tab bar
        // - Floating "+" action button fixed at bottom-right & right-edge scroll indicator
        // - Predominantly white background with thin text/list cards spanning y = 0...2200
        let shotSize = CGSize(width: 600, height: 1200)
        func realisticIPhoneShot(offsetY: CGFloat, clockText: String, glassTintOffset: CGFloat, scrollBarTop: CGFloat) -> CGImage {
            picture(size: shotSize) { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: shotSize))

                // Virtual feed items (mix of white whitespace, thin dividers, avatars, and dark text)
                let titleAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 22, weight: .semibold),
                    .foregroundColor: UIColor(white: 0.12, alpha: 1),
                ]
                let bodyAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 16, weight: .regular),
                    .foregroundColor: UIColor(white: 0.45, alpha: 1),
                ]
                for index in 0..<18 {
                    let itemY = 120 + CGFloat(index) * 116 - offsetY
                    guard itemY > -120 && itemY < 1220 else { continue }
                    let hue = CGFloat((index * 3) % 7) / 7.0
                    UIColor(hue: hue, saturation: 0.72, brightness: 0.85, alpha: 1).setFill()
                    UIBezierPath(roundedRect: CGRect(x: 28, y: itemY + 14, width: 48, height: 48), cornerRadius: 12).fill()

                    NSString(string: "Message Item #\(index + 1) · Conversation Row")
                        .draw(at: CGPoint(x: 92, y: itemY + 14), withAttributes: titleAttr)
                    NSString(string: "Detail snippet line \(index * 17 + 1003) with padding & whitespace")
                        .draw(at: CGPoint(x: 92, y: itemY + 46), withAttributes: bodyAttr)

                    UIColor(white: 0.91, alpha: 1).setFill()
                    ctx.fill(CGRect(x: 28, y: itemY + 98, width: 544, height: 1.5))
                }

                // Right-edge scrollbar moving per frame
                UIColor(white: 0.55, alpha: 0.75).setFill()
                UIBezierPath(roundedRect: CGRect(x: 590, y: scrollBarTop, width: 5, height: 140), cornerRadius: 2.5).fill()

                // Floating circular "+" button near bottom-right corner
                UIColor(red: 0.05, green: 0.55, blue: 0.65, alpha: 1).setFill()
                UIBezierPath(ovalIn: CGRect(x: 500, y: 950, width: 68, height: 68)).fill()
                UIColor.white.setFill()
                ctx.fill(CGRect(x: 520, y: 981, width: 28, height: 6))
                ctx.fill(CGRect(x: 531, y: 970, width: 6, height: 28))

                // Translucent top header with slightly varying glass tint + live clock digit changes
                UIColor(red: 0.94 - glassTintOffset, green: 0.95, blue: 0.97 + glassTintOffset, alpha: 0.95).setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 600, height: 112))
                let clockAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.monospacedDigitSystemFont(ofSize: 18, weight: .semibold),
                    .foregroundColor: UIColor.black,
                ]
                NSString(string: clockText).draw(at: CGPoint(x: 34, y: 18), withAttributes: clockAttr)
                NSString(string: "Inbox · Timeline").draw(at: CGPoint(x: 226, y: 66), withAttributes: titleAttr)

                // Translucent bottom tab bar with slightly shifting tint
                UIColor(red: 0.94 + glassTintOffset, green: 0.95, blue: 0.96, alpha: 0.95).setFill()
                ctx.fill(CGRect(x: 0, y: 1086, width: 600, height: 114))
                UIColor(white: 0.25, alpha: 1).setFill()
                ctx.fill(CGRect(x: 210, y: 1178, width: 180, height: 6))
            }
        }

        let shot1 = realisticIPhoneShot(offsetY: 0, clockText: "17:25", glassTintOffset: 0.00, scrollBarTop: 150)
        let shot2 = realisticIPhoneShot(offsetY: 480, clockText: "17:26", glassTintOffset: 0.02, scrollBarTop: 340)
        let shot3 = realisticIPhoneShot(offsetY: 990, clockText: "17:27", glassTintOffset: 0.03, scrollBarTop: 550)

        let expectedThreeShotHeight = 1200 + 480 + 510 // 2190 px

        // 1. Forward order [shot1, shot2, shot3]
        let forward = try LongScreenshotStitcher.stitch(images: [shot1, shot2, shot3], options: .init(smartOverlap: true))
        #expect(forward.stitchedOverlapCount == 2)
        #expect(abs(forward.image.height - expectedThreeShotHeight) <= 3, "Expected ~\(expectedThreeShotHeight)px, got \(forward.image.height)")

        // 2. Reverse order [shot3, shot2, shot1] (newest-first gallery selection) auto-recovers exact length
        let reversed = try LongScreenshotStitcher.stitch(images: [shot3, shot2, shot1], options: .init(smartOverlap: true))
        #expect(reversed.stitchedOverlapCount == 2)
        #expect(abs(reversed.image.height - expectedThreeShotHeight) <= 3, "Reverse selection should still stitch to ~\(expectedThreeShotHeight)px, got \(reversed.image.height)")

        // 3. Near-duplicate frame [shot1, shot1, shot2] skips the duplicate instead of appending twice
        let duplicatePass = try LongScreenshotStitcher.stitch(images: [shot1, shot1, shot2], options: .init(smartOverlap: true))
        let expectedTwoShotHeight = 1200 + 480
        #expect(abs(duplicatePass.image.height - expectedTwoShotHeight) <= 3, "Duplicate frame should be skipped (~1680px, got \(duplicatePass.image.height))")

        // 4. Two completely unrelated screenshots fall back cleanly without false-positive cropping
        let unrelatedA = Sample.text("Alpha Document Page One 11111", at: CGPoint(x: 40, y: 200))
        let unrelatedB = picture(size: CGSize(width: 600, height: 300)) { ctx in
            UIColor(red: 0.10, green: 0.18, blue: 0.34, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 600, height: 300))
            UIColor(red: 0.95, green: 0.65, blue: 0.15, alpha: 1).setFill()
            for x in stride(from: 20, to: 560, by: 60) {
                ctx.fill(CGRect(x: x, y: 80, width: 32, height: 140))
            }
        }
        let unrelated = try LongScreenshotStitcher.stitch(images: [unrelatedA, unrelatedB], options: .init(smartOverlap: true))
        #expect(unrelated.stitchedOverlapCount == 0)
        #expect(unrelated.image.height == unrelatedA.height + unrelatedB.height)
    }

    @Test
    func longScreenshotSmartOverlapMergesDifferingTabViewCollapsingHeaderAndFractionalOffset() throws {
        // Simulates iOS 26 real scrolling screenshots (900x1950, 3x portrait) where:
        // - Shot 1 has a tall Large Navigation Title (0...350px) and full 4-tab bottom TabView (1710...1950px, bright orange highlight)
        // - Shot 2 scrolls down by a fractional coarse-pixel offset (1237px, leaving a thin ~13% crisp overlap band),
        //   collapses into a compact Inline Navigation Bar (0...205px, deep teal), and switches to a minimized
        //   floating pill TabView (1785...1950px, distinct slate tint) plus soft scroll-edge blur and a floating corner pill.
        let shotSize = CGSize(width: 900, height: 1950)
        func iOS26Shot(offsetY: CGFloat, largeHeader: Bool, compactTab: Bool) -> CGImage {
            picture(size: shotSize) { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: shotSize))

                let titleAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 30, weight: .semibold),
                    .foregroundColor: UIColor(white: 0.10, alpha: 1),
                ]
                let subAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 22, weight: .regular),
                    .foregroundColor: UIColor(white: 0.40, alpha: 1),
                ]

                for idx in 0..<24 {
                    let itemY = 365 + CGFloat(idx) * 142 - offsetY
                    guard itemY > -150 && itemY < 1960 else { continue }
                    let hue = CGFloat((idx * 5) % 9) / 9.0
                    UIColor(hue: hue, saturation: 0.78, brightness: 0.80, alpha: 1).setFill()
                    UIBezierPath(roundedRect: CGRect(x: 36, y: itemY + 18, width: 72, height: 72), cornerRadius: 18).fill()

                    NSString(string: "Thread Row \(idx + 1) · Long Content Line")
                        .draw(at: CGPoint(x: 128, y: itemY + 18), withAttributes: titleAttr)
                    NSString(string: "Preview item \(idx * 23 + 419) with multi-word detail")
                        .draw(at: CGPoint(x: 128, y: itemY + 60), withAttributes: subAttr)

                    UIColor(white: 0.90, alpha: 1).setFill()
                    ctx.fill(CGRect(x: 36, y: itemY + 124, width: 828, height: 2))
                }

                // Floating corner action pill on right edge
                UIColor(red: 0.15, green: 0.45, blue: 0.90, alpha: 1).setFill()
                UIBezierPath(roundedRect: CGRect(x: 785, y: 1520, width: 76, height: 76), cornerRadius: 38).fill()

                // Completely different Top Navigation Chrome between Shot 1 and Shot 2
                if largeHeader {
                    UIColor(white: 0.96, alpha: 1).setFill()
                    ctx.fill(CGRect(x: 0, y: 0, width: 900, height: 350))
                    NSString(string: "9:41").draw(at: CGPoint(x: 48, y: 24), withAttributes: subAttr)
                    NSString(string: "Large Inbox Header").draw(at: CGPoint(x: 36, y: 220), withAttributes: titleAttr)
                } else {
                    UIColor(red: 0.08, green: 0.42, blue: 0.48, alpha: 1).setFill()
                    ctx.fill(CGRect(x: 0, y: 0, width: 900, height: 205))
                    NSString(string: "9:42").draw(at: CGPoint(x: 48, y: 24), withAttributes: subAttr)
                    NSString(string: "Inline Bar").draw(at: CGPoint(x: 360, y: 125), withAttributes: titleAttr)
                }

                // Completely different Bottom TabView Chrome between Shot 1 and Shot 2
                if compactTab {
                    UIColor(red: 0.14, green: 0.16, blue: 0.22, alpha: 1).setFill()
                    UIBezierPath(roundedRect: CGRect(x: 110, y: 1795, width: 680, height: 110), cornerRadius: 55).fill()
                    UIColor(white: 0.20, alpha: 1).setFill()
                    ctx.fill(CGRect(x: 320, y: 1922, width: 260, height: 8))
                } else {
                    // Vivid orange tab bar highlight (must NEVER remain inside the middle seam!)
                    UIColor(red: 0.99, green: 0.45, blue: 0.08, alpha: 1).setFill()
                    ctx.fill(CGRect(x: 0, y: 1710, width: 900, height: 240))
                    UIColor(white: 0.15, alpha: 1).setFill()
                    ctx.fill(CGRect(x: 320, y: 1922, width: 260, height: 8))
                }
            }
        }

        let shot1 = iOS26Shot(offsetY: 0, largeHeader: true, compactTab: false)
        let shot2 = iOS26Shot(offsetY: 1237, largeHeader: false, compactTab: true)

        let expectedHeight = 1950 + 1237 // 3187 px
        let stitched = try LongScreenshotStitcher.stitch(images: [shot1, shot2], options: .init(smartOverlap: true))
        #expect(stitched.stitchedOverlapCount == 1, "Should still merge differing TabView & collapsing header shots")
        #expect(abs(stitched.image.height - expectedHeight) <= 4, "Expected ~\(expectedHeight)px, got \(stitched.image.height)")

        // Verify Shot 1's orange bottom TabView (R~252, G~115, B~20) and Shot 2's teal inline header (R~20, G~107, B~122)
        // are completely excluded from the stitched middle junction (y in 1350...1750).
        let raw = bytes(stitched.image)
        let rowStride = stitched.image.width * 4
        var orangeChromeRows = 0
        var tealHeaderRows = 0
        for y in 1350..<min(stitched.image.height, 1750) {
            let p = y * rowStride + 250 * 4
            let r = Int(raw[p]), g = Int(raw[p + 1]), b = Int(raw[p + 2])
            if r > 235 && g < 130 && b < 45 {
                orangeChromeRows += 1
            }
            if r < 40 && abs(g - 107) < 25 && abs(b - 122) < 25 {
                tealHeaderRows += 1
            }
        }
        #expect(orangeChromeRows == 0, "Bottom TabView must not remain in the middle seam")
        #expect(tealHeaderRows == 0, "Top NavigationBar must not remain in the middle seam")
    }

    @Test
    func longScreenshotManualSeamAdjustmentGapAndEdgeCropping() throws {
        let img1 = Sample.solid(width: 600, height: 1000, fill: Sample.white)
        let img2 = Sample.solid(width: 600, height: 1000, fill: UIColor(white: 0.92, alpha: 1).cgColor)

        let layout = try LongScreenshotStitcher.computeVerticalLayout(
            images: [img1, img2],
            options: .init(direction: .vertical, smartOverlap: false)
        )
        #expect(layout.seams.count == 1)

        // Manual seam edit: cut 120px off bottom of frame 1, cut 90px off top of frame 2, add 40px red divider gap.
        let editedSeams = [
            LongScreenshotStitcher.SeamAdjustment(
                prevCutY: 880,
                currStartY: 90,
                gap: 40,
                isAutoMatched: false
            )
        ]
        let customRed = CustomColorRGB(red: 0.92, green: 0.15, blue: 0.20)
        let rendered = try LongScreenshotStitcher.renderVertical(
            layout: layout,
            seams: editedSeams,
            crop: .zero,
            dividerColor: customRed
        )
        let expectedUnCroppedH = 880 + 40 + 910 // 1830
        #expect(rendered.image.height == expectedUnCroppedH)
        #expect(rendered.image.width == 600)

        // Check pixel inside the 40px gap (top-down y = 900). Note `bytes(_:)` stores rows bottom-up,
        // so top-down y maps to `(height - 1 - y)`.
        let raw = bytes(rendered.image)
        let gapRowInBytes = rendered.image.height - 1 - 900
        let gapPixel = gapRowInBytes * rendered.image.width * 4 + 300 * 4
        #expect(raw[gapPixel] > 210 && raw[gapPixel + 1] < 75 && raw[gapPixel + 2] < 80,
                "Expected red divider pixel, got rgba=(\(raw[gapPixel]),\(raw[gapPixel+1]),\(raw[gapPixel+2]),\(raw[gapPixel+3]))")

        // Seam close-up preview renders centered junction with gap.
        let preview = try #require(LongScreenshotStitcher.renderSeamPreview(
            previous: layout.orderedImages[0],
            current: layout.orderedImages[1],
            seam: editedSeams[0],
            bandPixels: 120,
            dividerColor: customRed
        ))
        #expect(preview.width == 600)
        #expect(preview.height == 120 + 40 + 120)

        // Left 10% + Right 15% + Top 5% + Bottom 10% crop shrinks output dimensions precisely.
        let cropped = try LongScreenshotStitcher.renderVertical(
            layout: layout,
            seams: editedSeams,
            crop: LongScreenshotStitcher.CropInsets(left: 0.10, right: 0.15, top: 0.05, bottom: 0.10),
            dividerColor: customRed
        )
        #expect(abs(cropped.image.width - 450) <= 2)
        #expect(abs(cropped.image.height - Int((Double(expectedUnCroppedH) * 0.85).rounded())) <= 2)

        // Suggested chrome trim produces non-trivial top & bottom trim values for unmatched seams.
        let suggested = LongScreenshotStitcher.suggestedChromeTrim(
            previous: layout.orderedImages[0],
            current: layout.orderedImages[1]
        )
        #expect(suggested.prevCutY < layout.orderedImages[0].height)
        #expect(suggested.currStartY > 0)
    }

    @Test
    func deviceFrameRendererSupportsAll29Latest2026Models9AppStoreTemplatesAndScaling() throws {
        let baseScreen = Sample.text("13800138000", at: CGPoint(x: 30, y: 200))

        // Every single one of the 29 selectable 2026 Apple models across all 8 categories renders cleanly.
        #expect(AppleDeviceModel.allCases.count == 29)
        #expect(DeviceCategory.allCases.filter { $0 != .none }.count == 8)
        #expect(DeviceShowcaseTemplate.allCases.count == 9)

        for deviceModel in AppleDeviceModel.allCases {
            let framed = DeviceFrameRenderer.render(
                screen: baseScreen,
                options: DeviceFrameOptions(
                    model: deviceModel,
                    finish: deviceModel.availableFinishes.first ?? .silver,
                    showsBackground: true,
                    backdropKind: .gradient,
                    gradientPreset: .mist
                )
            )
            #expect(framed.width >= 700, "\(deviceModel.displayName) width should be high-res")
            #expect(framed.height >= 700, "\(deviceModel.displayName) height should be high-res")
        }

        // All 9 App Store directional showcase templates render distinct valid frames cleanly.
        for tpl in DeviceShowcaseTemplate.allCases {
            let framed = DeviceFrameRenderer.render(
                screen: baseScreen,
                options: DeviceFrameOptions(
                    model: .iPhone18ProMax,
                    finish: .burgundy,
                    template: tpl,
                    heroTitle: "QuickCover",
                    heroSubtitle: "Privacy in One Tap",
                    showsBackground: true,
                    backdropKind: .gradient,
                    gradientPreset: .obsidian
                )
            )
            #expect(framed.width >= 750, "\(tpl) width should be valid, got \(framed.width)")
            #expect(framed.height >= 900, "\(tpl) height should be valid, got \(framed.height)")
        }

        // Background OFF yields tight transparent PNG cutout (alpha == 0 in corner) even under 3D perspective.
        let cutoutPerspWatch = DeviceFrameRenderer.render(
            screen: baseScreen,
            options: DeviceFrameOptions(
                model: .watchUltra4,
                finish: .naturalTitanium,
                template: .perspectiveLeft,
                showsBackground: false
            )
        )
        let cornerBytes = bytes(cutoutPerspWatch)
        #expect(cornerBytes[3] == 0, "background-off Watch Ultra 4 3D cutout corner has alpha == 0")

        let bgWatchUltra = DeviceFrameRenderer.render(
            screen: baseScreen,
            options: DeviceFrameOptions(
                model: .watchUltra4,
                finish: .naturalTitanium,
                showsBackground: true,
                backdropKind: .solidColor,
                solidBackgroundColor: CustomColorRGB(red: 0.95, green: 0.25, blue: 0.40)
            )
        )
        #expect(bgWatchUltra.width > cutoutPerspWatch.width, "background ON adds studio padding around hardware")
        let bgCorner = bytes(bgWatchUltra)
        #expect(bgCorner[0] > 210 && bgCorner[1] < 90 && bgCorner[3] == 255, "custom RGB solid background paints exact color")

        // Post-frame overall outputScale shrinks final pixel resolution cleanly.
        let halfScaled = DeviceFrameRenderer.render(
            screen: baseScreen,
            options: DeviceFrameOptions(
                model: .appleTV4KGen4,
                finish: .spaceBlack,
                showsBackground: true,
                outputScale: 0.5
            )
        )
        let fullScaled = DeviceFrameRenderer.render(
            screen: baseScreen,
            options: DeviceFrameOptions(
                model: .appleTV4KGen4,
                finish: .spaceBlack,
                showsBackground: true,
                outputScale: 1.0
            )
        )
        #expect(abs(halfScaled.width * 2 - fullScaled.width) <= 2)
        #expect(abs(halfScaled.height * 2 - fullScaled.height) <= 2)

        // Post-frame bottom badge and full-canvas tiled watermarks visibly paint over the framed canvas.
        let frameOpts = DeviceFrameOptions(
            model: .iPhoneDuo,
            finish: .starWhite,
            showsBackground: true,
            backdropKind: .solidColor,
            solidBackgroundColor: CustomColorRGB(red: 0.96, green: 0.96, blue: 0.98)
        )
        let plainFramed = MaskRenderer.flatten(baseScreen, findings: [], appearance: .default, deviceFrame: frameOpts)
        let badgeWM = WatermarkOptions(
            isEnabled: true,
            text: "@QuickCover",
            opacity: 0.45,
            tint: .slate,
            placement: .bottomBadge,
            showsDeviceModel: true
        )
        let badgedFramed = MaskRenderer.flatten(
            baseScreen,
            findings: [],
            appearance: MaskAppearance(watermark: badgeWM),
            deviceFrame: frameOpts
        )
        #expect(badgedFramed.height > plainFramed.height, "bottomBadge reserves clean footer caption space")

        let fullCanvasWM = WatermarkOptions(
            isEnabled: true,
            text: "CONFIDENTIAL",
            opacity: 0.42,
            density: .dense,
            tint: .red,
            placement: .fullCanvasTiled
        )
        let fullTiledFramed = MaskRenderer.flatten(
            baseScreen,
            findings: [],
            appearance: MaskAppearance(watermark: fullCanvasWM),
            deviceFrame: frameOpts
        )
        #expect(bytes(fullTiledFramed) != bytes(plainFramed), "fullCanvasTiled watermark renders across backdrop")

        // Background-off hardware cutout forces PNG output even when JPEG export format is requested.
        let src = try #require(CGImageSourceCreateWithData(Sample.jpeg(baseScreen) as CFData, nil))
        let pngData = try MaskRenderer.encode(
            src,
            orientation: .up,
            findings: [],
            options: MaskRenderer.Options(
                format: .jpeg,
                deviceFrame: DeviceFrameOptions(model: .macStudioM5Ultra, finish: .silver, showsBackground: false)
            )
        )
        let encodedSource = try #require(CGImageSourceCreateWithData(pngData as CFData, nil))
        #expect(CGImageSourceGetType(encodedSource) as String? == "public.png")
    }

    @Test
    func exportAspectRatioPresetsRenderExactRatiosInFitFillAndDeviceFrameModes() {
        #expect(ExportAspectRatio.allCases.count == 15)
        for cat in ExportAspectCategory.allCases {
            #expect(!ExportAspectRatio.presets(in: cat).isEmpty)
        }
        let tallImage = Sample.solid(width: 900, height: 1800, fill: Sample.white)

        // All explicit aspect ratios produce exact proportions in both Fit and Fill modes.
        for preset in ExportAspectRatio.allCases {
            guard let expectedRatio = preset.ratio else { continue }

            let fitted = MaskRenderer.applyExportAspectRatio(
                tallImage,
                ratio: preset,
                fitMode: .fit,
                backdrop: .dark
            )
            let fitRatio = CGFloat(fitted.width) / CGFloat(fitted.height)
            #expect(abs(fitRatio - expectedRatio) < 0.025, "\(preset.rawValue) fit ratio mismatch: \(fitRatio) vs \(expectedRatio)")

            let cropped = MaskRenderer.applyExportAspectRatio(
                tallImage,
                ratio: preset,
                fitMode: .fill
            )
            let fillRatio = CGFloat(cropped.width) / CGFloat(cropped.height)
            #expect(abs(fillRatio - expectedRatio) < 0.025, "\(preset.rawValue) fill ratio mismatch: \(fillRatio) vs \(expectedRatio)")
        }

        // Fit with .light backdrop fills surrounding canvas with light neutral tone.
        let wechatFit = MaskRenderer.applyExportAspectRatio(
            tallImage,
            ratio: .wechatCover,
            fitMode: .fit,
            backdrop: .light
        )
        let wechatBytes = bytes(wechatFit)
        #expect(wechatBytes[0] > 235 && wechatBytes[1] > 235 && wechatBytes[2] > 235)

        // Device frame studio canvas inherits App Store 6.9" export aspect ratio cleanly without double margins.
        let framedAppStore = MaskRenderer.flatten(
            tallImage,
            findings: [],
            appearance: .default,
            deviceFrame: DeviceFrameOptions(model: .iPhone18ProMax, showsBackground: true, canvasAspect: .auto),
            exportAspectRatio: .appStorePhone69
        )
        let framedRatio = CGFloat(framedAppStore.width) / CGFloat(framedAppStore.height)
        #expect(abs(framedRatio - (1320.0 / 2868.0)) < 0.025)
    }

    @Test
    func screenRecordingStitchDiscardsOverlaysPausesBounceBacksAndSupportsComposition() async throws {
        let frameW = 390
        let frameH = 840
        let docH = 2200

        // Build a 2200px tall document with distinct colorful UI cards so every scroll offset has rich unique features.
        let docCtx = try #require(CGImage.rgbaContext(width: frameW, height: docH))
        docCtx.setFillColor(CGColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1))
        docCtx.fill(CGRect(x: 0, y: 0, width: frameW, height: docH))

        let rowStep = 95
        for idx in 0..<(docH / rowStep) {
            let yTop = idx * rowStep + 14
            let yGL = docH - yTop - 68
            let hueA = CGFloat((idx * 37) % 256) / 255.0
            let hueB = CGFloat((idx * 89 + 70) % 256) / 255.0
            let hueC = CGFloat((idx * 131 + 140) % 256) / 255.0
            docCtx.setFillColor(CGColor(red: 0.93, green: 0.94, blue: 0.96, alpha: 1))
            docCtx.fill(CGRect(x: 16, y: yGL, width: frameW - 32, height: 68))
            docCtx.setFillColor(CGColor(red: hueA, green: hueB, blue: hueC, alpha: 1))
            docCtx.fill(CGRect(x: 24, y: yGL + 14, width: 40, height: 40))

            let bar1W = 80 + ((idx * 47) % 190)
            let bar2W = 60 + ((idx * 73) % 210)
            docCtx.setFillColor(CGColor(red: 0.14, green: 0.16, blue: 0.22, alpha: 1))
            docCtx.fill(CGRect(x: 78, y: yGL + 38, width: bar1W, height: 14))
            docCtx.setFillColor(CGColor(red: 0.35, green: 0.40, blue: 0.48, alpha: 1))
            docCtx.fill(CGRect(x: 78, y: yGL + 14, width: bar2W, height: 12))
        }
        let docImage = try #require(docCtx.makeImage())

        func makeControlCenterFrame() throws -> CGImage {
            let ctx = try #require(CGImage.rgbaContext(width: frameW, height: frameH))
            ctx.setFillColor(CGColor(red: 0.94, green: 0.08, blue: 0.78, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: frameW, height: frameH))
            ctx.setFillColor(CGColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1))
            ctx.fill(CGRect(x: 36, y: 180, width: 144, height: 220))
            ctx.fill(CGRect(x: 210, y: 260, width: 144, height: 180))
            return try #require(ctx.makeImage())
        }

        func makeScrollFrame(offsetY: Int) throws -> CGImage {
            let clamped = max(0, min(docH - frameH, offsetY))
            let slice = try #require(docImage.cropping(to: CGRect(x: 0, y: clamped, width: frameW, height: frameH)))
            let ctx = try #require(CGImage.rgbaContext(width: frameW, height: frameH))
            ctx.draw(slice, in: CGRect(x: 0, y: 0, width: frameW, height: frameH))
            // Overlay fixed status bar (top) & home indicator (bottom) like a real iPhone screen recording.
            ctx.setFillColor(CGColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1))
            ctx.fill(CGRect(x: 0, y: frameH - 34, width: frameW, height: 34))
            ctx.setFillColor(CGColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1))
            ctx.fill(CGRect(x: 155, y: frameH - 22, width: 80, height: 10))
            ctx.fill(CGRect(x: 130, y: 10, width: 130, height: 5))
            return try #require(ctx.makeImage())
        }

        let controlCenter = try makeControlCenterFrame()
        // 10 fps timeline (~3.0s): Control Center -> Scroll 0...680 -> Pause -> Bounce up -> Resume 680...1360 -> Control Center
        let offsets: [Int?] = [
            nil, nil, nil, nil,
            0, 85, 170, 255, 340, 425, 510, 595, 680,
            680, 680, 680,
            590, 635,
            680, 765, 850, 935, 1020, 1105, 1190, 1275, 1360,
            nil, nil, nil, nil
        ]

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuickCoverVideoTest-\(UUID().uuidString).mov")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let writer = try AVAssetWriter(outputURL: tempURL, fileType: .mov)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: frameW,
            AVVideoHeightKey: frameH,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 2_800_000,
                AVVideoMaxKeyFrameIntervalKey: 10,
            ],
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: frameW,
                kCVPixelBufferHeightKey as String: frameH,
            ]
        )
        #expect(writer.canAdd(input))
        writer.add(input)
        #expect(writer.startWriting())
        writer.startSession(atSourceTime: .zero)

        for (index, offset) in offsets.enumerated() {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(5))
            }
            let frameImage = try offset.map { try makeScrollFrame(offsetY: $0) } ?? controlCenter
            var pxBuf: CVPixelBuffer?
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                frameW,
                frameH,
                kCVPixelFormatType_32BGRA,
                nil,
                &pxBuf
            )
            let buffer = try #require(pxBuf)
            CVPixelBufferLockBaseAddress(buffer, [])
            let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
            if let base = CVPixelBufferGetBaseAddress(buffer),
               let ctx = CGContext(
                   data: base,
                   width: frameW,
                   height: frameH,
                   bitsPerComponent: 8,
                   bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                   space: CGColorSpaceCreateDeviceRGB(),
                   bitmapInfo: bitmapInfo
               ) {
                ctx.draw(frameImage, in: CGRect(x: 0, y: 0, width: frameW, height: frameH))
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])

            let pts = CMTime(value: CMTimeValue(index), timescale: 10)
            #expect(adaptor.append(buffer, withPresentationTime: pts))
        }
        input.markAsFinished()
        await writer.finishWriting()
        #expect(writer.status == .completed)

        // Exercise both AVURLAsset and an AVMutableComposition (trimmed Photos recording path).
        let urlAsset = AVURLAsset(url: tempURL)
        let urlLayout = try await LongScreenshotStitcher.stitchVideoLayout(
            asset: urlAsset,
            options: .init(videoPrecision: .standard)
        )
        #expect(urlLayout.orderedImages.count >= 2)
        #expect(urlLayout.seams.allSatisfy { $0.isAutoMatched })

        let rendered = try LongScreenshotStitcher.renderVertical(layout: urlLayout, seams: urlLayout.seams)
        #expect(
            rendered.image.height >= docH - 45 && rendered.image.height <= docH + 45,
            "Unexpected stitched height: \(rendered.image.height), frames=\(urlLayout.orderedImages.count), seams=\(urlLayout.seams)"
        )

        // Confirm Control Center magenta panels at both ends were completely stripped.
        let outBytes = bytes(rendered.image)
        let w = rendered.image.width
        let h = rendered.image.height
        var magentaCount = 0
        let checkRows = Array(0..<min(40, h)) + Array(max(0, h - 40)..<h)
        for y in checkRows {
            for x in Swift.stride(from: 8, to: w - 8, by: 8) {
                let p = ((h - 1 - y) * w + x) * 4
                let r = outBytes[p], g = outBytes[p + 1], b = outBytes[p + 2]
                if r > 200 && g < 60 && b > 150 {
                    magentaCount += 1
                }
            }
        }
        #expect(magentaCount == 0)

        // Verify AVComposition support directly.
        let composition = AVMutableComposition()
        let compDuration = try await urlAsset.load(.duration)
        if let srcTrack = try await urlAsset.loadTracks(withMediaType: .video).first,
           let dstTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
            try dstTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: compDuration),
                of: srcTrack,
                at: .zero
            )
            let compLayout = try await LongScreenshotStitcher.stitchVideoLayout(
                asset: composition,
                options: .init(videoPrecision: .standard)
            )
            let compRendered = try LongScreenshotStitcher.renderVertical(layout: compLayout, seams: compLayout.seams)
            #expect(compRendered.image.height >= docH - 45 && compRendered.image.height <= docH + 45)
        }
    }

    @Test
    func framelessBackdropCustomGradientAndBackgroundImageCompositeCleanly() {
        let fg = Sample.solid(width: 400, height: 800, fill: Sample.white)

        // 1. Frameless mode (no device model) renders rounded cutout over a solid palette color.
        var solidOpts = DeviceFrameOptions(
            model: nil,
            showsBackground: true,
            backdropKind: .solidColor,
            solidBackgroundColor: CustomColorRGB(red: 0.10, green: 0.50, blue: 0.90)
        )
        solidOpts.enableFramelessBackdrop = true
        let solidOut = MaskRenderer.flatten(
            fg,
            findings: [],
            appearance: .default,
            deviceFrame: solidOpts
        )
        #expect(solidOut.width > fg.width && solidOut.height > fg.height)
        let solidCorner = bytes(solidOut)
        #expect(solidCorner[0] < 45 && solidCorner[1] > 105 && solidCorner[2] > 205)

        // 2. Custom multi-stop gradient synthesis supports 3 stops & multiple directions.
        var gradOpts = DeviceFrameOptions(
            model: nil,
            showsBackground: true,
            backdropKind: .gradient,
            canvasAspect: .portrait3x4
        )
        gradOpts.enableFramelessBackdrop = true
        gradOpts.usesCustomGradient = true
        gradOpts.customGradientStart = CustomColorRGB(red: 0.96, green: 0.12, blue: 0.18)
        gradOpts.customGradientMid = CustomColorRGB(red: 0.20, green: 0.85, blue: 0.45)
        gradOpts.customGradientEnd = CustomColorRGB(red: 0.10, green: 0.25, blue: 0.96)
        gradOpts.gradientDirection = .vertical
        let gradOut = DeviceFrameRenderer.render(screen: fg, options: gradOpts)
        let gradBytes = bytes(gradOut)
        // `bytes(_:)` stores rows bottom-up: `(height - 1 - y)` indexes top-down visual coordinates.
        let topPx = ((gradOut.height - 1 - 8) * gradOut.width + gradOut.width / 2) * 4
        let botPx = (8 * gradOut.width + gradOut.width / 2) * 4
        #expect(gradBytes[topPx] > 180 && gradBytes[topPx + 2] < 80)
        #expect(gradBytes[botPx + 2] > 180 && gradBytes[botPx] < 80)

        // Radial gradient renders cleanly.
        gradOpts.gradientDirection = .radial
        let radialOut = DeviceFrameRenderer.render(screen: fg, options: gradOpts)
        #expect(radialOut.width > fg.width)

        // 3. Custom background image compositing with Xiaohongshu 3:4 aspect ratio, blur & dim.
        let bgPhoto = Sample.solid(
            width: 600,
            height: 800,
            fill: CGColor(red: 0.15, green: 0.72, blue: 0.36, alpha: 1.0)
        )
        var photoOpts = DeviceFrameOptions(
            model: nil,
            template: .tiltRight,
            showsBackground: true,
            backdropKind: .customImage
        )
        photoOpts.enableFramelessBackdrop = true
        photoOpts.customBackgroundImage = CustomBackdropImage(image: bgPhoto)
        photoOpts.customImageBlur = 0.25
        photoOpts.customImageDim = 0.15

        let photoOut = MaskRenderer.flatten(
            fg,
            findings: [],
            appearance: .default,
            deviceFrame: photoOpts,
            exportAspectRatio: .xiaohongshu3x4
        )
        let ratio = CGFloat(photoOut.width) / CGFloat(photoOut.height)
        #expect(abs(ratio - 0.75) < 0.025)
        let photoBytes = bytes(photoOut)
        #expect(photoBytes[1] > photoBytes[0] && photoBytes[1] > photoBytes[2])
    }

    @Test
    func longScreenshotAutoReordersArbitrarilyScrambledScreenshots() throws {
        let w = 390
        let fullH = 1800
        let winH = 600
        let step = 380

        let ctx = try #require(CGImage.rgbaContext(width: w, height: fullH))
        ctx.setFillColor(CGColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: fullH))
        for i in 0..<(fullH / 60) {
            let yGL = fullH - (i * 60 + 48)
            let r = CGFloat((i * 41) % 256) / 255.0
            let g = CGFloat((i * 83 + 50) % 256) / 255.0
            let b = CGFloat((i * 127 + 100) % 256) / 255.0
            ctx.setFillColor(CGColor(red: 0.92, green: 0.93, blue: 0.95, alpha: 1))
            ctx.fill(CGRect(x: 16, y: yGL, width: w - 32, height: 42))
            ctx.setFillColor(CGColor(red: r, green: g, blue: b, alpha: 1))
            ctx.fill(CGRect(x: 24, y: yGL + 7, width: 28, height: 28))
            let barW = 70 + ((i * 53) % 200)
            ctx.setFillColor(CGColor(red: 0.14, green: 0.16, blue: 0.22, alpha: 1))
            ctx.fill(CGRect(x: 68, y: yGL + 16, width: barW, height: 12))
        }
        let doc = try #require(ctx.makeImage())

        let slices = (0..<4).map { idx in
            doc.cropping(to: CGRect(x: 0, y: idx * step, width: w, height: winH))!
        }
        let expectedH = 3 * step + winH

        for perm in [[2, 0, 3, 1], [3, 1, 0, 2]] {
            let scrambled = perm.map { slices[$0] }
            let layout = try LongScreenshotStitcher.computeVerticalLayout(
                images: scrambled,
                options: .init(direction: .vertical, smartOverlap: true, allowReverseOrder: true)
            )
            #expect(layout.seams.count == 3, "seams count=\(layout.seams.count), perm=\(perm), seams=\(layout.seams)")
            #expect(layout.seams.allSatisfy { $0.isAutoMatched }, "perm=\(perm), seams=\(layout.seams)")
            let rendered = try LongScreenshotStitcher.renderVertical(layout: layout, seams: layout.seams)
            #expect(abs(rendered.image.height - expectedH) <= 8, "perm=\(perm), height=\(rendered.image.height), expected=\(expectedH)")
        }
    }

    @Test
    func officialAppleProductBezelsLoadAndCompositeAllCategories() {
        #expect(DeviceFrameRenderer.OfficialBezelCatalog.isAvailable)
        let screen = Sample.solid(width: 480, height: 960, fill: CGColor(red: 0.20, green: 0.55, blue: 0.92, alpha: 1.0))

        let modelsToVerify: [AppleDeviceModel] = [
            .watchUltra4,
            .watchSeries12_46,
            .watchSeries12_42,
            .watchSE3,
            .iPhone18ProMax,
            .iPhoneDuo,
            .iPadPro13M5,
            .macBookPro16M5Max,
            .iMac24M4,
            .studioDisplay2026,
            .macStudioM5Ultra,
            .appleTV4KGen4,
        ]

        for model in modelsToVerify {
            let finish = model.availableFinishes.first ?? .silver
            let entry = DeviceFrameRenderer.OfficialBezelCatalog.entry(for: model, finish: finish)
            #expect(entry != nil, "Missing official bezel manifest entry for \(model.rawValue)")
            if let entry {
                #expect(DeviceFrameRenderer.OfficialBezelCatalog.bezelCGImage(for: entry) != nil, "Missing bezel PNG \(entry.file)")
            }

            let cutout = DeviceFrameRenderer.render(
                screen: screen,
                options: DeviceFrameOptions(
                    model: model,
                    finish: finish,
                    showsBackground: false
                )
            )
            #expect(cutout.width >= 400 && cutout.height >= 400)
            let cornerAlpha = bytes(cutout)[3]
            #expect(cornerAlpha == 0, "\(model.displayName) should preserve transparent outer corners")
        }
    }

    @Test
    func longScreenshotInsideIPhoneBezelAndStitcherNeverTruncateBottom() throws {
        // 1:6 long screenshot with bright red top band (y_top 0..<200) and bright blue bottom band (y_top 2680..<2880).
        let w = 480
        let h = 2880
        let ctx = try #require(CGImage.rgbaContext(width: w, height: h))
        ctx.setFillColor(CGColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        // CGContext Y=0 is bottom-left.
        ctx.setFillColor(CGColor(red: 0.95, green: 0.15, blue: 0.15, alpha: 1.0))
        ctx.fill(CGRect(x: 0, y: h - 200, width: w, height: 200))
        ctx.setFillColor(CGColor(red: 0.12, green: 0.25, blue: 0.95, alpha: 1.0))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: 200))
        let longShot = try #require(ctx.makeImage())

        let cutout = DeviceFrameRenderer.render(
            screen: longShot,
            options: DeviceFrameOptions(
                model: .iPhone18ProMax,
                finish: .spaceBlack,
                showsBackground: false
            )
        )
        let aspect = Double(cutout.height) / Double(max(cutout.width, 1))
        #expect(aspect > 4.5, "Expected stretched iPhone bezel aspect > 4.5 for 1:6 long screenshot, got \(aspect)")

        let cutoutBytes = bytes(cutout)
        let rowStride = cutout.width * 4
        let sampleX = cutout.width / 2
        // Remember bytes(_:) is bottom-up: row ~94% of height is near top, row ~6% is near bottom.
        let topSampleY = Int(Double(cutout.height) * 0.94)
        let botSampleY = Int(Double(cutout.height) * 0.06)
        let topIdx = topSampleY * rowStride + sampleX * 4
        let botIdx = botSampleY * rowStride + sampleX * 4
        #expect(cutoutBytes[topIdx] > 180 && cutoutBytes[topIdx + 2] < 80, "Top red band should be preserved")
        #expect(cutoutBytes[botIdx + 2] > 180 && cutoutBytes[botIdx] < 80, "Bottom blue band must not be truncated")

        let studio = DeviceFrameRenderer.render(
            screen: longShot,
            options: DeviceFrameOptions(
                model: .iPhone17,
                finish: .blue,
                showsBackground: true,
                backdropKind: .solidColor,
                solidBackgroundColor: CustomColorRGB(red: 0.92, green: 0.93, blue: 0.95)
            )
        )
        #expect(studio.height > studio.width * 3, "Studio backdrop must keep tall height for long iPhone screenshot")
        let studioBytes = bytes(studio)
        let sStride = studio.width * 4
        let sX = studio.width / 2
        let hasTopRed = (Int(Double(studio.height) * 0.72)..<Int(Double(studio.height) * 0.96)).contains { y in
            let p = y * sStride + sX * 4
            return studioBytes[p] > 180 && studioBytes[p + 2] < 80
        }
        let hasBotBlue = (Int(Double(studio.height) * 0.04)..<Int(Double(studio.height) * 0.28)).contains { y in
            let p = y * sStride + sX * 4
            return studioBytes[p + 2] > 180 && studioBytes[p] < 80
        }
        #expect(hasTopRed, "Top red band should remain intact in studio frame")
        #expect(hasBotBlue, "Bottom blue band must not be truncated in studio frame")

        // Stitcher exceeding maxHeight scales proportionally instead of dropping bottom frames.
        let redFrame = Sample.solid(width: 300, height: 600, fill: CGColor(red: 0.95, green: 0.15, blue: 0.15, alpha: 1))
        let greenFrame = Sample.solid(width: 300, height: 600, fill: CGColor(red: 0.15, green: 0.85, blue: 0.25, alpha: 1))
        let blueFrame = Sample.solid(width: 300, height: 600, fill: CGColor(red: 0.12, green: 0.25, blue: 0.95, alpha: 1))
        let layout = try LongScreenshotStitcher.computeVerticalLayout(
            images: [redFrame, greenFrame, blueFrame],
            options: .init(direction: .vertical, smartOverlap: false)
        )
        let scaled = try LongScreenshotStitcher.renderVertical(layout: layout, seams: layout.seams, maxHeight: 900)
        #expect(scaled.image.height == 900)
        #expect(scaled.image.width == 150)
        let scaledBytes = bytes(scaled.image)
        let scaledBotIdx = 12 * scaled.image.width * 4 + (scaled.image.width / 2) * 4
        #expect(scaledBytes[scaledBotIdx + 2] > 180 && scaledBytes[scaledBotIdx] < 80, "Scaled stitch must retain final blue frame")
    }

    @Test
    func exportShareFileUsesConcreteExtensionAndWritesReadableImage() throws {
        let img = Sample.solid(width: 64, height: 64, fill: CGColor(red: 0.25, green: 0.55, blue: 0.90, alpha: 1))
        let src = try #require(CGImageSourceCreateWithData(Sample.jpeg(img) as CFData, nil))
        let pngData = try MaskRenderer.encode(
            src,
            orientation: .up,
            findings: [],
            options: MaskRenderer.Options(format: .png)
        )
        let url = try ExportActions.makeShareFileURL(data: pngData, fileType: .png)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(url.pathExtension == "png")
        let diskData = try Data(contentsOf: url)
        #expect(diskData == pngData)
        #expect(ExportActions.fileExtension(for: .jpeg) == "jpg")
        #expect(ExportActions.fileExtension(for: .heic) == "heic")
    }
}

struct PictureSourceTests {

    @Test
    func sidewaysPictureComesOutUpright() throws {
        let image = Sample.text("13812345678", at: CGPoint(x: 20, y: 20))
        let source = try PictureSource(data: Sample.jpeg(image, orientation: 6))
        #expect(source.orientation == .right)
        #expect(source.size == CGSize(width: 300, height: 600))
        let thumb = try #require(source.thumbnail(maxLongSide: 300))
        #expect(thumb.width == 150)
        #expect(thumb.height == 300)
        let full = try source.uprightImage()
        #expect(full.width == 300)
        #expect(full.height == 600)
    }

    @Test
    func plainPictureKeepsItsFacts() throws {
        let image = Sample.solid(width: 40, height: 30, fill: Sample.white)
        let source = try PictureSource(data: Sample.jpeg(image))
        #expect(source.orientation == .up)
        #expect(source.size == CGSize(width: 40, height: 30))
        #expect(source.fileType == .jpeg)
        #expect(source.thumbnail(maxLongSide: 20)?.width == 20)
    }
}
