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
    /// The smallest rectangle around `quad` and every box in `parts`.
    let box: CGRect
    /// The area to fill, padded already: top-left, top-right, bottom-right, bottom-left. The
    /// item's first box, and its only one but for a value a line wrap cut in two.
    let quad: [CGPoint]
    /// The item's other boxes, padded already, in any order: the second line of a wrapped value.
    /// Empty for one box.
    let parts: [[CGPoint]]
    /// What was recognized: the matched text, or the code payload. Empty for faces.
    let evidence: String
    /// The rule matched only after OCR confusions were fixed.
    let tolerant: Bool
    /// For text the recognizer read, a rule's hit or a line under「cover all text」: the height of
    /// Vision's box for the tallest piece of the item, before any padding or widening, in pixels of
    /// the upright picture. The mosaic's cells and the blur's grains over the box are sized by it
    /// (`MaskRenderer.grid`). Nil for faces, codes and boxes drawn by hand.
    let textHeight: CGFloat?
    /// A box drawn by hand: nothing was read under it.
    let drawnByHand: Bool

    /// Every box of the item, `quad` first.
    var quads: [[CGPoint]] { [quad] + parts }

    /// The smallest rectangle around each box apart: the item hides what these hide and, for a
    /// wrapped value, not what lies between them.
    var boxes: [CGRect] { quads.map(Geometry.bounds(of:)) }

    /// The rectangle around `quad` alone: the line the item stands on. Two hits are on one line
    /// when these overlap sideways, whatever `box` spans.
    var lineBox: CGRect { Geometry.bounds(of: quad) }

    /// The same box under another rule: a number cut across two lines is named by its whole length.
    func labelled(_ rule: TextRule) -> Finding {
        Finding(kind: kind, rule: rule, pieces: quads, evidence: evidence, tolerant: tolerant,
                textHeight: textHeight, drawnByHand: drawnByHand)
    }

    /// The same thing in a picture scaled by `scale`.
    func scaled(by scale: CGSize) -> Finding {
        Finding(kind: kind, rule: rule,
                pieces: quads.map { $0.map { CGPoint(x: $0.x * scale.width, y: $0.y * scale.height) } },
                evidence: evidence, tolerant: tolerant, textHeight: textHeight.map { $0 * scale.height },
                drawnByHand: drawnByHand)
    }

    /// One box.
    init(kind: Kind, rule: TextRule? = nil, quad: [CGPoint], evidence: String = "", tolerant: Bool = false,
         textHeight: CGFloat? = nil, drawnByHand: Bool = false) {
        self.init(kind: kind, rule: rule, pieces: [quad], evidence: evidence, tolerant: tolerant,
                  textHeight: textHeight, drawnByHand: drawnByHand)
    }

    /// The boxes of one item, at least one: the first is `quad`, the others are `parts`.
    init(kind: Kind, rule: TextRule? = nil, pieces: [[CGPoint]], evidence: String = "", tolerant: Bool = false,
         textHeight: CGFloat? = nil, drawnByHand: Bool = false) {
        self.kind = kind
        self.rule = rule
        self.quad = pieces.first ?? []
        self.parts = Array(pieces.dropFirst())
        self.evidence = evidence
        self.tolerant = tolerant
        self.textHeight = textHeight
        self.drawnByHand = drawnByHand
        self.box = Geometry.bounds(of: pieces.flatMap { $0 })
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
    /// The line's box, padded a little.
    let quad: [CGPoint]
    let text: String
    /// The height of the box Vision gave, before the padding, in pixels of the picture: what the
    /// mosaic's cells are sized by once the line is covered (`Finding.textHeight`).
    let lineHeight: CGFloat?

    init(quad: [CGPoint], text: String, lineHeight: CGFloat? = nil) {
        self.quad = quad
        self.text = text
        self.lineHeight = lineHeight
    }
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
            textLines: textLines.map {
                TextLine(quad: $0.quad.map { CGPoint(x: $0.x * scale.width, y: $0.y * scale.height) }, text: $0.text,
                         lineHeight: $0.lineHeight.map { $0 * scale.height })
            })
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

        let handler = ImageRequestHandler(working, orientation: .up)
        let (text, initialFaces, codes) = try await handler.perform(
            Self.textRequest(languages: options.languages),
            Self.faceRequest(),
            DetectBarcodesRequest()
        )
        var faces = initialFaces
        if let pass = options.smallFacePass, !faces.isEmpty {
            faces += try await Self.smallFaces(in: working, pass: pass, known: faces.map(\.boundingBox))
        }

        var findings: [Finding] = []
        findings.reserveCapacity(faces.count + codes.count)
        for face in faces {
            findings.append(Self.faceFinding(face, in: workingSize, scale: scale))
        }
        for code in codes {
            findings.append(Self.codeFinding(code, in: workingSize, scale: scale))
        }
        findings.append(contentsOf: Self.textFindings(text, in: workingSize, scale: scale, readOn: working))
        findings = BlockMerger.merge(findings, options: .init(maxGapEm: options.mergeGapEm))
        let lines = text.map { line in
            let corners = [line.topLeft, line.topRight, line.bottomRight, line.bottomLeft]
                .map { $0.toImageCoordinates(workingSize, origin: .upperLeft) }
            let bounds = Geometry.bounds(of: corners)
            let p = Self.textPadding(for: nil, lineHeight: bounds.height)
            let grown = Self.padded(corners, top: p.top, bottom: p.bottom, side: p.side)
            return TextLine(quad: grown.map { Self.scaled($0, scale) },
                            text: line.transcript, lineHeight: bounds.height * scale.height)
        }
        return RecognitionResult(size: CGSize(width: upright.width, height: upright.height), findings: findings, textLines: lines)
    }

    // MARK: - Vision requests

    private static func faceRequest() -> DetectFaceRectanglesRequest {
        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            return DetectFaceRectanglesRequest(.revision4)
        }
        #endif
        return DetectFaceRectanglesRequest()
    }

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
                let seen = try await Self.faceRequest().perform(on: big, orientation: .up)
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

    /// A piece's padded box, kept clear of the lines around it.
    ///
    /// Where the box of a line above ends above the box of the piece's own line — a gap between the
    /// two boxes — the padding stops at that box, and the same below: the margin is taken in the
    /// gap and only up to the neighbour, never over its glyphs; where the two boxes overlap by a
    /// hair, the margin keeps a twentieth of the line over the piece's own box. A wrapped value's
    /// piece on a line is boxed just as a hit on that line alone would be.
    ///
    /// A box is not its glyphs, though: Vision runs a line's box under its last glyph by a couple
    /// of pixels in one rendering and by half a line in another — a line with a full-width comma or
    /// Chinese characters in a browser's type gets a box a tenth to a fifth of its height under its
    /// glyphs — and nothing in the box tells the two apart. Given the picture (`inkBottom`), the
    /// margin above goes on up to the line's ink itself under the piece's columns, and never over
    /// one row of it: a line as laid out starts about a fifth of a box above its own capitals, and
    /// the frozen truth boxes are laid-out lines, so that space has to be covered where the line
    /// over it ends well above it. Without the picture, the box stands for the ink.
    ///
    /// Only on a line whose box takes in most of its row, the distance from its top to the top of
    /// the line over or under it: such a box has the space above the capitals in it already, and
    /// the margin above it has nothing left to cover. A bare number's box, which is just its
    /// digits, keeps its whole margin, ascenders and all.
    ///
    /// One swollen box is cut, a box taller than its row. A line ending in a full-width comma gets
    /// from Vision a box that runs half a line under its baseline, into the row under it. Where
    /// the line under it has a box no taller than its own row, its top is where this line's glyphs
    /// end, and the piece's box ends there too — unless the piece has a letter that hangs under
    /// the baseline, which would be cut with the box.
    private static func clearOfNeighbours(_ padded: [CGPoint], on line: Int, glyphs: String, in read: [ReadLine],
                                          inkBottom: @escaping (CGRect) -> CGFloat?) -> [CGPoint] {
        let box = Geometry.bounds(of: padded)
        let kept = clearOfNeighbours(box, own: read[line].box, glyphs: glyphs, lines: read.map(\.box), inkBottom: inkBottom)
        guard kept != box else { return padded }
        return padded.map { CGPoint(x: $0.x, y: min(max($0.y, kept.minY), kept.maxY)) }
    }

    /// A piece's box cut short of the ink written beside it on its line. The side margins are a
    /// quarter of the line's height, half of it for a plate, and cover whatever stands within them:
    /// the comma after a phone number, the colon before an address, the character before a plate.
    /// Given the picture (`inkColumns`), the margin stops a pixel short of the first column of ink
    /// past the box of the piece's own glyphs — the first after a column without ink, so the edge
    /// of a glyph hanging over its box is no stop — and never inside that box. Only where something
    /// is written beside the piece on its line: a plate alone on its line, in a photo, keeps its
    /// margin, what lies around it there being no text. Without the picture the margin stands.
    /// The ink is read in the rows of the piece's line alone (`line`): what is written on the lines
    /// over and under it is no neighbour.
    static func clearOfInk(_ quad: [CGPoint], range: [CGPoint], beside: Bool, line: CGRect,
                           inkColumns: ((CGRect) -> (origin: CGFloat, ink: [Bool])?)?) -> [CGPoint] {
        guard beside, let inkColumns else { return quad }
        let box = Geometry.bounds(of: quad)
        let rows = CGRect(x: box.minX, y: max(box.minY, line.minY), width: box.width,
                          height: min(box.maxY, line.maxY) - max(box.minY, line.minY))
        guard rows.height >= 1, let (origin, ink) = inkColumns(rows) else { return quad }
        let kept = clearOfInk(box, range: Geometry.bounds(of: range), origin: origin, ink: ink)
        guard kept.minX != box.minX || kept.maxX != box.maxX else { return quad }
        return quad.enumerated().map { i, p in
            // Corners top left, top right, bottom right, bottom left: the two of an edge move with it.
            CGPoint(x: i == 0 || i == 3 ? max(p.x, kept.minX) : min(p.x, kept.maxX), y: p.y)
        }
    }

    /// The same on a box: `box` grown from the box `range` of the piece's glyphs; `ink` tells which
    /// columns of the picture under `box` hold ink, the first of them at x `origin`.
    static func clearOfInk(_ box: CGRect, range: CGRect, origin: CGFloat, ink: [Bool]) -> CGRect {
        var left = box.minX, right = box.maxX
        func column(_ x: CGFloat) -> Int { Int((x - origin).rounded(.down)) }
        // Looking right from the column the glyphs end in, and left from the one they start in.
        var blank = false
        let after = column(range.maxX)
        if after >= 0 && after < ink.count {
            for k in after..<ink.count {
                if !ink[k] { blank = true }
                else if blank { right = min(right, max(range.maxX, origin + CGFloat(k) - 1)); break }
            }
        }
        blank = false
        let before = column(range.minX)
        if before >= 0 && before < ink.count {
            for k in stride(from: before, through: 0, by: -1) {
                if !ink[k] { blank = true }
                else if blank { left = max(left, min(range.minX, origin + CGFloat(k) + 1)); break }
            }
        }
        guard left != box.minX || right != box.maxX else { return box }
        return CGRect(x: left, y: box.minY, width: right - left, height: box.height)
    }

    /// The same on boxes: `padded`, grown from the box `own` of its line, among the boxes of all
    /// the lines of the picture. `inkBottom` gives, for a band of the picture, the bottom edge of
    /// the lowest row of ink in it; without it the box of the line above stands for its ink.
    static func clearOfNeighbours(_ padded: CGRect, own: CGRect, glyphs: String, lines: [CGRect],
                                  inkBottom: ((CGRect) -> CGFloat?)? = nil) -> CGRect {
        let around = lines.filter { $0 != own && $0.maxX > padded.minX && $0.minX < padded.maxX }
        // The row of the line: from the top of its box to the top of the nearest line over or under
        // it. A line beside it on the same row is neither.
        guard let row = around.map({ abs($0.minY - own.minY) }).filter({ $0 > own.height / 4 }).min(),
              own.height >= row * mostOfRow else { return padded }
        let hair = own.height / 10
        var top = padded.minY
        var bottom = padded.maxY
        for b in around {
            if b.minY >= own.maxY - hair { bottom = min(bottom, max(b.minY, own.maxY)) }
            guard b.maxY <= own.minY + hair else { continue }
            var stop = min(b.maxY, own.minY)
            // The part of the line's box over the piece's columns and over our own box: where its
            // ink ends there, the margin may reach up to it.
            let band = CGRect(x: max(b.minX, padded.minX), y: b.minY,
                              width: min(b.maxX, padded.maxX) - max(b.minX, padded.minX),
                              height: stop - b.minY)
            if band.width >= 1, band.height >= 1, let inkBottom, let ink = inkBottom(band) { stop = min(max(ink, b.minY), stop) }
            // The line's box running into ours does not take the ascenders' space away: a twentieth of
            // the line stays over the piece's own box, the bottom edge of a hanging letter at most.
            if b.maxY > own.minY { stop = min(stop, own.minY - own.height * ascendersKeep) }
            top = max(top, stop)
        }
        if own.height > row, !glyphs.contains(where: { hangs.contains($0) }),
           let under = around.filter({ $0.minY > own.minY && $0.minY < own.maxY - hair }).min(by: { $0.minY < $1.minY }) {
            // The row of the line under ours: up to the line under that, or, it being the last, as
            // tall as its distance from ours.
            let after = around.filter { $0.minY > under.minY && $0.maxX > under.minX && $0.minX < under.maxX }.map(\.minY).min() ?? (2 * under.minY - own.minY)
            if under.height <= after - under.minY { bottom = min(bottom, under.minY) }
        }
        guard top != padded.minY || bottom != padded.maxY else { return padded }
        return CGRect(x: padded.minX, y: top, width: padded.width, height: max(0, bottom - top))
    }

    /// A box that takes in most of its row, as a share of the row.
    private static let mostOfRow: CGFloat = 0.85

    /// The margin a line keeps over its own box top when the box of the line above runs into it.
    private static let ascendersKeep: CGFloat = 0.05

    /// Letters that hang under the baseline of a line.
    private static let hangs: Set<Character> = ["g", "j", "p", "q", "y", "@", "Q", "J", "_", "(", ")", "[", "]", "{", "}", ";", ","]

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

    private static func textFindings(_ lines: [RecognizedTextObservation], in size: CGSize, scale: CGSize,
                                    readOn picture: CGImage) -> [Finding] {
        let read = lines.map { Self.readLine($0, in: size) }
        // Where the ink of a line ends under a piece's columns, read off the picture the lines were read on.
        let inkBottom: (CGRect) -> CGFloat? = { Ink.bottom(in: $0, of: picture) }
        // Which columns under a piece's box hold ink, for the side margins to stop at the ink beside it.
        let inkColumns: (CGRect) -> (origin: CGFloat, ink: [Bool])? = { Ink.columns(in: $0, of: picture) }

        // One line's share of a value: the characters it covers on that line, and the box that
        // hides them, in upright pixels, padded.
        struct Piece {
            let line: Int
            let range: Range<Int>
            let rule: TextRule
            let quad: [CGPoint]
            /// The height of the piece's box before the padding, Vision's box for these characters
            /// on their line, in pixels of the picture (`Finding.textHeight`).
            let lineHeight: CGFloat
            let evidence: String
            let tolerant: Bool
        }
        func piece(_ line: Int, _ range: Range<Int>, _ rule: TextRule, evidence: String? = nil, tolerant: Bool = false) -> Piece {
            let l = read[line]
            let p = l.padding(for: rule)
            let glyphs = String(String.UnicodeScalarView(l.scalars[range]))
            let own = l.quad(from: range.lowerBound, to: range.upperBound)
            let padded = Self.padded(own, top: p.top, bottom: p.bottom, side: p.side)
            let cleared = Self.clearOfNeighbours(padded, on: line, glyphs: glyphs, in: read, inkBottom: inkBottom)
            let beside = l.scalars.indices.contains { !range.contains($0) && !l.scalars[$0].properties.isWhitespace }
            let quad = Self.clearOfInk(cleared, range: own, beside: beside, line: l.box, inkColumns: inkColumns).map { Self.scaled($0, scale) }
            return Piece(line: line, range: range, rule: rule, quad: quad,
                         lineHeight: Geometry.bounds(of: own).height * scale.height,
                         evidence: evidence ?? glyphs, tolerant: tolerant)
        }
        // Whether `q` is `p` over again: the same characters of the same line, or more around
        // them, or a box cut from the line a second time that holds p a pixel aside on every side.
        func taken(_ p: Piece, by q: Piece) -> Bool {
            guard p.line == q.line else { return false }
            if q.range.lowerBound <= p.range.lowerBound, p.range.upperBound <= q.range.upperBound { return true }
            let a = Geometry.bounds(of: p.quad), b = Geometry.bounds(of: q.quad), slack = WrapGeometry.takenSlack
            return a.minX >= b.minX - slack && a.maxX <= b.maxX + slack && a.minY >= b.minY - slack && a.maxY <= b.maxY + slack
        }
        // A value a wrap cut in two or three: its pieces in the order of its lines, and what it reads.
        struct Value {
            let pieces: [Piece]
            let evidence: String
        }

        // 1. What each line carries whole.
        var singles: [Piece] = []
        for (i, line) in read.enumerated() {
            for m in line.runs { singles.append(piece(i, m.start..<m.end, m.rule, evidence: m.text, tolerant: m.tolerant)) }
        }

        // 2. A line that wraps carries the rest of its number or address down to the next line,
        // where no rule can know the piece for what it is. The piece is hidden with what it
        // continues, as one item: one box each, one switch in the checklist.
        var continued: [Value] = []
        for (i, line) in read.enumerated() where !line.matches.isEmpty {
            guard let last = line.matches.last, line.scalars[last.end...].allSatisfy({ $0.properties.isWhitespace }),
                  let below = Self.lineBelow(i, in: read), let rest = Self.continuation(read[below], of: last) else { continue }
            let rule = rest.rule ?? last.rule
            // The value follows another rule once its halves are counted together: sixteen digits
            // and two more are an ID number. The box is the one its line hid already.
            let k = singles.firstIndex { $0.line == i && $0.range.lowerBound <= last.start && last.end <= $0.range.upperBound }
            let anchor = piece(i, k.map { singles[$0].range } ?? last.start..<last.end, rule,
                               evidence: k.map { singles[$0].evidence } ?? last.text, tolerant: k.map { singles[$0].tolerant } ?? last.tolerant)
            if let k { singles[k] = anchor }
            let tail = piece(below, 0..<rest.end, rule, evidence: read[below].text(to: rest.end), tolerant: anchor.tolerant)
            // A number printed in groups keeps a space between the groups it was cut in; a value
            // cut inside a run reads on without one.
            let apart = rule == .phone || rule == .bankCard
            continued.append(Value(pieces: [anchor, tail], evidence: anchor.evidence + (apart ? " " : "") + tail.evidence))
        }

        // 3. A value the wrap cut where no rule can know either piece for what it is: read as one
        // line, the lines match across the cut. A line and the one under it that starts at the
        // same left edge are where a wrap is; a value may be cut twice, over three lines.
        let lines = read.indices.sorted { (read[$0].box.minY, read[$0].box.minX) < (read[$1].box.minY, read[$1].box.minX) }
        func wraps(_ a: Int, _ b: Int) -> Bool {
            WrapGeometry.wraps(from: read[a].box, characters: read[a].scalars.count, to: read[b].box)
        }
        // The lines a wrap may run over: three where each line passes the geometry with the one
        // under it, then two that pass it. Three first: a value cut twice is one item of three
        // boxes, and its pairs are found again inside it and skipped.
        var triples: [[Int]] = []
        var pairs: [[Int]] = []
        for (k, a) in lines.enumerated() {
            for b in lines.dropFirst(k + 1) where wraps(a, b) {
                for c in lines.dropFirst(k + 2) where wraps(b, c) { triples.append([a, b, c]) }
                pairs.append([a, b])
            }
        }
        var joined: [Value] = []
        for group in triples + pairs {
            for match in TextRuleMatcher.junctionMatches(lines: group.map { read[$0].text }) {
                let pieces = zip(group, match.ranges).compactMap { (index: Int, range: Range<Int>?) -> Piece? in
                    guard let range, !range.isEmpty else { return nil }
                    return piece(index, range, match.rule, evidence: match.text)
                }
                // The same value told already, in one item: its pair inside its triple, or the cut
                // its pieces were hidden by on their own lines. Every piece of it is a piece of that
                // one value.
                guard !(continued + joined).contains(where: { told in pieces.allSatisfy({ p in told.pieces.contains { taken(p, by: $0) } }) }) else { continue }
                joined.append(Value(pieces: pieces, evidence: match.text))
            }
        }

        // 4. One value, one item. A wrapped value takes in the pieces that hid its parts on their
        // own lines and goes in place of the first of them; the others are not told a second time.
        // A value cut over three lines is told in the three lines it takes; the two-line pieces of
        // it, the first two and the last two, are readings of the same pieces and are not told.
        let all = continued + joined
        let values = all.filter { v in
            !all.contains { w in w.pieces.count > v.pieces.count && v.pieces.allSatisfy { p in w.pieces.contains { taken(p, by: $0) } } }
        }
        var out: [Finding] = []
        var told = Array(repeating: false, count: values.count)
        func tell(_ n: Int) {
            guard !told[n] else { return }
            told[n] = true
            let v = values[n]
            out.append(Finding(kind: .text, rule: v.pieces[0].rule, pieces: v.pieces.map(\.quad), evidence: v.evidence,
                               tolerant: v.pieces.contains { $0.tolerant }, textHeight: v.pieces.map(\.lineHeight).max()))
        }
        for i in read.indices {
            for s in singles where s.line == i {
                if let n = values.firstIndex(where: { v in v.pieces.contains { taken(s, by: $0) } }) { tell(n) }
                else { out.append(Finding(kind: .text, rule: s.rule, quad: s.quad, evidence: s.evidence, tolerant: s.tolerant,
                                           textHeight: s.lineHeight)) }
            }
            for n in values.indices where !told[n] && values[n].pieces.first?.line == i { tell(n) }
        }
        return out
    }

    /// One recognized line: where it is in working pixels, its characters, and what matched in them.
    private struct ReadLine {
        let quad: [CGPoint]
        let box: CGRect
        /// The line as the rules read it (`TextRuleMatcher.reading(of:)`): NFKC, and without the
        /// space Vision puts into a dotted name before the letter of an address.
        let text: String
        let scalars: [Unicode.Scalar]
        /// Where in the NFKC line each space `text` leaves out stood, as scalar indices.
        let dropped: [Int]
        /// How much of the line's width each character takes: a Latin character is a little over
        /// half of a Chinese one. One for each character of the NFKC line, the spaces left out included.
        let widths: [CGFloat]
        let total: CGFloat
        let matches: [RuleMatch]
        /// Vision's own placing of the line's characters, when its text and the line's read the same.
        let placed: Placement?

        /// Where in the NFKC line the character at `index` of the text stands.
        func original(_ index: Int) -> Int {
            var at = index
            for d in dropped where d <= at { at += 1 }
            return at
        }

        /// How far a mask for `rule` reaches beyond this line's box on each side.
        func padding(for rule: TextRule?) -> (top: CGFloat, bottom: CGFloat, side: CGFloat) {
            Recognizer.textPadding(for: rule, lineHeight: box.height)
        }

        /// The matches, each grown to the whole run of characters it sits in, runs that touch
        /// joined, and a long run of digits that glued two values cut into them.
        var runs: [RuleMatch] { TextRuleMatcher.runs(in: text) }

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
            let (from, to) = (original(start), original(end))
            let e0 = share(from), e1 = share(to)
            let a = quad[0], b = quad[1]
            let ux = b.x - a.x, uy = b.y - a.y
            let squared = ux * ux + uy * uy
            if let placed, squared > 0, let corners = placed.corners(from: from, to: to) {
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
        let (text, dropped) = TextRuleMatcher.reading(of: line.transcript)
        let scalars = Array(text.unicodeScalars)
        let original = Array(line.transcript.precomposedStringWithCompatibilityMapping.unicodeScalars)
        let widths: [CGFloat] = original.map { $0.isASCII ? 0.6 : 1.0 }
        let candidate = line.topCandidates(1).first
        let placed = candidate.flatMap { $0.string.unicodeScalars.count == original.count ? Placement(candidate: $0, size: size) : nil }
        return ReadLine(quad: quad, box: Geometry.bounds(of: quad), text: text, scalars: scalars, dropped: dropped, widths: widths,
                        total: widths.reduce(0, +),
                        matches: TextRuleMatcher.matches(in: text).sorted { $0.start < $1.start },
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
    /// A line that starts with the colon of a label stands in the value column, right of the label;
    /// the rest of its value goes back to the margin the label stands on, where other lines of the
    /// page start too. The rest may be long enough to reach under the value column.
    private static func lineBelow(_ i: Int, in read: [ReadLine]) -> Int? {
        let line = read[i]
        let em = max(line.box.height, 1)
        // The colon of a label, half width or full.
        let inValueColumn = line.scalars.drop(while: { $0.properties.isWhitespace }).first
            .map { $0 == ":" || $0.value == 0xFF1A } ?? false
        var best: (index: Int, gap: CGFloat)?
        for (j, other) in read.enumerated() where j != i {
            guard other.box.minY >= line.box.midY else { continue }
            let gap = other.box.minY - line.box.maxY
            guard gap <= 1.2 * em else { continue }
            let indent = other.box.minX - line.box.minX
            let under = other.box.minX < line.box.maxX && other.box.maxX > line.box.minX
            let margin = WrapGeometry.leftSlack * WrapGeometry.charWidth(of: other.box, characters: other.scalars.count)
            let onTheMargin = read.indices.contains { k in
                k != i && k != j && abs(read[k].box.minX - other.box.minX) <= margin
            }
            if under, indent >= -2.5 * em, indent <= 0.75 * em {
                // The paragraph's own left edge, a little indented or outdented.
            } else if inValueColumn, indent < -2.5 * em, onTheMargin {
                // Back to the margin the label stands on.
            } else {
                continue
            }
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
        // Sixteen digits and two more make eighteen: an ID cut in two, not a card. Seventeen digits
        // and an X make one too.
        guard anchor.rule == .bankCard || anchor.rule == .reference else { return (end, nil) }
        let number = Array((anchor.text + line.text(to: end)).unicodeScalars)
        let digits = number.filter(Self.isDigit).count
        let endsInX = number.last.map { $0.value == 88 || $0.value == 120 } ?? false
        switch (digits, endsInX) {
        case (18, false), (17, true): return (end, .idNumber)
        case (16...19, false): return (end, anchor.rule == .reference ? .bankCard : nil)
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

/// Where a line wrap is, from the boxes of the recognized lines in working pixels and how many
/// characters each carries. Pure, so it can be tried on made-up lines. Relaxed on purpose: a
/// narrow chat bubble breaks lines at spaces, so a wrapped line need not reach the right edge of
/// its column. The next line of the paragraph and the shared left edge are what tell a wrap from
/// a new paragraph, a table row or the next column.
enum WrapGeometry {

    /// How far under the top of a line the top of the next line of the same text may be, in line
    /// heights of the taller of the two: wrapped text has a pitch of about 1.1 to 1.4, and table
    /// rows and paragraphs sit farther apart.
    static let pitch: CGFloat = 1.6
    /// How far the left edges of the two lines may differ, in characters of the upper line: a
    /// box starts at the ink of the first glyph, which varies a little from glyph to glyph.
    static let leftSlack: CGFloat = 1.9
    /// The least share of the narrower line's width by which the two lines must overlap sideways.
    static let overlapShare: CGFloat = 1.0 / 3.0
    /// How far a piece may reach outside a box already on its line, in working pixels, for that
    /// box to count as hiding the piece: a box cut the same characters out of the line a second
    /// time falls a fraction of a pixel apart.
    static let takenSlack: CGFloat = 1

    /// How wide a character of the line is, from its box and what it carries.
    static func charWidth(of box: CGRect, characters: Int) -> CGFloat {
        box.width / CGFloat(max(characters, 1))
    }

    /// Whether line `b` is the line the wrap of line `a` went to.
    static func wraps(from a: CGRect, characters aCount: Int, to b: CGRect) -> Bool {
        let drop = b.minY - a.minY
        guard drop > 0, drop <= pitch * max(a.height, b.height) else { return false }
        guard abs(b.minX - a.minX) <= leftSlack * charWidth(of: a, characters: aCount) else { return false }
        let overlap = min(a.maxX, b.maxX) - max(a.minX, b.minX)
        return overlap >= overlapShare * min(a.width, b.width)
    }
}
