import CoreGraphics
import Foundation
import ImageIO
import Testing
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
