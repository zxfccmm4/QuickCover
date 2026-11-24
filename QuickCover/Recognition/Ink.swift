import CoreGraphics

/// Where the ink of a line ends in the picture itself, for a margin that has to stop at the glyphs
/// and not at their box. Vision's box of a line runs under its last glyph by a couple of pixels in
/// one rendering and by half a line in another — a line with a full-width comma in a browser's
/// type gets a box half a line under its baseline — and nothing in the box tells the two apart.
enum Ink {
    /// How far a pixel's colour must be from the paper, on one channel, to be ink: a sixth of the
    /// way from black to white, which the palest grey a line of text is printed in passes.
    private static let contrast = 40

    /// The bottom edge of the lowest row of ink in `band` of `picture`, in the picture's pixels from
    /// its top. Nil where the band holds no ink, or none that can be told from the paper.
    ///
    /// The paper is the colour most of the band has. A row holds ink when two of its pixels do, so
    /// a lone speck of noise holds the margin back for nothing.
    static func bottom(in band: CGRect, of picture: CGImage) -> CGFloat? {
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
        for y in stride(from: h - 1, through: 0, by: -1) {
            var ink = 0
            for x in 0..<w {
                let c = colour(x, y)
                let gap = max(abs((c & 255) - red), max(abs((c >> 8 & 255) - green), abs((c >> 16 & 255) - blue)))
                if gap >= contrast { ink += 1 }
            }
            if ink >= 2 { return area.minY + CGFloat(y) + 1 }
        }
        return nil
    }
}
