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
    }

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
        let flat = flatten(upright, findings: findings, style: options.style)

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
    static func flatten(_ image: CGImage, findings: [Finding], style: MaskStyle) -> CGImage {
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
            let path = quadPath(finding.quad)
            switch style {
            case .solid:
                context.addPath(path)
                context.fillPath()
            case .mosaic, .blur:
                cover(from: image, rect: finding.box, path: path, into: context, style: style)
            }
        }
        return context.makeImage() ?? image
    }

    /// Redraws `rect` of `image` through a much smaller copy, clipped to `path`.
    private static func cover(from image: CGImage, rect: CGRect, path: CGPath, into context: CGContext, style: MaskStyle) {
        let bounds = rect.intersection(CGRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height)))
        guard bounds.width >= 2, bounds.height >= 2 else { return }
        // Mosaic cells and blur grain follow the height of the thing hidden: a text line gets
        // cells a fraction of its height, never below the floor that keeps digits unreadable.
        let cell: CGFloat
        switch style {
        case .mosaic: cell = max(12, bounds.height / 6)
        case .blur: cell = max(10, bounds.height / 8)
        case .solid: cell = 1
        }
        let columns = max(1, Int((bounds.width / cell).rounded(.up)))
        let rows = max(1, Int((bounds.height / cell).rounded(.up)))
        guard let small = CGImage.rgbaContext(width: columns, height: rows) else { return }
        small.interpolationQuality = .high
        // `image` is drawn in its own bottom-left coordinates; shift so `bounds` fills the small canvas.
        small.draw(image, in: CGRect(x: -bounds.minX, y: -(CGFloat(image.height) - bounds.maxY),
                                     width: CGFloat(image.width), height: CGFloat(image.height)))
        guard let grains = small.makeImage() else { return }

        context.saveGState()
        context.addPath(path)
        context.clip()
        context.interpolationQuality = style == .mosaic ? .none : .high
        context.draw(grains, in: bounds)
        context.restoreGState()
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
