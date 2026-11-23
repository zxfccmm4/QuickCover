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
    func paddedQuadGrowsOnEverySide() {
        let q = [CGPoint(x: 10, y: 10), CGPoint(x: 50, y: 10), CGPoint(x: 50, y: 30), CGPoint(x: 10, y: 30)]
        let grown = Geometry.bounds(of: Recognizer.padded(q, by: 5))
        #expect(grown == CGRect(x: 5, y: 5, width: 50, height: 30))
    }
}
