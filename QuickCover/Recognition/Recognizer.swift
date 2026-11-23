import CoreGraphics
import Foundation
import ImageIO
import Vision

/// Something to hide: one box over the upright picture, in pixels from its top-left corner.
struct Finding: Equatable, Sendable {
    enum Kind: String, Sendable {
        case face, text, code
    }

    let kind: Kind
    /// For text, the rule that matched. Nil for faces and codes.
    let rule: TextRule?
    /// The smallest rectangle around `quad`.
    let box: CGRect
    /// The area to fill, padded already: top-left, top-right, bottom-right, bottom-left.
    let quad: [CGPoint]
    /// What was recognized: the matched text, or the code payload. Empty for faces.
    let evidence: String
    /// The rule matched only after OCR confusions were fixed.
    let tolerant: Bool

    /// The same thing in a picture scaled by `scale`.
    func scaled(by scale: CGSize) -> Finding {
        Finding(kind: kind, rule: rule, quad: quad.map { CGPoint(x: $0.x * scale.width, y: $0.y * scale.height) },
                evidence: evidence, tolerant: tolerant)
    }

    init(kind: Kind, rule: TextRule? = nil, quad: [CGPoint], evidence: String = "", tolerant: Bool = false) {
        self.kind = kind
        self.rule = rule
        self.quad = quad
        self.evidence = evidence
        self.tolerant = tolerant
        self.box = Geometry.bounds(of: quad)
    }
}

/// The smallest rectangle containing every point, or `.zero` when there are none.
enum Geometry {
    static func bounds(of points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for p in points.dropFirst() {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

/// One line of text as the recognizer read it, whether or not a rule matched.
struct TextLine: Equatable, Sendable {
    let quad: [CGPoint]
    let text: String
}

struct RecognitionResult: Equatable, Sendable {
    /// Pixels, top-left origin, of the upright picture.
    let size: CGSize
    let findings: [Finding]
    /// Every text line the recognizer read, in reading order, padded a little.
    let textLines: [TextLine]

    static let empty = RecognitionResult(size: .zero, findings: [], textLines: [])

    /// The same result in a picture scaled by `scale`.
    func scaled(by scale: CGSize) -> RecognitionResult {
        RecognitionResult(
            size: CGSize(width: size.width * scale.width, height: size.height * scale.height),
            findings: findings.map { $0.scaled(by: scale) },
            textLines: textLines.map { TextLine(quad: $0.quad.map { CGPoint(x: $0.x * scale.width, y: $0.y * scale.height) }, text: $0.text) }
        )
    }
}

/// Finds faces, codes and rule-matching text. Everything stays on this device: Vision runs locally.
struct Recognizer: Sendable {

    struct Options: Sendable {
        /// Recognition works on a copy no larger than this; boxes are mapped back to full size.
        var maxLongSide: CGFloat = 2560
        var languages: [String] = ["zh-Hans", "zh-Hant", "en-US"]
    }

    let options: Options

    init(options: Options = Options()) {
        self.options = options
    }

    /// - Parameter orientation: the EXIF orientation stored with the pixels. The result is in the
    ///   upright picture's pixels.
    func recognize(_ image: CGImage, orientation: CGImagePropertyOrientation = .up) async throws -> RecognitionResult {
        let upright = image.oriented(orientation)
        let working = upright.scaledDown(maxLongSide: options.maxLongSide)
        let scale = CGSize(width: CGFloat(upright.width) / CGFloat(working.width),
                           height: CGFloat(upright.height) / CGFloat(working.height))
        let workingSize = CGSize(width: working.width, height: working.height)

        let text = try await Self.textRequest(languages: options.languages).perform(on: working, orientation: .up)
        let faces = try await DetectFaceRectanglesRequest().perform(on: working, orientation: .up)
        let codes = try await DetectBarcodesRequest().perform(on: working, orientation: .up)

        var findings: [Finding] = []
        findings.reserveCapacity(faces.count + codes.count)
        for face in faces {
            findings.append(Self.faceFinding(face, in: workingSize, scale: scale))
        }
        for code in codes {
            findings.append(Self.codeFinding(code, in: workingSize, scale: scale))
        }
        findings.append(contentsOf: Self.textFindings(text, in: workingSize, scale: scale))
        let lines = text.map { line in
            let corners = [line.topLeft, line.topRight, line.bottomRight, line.bottomLeft]
                .map { $0.toImageCoordinates(workingSize, origin: .upperLeft) }
            let bounds = Geometry.bounds(of: corners)
            return TextLine(quad: Self.padded(corners, by: max(2, bounds.height * 0.15) + 1).map { Self.scaled($0, scale) },
                            text: line.transcript)
        }
        return RecognitionResult(size: CGSize(width: upright.width, height: upright.height), findings: findings, textLines: lines)
    }

    // MARK: - Vision requests

    private static func textRequest(languages: [String]) -> RecognizeTextRequest {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        // Correction would tidy stray characters into words, which hides order numbers and IDs.
        request.usesLanguageCorrection = false
        let supported = Set(request.supportedRecognitionLanguages)
        request.recognitionLanguages = languages
            .map { Locale.Language(identifier: $0) }
            .filter(supported.contains)
        return request
    }

    // MARK: - Mapping to pixels

    private static func faceFinding(_ face: FaceObservation, in size: CGSize, scale: CGSize) -> Finding {
        let r = face.boundingBox.toImageCoordinates(size, origin: .upperLeft)
        // The box Vision gives ends at the eyebrows and the cheeks. Hair, ears and the chin below
        // still identify a person, so it grows generously: better too much than a leak.
        let padX = r.width * 0.25
        let top = r.height * 0.5
        let bottom = r.height * 0.25
        let rect = CGRect(x: r.minX - padX, y: r.minY - top, width: r.width + 2 * padX, height: r.height + top + bottom)
        return Finding(kind: .face, quad: Self.quad(of: rect).map { Self.scaled($0, scale) })
    }

    private static func codeFinding(_ code: BarcodeObservation, in size: CGSize, scale: CGSize) -> Finding {
        let corners = [code.topLeft, code.topRight, code.bottomRight, code.bottomLeft]
            .map { $0.toImageCoordinates(size, origin: .upperLeft) }
        let bounds = Geometry.bounds(of: corners)
        let pad = max(bounds.width, bounds.height) * 0.06 + 2
        return Finding(kind: .code, quad: Self.padded(corners, by: pad).map { Self.scaled($0, scale) },
                       evidence: code.payloadString ?? "")
    }

    private static func textFindings(_ lines: [RecognizedTextObservation], in size: CGSize, scale: CGSize) -> [Finding] {
        var out: [Finding] = []
        for line in lines {
            let matches = TextRuleMatcher.matches(in: line.transcript).sorted { $0.start < $1.start }
            guard !matches.isEmpty else { continue }
            let corners = [line.topLeft, line.topRight, line.bottomRight, line.bottomLeft]
                .map { $0.toImageCoordinates(size, origin: .upperLeft) }
            let bounds = Geometry.bounds(of: corners)
            let pad = max(2, bounds.height * 0.15) + 1
            // A rule usually matches part of a line; where it sits is estimated from the characters
            // before it, counting a Latin character as a little over half of a Chinese one.
            let scalars = Array(line.transcript.precomposedStringWithCompatibilityMapping.unicodeScalars)
            let weights = scalars.map { $0.isASCII ? 0.6 : 1.0 }
            let total = weights.reduce(0, +)
            var consumed = 0
            var running = 0.0
            for m in matches {
                running += weights[consumed..<m.start].reduce(0, +)
                let f0 = total > 0 ? running / total : 0
                running += weights[m.start..<m.end].reduce(0, +)
                let f1 = total > 0 ? running / total : 1
                consumed = m.end
                let sub = Self.slice(corners, from: f0, to: f1)
                out.append(Finding(kind: .text, rule: m.rule, quad: Self.padded(sub, by: pad).map { Self.scaled($0, scale) },
                                   evidence: m.text, tolerant: m.tolerant))
            }
        }
        return out
    }

    /// The part of a quad between two fractions of the line, measured from its left edge.
    private static func slice(_ q: [CGPoint], from f0: CGFloat, to f1: CGFloat) -> [CGPoint] {
        func along(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }
        let topLeft = along(q[0], q[1], f0), topRight = along(q[0], q[1], f1)
        let bottomLeft = along(q[3], q[2], f0), bottomRight = along(q[3], q[2], f1)
        return [topLeft, topRight, bottomRight, bottomLeft]
    }

    /// Grows a quad away from its centre by `pad` pixels on every side.
    static func padded(_ q: [CGPoint], by pad: CGFloat) -> [CGPoint] {
        guard q.count == 4, pad > 0 else { return q }
        let box = Geometry.bounds(of: q)
        let c = CGPoint(x: box.midX, y: box.midY)
        let sx = box.width > 0 ? (box.width + 2 * pad) / box.width : 1
        let sy = box.height > 0 ? (box.height + 2 * pad) / box.height : 1
        return q.map { CGPoint(x: c.x + ($0.x - c.x) * sx, y: c.y + ($0.y - c.y) * sy) }
    }

    private static func quad(of rect: CGRect) -> [CGPoint] {
        [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
         CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)]
    }

    private static func scaled(_ p: CGPoint, _ scale: CGSize) -> CGPoint {
        CGPoint(x: p.x * scale.width, y: p.y * scale.height)
    }
}
