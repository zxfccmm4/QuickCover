import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// An opened picture, kept as its file so full pixels are decoded only when needed.
final class PictureSource: @unchecked Sendable {

    enum Failure: Error {
        case cannotOpen
    }

    let source: CGImageSource
    /// The EXIF orientation stored with the pixels.
    let orientation: CGImagePropertyOrientation
    /// Pixel size of the upright picture.
    let size: CGSize
    let fileType: UTType?
    private let decodeOptions = [kCGImageSourceShouldCache: false] as CFDictionary

    init(data: Data) throws {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0 else { throw Failure.cannotOpen }
        self.source = source
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        let rawOrientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.uint32Value ?? 1
        orientation = CGImagePropertyOrientation(rawValue: rawOrientation) ?? .up
        let width = CGFloat((properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue ?? 0)
        let height = CGFloat((properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue ?? 0)
        let swapsSides = (5...8).contains(orientation.rawValue)
        size = CGSize(width: swapsSides ? height : width, height: swapsSides ? width : height)
        fileType = (CGImageSourceGetType(source) as String?).flatMap(UTType.init)
    }

    convenience init(url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    /// Full-resolution upright pixels. Decoded afresh on every call: use once, for the export.
    func uprightImage() throws -> CGImage {
        guard let raw = CGImageSourceCreateImageAtIndex(source, 0, decodeOptions) else { throw Failure.cannotOpen }
        return raw.oriented(orientation)
    }

    /// Upright, longest side at most `maxLongSide`. Cheap enough for recognition and the preview.
    func thumbnail(maxLongSide: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxLongSide,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCache: false,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
