import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// How a covered area looks in the result.
enum MaskStyle: String, CaseIterable, Codable, Sendable {
    case mosaic
    case solid
    case blur

    /// Mosaic is the default: it hides well and still reads as "this was something".
    static let `default` = MaskStyle.mosaic
}

/// Presses the masks into the pixels. Pure CoreGraphics, so a 48 MP picture costs about
/// two copies of its pixels and nothing more.
enum MaskRenderer {

    struct Options: Sendable {
        var style: MaskStyle = .default
        /// The export leaves out location and other metadata of the original.
        var stripMetadata = true
        var quality = 0.95
        /// How coarse the blur is. The app leaves it at the shipped grain; the probe tries others.
        var blurGrain: BlurGrain = .default
    }

    /// How coarse the blur is over a face: a face `height` pixels tall gets one blurred grain to
    /// every `divisor`th of its height, but never one under `floor` pixels. Everything else is cut
    /// by a base or, drawn by hand, by its own height, its blur the same way as its mosaic (`grid`).
    struct BlurGrain: Equatable, Sendable {
        var divisor: CGFloat
        var floor: CGFloat

        func cell(forHeight height: CGFloat) -> CGFloat { max(floor, height / divisor) }

        /// The numbers a mosaic over a face is cut by. Measured on the fixtures
        /// (`RenderProbeTests`) while text was still cut this way: with a tenth and a floor of 10,
        /// Vision still read runs of 3–5 characters of card and ID numbers through the blur; with
        /// these, no more than one character in a row.
        static let `default` = BlurGrain(divisor: 6, floor: 12)
    }

    /// The grains one covered box is cut into: the mosaic's cells, or, for the blur, the pixels the
    /// part of the picture under it is squeezed through. `columns` across and `rows` down, they
    /// share the box exactly between them (`grain(in:)`), so a cover never reaches past its box.
    struct Grid: Equatable, Sendable {
        let columns: Int
        let rows: Int

        /// One grain over `bounds`.
        func grain(in bounds: CGRect) -> CGSize {
            CGSize(width: bounds.width / CGFloat(columns), height: bounds.height / CGFloat(rows))
        }
    }

    /// The smallest base, in pixels of the picture: no cell is under it but a single one over a
    /// box narrower than it.
    static let mosaicFloor: CGFloat = 12

    enum Failure: Error {
        case cannotDecode
        case cannotEncode
    }

    /// The encoded result file: same pixel size as the source, upright, masks pressed in.
    static func encode(_ source: CGImageSource, orientation: CGImagePropertyOrientation,
                       findings: [Finding], options: Options = Options()) throws -> Data {
        let decode = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let raw = CGImageSourceCreateImageAtIndex(source, 0, decode) else { throw Failure.cannotDecode }
        let upright = raw.oriented(orientation)
        let flat = flatten(upright, findings: findings, style: options.style, blurGrain: options.blurGrain)

        let fileType = (CGImageSourceGetType(source) as String?) ?? UTType.jpeg.identifier
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, fileType as CFString, 1, nil) else { throw Failure.cannotEncode }
        var properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: options.quality]
        if !options.stripMetadata, let original = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            // The pixels are upright already, so the rotation tag must not be carried over.
            var tiff = original[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
            tiff[kCGImagePropertyTIFFOrientation] = 1
            properties[kCGImagePropertyTIFFDictionary] = tiff
            if let exif = original[kCGImagePropertyExifDictionary] { properties[kCGImagePropertyExifDictionary] = exif }
            if let gps = original[kCGImagePropertyGPSDictionary] { properties[kCGImagePropertyGPSDictionary] = gps }
        }
        CGImageDestinationAddImage(destination, flat, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw Failure.cannotEncode }
        return data as Data
    }

    /// `image` is upright; findings are in its pixels, top-left origin.
    static func flatten(_ image: CGImage, findings: [Finding], style: MaskStyle,
                        blurGrain: BlurGrain = .default) -> CGImage {
        guard !findings.isEmpty, let context = CGImage.rgbaContext(width: image.width, height: image.height) else { return image }
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // From here on the context works in top-left pixel coordinates, the same as findings.
        context.translateBy(x: 0, y: height)
        context.scaleBy(x: 1, y: -1)
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        for finding in findings {
            // Every box apart: a value wrapped onto two lines is two boxes, and what lies between
            // them on the picture stays as it is.
            for quad in finding.quads {
                let path = quadPath(quad)
                switch style {
                case .solid:
                    context.addPath(path)
                    context.fillPath()
                case .mosaic, .blur:
                    cover(from: image, rect: Geometry.bounds(of: quad), path: path, finding: finding,
                          into: context, style: style, blurGrain: blurGrain)
                }
            }
        }
        return context.makeImage() ?? image
    }

    /// How `bounds`, the cover over `finding`, is cut under `style` (`Grid`). Solid has no grains.
    ///
    /// Everything but a face is cut by a base, and the blur over it through the same grains as its
    /// mosaic, so that it is as coarse. The box is one or two cells high, never more (`rows`), and
    /// as many cells across as whole ones the base wide fit (`columns`); the cells share the box
    /// exactly, so nothing is pasted over what was not to be hidden.
    ///
    /// Text the recognizer read has its base in the height of its letters. Ato looked at the
    /// exported pictures pixel by pixel (2026-11-24, message 1930), when every text box was cut
    /// into six rows whatever the size of its letters: no digit could be read, but each left its
    /// own pattern of light and dark cells, the two 1s of a card number as two thin bright bars
    /// one cell wide, the three 6s as one picture. So a cell is never smaller than a letter is
    /// tall. The measure is the height of Vision's box for the tallest piece of the text, taken
    /// before the padding and the widening (`Finding.textHeight`): a little more than the glyphs,
    /// so the cell is a little more than the letter. The base is never less than half the box's
    /// height either, so a block of three lines or more gets wider cells, nor under
    /// `mosaicFloor`. When the height is missing, which nothing in the app produces, half the
    /// box's height stands in for it.
    ///
    /// Codes have no letters to go by: their base is half the box's height, never under
    /// `mosaicFloor`.
    ///
    /// A box drawn by hand gets one row of cells, each the box's height wide and tall. Nobody
    /// knows what is under it: most likely a line of text the recognizer did not read, or a small
    /// thing. Such a cover comes without the notice that a mosaic leaves traces (copy 6.3.3), so
    /// it must not give more away than the covers over text that was read. Cut by half the box's
    /// height, a box drawn round one line of text would get cells half a letter tall; in one row
    /// a cell covers several letters, as coarse as the mosaic over read text or coarser (Ato,
    /// message 1951).
    ///
    /// A face is cut by the height of what is hidden, as it always was: the mosaic in cells a
    /// sixth of it, never under `mosaicFloor`; the blur in `blurGrain`.
    static func grid(over bounds: CGRect, hiding finding: Finding, style: MaskStyle,
                     blurGrain: BlurGrain = .default) -> Grid {
        guard style != .solid else { return Grid(columns: 1, rows: 1) }
        if finding.kind == .face {
            let cell = style == .mosaic ? max(mosaicFloor, bounds.height / 6) : blurGrain.cell(forHeight: bounds.height)
            return Grid(columns: max(1, Int((bounds.width / cell).rounded(.up))),
                        rows: max(1, Int((bounds.height / cell).rounded(.up))))
        }
        if finding.drawnByHand {
            return Grid(columns: max(1, whole(bounds.width / max(bounds.height, mosaicFloor))), rows: 1)
        }
        return grid(over: bounds, base: base(over: bounds, textHeight: finding.textHeight))
    }

    /// The base text that was read and codes are cut by: the height of the tallest piece of text
    /// read under the box (`textHeight`), half the box's height and `mosaicFloor`, whichever is
    /// largest.
    static func base(over bounds: CGRect, textHeight: CGFloat?) -> CGFloat {
        max(mosaicFloor, bounds.height / 2, textHeight ?? 0)
    }

    /// `grid` for a box cut by `base`: whole ones across, one row or two down.
    static func grid(over bounds: CGRect, base: CGFloat) -> Grid {
        Grid(columns: max(1, whole(bounds.width / base)),
             rows: max(1, min(2, whole(bounds.height / base))))
    }

    /// `value` rounded down, a rounding error's hair under a whole number counted as that whole
    /// number: the quotient of a box and half its height is two, not one and a hair short of it.
    private static func whole(_ value: CGFloat) -> Int {
        value.isFinite ? max(0, Int((value + 1e-9).rounded(.down))) : 0
    }

    /// Redraws `rect` of the picture through a much smaller copy, clipped to `path`.
    ///
    /// The copy is cut out of `context`, which `flatten` has just drawn the picture into: each of its
    /// pixels is the mean of the pixels under it and of nothing else (`fillGrains`). It is not the
    /// picture drawn into the copy, shrunk to fit `bounds`: measured, CoreGraphics' filter wanders
    /// by several pixels over the box when it shrinks (a 100 px box into 9 cells: the first cell's
    /// centre read 1.6 px off, the last one's 4.3) and takes the picture's outermost pixel for all
    /// that lies beyond its edge (55 % of a cell flush with the edge), which left such a cell with a
    /// light or a dark rim.
    private static func cover(from image: CGImage, rect: CGRect, path: CGPath, finding: Finding, into context: CGContext,
                              style: MaskStyle, blurGrain: BlurGrain) {
        let bounds = rect.intersection(CGRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height)))
        guard bounds.width >= 2, bounds.height >= 2 else { return }
        // Mosaic cells and blur grain follow what is hidden and how tall it is (`grid`).
        let cut = grid(over: bounds, hiding: finding, style: style, blurGrain: blurGrain)
        guard let small = CGImage.rgbaContext(width: cut.columns, height: cut.rows), let grains = small.data,
              let picture = context.data else { return }
        fillGrains(grains.assumingMemoryBound(to: UInt8.self), grainStride: small.bytesPerRow,
                   from: picture.assumingMemoryBound(to: UInt8.self), stride: context.bytesPerRow,
                   bounds: bounds, columns: cut.columns, rows: cut.rows)
        guard let grainImage = small.makeImage() else { return }

        context.saveGState()
        context.addPath(path)
        context.clip()
        context.interpolationQuality = style == .mosaic ? .none : .high
        // The context is flipped to top-left coordinates, and an image drawn into a flipped context
        // comes out upside down. Turn this one back over the top edge of `bounds`, so every cell
        // lands over the piece of the picture it was made from.
        context.translateBy(x: bounds.minX, y: bounds.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(grainImage, in: CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height))
        context.restoreGState()
    }

    /// The mean colour of the pixels under each cell of `bounds`, written into `grains` as
    /// `columns × rows` pixels of RGBA8, four bytes a pixel, `stride` a row: the layout of
    /// `rgbaContext`, whose first row is the top one whatever coordinate system the context was
    /// flipped to. `bounds` is top-left like Vision's boxes, and lies inside the picture; a pixel
    /// belongs to the cell its centre lies in, so a cover flush with the picture's edge is filled
    /// with picture and nothing outside it. Both bitmaps are premultiplied, and so is their mean.
    private static func fillGrains(_ grains: UnsafeMutablePointer<UInt8>, grainStride: Int,
                                   from picture: UnsafePointer<UInt8>, stride: Int,
                                   bounds: CGRect, columns: Int, rows: Int) {
        let across = bounds.width / CGFloat(columns), up = bounds.height / CGFloat(rows)
        for row in 0..<rows {
            // The rows of pixels whose centres (y + 0.5) lie in [top, bottom), and likewise across.
            let top = bounds.minY + CGFloat(row) * up
            let from = Int((top - 0.5).rounded(.up)), under = Int((top + up - 0.5).rounded(.up))
            for column in 0..<columns {
                let left = bounds.minX + CGFloat(column) * across
                let first = Int((left - 0.5).rounded(.up)), past = Int((left + across - 0.5).rounded(.up))
                var red = 0, green = 0, blue = 0, alpha = 0
                for y in from..<under {
                    var pixel = picture + y * stride + first * 4
                    for _ in first..<past {
                        red += Int(pixel[0]); green += Int(pixel[1]); blue += Int(pixel[2]); alpha += Int(pixel[3])
                        pixel += 4
                    }
                }
                // Every cell holds pixels: at least half of what it is cut by across (6 pixels at least,
                // the smallest measure being `mosaicFloor`), or, when it is the only one, the whole
                // `bounds`, 2 at least. `max` only keeps the division safe.
                let count = max(1, (under - from) * (past - first))
                let grain = grains + row * grainStride + column * 4
                for (component, sum) in [red, green, blue, alpha].enumerated() {
                    grain[component] = UInt8((sum + count / 2) / count)
                }
            }
        }
    }

    static func quadPath(_ quad: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = quad.first else { return path }
        path.move(to: first)
        for p in quad.dropFirst() { path.addLine(to: p) }
        path.closeSubpath()
        return path
    }
}
