import CoreGraphics

/// Where the ink of a line ends in the picture itself, for a margin that has to stop at the glyphs
/// and not at their box. Vision's box of a line runs under its last glyph by a couple of pixels in
/// one rendering and by half a line in another — a line with a full-width comma in a browser's
/// type gets a box half a line under its baseline — and nothing in the box tells the two apart.
enum Ink {
    /// How far a pixel's colour must be from the paper, on one channel, to be ink: a sixth of the
    /// way from black to white, which the palest grey a line of text is printed in passes.
    private static let contrast = 40

    /// The pixels of ink a row or a column must have to hold ink: so a lone speck of noise is none,
    /// and a hairline a pixel thick is none either.
    private static let pixelsOfInk = 2

    /// A band of the picture drawn into a bitmap, a pixel to a pixel.
    private struct Raster {
        /// The band in whole pixels, from the picture's top.
        let area: CGRect
        let width: Int, height: Int
        /// The colour most of the band has, channel by channel: what the band is printed on.
        private let paper: (red: Int, green: Int, blue: Int)
        private let context: CGContext
        private let bytes: UnsafeMutablePointer<UInt8>
        private let rowBytes: Int

        init?(_ band: CGRect, of picture: CGImage) {
            let whole = CGRect(x: 0, y: 0, width: picture.width, height: picture.height)
            let area = CGRect(x: band.minX.rounded(.down), y: band.minY.rounded(.down),
                              width: band.maxX.rounded(.up) - band.minX.rounded(.down),
                              height: band.maxY.rounded(.up) - band.minY.rounded(.down)).intersection(whole)
            guard area.width >= 1, area.height >= 1, let crop = picture.cropping(to: area) else { return nil }
            let w = crop.width, h = crop.height
            guard w > 0, h > 0, let context = CGImage.rgbaContext(width: w, height: h) else { return nil }
            context.draw(crop, in: CGRect(x: 0, y: 0, width: w, height: h))
            guard let data = context.data else { return nil }
            let rowBytes = context.bytesPerRow
            let bytes = data.bindMemory(to: UInt8.self, capacity: rowBytes * h)
            // A bitmap context keeps the top row first.
            func colour(_ x: Int, _ y: Int) -> Int {
                let i = y * rowBytes + x * 4
                return Int(bytes[i]) | Int(bytes[i + 1]) << 8 | Int(bytes[i + 2]) << 16
            }
            // The paper is the colour most of the band has.
            var counts = [Int](repeating: 0, count: 768)
            for y in 0..<h {
                for x in 0..<w {
                    let c = colour(x, y)
                    counts[c & 255] += 1
                    counts[256 + (c >> 8 & 255)] += 1
                    counts[512 + (c >> 16 & 255)] += 1
                }
            }
            func paper(_ channel: Int) -> Int {
                var seen = 0
                for value in 0..<256 {
                    seen += counts[channel * 256 + value]
                    if seen * 2 >= w * h { return value }
                }
                return 128
            }
            let red = paper(0), green = paper(1), blue = paper(2)
            self.area = area
            self.width = w
            self.height = h
            self.paper = (red, green, blue)
            self.context = context
            self.bytes = bytes
            self.rowBytes = rowBytes
        }

        /// How far a pixel is from the paper, on the channel farthest from it.
        private func gap(_ x: Int, _ y: Int) -> Int {
            let i = y * rowBytes + x * 4
            let c = Int(bytes[i]) | Int(bytes[i + 1]) << 8 | Int(bytes[i + 2]) << 16
            return max(abs((c & 255) - paper.red), max(abs((c >> 8 & 255) - paper.green), abs((c >> 16 & 255) - paper.blue)))
        }

        func hasInk(_ x: Int, _ y: Int) -> Bool { gap(x, y) >= Ink.contrast }
    }

    /// The bottom edge of the lowest row of ink in `band` of `picture`, in the picture's pixels from
    /// its top. Nil where the band holds no ink, or none that can be told from the paper.
    static func bottom(in band: CGRect, of picture: CGImage) -> CGFloat? {
        guard let r = Raster(band, of: picture) else { return nil }
        for y in stride(from: r.height - 1, through: 0, by: -1) {
            var ink = 0
            for x in 0..<r.width where r.hasInk(x, y) { ink += 1 }
            if ink >= pixelsOfInk { return r.area.minY + CGFloat(y) + 1 }
        }
        return nil
    }

    /// Which columns of `band` of `picture` hold ink, and the x of the band's first column: one
    /// entry per column of the band, from its left edge. Nil where the band is empty or lies off
    /// the picture.
    static func columns(in band: CGRect, of picture: CGImage) -> (origin: CGFloat, ink: [Bool])? {
        guard let r = Raster(band, of: picture) else { return nil }
        var ink = [Bool](repeating: false, count: r.width)
        for x in 0..<r.width {
            var n = 0
            for y in 0..<r.height where r.hasInk(x, y) { n += 1 }
            ink[x] = n >= pixelsOfInk
        }
        return (r.area.minX, ink)
    }
}
