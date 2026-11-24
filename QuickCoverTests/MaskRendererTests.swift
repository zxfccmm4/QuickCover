import CoreGraphics
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
