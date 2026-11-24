import CoreGraphics
import Foundation
import ImageIO
import Testing
import UIKit
import UniformTypeIdentifiers

@testable import QuickCover

/// Pictures drawn in the test, so nothing depends on a photo that happens to be in a bundle.
enum Sample {
    static let black = UIColor.black.cgColor
    static let white = UIColor.white.cgColor

    static func solid(width: Int, height: Int, fill: CGColor) -> CGImage {
        let context = CGImage.rgbaContext(width: width, height: height)!
        context.setFillColor(fill)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    /// A white picture with black text at a point measured from the top-left corner.
    static func text(_ string: String, at point: CGPoint, size: CGSize = CGSize(width: 600, height: 300), fontSize: CGFloat = 40) -> CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            (string as NSString).draw(at: point, withAttributes: [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: UIColor.black,
            ])
        }.cgImage!
    }

    /// A white picture with black text lines, one under another, starting at a top-left point.
    static func lines(_ strings: [String], at point: CGPoint, lineHeight: CGFloat,
                      size: CGSize = CGSize(width: 900, height: 400), fontSize: CGFloat = 40) -> CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: UIColor.black,
            ]
            for (index, string) in strings.enumerated() {
                (string as NSString).draw(at: CGPoint(x: point.x, y: point.y + CGFloat(index) * lineHeight), withAttributes: attributes)
            }
        }.cgImage!
    }

    /// The first and last row of the glyphs of line `index`, counted from the top of the picture:
    /// the rows between that line's top and the next line's where something is darker than mid-grey.
    static func inkRows(of image: CGImage, line index: Int, firstTop: CGFloat, lineHeight: CGFloat) -> ClosedRange<CGFloat> {
        let width = image.width, height = image.height
        let context = CGImage.rgbaContext(width: width, height: height)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let stride = context.bytesPerRow
        let buffer = context.data!.assumingMemoryBound(to: UInt8.self)
        let top = Int(firstTop + CGFloat(index) * lineHeight)
        let bottom = min(Int(firstTop + CGFloat(index + 1) * lineHeight), height)
        let rows = (top..<bottom).filter { row in
            (0..<width).contains { buffer[row * stride + $0 * 4] < 128 }
        }
        return CGFloat(rows.first ?? top)...CGFloat(rows.last ?? top)
    }

    /// A JPEG of `image` with the given EXIF orientation tag and, optionally, a location and a date.
    static func jpeg(_ image: CGImage, orientation: UInt32 = 1, metadata: Bool = false) -> Data {
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)!
        var properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.9,
            kCGImagePropertyTIFFOrientation: orientation,
        ]
        if metadata {
            properties[kCGImagePropertyExifDictionary] = [kCGImagePropertyExifDateTimeOriginal: "2026:11:23 10:00:00"]
            properties[kCGImagePropertyGPSDictionary] = [kCGImagePropertyGPSLatitude: 31.2, kCGImagePropertyGPSLatitudeRef: "N",
                                                        kCGImagePropertyGPSLongitude: 121.4, kCGImagePropertyGPSLongitudeRef: "E"]
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        precondition(CGImageDestinationFinalize(destination))
        return data as Data
    }

    /// Luminance 0…1 of the pixel at a top-left point.
    static func brightness(_ image: CGImage, x: Int, y: Int) -> Double {
        let context = CGImage.rgbaContext(width: 1, height: 1)!
        context.translateBy(x: CGFloat(-x), y: CGFloat(-(image.height - 1 - y)))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let data = context.data!.assumingMemoryBound(to: UInt8.self)
        return Double(Int(data[0]) + Int(data[1]) + Int(data[2])) / 765
    }
}

struct ImageScalingTests {

    @Test
    func largePicturesShrinkToTheLimit() {
        let big = Sample.solid(width: 4032, height: 3024, fill: Sample.white)
        let small = big.scaledDown(maxLongSide: 2560)
        #expect(small.width == 2560)
        #expect(small.height == 1920)
    }

    @Test
    func smallPicturesStayAsTheyAre() {
        let small = Sample.solid(width: 800, height: 600, fill: Sample.white)
        #expect(small.scaledDown(maxLongSide: 2560) === small)
    }

    @Test
    func rightOrientationTurnsSizeAndMovesCorner() throws {
        // Raw pixels 200×100 with a black block in their top-left corner. EXIF "right" means the
        // stored picture is turned a quarter clockwise for viewing, so the block ends up top-right.
        let context = try #require(CGImage.rgbaContext(width: 200, height: 100))
        context.setFillColor(Sample.white)
        context.fill(CGRect(x: 0, y: 0, width: 200, height: 100))
        context.setFillColor(Sample.black)
        context.fill(CGRect(x: 0, y: 80, width: 20, height: 20))
        let raw = try #require(context.makeImage())

        let upright = raw.oriented(.right)
        #expect(upright.width == 100)
        #expect(upright.height == 200)
        #expect(Sample.brightness(upright, x: 90, y: 10) < 0.2)
        #expect(Sample.brightness(upright, x: 10, y: 10) > 0.8)
    }

    @Test
    func upOrientationReturnsSamePixels() {
        let raw = Sample.solid(width: 10, height: 10, fill: Sample.black)
        #expect(raw.oriented(.up) === raw)
    }
}

struct TextRuleMatcherTests {

    private func rules(_ line: String) -> Set<TextRule> {
        Set(TextRuleMatcher.matches(in: line).map(\.rule))
    }

    @Test
    func plainFormats() {
        #expect(rules("收货人电话 13812345678") == [.phone])
        #expect(rules("身份证号 11010119900307777X") == [.idNumber])
        #expect(rules("卡号 6222021234567890123") == [.bankCard])
        #expect(rules("邮箱 someone@example.com") == [.email])
        #expect(rules("详见 https://example.com/orders/1?token=abc") == [.url])
        #expect(rules("服务器 192.168.1.25") == [.ipv4])
        #expect(rules("京A12345") == [.plate])
        // What the reader makes of a plate photo: other dots, the dot in either place, an older province glyph.
        #expect(rules("粤B8S6Q0") == [.plate])
        #expect(rules("粵B•8S600") == [.plate])
        #expect(rules("京A・FOK2L") == [.plate])
        #expect(rules("粵AD・12345") == [.plate])
        #expect(rules("苏E・7H3M6") == [.plate])
        #expect(rules("A12345 北京") == [])
        #expect(rules("订单号 QC20260307A1B2C3") == [.reference])
    }

    @Test
    func numbersSurviveGrouping() {
        #expect(rules("138 1234 5678") == [.phone])
        #expect(rules("138-1234-5678") == [.phone])
        #expect(rules("110101 19900307 777X") == [.idNumber])
        #expect(rules("6222 0212 3456 7890") == [.bankCard])
    }

    @Test
    func ordinaryTextStaysOut() {
        #expect(rules("明天下午三点在会议室见") == [])
        #expect(rules("共 3 件，合计 128 元") == [])
        #expect(rules("2026 年 3 月 7 日") == [])
        #expect(rules("Let's meet at 3pm tomorrow") == [])
        #expect(rules("400-800-1234") == [])
        #expect(rules("1,234,567,890") == [])
        #expect(rules("qc_support_2026") == [])
    }

    @Test
    func severalRulesInOneLine() {
        let line = "电话 13812345678，邮箱 someone@example.com"
        let matches = TextRuleMatcher.matches(in: line)
        #expect(matches.map(\.rule) == [.phone, .email])
        // Each match points at its own characters of the line.
        let scalars = Array(line.precomposedStringWithCompatibilityMapping.unicodeScalars)
        for m in matches {
            #expect(String(String.UnicodeScalarView(scalars[m.start..<m.end])).contains(
                m.rule == .phone ? "13812345678" : "someone@example.com"))
        }
    }
}

struct RecognizerTests {

    @Test
    func topLeftTextLandsInTopLeftPixels() async throws {
        let image = Sample.text("13812345678", at: CGPoint(x: 20, y: 20))
        let result = try await Recognizer().recognize(image)
        let phone = try #require(result.findings.first { $0.rule == .phone })
        #expect(phone.box.minX < 40)
        #expect(phone.box.minY < 40)
        #expect(phone.box.maxX < 400)
        #expect(phone.box.maxY < 90)
        #expect(result.size == CGSize(width: 600, height: 300))
    }

    @Test
    func onlyPartOfALineIsCovered() async throws {
        // The name before the number must stay visible.
        let image = Sample.text("收货人张三 13812345678", at: CGPoint(x: 20, y: 20), fontSize: 36)
        let result = try await Recognizer().recognize(image)
        let phone = try #require(result.findings.first { $0.rule == .phone })
        #expect(phone.box.minX > 150)
    }

    @Test
    func ordinaryLineProducesNothing() async throws {
        let image = Sample.text("明天下午三点在会议室见", at: CGPoint(x: 20, y: 20), fontSize: 36)
        let result = try await Recognizer().recognize(image)
        #expect(result.findings.isEmpty)
        #expect(!result.textLines.isEmpty)
    }

    @Test
    func rotatedPictureIsReadUpright() async throws {
        // Draw the text, store it as if shot sideways, and tell the recognizer.
        let upright = Sample.text("13812345678", at: CGPoint(x: 20, y: 20))
        let raw = upright.oriented(.left)   // inverse of a quarter turn
        let result = try await Recognizer().recognize(raw, orientation: .right)
        #expect(result.size == CGSize(width: 600, height: 300))
        #expect(result.findings.contains { $0.rule == .phone })
    }

    @Test
    func numberWrappedToTheNextLineIsHiddenOnBoth() async throws {
        // Cut after fifteen digits, an ID reads as a long number on one line and three stray digits
        // below, with an ordinary line above and one under.
        let image = Sample.lines(["第一行普通文字", "身份证号是 110101198807154", "417", "第三行普通文字"],
                                 at: CGPoint(x: 20, y: 20), lineHeight: 56)
        let hits = try await Recognizer().recognize(image).findings.filter { $0.kind == .text }
        #expect(hits.map(\.rule) == [.idNumber])
        #expect(hits.map(\.evidence) == ["110101198807154417"])
        try #require(hits.count == 1)
        // One item of two boxes: the number on its line, the stray digits on theirs.
        #expect(hits[0].parts.count == 1)
        let boxes = hits[0].boxes
        #expect(boxes.count == 2)

        // Where the glyphs of each line are, read from the picture itself.
        let ink = (0..<4).map { Sample.inkRows(of: image, line: $0, firstTop: 20, lineHeight: 56) }
        for (index, rows) in ink.enumerated() {
            let top = 20 + CGFloat(index) * 56
            #expect(rows.lowerBound > top && rows.upperBound < top + 56)
        }

        // Both pieces are hidden, each under a box of the one item on its own line.
        #expect(boxes[0].minY <= ink[1].lowerBound && boxes[0].maxY >= ink[1].upperBound)
        #expect(boxes[1].minY <= ink[2].lowerBound && boxes[1].maxY >= ink[2].upperBound)

        // The margins are the tuned ones and no wider, give or take three pixels. Measured on the
        // simulator: the number's mask reaches 20 pixels above its glyphs and 12.6 under them, the
        // stray digits' 18 above and 11.4 under. The two masks may meet in the space between the
        // lines, which was taken as the price of never leaving the top of a digit bare.
        let slack: CGFloat = 3
        #expect(ink[1].lowerBound - boxes[0].minY <= 20 + slack)
        #expect(boxes[0].maxY - ink[1].upperBound <= 12.6 + slack)
        #expect(ink[2].lowerBound - boxes[1].minY <= 18 + slack)
        #expect(boxes[1].maxY - ink[2].upperBound <= 11.4 + slack)

        // A line one row further off is never touched.
        #expect(boxes[1].minY > ink[0].upperBound)
        #expect(boxes[0].maxY < ink[3].lowerBound)
    }

    @Test
    func textMarginsStayAtTheTunedSize() {
        // A line box 40 pixels tall, as Vision gives one for text of about that size.
        let line = Recognizer.textPadding(for: .idNumber, lineHeight: 40)
        #expect(abs(line.top - 21) <= 0.5)
        #expect(abs(line.bottom - 9) <= 0.5)
        #expect(abs(line.side - 11) <= 0.5)
        let plate = Recognizer.textPadding(for: .plate, lineHeight: 40)
        #expect(abs(plate.top - 15) <= 0.5)
        #expect(abs(plate.bottom - 13) <= 0.5)
        #expect(abs(plate.side - 21) <= 0.5)
        // A box too shallow to take a share keeps two pixels and the one on top, whatever the rule.
        for rule in TextRule.allCases.map({ Optional($0) }) + [nil] {
            let tiny = Recognizer.textPadding(for: rule, lineHeight: 2)
            #expect(abs(tiny.top - 3) <= 0.01 && abs(tiny.bottom - 3) <= 0.01 && abs(tiny.side - 3) <= 0.01)
        }
    }

    @Test
    func addressWrappedToTheNextLineIsHiddenOnBoth() async throws {
        let image = Sample.lines(["攻略 https://docs.example.c", "om/hike/2026.pdf"], at: CGPoint(x: 20, y: 20), lineHeight: 56)
        let hits = try await Recognizer().recognize(image).findings.filter { $0.kind == .text }
        #expect(hits.map(\.rule) == [.url])
        #expect(hits.map(\.evidence) == ["https://docs.example.com/hike/2026.pdf"])
        // One item of two boxes, the scheme and most of the host on the first line, the rest under it.
        #expect(hits.count == 1 && hits[0].parts.count == 1)
    }

    @Test
    func valueColumnWrapGoesBackToTheMargin() async throws {
        // A label column and a value column, as on a waybill: the label on one line, the value after
        // a colon on the next, and the rest of the value back at the left margin under it.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: 900, height: 400), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 900, height: 400))
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 40, weight: .semibold), .foregroundColor: UIColor.black]
            ("ID NO" as NSString).draw(at: CGPoint(x: 20, y: 20), withAttributes: attributes)
            ("： 44030119870" as NSString).draw(at: CGPoint(x: 320, y: 76), withAttributes: attributes)
            ("3124916" as NSString).draw(at: CGPoint(x: 20, y: 132), withAttributes: attributes)
        }.cgImage!
        let hits = try await Recognizer().recognize(image).findings.filter { $0.kind == .text }
        #expect(hits.map(\.rule) == [.idNumber])
        #expect(hits.map(\.evidence) == ["440301198703124916"])
        try #require(hits.count == 1 && hits[0].parts.count == 1)
        // The first box stands on the value line, right of the label; the second back on the margin.
        #expect(hits[0].lineBox.minX > 280)
        #expect(Geometry.bounds(of: hits[0].parts[0]).minX < 120)
    }

    @Test
    func valueColumnWrapThatReachesUnderTheValueGoesBackToTheMargin() async throws {
        // As above, with the rest of the number long enough to reach under the value column: the
        // two lines overlap sideways, and the lower one is still the line the wrap went to.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: 900, height: 400), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 900, height: 400))
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 40, weight: .semibold), .foregroundColor: UIColor.black]
            ("ID NO" as NSString).draw(at: CGPoint(x: 20, y: 20), withAttributes: attributes)
            ("： 44030119870" as NSString).draw(at: CGPoint(x: 160, y: 76), withAttributes: attributes)
            ("3124916" as NSString).draw(at: CGPoint(x: 20, y: 132), withAttributes: attributes)
        }.cgImage!
        let hits = try await Recognizer().recognize(image).findings.filter { $0.kind == .text }
        #expect(hits.map(\.rule) == [.idNumber])
        #expect(hits.map(\.evidence) == ["440301198703124916"])
    }

    @Test
    func urlCutTwiceIsOneItemOfThreeBoxes() async throws {
        // The address is whole for the rule on its first line, and the middle line carries an address
        // whole as well: one item over the three lines, not two of two lines each.
        let image = Sample.lines(["文档 https://drive.ficti", "onbox.net/shared/fol", "ders/x/9CT4kQ2mVp"],
                                 at: CGPoint(x: 20, y: 20), lineHeight: 56)
        let hits = try await Recognizer().recognize(image).findings.filter { $0.kind == .text }
        #expect(hits.map(\.rule) == [.url])
        #expect(hits.map(\.evidence) == ["https://drive.fictionbox.net/shared/folders/x/9CT4kQ2mVp"])
        try #require(hits.count == 1 && hits[0].boxes.count == 3)
    }

    @Test
    func lineBelowAWholeNumberStaysOutWhenItStartsWithWords() async throws {
        let image = Sample.lines(["电话 13812345678", "明天下午三点在会议室见"], at: CGPoint(x: 20, y: 20), lineHeight: 56)
        let hits = try await Recognizer().recognize(image).findings.filter { $0.kind == .text }
        #expect(hits.map(\.rule) == [.phone])
    }

    @Test
    func sentenceUnderAHitIsNotTakenForItsTail() async throws {
        let image = Sample.lines(["邮箱 zhang.wei@example.com", "Thanks."], at: CGPoint(x: 20, y: 20), lineHeight: 56)
        let hits = try await Recognizer().recognize(image).findings.filter { $0.kind == .text }
        #expect(hits.map(\.rule) == [.email])
    }

    @Test
    func datedRowUnderAHitIsNotTakenForItsTail() async throws {
        let image = Sample.lines(["from 192.168.1.23", "2026-11-23 09:00:02 login ok", "13800138000", "2026年1月5日 交费"],
                                at: CGPoint(x: 20, y: 20), lineHeight: 56)
        let hits = try await Recognizer().recognize(image).findings.filter { $0.kind == .text }
        #expect(hits.map(\.rule) == [.ipv4, .phone])
    }

    @Test
    func paddedQuadGrowsOnEverySide() {
        let q = [CGPoint(x: 10, y: 10), CGPoint(x: 50, y: 10), CGPoint(x: 50, y: 30), CGPoint(x: 10, y: 30)]
        let grown = Geometry.bounds(of: Recognizer.padded(q, by: 5))
        #expect(grown == CGRect(x: 5, y: 5, width: 50, height: 30))
    }
    @Test
    func pieceStaysClearOfTheLinesAroundIt() {
        // A notice's line with the rest of an address, 15 point at 2x: Vision's box of the line
        // is swollen under the baseline by its full-width comma, 49 tall for a row of 38; the
        // label line above ends two pixels higher, the one below starts inside the swollen part.
        let own = CGRect(x: 38, y: 502, width: 420, height: 49)
        let above = CGRect(x: 62, y: 466, width: 583, height: 34)
        let below = CGRect(x: 45, y: 540, width: 40, height: 32)
        let padded = CGRect(x: 25, y: 478, width: 446, height: 84)
        let lines = [above, own, below]
        // The margin stops at the label line's box above and at the line below: its top is where
        // this line's glyphs end, its own box being no taller than its row.
        let kept = Recognizer.clearOfNeighbours(padded, own: own, glyphs: "www.fictbank.cn/notice/482", lines: lines)
        #expect(kept == CGRect(x: 25, y: 500, width: 446, height: 40))
        // A letter hanging under the baseline keeps the swollen box: the cut could take its tail.
        // The margin above is stopped all the same.
        let tail = Recognizer.clearOfNeighbours(padded, own: own, glyphs: "fict.ly/8Kd2Qz", lines: lines)
        #expect(tail == CGRect(x: 25, y: 500, width: 446, height: 62))
        // A line below with a swollen box of its own says where nothing ends: the box stays whole.
        let fat = CGRect(x: 45, y: 540, width: 640, height: 90)
        let whole = Recognizer.clearOfNeighbours(padded, own: own, glyphs: "www.fictbank.cn/notice/482", lines: [above, own, fat, CGRect(x: 45, y: 612, width: 600, height: 60)])
        #expect(whole == tail)
        // A line that is no taller than its row is not cut, whatever stands under it.
        let slim = CGRect(x: 38, y: 502, width: 420, height: 34)
        let slimPadded = CGRect(x: 30, y: 484, width: 436, height: 75)
        #expect(Recognizer.clearOfNeighbours(slimPadded, own: slim, glyphs: "6013", lines: [above, slim, below])
            == CGRect(x: 30, y: 500, width: 436, height: 40))

        // Lines of a paragraph whose boxes touch or overlap, as on the frozen pictures: the tuned
        // margin stands whole, above and below.
        let own2 = CGRect(x: 196, y: 497, width: 804, height: 106)
        let over = [CGRect(x: 195, y: 423, width: 828, height: 115), own2, CGRect(x: 197, y: 569, width: 836, height: 115)]
        let padded2 = CGRect(x: 180, y: 443, width: 836, height: 172)
        #expect(Recognizer.clearOfNeighbours(padded2, own: own2, glyphs: "wangfang@example.com", lines: over) == padded2)
        // A line in another column does not count.
        let side = CGRect(x: 900, y: 466, width: 200, height: 34)
        #expect(Recognizer.clearOfNeighbours(padded, own: own, glyphs: "6013", lines: [side, own, below])
            == CGRect(x: 25, y: 478, width: 446, height: 62))
        // A label line whose box runs two pixels into ours, as Vision draws them tight: the margin
        // stops at the piece's own box, not a hair above it.
        let touching = CGRect(x: 62, y: 470, width: 583, height: 34)
        #expect(Recognizer.clearOfNeighbours(padded, own: own, glyphs: "fict.ly/8Kd2Qz", lines: [touching, own, below])
            == CGRect(x: 25, y: 502, width: 446, height: 60))

        // A bare number's box is just its digits, a little over half of its row: the line above ends
        // a few pixels higher still, and the margin stays whole, since the number's line reaches
        // half a box above the digits.
        let digits = CGRect(x: 158, y: 631, width: 475, height: 35)
        let digitsPadded = CGRect(x: 143, y: 612, width: 505, height: 62)
        let sentence = CGRect(x: 158, y: 573, width: 458, height: 54)
        #expect(Recognizer.clearOfNeighbours(digitsPadded, own: digits, glyphs: "6222 0210 0110 8867123", lines: [sentence, digits])
            == digitsPadded)
    }
}
