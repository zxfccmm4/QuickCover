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

    // MARK: - 遮盖取的是哪一块（修「小画布里只有框左下角那几个像素」）

    /// The box under test: 100×40 at (10, 10) in a 120×60 picture. The mosaic's `cell` comes to 12
    /// here (the floor is above 40 / 6), so it has 9 × 4 cells; the blur's is 10, 10 × 4.
    private static let coverBox = CGRect(x: 10, y: 10, width: 100, height: 40)

    private var cover: [Finding] { [Finding(kind: .text, quad: quad(Self.coverBox))] }

    /// A 120×60 white picture with `paint` added to it, drawn in UIKit's top-left coordinates.
    private func picture(_ paint: (UIGraphicsRendererContext) -> Void) -> CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let size = CGSize(width: 120, height: 60)
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
        // A cover 100×50 at (10, 5): `cell` is still 12, so five rows of cells. Black from the middle
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
        let findings = [Finding(kind: .text, quad: quad(box))]
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
        // The blur's grain is never under 10 pixels (the floor in `cell`), so the steepest thing a
        // picture holds, black next to white, is spread over at least 10 pixels: 255 / 10 ≈ 26 a pixel.
        // Stretching the grains is interpolated and rings a little at a hard step, so twice that.
        #expect(steepestStep(red, inside: Self.coverBox) <= 51)
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
        // A cover flush with the picture's top and right edges: 100×40 at (20, 0). Its cells must
        // still each be the mix of what lies under them, with none of the picture showing through.
        let box = CGRect(x: 20, y: 0, width: 100, height: 40)
        let flat = MaskRenderer.flatten(fineStripes(), findings: [Finding(kind: .text, quad: quad(box))], style: .mosaic)
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
