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

    /// The same box under another rule: a number cut across two lines is named by its whole length.
    func labelled(_ rule: TextRule) -> Finding {
        Finding(kind: kind, rule: rule, quad: quad, evidence: evidence, tolerant: tolerant)
    }

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
        /// Text hits closer than this many line heights become one block; 0 keeps every hit apart.
        var mergeGapEm: CGFloat = BlockMerger.defaultGapEm
        /// The second look for faces, on pictures where the first look found one. nil turns it off.
        var smallFacePass: SmallFacePass? = SmallFacePass()
    }

    /// Faces in a crowd can be a few dozen pixels wide, too small to be seen in a picture looked
    /// at whole. Once the first look has found a face, the picture is looked at again in
    /// overlapping square crops, each enlarged: what that adds is faces the first look did not see.
    ///
    /// Vision shrinks whatever it is given to about 1024 pixels on its long side before looking,
    /// then sees faces about 40 pixels up (measured in FaceMarginTests.inputCap: the same 92-pixel
    /// face is found in a 2048-pixel input and lost in a 3072-pixel one). So a crop is enlarged to
    /// just that: no less, or small faces stay small; no more, Vision would only shrink it again.
    /// The first look at a whole 2560-pixel picture is thus Vision looking at 1024 pixels, and
    /// faces under 100 pixels wide in it are not seen without this second look.
    struct SmallFacePass: Sendable {
        /// The side of each crop, in the picture's pixels.
        var cropSide: CGFloat = 512
        /// What each crop is enlarged to on its long side.
        var inputLongSide: CGFloat = 1024
        /// How much of a crop's side it shares with its neighbour: a face on one crop's edge is
        /// inside its neighbour.
        var overlap: CGFloat = 0.5
        /// The most crops a picture is cut into. Past it the crops grow, and with them the
        /// enlargement shrinks, until they fit: one crop costs about 75 ms on the simulator
        /// whatever its size. A 1536x1024 picture is 15 crops enlarged 2 times, a 2560x1920
        /// photo 24 crops enlarged 1.2 times.
        var maxCrops = 24
        /// A face seen again where one was already found is the same face, not a new one.
        var sameFaceShare: CGFloat = 0.3
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
        var faces = try await DetectFaceRectanglesRequest().perform(on: working, orientation: .up)
        if let pass = options.smallFacePass, !faces.isEmpty {
            faces += try await Self.smallFaces(in: working, pass: pass, known: faces.map(\.boundingBox))
        }
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
        findings = BlockMerger.merge(findings, options: .init(maxGapEm: options.mergeGapEm))
        let lines = text.map { line in
            let corners = [line.topLeft, line.topRight, line.bottomRight, line.bottomLeft]
                .map { $0.toImageCoordinates(workingSize, origin: .upperLeft) }
            let bounds = Geometry.bounds(of: corners)
            let p = Self.textPadding(for: nil, lineHeight: bounds.height)
            let grown = Self.padded(corners, top: p.top, bottom: p.bottom, side: p.side)
            return TextLine(quad: grown.map { Self.scaled($0, scale) },
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

    /// How a picture is cut up for the second look: `columns` by `rows` crops of `crop` pixels,
    /// each enlarged `zoom` times.
    struct CropPlan: Equatable, Sendable {
        let columns: Int, rows: Int
        let crop: CGSize
        let zoom: CGFloat
    }

    /// Crops of the given side; if there would be more than the pass allows, larger ones until
    /// there are not. The enlargement is below 1 when even the whole picture at its own pixels is
    /// more crops than allowed, and then the second look has nothing to add.
    static func cropPlan(for size: CGSize, pass: SmallFacePass) -> CropPlan {
        let width = max(size.width, 0), height = max(size.height, 0)
        guard width > 0, height > 0, pass.cropSide > 0, pass.inputLongSide > 0, pass.maxCrops > 0,
              (0..<1).contains(pass.overlap) else { return CropPlan(columns: 0, rows: 0, crop: .zero, zoom: 0) }
        /// How many crops of side `side` cover a side of the picture with the given overlap.
        func count(along length: CGFloat, side: CGFloat) -> Int {
            guard length > side else { return 1 }
            return 1 + Int(ceil((length - side) / (side * (1 - pass.overlap)) - 1e-6))
        }
        var side = pass.cropSide
        var columns = 0, rows = 0
        while true {
            columns = count(along: width, side: side)
            rows = count(along: height, side: side)
            if columns * rows <= pass.maxCrops || side >= max(width, height) { break }
            side = min(side * 1.1, max(width, height))
        }
        let crop = CGSize(width: min(side, width), height: min(side, height))
        return CropPlan(columns: columns, rows: rows, crop: crop, zoom: pass.inputLongSide / max(crop.width, crop.height))
    }

    /// Faces in the overlapping crops that lie where no face was found yet, as observations of
    /// the whole picture.
    static func smallFaces(in image: CGImage, pass: SmallFacePass, known: [NormalizedRect]) async throws -> [FaceObservation] {
        let width = CGFloat(image.width), height = CGFloat(image.height)
        let plan = cropPlan(for: CGSize(width: width, height: height), pass: pass)
        // A crop enlarged to less than the picture's own pixels shows nothing new.
        guard plan.columns > 0, plan.rows > 0, plan.zoom >= 1 else { return [] }
        let zoom = plan.zoom
        func area(_ r: CGRect) -> CGFloat { max(r.width * r.height, 0) }
        var found: [FaceObservation] = []
        for row in 0..<plan.rows {
            for column in 0..<plan.columns {
                let x = plan.columns > 1 ? CGFloat(column) * (width - plan.crop.width) / CGFloat(plan.columns - 1) : 0
                let y = plan.rows > 1 ? CGFloat(row) * (height - plan.crop.height) / CGFloat(plan.rows - 1) : 0
                let crop = CGRect(x: x, y: y, width: plan.crop.width, height: plan.crop.height)
                guard let piece = image.cropping(to: crop),
                      let big = piece.resized(to: CGSize(width: crop.width * zoom, height: crop.height * zoom))
                else { continue }
                let seen = try await DetectFaceRectanglesRequest().perform(on: big, orientation: .up)
                for face in seen {
                    // Crop fractions, then whole-picture fractions. Vision counts y from the bottom, so
                    // the crop's bottom edge is where its y starts.
                    let local = face.boundingBox.cgRect
                    let box = CGRect(x: (crop.minX + local.minX * crop.width) / width,
                                     y: (height - crop.maxY) / height + local.minY * crop.height / height,
                                     width: local.width * crop.width / width, height: local.height * crop.height / height)
                    // Seen in the first look, or already in an overlapping crop of this one.
                    let same = (known + found.map(\.boundingBox)).contains { other in
                        let o = other.cgRect
                        return area(box.intersection(o)) >= pass.sameFaceShare * min(area(box), area(o))
                    }
                    if !same { found.append(FaceObservation(boundingBox: NormalizedRect(x: box.minX, y: box.minY, width: box.width, height: box.height))) }
                }
            }
        }
        return found
    }

    /// How far a face mask reaches beyond the box Vision gives, as a share of that box's sides.
    /// Set from what the frozen baseline pictures need (FaceMarginTests measures it): of the 26
    /// faces Vision saw, the truth reached beyond its box by up to 0.50 of its width on the left
    /// (two profile faces; 0.49 on a small one in the crowd, 0.40 on a backlit one), 0.35 on the
    /// right, 0.65 of its height above (a profile face; the ID card photo 0.54) and 0.22 below.
    /// Sides are padded alike, since a face may look either way.
    static let facePadX: CGFloat = 0.5
    static let facePadTop: CGFloat = 0.65
    static let facePadBottom: CGFloat = 0.3

    /// How far a text mask reaches beyond the box Vision gives, as a share of that box's height.
    /// Vision's box runs from the top of the capitals to a little under the baseline, while a line
    /// as laid out reaches about half a box higher still (the space above the capitals, where the
    /// long strokes of letters like h and l also stand). On the frozen baseline pictures the truth
    /// reached 0.47 of the box above it, 0.17 below and 0.24 to the sides, so a half, a fifth and
    /// a quarter leave a margin. A plate is different: its truth is the plate's whole face, which
    /// reached 0.43 of the box's height to the left and right, 0.31 above and 0.23 below.
    static func textPadding(for rule: TextRule?) -> (top: CGFloat, bottom: CGFloat, side: CGFloat) {
        rule == .plate ? (0.35, 0.3, 0.5) : (0.5, 0.2, 0.25)
    }

    /// The same for a line box `height` tall, in working pixels: the share of the height, but
    /// never under two pixels, and one more so the mask covers the box's own edge.
    static func textPadding(for rule: TextRule?, lineHeight: CGFloat) -> (top: CGFloat, bottom: CGFloat, side: CGFloat) {
        let p = textPadding(for: rule)
        return (max(2, lineHeight * p.top) + 1, max(2, lineHeight * p.bottom) + 1, max(2, lineHeight * p.side) + 1)
    }

    private static func faceFinding(_ face: FaceObservation, in size: CGSize, scale: CGSize) -> Finding {
        let r = face.boundingBox.toImageCoordinates(size, origin: .upperLeft)
        // The box Vision gives ends at the eyebrows and the cheeks. Hair, ears and the chin below
        // still identify a person, so it grows generously: better too much than a leak.
        let padX = r.width * facePadX
        let top = r.height * facePadTop
        let bottom = r.height * facePadBottom
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
        let read = lines.map { Self.readLine($0, in: size) }
        var byLine: [[Finding]] = read.map { line in
            line.runs.map { m in
                let p = line.padding(for: m.rule)
                let grown = Self.padded(line.quad(from: m.start, to: m.end), top: p.top, bottom: p.bottom, side: p.side)
                return Finding(kind: .text, rule: m.rule,
                               quad: grown.map { Self.scaled($0, scale) },
                               evidence: m.text, tolerant: m.tolerant)
            }
        }

        // A line that wraps carries the rest of its number or address down to the next line, where
        // no rule can know the piece for what it is. The piece is hidden with what it continues.
        for (i, line) in read.enumerated() where !byLine[i].isEmpty {
            guard let last = line.matches.last, line.scalars[last.end...].allSatisfy({ $0.properties.isWhitespace }),
                  let below = Self.lineBelow(i, in: read), let piece = Self.continuation(read[below], of: last) else { continue }
            let p = read[below].padding(for: piece.rule ?? last.rule)
            byLine[i].append(Finding(kind: .text, rule: piece.rule ?? last.rule,
                                     quad: Self.padded(read[below].quad(from: 0, to: piece.end), top: p.top, bottom: p.bottom, side: p.side)
                                         .map { Self.scaled($0, scale) },
                                     evidence: read[below].text(to: piece.end), tolerant: last.tolerant))
            if let rule = piece.rule {
                byLine[i][byLine[i].count - 2] = byLine[i][byLine[i].count - 2].labelled(rule)
            }
        }
        return byLine.flatMap { $0 }
    }

    /// One recognized line: where it is in working pixels, its characters, and what matched in them.
    private struct ReadLine {
        let quad: [CGPoint]
        let box: CGRect
        let text: String
        let scalars: [Unicode.Scalar]
        /// How much of the line's width each character takes: a Latin character is a little over
        /// half of a Chinese one.
        let widths: [CGFloat]
        let total: CGFloat
        let matches: [RuleMatch]
        /// Vision's own placing of the line's characters, when its text and the line's read the same.
        let placed: Placement?

        /// How far a mask for `rule` reaches beyond this line's box on each side.
        func padding(for rule: TextRule?) -> (top: CGFloat, bottom: CGFloat, side: CGFloat) {
            Recognizer.textPadding(for: rule, lineHeight: box.height)
        }

        /// The matches, each grown to the whole run of characters it sits in, and runs that touch
        /// joined.
        var runs: [RuleMatch] { RuleMatch.grow(matches, in: scalars) }

        /// The characters from `start` up to `end` as a share of the line's width, from the widths
        /// of the characters before them: a Latin character a little over half a Chinese one.
        func share(_ index: Int) -> CGFloat {
            total > 0 ? widths[..<min(max(index, 0), widths.count)].reduce(0, +) / total : 0
        }

        /// The part of the line from one character up to another. Where Vision places them wins:
        /// it boxes a run by the words it touches, which on the frozen baseline pictures put the
        /// digits of an ID number within 3 pixels where the widths put them 75 off, since on that
        /// card a digit is wider than the Chinese label before it. Vision's box is taken only when
        /// it is no narrower than a third of what the widths say, since it tells whole words and
        /// not characters, and the line's own top and bottom are kept.
        func quad(from start: Int, to end: Int) -> [CGPoint] {
            let e0 = share(start), e1 = share(end)
            let a = quad[0], b = quad[1]
            let ux = b.x - a.x, uy = b.y - a.y
            let squared = ux * ux + uy * uy
            if let placed, squared > 0, let corners = placed.corners(from: start, to: end) {
                func along(_ p: CGPoint, _ q: CGPoint) -> CGFloat { ((p.x + q.x) / 2 - a.x) * ux + ((p.y + q.y) / 2 - a.y) * uy }
                let v0 = along(corners[0], corners[3]) / squared
                let v1 = along(corners[1], corners[2]) / squared
                if v1 > v0, v1 - v0 >= 0.33 * max(e1 - e0, 0.01) {
                    return Recognizer.slice(quad, from: min(max(v0, 0), 1), to: min(max(v1, 0), 1))
                }
            }
            return Recognizer.slice(quad, from: e0, to: e1)
        }

        /// The characters from the start of the line up to `end`.
        func text(to end: Int) -> String { String(text.unicodeScalars.prefix(end)) }
    }

    private static func readLine(_ line: RecognizedTextObservation, in size: CGSize) -> ReadLine {
        let quad = [line.topLeft, line.topRight, line.bottomRight, line.bottomLeft]
            .map { $0.toImageCoordinates(size, origin: .upperLeft) }
        // A rule usually matches part of a line; where it sits comes from Vision when it says,
        // and is estimated from the characters before it when it does not.
        let text = line.transcript.precomposedStringWithCompatibilityMapping
        let scalars = Array(text.unicodeScalars)
        let widths: [CGFloat] = scalars.map { $0.isASCII ? 0.6 : 1.0 }
        let candidate = line.topCandidates(1).first
        let placed = candidate.flatMap { $0.string.unicodeScalars.count == scalars.count ? Placement(candidate: $0, size: size) : nil }
        return ReadLine(quad: quad, box: Geometry.bounds(of: quad), text: text, scalars: scalars, widths: widths,
                        total: widths.reduce(0, +),
                        matches: TextRuleMatcher.matches(in: line.transcript).sorted { $0.start < $1.start },
                        placed: placed)
    }

    /// What Vision read of a line, asked where a stretch of its characters stands. Its answer is
    /// in working pixels, corners top left, top right, bottom right, bottom left.
    private struct Placement {
        let candidate: RecognizedText
        let size: CGSize

        func corners(from start: Int, to end: Int) -> [CGPoint]? {
            let text = candidate.string
            guard end > start, end <= text.unicodeScalars.count else { return nil }
            let from = text.unicodeScalars.index(text.startIndex, offsetBy: start)
            let to = text.unicodeScalars.index(text.startIndex, offsetBy: end)
            guard let box = candidate.boundingBox(for: from..<to) else { return nil }
            return [box.topLeft, box.topRight, box.bottomRight, box.bottomLeft].map { $0.toImageCoordinates(size, origin: .upperLeft) }
        }
    }

    /// The next line of the same paragraph: right under line `i`, starting where a wrapped line
    /// starts. A paragraph's first line may be indented, so the line below may start further left.
    private static func lineBelow(_ i: Int, in read: [ReadLine]) -> Int? {
        let line = read[i]
        let em = max(line.box.height, 1)
        var best: (index: Int, gap: CGFloat)?
        for (j, other) in read.enumerated() where j != i {
            guard other.box.minY >= line.box.midY, other.box.minX < line.box.maxX, other.box.maxX > line.box.minX else { continue }
            let gap = other.box.minY - line.box.maxY
            let indent = other.box.minX - line.box.minX
            guard gap <= 1.2 * em, indent >= -2.5 * em, indent <= 0.75 * em else { continue }
            if best.map({ gap < $0.gap }) ?? true { best = (j, gap) }
        }
        return best?.index
    }

    /// The piece of `anchor` that starts `line`: where the piece ends, and the rule the whole
    /// number follows once its two halves are counted together, when that is another rule.
    private static func continuation(_ line: ReadLine, of anchor: RuleMatch) -> (end: Int, rule: TextRule?)? {
        let end: Int
        switch anchor.rule {
        case .phone, .idNumber, .bankCard, .ipv4, .reference:
            guard let n = Self.leadingNumber(in: line, like: anchor.text) else { return nil }
            end = n
        case .email, .url:
            guard let n = Self.leadingAddress(in: line.scalars) else { return nil }
            end = n
        case .plate:
            return nil
        }
        // Sixteen digits and two more make eighteen: an ID cut in two, not a card.
        guard anchor.rule == .bankCard || anchor.rule == .reference else { return (end, nil) }
        let digits = (anchor.text + line.text(to: end)).unicodeScalars.filter(Self.isDigit).count
        switch digits {
        case 18: return (end, .idNumber)
        case 16...19: return (end, anchor.rule == .reference ? .bankCard : nil)
        default: return (end, nil)
        }
    }

    private static func isDigit(_ s: Unicode.Scalar) -> Bool { (48...57).contains(s.value) }

    private static func isNumberCharacter(_ s: Unicode.Scalar) -> Bool {
        isDigit(s) || s.value == 88 || s.value == 120   // X, x
    }

    /// How many characters from `start` on pass `test`.
    private static func leading(in scalars: [Unicode.Scalar], from start: Int, where test: (Unicode.Scalar) -> Bool) -> Int {
        var end = start
        while end < scalars.count, test(scalars[end]) { end += 1 }
        return end - start
    }

    /// Digits at the start of a line, in the groups a card number is printed in. Where they end, or
    /// nil under two: a date or a count is not the rest of a number. The groups are parted the way
    /// the first half is, and a date is not it: 2026-11-23 is the start of a line, not the end of a card.
    private static func leadingNumber(in line: ReadLine, like anchor: String) -> Int? {
        let separators = " -\u{00A0}".unicodeScalars
        let scalars = line.scalars
        var end = Self.leading(in: scalars, from: 0, where: isNumberCharacter)
        guard end >= 2 else { return nil }
        if anchor.unicodeScalars.contains(where: { separators.contains($0) }) {
            while true {
                var space = end
                while space < scalars.count, separators.contains(scalars[space]) { space += 1 }
                let more = Self.leading(in: scalars, from: space, where: isNumberCharacter)
                guard space > end, space - end <= 2, more >= 2 else { break }
                end = space + more
            }
        }
        // "09:00" or "11月23日": what comes right after the digits dates the line.
        if end < scalars.count, "-:/年月日".unicodeScalars.contains(scalars[end]) { return nil }
        let groups = line.text(to: end).unicodeScalars.split { separators.contains($0) }.map(\.count)
        if groups.count == 3, groups[0] == 4, groups[1] <= 2, groups[2] <= 2,
           ["18", "19", "20"].contains(where: { line.text(to: end).hasPrefix($0) }) { return nil }
        return end
    }

    /// The rest of a mail or web address at the start of a line: letters, digits and the marks
    /// addresses are written with, and in it something an ordinary word does not have: a digit,
    /// a slash or an at sign, or a dot between two names rather than at the end of a sentence.
    private static func leadingAddress(in scalars: [Unicode.Scalar]) -> Int? {
        let marks = "._%+-/:?=&#~@".unicodeScalars
        let strong = "/_%+:@?=&#~".unicodeScalars
        func isLetter(_ s: Unicode.Scalar) -> Bool { (65...90).contains(s.value) || (97...122).contains(s.value) }
        func isAddressCharacter(_ s: Unicode.Scalar) -> Bool { isDigit(s) || isLetter(s) || marks.contains(s) }
        let end = Self.leading(in: scalars, from: 0, where: isAddressCharacter)
        guard end >= 2 else { return nil }
        let piece = scalars[..<end]
        let named = (1..<(end - 1)).contains { piece[$0] == "." && isLetter(piece[$0 - 1]) && isLetter(piece[$0 + 1]) }
        guard named || piece.contains(where: { strong.contains($0) || isDigit($0) }) else { return nil }
        return end
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

    /// Grows a quad along its own sides: `top` and `bottom` away from its top and bottom edges,
    /// `side` away from its left and right edges. The corners are top left, top right, bottom
    /// right, bottom left, so a tilted line grows along its tilt.
    static func padded(_ q: [CGPoint], top: CGFloat, bottom: CGFloat, side: CGFloat) -> [CGPoint] {
        guard q.count == 4 else { return q }
        let edge = CGPoint(x: q[1].x - q[0].x, y: q[1].y - q[0].y)
        let rise = CGPoint(x: q[0].x - q[3].x, y: q[0].y - q[3].y)
        let along = (edge.x * edge.x + edge.y * edge.y).squareRoot()
        let across = (rise.x * rise.x + rise.y * rise.y).squareRoot()
        guard along > 0, across > 0 else { return padded(q, by: max(top, bottom, side)) }
        let right = CGPoint(x: edge.x / along, y: edge.y / along)
        let up = CGPoint(x: rise.x / across, y: rise.y / across)
        func moved(_ p: CGPoint, _ a: CGFloat, _ b: CGFloat) -> CGPoint {
            CGPoint(x: p.x + right.x * a + up.x * b, y: p.y + right.y * a + up.y * b)
        }
        return [moved(q[0], -side, top), moved(q[1], side, top), moved(q[2], side, -bottom), moved(q[3], -side, -bottom)]
    }

    private static func quad(of rect: CGRect) -> [CGPoint] {
        [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
         CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)]
    }

    private static func scaled(_ p: CGPoint, _ scale: CGSize) -> CGPoint {
        CGPoint(x: p.x * scale.width, y: p.y * scale.height)
    }
}
