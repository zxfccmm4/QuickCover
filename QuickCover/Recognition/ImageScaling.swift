import CoreGraphics
import ImageIO

extension CGImage {

    /// The same picture, rotated and mirrored so it stands upright for the given EXIF orientation.
    func oriented(_ orientation: CGImagePropertyOrientation) -> CGImage {
        guard orientation != .up else { return self }
        let rawWidth = CGFloat(width)
        let rawHeight = CGFloat(height)
        let swapsSides = (5...8).contains(orientation.rawValue)
        let outWidth = swapsSides ? rawHeight : rawWidth
        let outHeight = swapsSides ? rawWidth : rawHeight
        guard let context = Self.rgbaContext(width: Int(outWidth), height: Int(outHeight)) else { return self }

        var transform = CGAffineTransform.identity
        switch orientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: outWidth, y: outHeight).rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: outWidth, y: 0).rotated(by: .pi / 2)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: outHeight).rotated(by: -.pi / 2)
        default:
            break
        }
        switch orientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: outWidth, y: 0).scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: outHeight, y: 0).scaledBy(x: -1, y: 1)
        default:
            break
        }
        context.interpolationQuality = .high
        context.concatenate(transform)
        context.draw(
            self,
            in: CGRect(x: 0, y: 0, width: swapsSides ? outHeight : outWidth, height: swapsSides ? outWidth : outHeight)
        )
        return context.makeImage() ?? self
    }

    /// A smaller copy whose longest side is at most `maxLongSide`, halved step by step so thin
    /// strokes survive.
    func scaledDown(maxLongSide: CGFloat) -> CGImage {
        let longSide = CGFloat(max(width, height))
        guard maxLongSide > 0, longSide > maxLongSide else { return self }
        let ratio = maxLongSide / longSide
        let target = CGSize(
            width: max(1, (CGFloat(width) * ratio).rounded()),
            height: max(1, (CGFloat(height) * ratio).rounded())
        )
        var current = self
        for _ in 0..<8 {
            guard CGFloat(max(current.width, current.height)) / 2 >= maxLongSide,
                  let half = current.resized(to: CGSize(width: CGFloat(current.width) / 2, height: CGFloat(current.height) / 2)),
                  half !== current
            else { break }
            current = half
        }
        return current.resized(to: target) ?? current
    }

    /// A copy at `size`, in sRGB. The same image when the size already fits.
    func resized(to size: CGSize) -> CGImage? {
        let newWidth = max(1, Int(size.width.rounded()))
        let newHeight = max(1, Int(size.height.rounded()))
        guard newWidth != width || newHeight != height else { return self }
        guard let context = Self.rgbaContext(width: newWidth, height: newHeight) else { return nil }
        context.interpolationQuality = .high
        context.draw(self, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        return context.makeImage()
    }

    static func rgbaContext(width: Int, height: Int) -> CGContext? {
        guard width > 0, height > 0 else { return nil }
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        return CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    /// Clamps a rect in this image's pixels to the image bounds.
    func clamped(_ rect: CGRect) -> CGRect {
        rect.intersection(CGRect(x: 0, y: 0, width: width, height: height))
    }
}
