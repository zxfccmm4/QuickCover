import CoreGraphics
import CoreText
import Testing
import UIKit

@testable import QuickCover

/// Fix 5, on pictures: the piece a line wrap leaves at the end of the line above is hidden with
/// the value it is the head of, and what stands before it on that line stays showing.
@Suite struct JunctionHeadPictureTests {

    /// A white picture with black lines, as `Sample.lines` draws them, and where the ink of a
    /// piece of a line is.
    private struct Picture {
        let image: CGImage
        let lines: [String]
        let point: CGPoint
        let lineHeight: CGFloat
        let fontSize: CGFloat

        init(_ lines: [String], point: CGPoint = CGPoint(x: 20, y: 20), lineHeight: CGFloat = 56, fontSize: CGFloat = 40) {
            self.image = Sample.lines(lines, at: point, lineHeight: lineHeight, fontSize: fontSize)
            self.lines = lines
            self.point = point
            self.lineHeight = lineHeight
            self.fontSize = fontSize
        }

        /// The top of the line `index` was drawn under.
        func top(ofLine index: Int) -> CGFloat { point.y + CGFloat(index) * lineHeight }

        /// The box of the ink of the last `count` characters of line `index`.
        func ink(ofTail count: Int, onLine index: Int) -> CGRect {
            ink(from: lines[index].count - count, to: lines[index].count, onLine: index)
        }

        /// The box of the ink of the first `count` characters of line `index`.
        func ink(ofHead count: Int, onLine index: Int) -> CGRect {
            ink(from: 0, to: count, onLine: index)
        }

        /// The box of the ink of the characters `from..<to` of line `index`: the picture is read
        /// where the string was drawn, laid out as it was, a pixel aside on each side.
        private func ink(from: Int, to: Int, onLine index: Int) -> CGRect {
            let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
            let laid = CTLineCreateWithAttributedString(NSAttributedString(string: lines[index], attributes: [.font: font]))
            func x(_ index: Int) -> CGFloat { point.x + CTLineGetOffsetForStringIndex(laid, index, nil) }
            let piece = String(lines[index].dropFirst(from).prefix(to - from))
            let columns = CGRect(x: (x(from) - 1).rounded(.down), y: top(ofLine: index),
                                 width: (x(to) - x(from) + 2).rounded(.up), height: lineHeight)
            guard let box = Self.inkBox(in: image, inside: columns) else {
                Issue.record("no ink drawn for \"\(piece)\" on line \(index)")
                return columns
            }
            return box
        }

        /// The smallest box around the pixels darker than mid-grey inside `rect`.
        private static func inkBox(in image: CGImage, inside rect: CGRect) -> CGRect? {
            let width = image.width, height = image.height
            let context = CGImage.rgbaContext(width: width, height: height)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            let stride = context.bytesPerRow
            let buffer = context.data!.assumingMemoryBound(to: UInt8.self)
            let x0 = max(Int(rect.minX.rounded(.down)), 0), x1 = min(Int(rect.maxX.rounded(.up)), width)
            let y0 = max(Int(rect.minY.rounded(.down)), 0), y1 = min(Int(rect.maxY.rounded(.up)), height)
            var minX = Int.max, maxX = -1, minY = Int.max, maxY = -1
            for row in y0..<y1 {
                for column in x0..<x1 where buffer[row * stride + column * 4] < 128 {
                    minX = min(minX, column); maxX = max(maxX, column)
                    minY = min(minY, row); maxY = max(maxY, row)
                }
            }
            guard maxX >= 0 else { return nil }
            return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        }
    }

    private func textFindings(in picture: Picture) async throws -> [Finding] {
        try await Recognizer().recognize(picture.image).findings.filter { $0.kind == .text }
    }

    /// Whether one of `boxes` hides `ink` whole, a pixel aside.
    private func hides(_ boxes: [CGRect], _ ink: CGRect) -> Bool {
        boxes.contains { $0.minX <= ink.minX + 1 && $0.maxX >= ink.maxX - 1 && $0.minY <= ink.minY + 1 && $0.maxY >= ink.maxY - 1 }
    }

    /// The boxes on line `index` of the picture.
    private func boxes(onLine index: Int, in picture: Picture, of hits: [Finding]) -> [CGRect] {
        let top = picture.top(ofLine: index)
        return hits.flatMap(\.boxes).filter { $0.midY >= top && $0.midY < top + picture.lineHeight }
    }

    // MARK: The first number of an address

    @Test(arguments: [
        (["网关地址是 192.", "168.0.1，别改"], "192.168.0.1", "192.", "168.0.1", "网关地址是"),
        (["服务器 10.", "0.0.1 端口 8080"], "10.0.0.1", "10.", "0.0.1", "服务器"),
    ])
    func addressCutAfterItsFirstNumber(lines: [String], evidence: String, head: String, rest: String, before: String) async throws {
        let picture = Picture(lines)
        let hits = try await textFindings(in: picture)
        #expect(hits.map(\.rule) == [.ipv4])
        #expect(hits.map(\.evidence) == [evidence])
        #expect(hits.first?.boxes.count == 2)
        let upper = boxes(onLine: 0, in: picture, of: hits), lower = boxes(onLine: 1, in: picture, of: hits)
        #expect(upper.count == 1 && lower.count == 1)
        // The full stop at the end of the line goes with the address.
        #expect(hides(upper, picture.ink(ofTail: head.count, onLine: 0)))
        #expect(hides(lower, picture.ink(ofHead: rest.count, onLine: 1)))
        // The words before it stay showing.
        #expect(upper.allSatisfy { $0.minX >= picture.ink(ofHead: before.count, onLine: 0).maxX })
    }

    // MARK: What only looks like such a piece

    @Test func aLabelOverAnAddressStaysShowing() async throws {
        // A suffix the URL rule knows, so that the address under the label is a URL to tell apart from it.
        let picture = Picture(["链接见 link", "fict.io/coupon 今天"])
        let hits = try await textFindings(in: picture)
        // The address under it is hidden on its own line; the word above is a label and stays.
        #expect(hits.map(\.rule) == [.url])
        #expect(boxes(onLine: 0, in: picture, of: hits).isEmpty)
        #expect(hides(boxes(onLine: 1, in: picture, of: hits), picture.ink(ofHead: "fict.io/coupon".count, onLine: 1)))
    }
}
