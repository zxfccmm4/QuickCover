import CoreGraphics
import Foundation
import ImageIO
import Testing
import Vision
@testable import QuickCover

/// The second look for faces, on the fake pictures, against the first look alone: what it adds,
/// what it never adds, and what it costs.
@Suite struct FaceSecondPassTests {

    private final class Token {}
    private static let directory: URL = {
        var found: URL?
        let root = Bundle(for: Token.self).bundleURL
        if let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator where url.pathExtension == "json" {
                if (try? JSONDecoder().decode(BaselineFixture.self, from: Data(contentsOf: url))) != nil {
                    found = url.deletingLastPathComponent()
                    break
                }
            }
        }
        return found ?? root
    }()

    private static let facePictures = ["photo_01_friends", "photo_02_couple", "photo_03_crowd", "photo_04_profile",
                                       "photo_05_dinner", "photo_06_backlit", "doc_01_idcard"]

    private static func milliseconds(_ duration: Duration) -> Double {
        let parts = duration.components
        return Double(parts.seconds) * 1000 + Double(parts.attoseconds) / 1e15
    }

    @Test func secondLook() async throws {
        var lines: [String] = []
        var totalOff = 0, totalOn = 0, totalGT = 0, extraOff = 0, extraOn = 0
        var msOff = 0.0, msOn = 0.0
        for id in Self.facePictures {
            let fixture = try JSONDecoder().decode(BaselineFixture.self, from: Data(contentsOf: Self.directory.appending(path: id + ".json")))
            let source = try PictureSource(data: try Data(contentsOf: Self.directory.appending(path: fixture.file)))
            let thumb = try #require(source.thumbnail(maxLongSide: 2048))
            let sx = CGFloat(thumb.width) / CGFloat(fixture.width), sy = CGFloat(thumb.height) / CGFloat(fixture.height)
            let gt = fixture.faces.items.flatMap(\.rects).map {
                CGRect(x: $0.minX * sx, y: $0.minY * sy, width: $0.width * sx, height: $0.height * sy)
            }
            func count(_ result: RecognitionResult) -> (hits: Int, extra: Int, faces: Int) {
                let boxes = result.findings.filter { $0.kind == .face }.map(\.box)
                let hits = gt.filter { BaselineScore.unionCover($0, boxes) >= BaselineScore.coveredShare }.count
                let extra = boxes.filter { box in
                    !gt.contains { BaselineScore.area(box.intersection($0)) >= 0.3 * max(BaselineScore.area($0), 1) }
                }.count
                return (hits, extra, boxes.count)
            }
            var start = ContinuousClock.now
            let off = count(try await Recognizer(options: .init(mergeGapEm: 0, smallFacePass: nil)).recognize(thumb))
            let offMs = Self.milliseconds(start.duration(to: .now))
            start = .now
            let on = count(try await Recognizer(options: .init(mergeGapEm: 0)).recognize(thumb))
            let onMs = Self.milliseconds(start.duration(to: .now))
            totalOff += off.hits; totalOn += on.hits; totalGT += gt.count; extraOff += off.extra; extraOn += on.extra
            msOff += offMs; msOn += onMs
            lines.append("\(id): faces \(off.hits) → \(on.hits) of \(gt.count), extra \(off.extra) → \(on.extra), \(Int(offMs)) → \(Int(onMs)) ms")
            // Never fewer faces than the first look alone found, and never a face outside the truth.
            #expect(on.hits >= off.hits, "\(id): the second look lost a face")
            #expect(on.faces >= off.faces, "\(id): the second look dropped a face the first look found")
            #expect(on.extra <= off.extra, "\(id): the second look found a face that is not one")
        }
        lines.append("total: faces \(totalOff)/\(totalGT) → \(totalOn)/\(totalGT), extra \(extraOff) → \(extraOn), time \(Int(msOff)) → \(Int(msOn)) ms on 7 pictures")
        print("===FACE-SECOND-LOOK===\n" + lines.joined(separator: "\n") + "\n===FACE-SECOND-LOOK-END===")
    }

    /// Which look sees each truth face: the first, the second before faces are dropped as already
    /// seen, and the result. A face the second look saw and then dropped as "the same" as a
    /// neighbour is a face that only its neighbour's mask covers.
    @Test func whoSeesThem() async throws {
        var lines: [String] = []
        for id in ["photo_03_crowd"] {
            let fixture = try JSONDecoder().decode(BaselineFixture.self, from: Data(contentsOf: Self.directory.appending(path: id + ".json")))
            let source = try PictureSource(data: try Data(contentsOf: Self.directory.appending(path: fixture.file)))
            let thumb = try #require(source.thumbnail(maxLongSide: 2048))
            let size = CGSize(width: thumb.width, height: thumb.height)
            let sx = size.width / CGFloat(fixture.width), sy = size.height / CGFloat(fixture.height)
            let gt = fixture.faces.items.flatMap(\.rects).map {
                CGRect(x: $0.minX * sx, y: $0.minY * sy, width: $0.width * sx, height: $0.height * sy)
            }
            func pixel(_ r: NormalizedRect) -> CGRect { r.toImageCoordinates(size, origin: .upperLeft) }
            func inside(_ box: CGRect, _ face: CGRect) -> Bool { face.contains(CGPoint(x: box.midX, y: box.midY)) }
            let first = try await DetectFaceRectanglesRequest().perform(on: thumb, orientation: .up).map { pixel($0.boundingBox) }
            let pass = Recognizer.SmallFacePass()
            let second = try await Recognizer.smallFaces(in: thumb, pass: pass, known: []).map { pixel($0.boundingBox) }
            let result = try await Recognizer(options: .init(mergeGapEm: 0)).recognize(thumb)
            // A mask, back to the box Vision gave it.
            let final = result.findings.filter { $0.kind == .face }.map { finding -> CGRect in
                let m = finding.box
                let w = m.width / (1 + 2 * Recognizer.facePadX), h = m.height / (1 + Recognizer.facePadTop + Recognizer.facePadBottom)
                return CGRect(x: m.minX + w * Recognizer.facePadX, y: m.minY + h * Recognizer.facePadTop, width: w, height: h)
            }
            let masks = result.findings.filter { $0.kind == .face }.map(\.box)
            lines.append("\(id): first look \(first.count) boxes, second look before dropping \(second.count), result \(final.count)")
            for (i, face) in gt.enumerated() {
                func own(_ boxes: [CGRect]) -> String {
                    let mine = boxes.filter { inside($0, face) }
                    return mine.isEmpty ? "-" : mine.map { String(format: "%.0fx%.0f", $0.width, $0.height) }.joined(separator: "+")
                }
                lines.append(String(format: "  face %ld truth %.0fx%.0f at %.0f,%.0f: first %@ | second %@ | result %@ | cover %.2f",
                                     i + 1, face.width, face.height, face.minX, face.minY, own(first), own(second), own(final),
                                     BaselineScore.unionCover(face, masks)))
            }
            let strays = second.filter { s in !gt.contains { inside(s, $0) } }
            lines.append("  second-look boxes on no truth face: \(strays.count) " + strays.map { String(format: "%.0fx%.0f@%.0f,%.0f", $0.width, $0.height, $0.minX, $0.minY) }.joined(separator: " "))
        }
        print("===WHO-SEES-THEM===\n" + lines.joined(separator: "\n") + "\n===WHO-SEES-THEM-END===")
    }

    /// How pictures of common sizes are cut up: a forwarded photo is enlarged 2 times, and a
    /// 12-megapixel photo (2560 pixels as the recognizer works on it) or a tall screenshot only
    /// as much as 24 crops allow, never to less than their own pixels.
    @Test func cropPlan() {
        let pass = Recognizer.SmallFacePass()
        let forwarded = Recognizer.cropPlan(for: CGSize(width: 1536, height: 1024), pass: pass)
        #expect(forwarded.columns == 5 && forwarded.rows == 3)
        #expect(forwarded.crop == CGSize(width: 512, height: 512) && forwarded.zoom == 2)
        let photo = Recognizer.cropPlan(for: CGSize(width: 2560, height: 1920), pass: pass)
        #expect(photo.columns * photo.rows <= pass.maxCrops && photo.zoom > 1.2 && photo.zoom < 1.3)
        let small = Recognizer.cropPlan(for: CGSize(width: 400, height: 300), pass: pass)
        #expect(small.columns == 1 && small.rows == 1 && small.zoom == 1024.0 / 400)
        let screenshot = Recognizer.cropPlan(for: CGSize(width: 1170, height: 3948), pass: pass)
        #expect(screenshot.columns * screenshot.rows <= pass.maxCrops && screenshot.zoom >= 1 && screenshot.zoom < 1.5)
        var fewer = pass
        fewer.maxCrops = 6
        let coarse = Recognizer.cropPlan(for: CGSize(width: 1536, height: 1024), pass: fewer)
        #expect(coarse.columns * coarse.rows <= 6 && coarse.zoom < forwarded.zoom && coarse.zoom >= 1)
    }

    /// The crowd picture as a 12-megapixel photo is seen: enlarged to the 2560 pixels the
    /// recognizer works on, where the first look is Vision looking at 1024. What the second look
    /// adds there, and what it costs.
    @Test func bigPicture() async throws {
        let dir = Self.directory
        let fixture = try JSONDecoder().decode(BaselineFixture.self, from: Data(contentsOf: dir.appending(path: "photo_03_crowd.json")))
        let source = try PictureSource(data: try Data(contentsOf: dir.appending(path: fixture.file)))
        let thumb = try #require(source.thumbnail(maxLongSide: 2048))
        var lines: [String] = []
        for factor in [1, 1.667] as [CGFloat] {
            let size = CGSize(width: CGFloat(thumb.width) * factor, height: CGFloat(thumb.height) * factor)
            let picture = try #require(thumb.resized(to: size))
            let gt = fixture.faces.items.flatMap(\.rects).map {
                CGRect(x: $0.minX * factor, y: $0.minY * factor, width: $0.width * factor, height: $0.height * factor)
            }
            func count(_ result: RecognitionResult) -> Int {
                let boxes = result.findings.filter { $0.kind == .face }.map(\.box)
                return gt.filter { BaselineScore.unionCover($0, boxes) >= BaselineScore.coveredShare }.count
            }
            var start = ContinuousClock.now
            let off = count(try await Recognizer(options: .init(mergeGapEm: 0, smallFacePass: nil)).recognize(picture))
            let offMs = Self.milliseconds(start.duration(to: .now))
            start = .now
            let on = count(try await Recognizer(options: .init(mergeGapEm: 0)).recognize(picture))
            let onMs = Self.milliseconds(start.duration(to: .now))
            let plan = Recognizer.cropPlan(for: size, pass: .init())
            lines.append(String(format: "%.0f px wide: first look %ld of %ld in %.0f ms; second look %ldx%ld crops enlarged %.2f times: %ld, in %.0f ms",
                                 size.width, off, gt.count, offMs, plan.columns, plan.rows, plan.zoom, on, onMs))
        }
        print("===BIG-PICTURE===\n" + lines.joined(separator: "\n") + "\n===BIG-PICTURE-END===")
    }
}

/// Every truth face beside the box Vision gives for it: how far the truth reaches beyond that box
/// on each side, so the padding of a face mask is set from what the pictures need, not a guess.
@Suite struct FaceMarginTests {

    private final class Token {}
    private static let directory: URL = {
        var found: URL?
        let root = Bundle(for: Token.self).bundleURL
        if let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator where url.pathExtension == "json" {
                if (try? JSONDecoder().decode(BaselineFixture.self, from: Data(contentsOf: url))) != nil {
                    found = url.deletingLastPathComponent()
                    break
                }
            }
        }
        return found ?? root
    }()

    @Test func margins() async throws {
        let dir = Self.directory
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }
        var lines: [String] = []
        var beyond: [[CGFloat]] = []
        for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let fixture = try JSONDecoder().decode(BaselineFixture.self, from: Data(contentsOf: file))
            guard !fixture.faces.items.isEmpty else { continue }
            let source = try PictureSource(data: try Data(contentsOf: dir.appending(path: fixture.file)))
            let thumb = try #require(source.thumbnail(maxLongSide: 2048))
            let size = CGSize(width: thumb.width, height: thumb.height)
            let sx = size.width / CGFloat(fixture.width), sy = size.height / CGFloat(fixture.height)
            let seen = try await DetectFaceRectanglesRequest().perform(on: thumb, orientation: .up)
            let boxes = seen.map { $0.boundingBox.toImageCoordinates(size, origin: .upperLeft) }
            for item in fixture.faces.items {
                for r in item.rects {
                    let gt = CGRect(x: r.minX * sx, y: r.minY * sy, width: r.width * sx, height: r.height * sy)
                    // The box Vision gives with the largest overlap on the truth; none if it barely touches.
                    let v = boxes.max { BaselineScore.area($0.intersection(gt)) < BaselineScore.area($1.intersection(gt)) }
                        .flatMap { BaselineScore.area($0.intersection(gt)) >= 0.3 * BaselineScore.area($0) ? $0 : nil }
                    guard let v else {
                        lines.append(String(format: "%@ gt %.0fx%.0f at %.0f,%.0f: not seen", fixture.id, gt.width, gt.height, gt.minX, gt.minY))
                        continue
                    }
                    // Positive: the truth reaches beyond Vision's box by that share of its side.
                    let m: [CGFloat] = [(v.minX - gt.minX) / v.width, (gt.maxX - v.maxX) / v.width,
                                       (v.minY - gt.minY) / v.height, (gt.maxY - v.maxY) / v.height]
                    beyond.append(m)
                    lines.append(String(format: "%@ gt %.0fx%.0f vision %.0fx%.0f truth beyond: left %.2f right %.2f top %.2f bottom %.2f",
                                        fixture.id, gt.width, gt.height, v.width, v.height, m[0], m[1], m[2], m[3]))
                }
            }
        }
        func pct(_ i: Int) -> CGFloat { beyond.map { $0[i] }.sorted()[max(0, (beyond.count * 9) / 10 - 1)] }
        func mx(_ i: Int) -> CGFloat { beyond.map { $0[i] }.max() ?? 0 }
        print("===FACE-MARGIN===\n" + lines.joined(separator: "\n"))
        print(String(format: "===FACE-MARGIN=== %ld faces: truth beyond Vision's box, share of its side (90th pct / max): left %.2f/%.2f right %.2f/%.2f top %.2f/%.2f bottom %.2f/%.2f",
                     beyond.count, pct(0), mx(0), pct(1), mx(1), pct(2), mx(2), pct(3), mx(3)) + "\n===FACE-MARGIN-END===")
    }

    /// The same small face, in crops of growing width each made larger, so the face is about the
    /// same size in pixels in every input and only the input's size differs: from what input
    /// width on Vision stops seeing it, which is the size the second look's crops must not
    /// exceed. Each detection is timed.
    @Test func inputCap() async throws {
        let dir = Self.directory
        let fixture = try JSONDecoder().decode(BaselineFixture.self, from: Data(contentsOf: dir.appending(path: "photo_03_crowd.json")))
        let source = try PictureSource(data: try Data(contentsOf: dir.appending(path: fixture.file)))
        let thumb = try #require(source.thumbnail(maxLongSide: 2048))
        let size = CGSize(width: thumb.width, height: thumb.height)
        let whole = CGRect(origin: .zero, size: size)
        var lines: [String] = []
        let smallest = fixture.faces.items.flatMap(\.rects).sorted { $0.width < $1.width }.prefix(3)
        for r in smallest {
            var row = String(format: "face %.0fx%.0f at %.0f,%.0f:", r.width, r.height, r.minX, r.minY)
            for width in [341, 512, 768, 1024, 1536] {
                for zoom in [2, 3, 4] {
                    let crop = CGRect(x: r.midX - CGFloat(width) / 2, y: r.midY - CGFloat(width) / 2,
                                      width: CGFloat(width), height: CGFloat(width)).intersection(whole)
                    guard let cropped = thumb.cropping(to: crop),
                          let piece = cropped.resized(to: CGSize(width: crop.width * CGFloat(zoom), height: crop.height * CGFloat(zoom)))
                    else { continue }
                    let pieceSize = CGSize(width: piece.width, height: piece.height)
                    let started = ContinuousClock.now
                    let found = try await DetectFaceRectanglesRequest().perform(on: piece, orientation: .up)
                    let parts = started.duration(to: .now).components
                    let ms = Double(parts.seconds) * 1000 + Double(parts.attoseconds) / 1e15
                    let zoomed = CGFloat(zoom)
                    var hit = false
                    var side: CGFloat = 0
                    for face in found {
                        let local = face.boundingBox.toImageCoordinates(pieceSize, origin: .upperLeft)
                        let box = CGRect(x: local.minX / zoomed + crop.minX, y: local.minY / zoomed + crop.minY,
                                         width: local.width / zoomed, height: local.height / zoomed)
                        if box.contains(CGPoint(x: r.midX, y: r.midY)) {
                            hit = true
                            side = max(side, local.width)
                        }
                    }
                    row += String(format: " [in %.0f, face %.0f: %@ %.0fms]", pieceSize.width, r.width * zoomed,
                                  hit ? String(format: "box %.0f", side) : "-", ms)
                }
            }
            lines.append(row)
        }
        print("===INPUT-CAP===\n" + lines.joined(separator: "\n") + "\n===INPUT-CAP-END===")
    }
}
