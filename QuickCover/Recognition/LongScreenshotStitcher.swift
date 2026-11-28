import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Pure on-device long-screenshot engine supporting:
/// 1. Vertical multi-screenshot smart overlap detection & seamless stitching:
///    - Automatically handles reverse-ordered selections (common when tapping newest-first thumbnails)
///    - Skips near-duplicate frames with zero scroll displacement
///    - Tolerates live status-bar clocks, translucent top/bottom Liquid Glass bars, corner floating
///      action buttons, right-edge scrollbars, sparse solid bars, and white/dark text layouts via a
///      3-stage coarse-to-fine ZNCC + active-pixel matcher with 1-pixel full-res seam refinement
/// 2. Horizontal side-by-side multi-screenshot stitching with configurable divider spacing.
/// 3. Screen recording video (`AVAsset`) keyframe extraction with Standard / High precision sampling.
enum LongScreenshotStitcher {

    enum Failure: LocalizedError, Sendable {
        case notEnoughImages
        case invalidImage
        case videoHasNoFrames
        case stitchFailed

        var errorDescription: String? {
            switch self {
            case .notEnoughImages: L10n.text("longshot.err.needTwo")
            case .invalidImage: L10n.text("3.1.7")
            case .videoHasNoFrames: L10n.text("longshot.err.noVideoFrames")
            case .stitchFailed: L10n.text("longshot.err.stitchFailed")
            }
        }
    }

    enum Direction: String, CaseIterable, Identifiable, Sendable {
        case vertical
        case horizontal

        var id: String { rawValue }
        var titleKey: String { "longshot.dir.\(rawValue)" }
    }

    enum Spacing: Int, CaseIterable, Identifiable, Sendable {
        case none = 0
        case narrow = 16
        case wide = 36

        var id: Int { rawValue }
        var titleKey: String {
            switch self {
            case .none: "longshot.space.none"
            case .narrow: "longshot.space.narrow"
            case .wide: "longshot.space.wide"
            }
        }
    }

    enum VideoPrecision: String, CaseIterable, Identifiable, Sendable {
        case standard
        case high

        var id: String { rawValue }
        var titleKey: String { "longshot.videoPrec.\(rawValue)" }

        var framesPerSecond: Double {
            switch self {
            case .standard: 4.5
            case .high: 7.5
            }
        }

        var maxSamples: Int {
            switch self {
            case .standard: 90
            case .high: 150
            }
        }
    }

    struct Options: Equatable, Sendable {
        /// Stitch orientation: continuous vertical scroll or side-by-side horizontal strip.
        var direction: Direction = .vertical
        /// Automatically detect overlapping scroll content and strip fixed headers/footers (vertical).
        var smartOverlap: Bool = true
        /// Allow auto-reversing when thumbnails are selected newest-first in the gallery.
        var allowReverseOrder: Bool = true
        /// Optional separator gap between frames (used in horizontal mode or direct vertical append).
        var spacing: Spacing = .none
        /// Keyframe sampling density for screen recordings.
        var videoPrecision: VideoPrecision = .standard
        /// Uses lossy H.264/HEVC overlap tolerances when restitching frames extracted from video.
        var preferVideoTolerances: Bool = false
        /// Maximum width per frame in vertical mode (or height in horizontal mode).
        var maxWidth: Int = 1320
        /// Maximum output length along the stitch axis.
        var maxHeight: Int = 24_000
    }

    struct Result: Sendable {
        let image: CGImage
        let frameCount: Int
        let stitchedOverlapCount: Int
    }

    struct SeamAdjustment: Equatable, Sendable {
        /// Pixel Y coordinate (top-left origin) where frame `i` ends (`1...prevHeight`).
        var prevCutY: Int
        /// Pixel Y coordinate (top-left origin) where frame `i + 1` begins (`0...(currHeight - 1)`).
        var currStartY: Int
        /// Divider gap in pixels inserted between frame `i` and frame `i + 1` (`0...160`).
        var gap: Int = 0
        /// Whether this seam was initially matched by smart overlap detection.
        var isAutoMatched: Bool = false
    }

    struct CropInsets: Equatable, Sendable {
        var left: Double = 0
        var right: Double = 0
        var top: Double = 0
        var bottom: Double = 0

        static let zero = CropInsets()

        var isZero: Bool {
            left <= 0.0001 && right <= 0.0001 && top <= 0.0001 && bottom <= 0.0001
        }
    }

    struct VerticalLayout: Sendable {
        let orderedImages: [CGImage]
        let seams: [SeamAdjustment]
        let duplicateSkips: Int
        let originalFrameCount: Int
        let targetWidth: Int

        var autoOverlapCount: Int {
            duplicateSkips + seams.filter(\.isAutoMatched).count
        }
    }

    static let defaultDividerColor = CustomColorRGB(red: 0.96, green: 0.96, blue: 0.97)

    // MARK: - Multi-Screenshot Stitching

    /// Stitches ordered screenshots vertically (with optional smart overlap) or horizontally side-by-side.
    static func stitch(
        images rawImages: [CGImage],
        options: Options = Options(),
        crop: CropInsets = .zero,
        dividerColor: CustomColorRGB = defaultDividerColor
    ) throws -> Result {
        guard !rawImages.isEmpty else { throw Failure.notEnoughImages }
        if rawImages.count == 1 {
            let cropped = applyCrop(rawImages[0], crop: crop)
            return Result(image: cropped, frameCount: 1, stitchedOverlapCount: 0)
        }
        switch options.direction {
        case .vertical:
            let layout = try computeVerticalLayout(images: rawImages, options: options)
            return try renderVertical(
                layout: layout,
                seams: layout.seams,
                crop: crop,
                dividerColor: dividerColor,
                maxHeight: options.maxHeight
            )
        case .horizontal:
            return try stitchHorizontal(images: rawImages, options: options, crop: crop, dividerColor: dividerColor)
        }
    }

    /// Computes width-normalized ordering and editable per-seam overlap parameters without finalizing the image.
    static func computeVerticalLayout(images rawImages: [CGImage], options: Options = Options()) throws -> VerticalLayout {
        guard !rawImages.isEmpty else { throw Failure.notEnoughImages }
        let targetWidth = max(64, min(rawImages[0].width, options.maxWidth))
        let normalized: [CGImage] = rawImages.compactMap { normalizeWidth($0, targetWidth: targetWidth) }
        guard normalized.count >= 2 else { throw Failure.invalidImage }

        let defaultGap = options.smartOverlap ? 0 : options.spacing.rawValue
        let resolved: (ordered: [CGImage], seams: [SeamAdjustment], duplicateSkips: Int, totalScore: Double)
        if options.smartOverlap && options.allowReverseOrder && normalized.count >= 2 {
            // Pairwise overlap graph + exact/greedy Hamiltonian path solver automatically recovers the
            // true scroll sequence even when the user picked screenshots in an arbitrary scrambled order.
            resolved = solveOptimalVerticalOrder(
                frames: normalized,
                defaultGap: defaultGap,
                isVideo: options.preferVideoTolerances
            )
        } else {
            resolved = buildVerticalLayout(
                frames: normalized,
                smartOverlap: options.smartOverlap,
                defaultGap: defaultGap,
                isVideo: options.preferVideoTolerances
            )
        }

        return VerticalLayout(
            orderedImages: resolved.ordered,
            seams: resolved.seams,
            duplicateSkips: resolved.duplicateSkips,
            originalFrameCount: normalized.count,
            targetWidth: targetWidth
        )
    }

    /// Renders a vertical long screenshot from a computed layout using user-adjusted seams, gaps, divider color, and overall crop.
    static func renderVertical(
        layout: VerticalLayout,
        seams: [SeamAdjustment],
        crop: CropInsets = .zero,
        dividerColor: CustomColorRGB = defaultDividerColor,
        maxHeight: Int = 24_000
    ) throws -> Result {
        let frames = layout.orderedImages
        guard !frames.isEmpty else { throw Failure.notEnoughImages }
        if frames.count == 1 {
            let finalImg = applyCrop(frames[0], crop: crop)
            return Result(image: finalImg, frameCount: layout.originalFrameCount, stitchedOverlapCount: layout.duplicateSkips)
        }

        let expectedSeams = frames.count - 1
        let activeSeams = seams.count == expectedSeams ? seams : layout.seams
        guard activeSeams.count == expectedSeams else { throw Failure.stitchFailed }

        struct RenderSlice {
            let image: CGImage
            let cropTop: Int
            let cropBottom: Int
            let gapAfter: Int
        }

        var slices: [RenderSlice] = []
        slices.reserveCapacity(frames.count)

        for i in 0..<frames.count {
            let img = frames[i]
            let rawTop = (i == 0) ? 0 : max(0, min(img.height - 1, activeSeams[i - 1].currStartY))
            let rawBottom = (i == frames.count - 1) ? img.height : max(1, min(img.height, activeSeams[i].prevCutY))
            let safeTop = min(rawTop, max(0, rawBottom - 1))
            let safeBottom = max(safeTop + 1, rawBottom)
            let gapAfter = (i < expectedSeams) ? max(0, min(160, activeSeams[i].gap)) : 0
            slices.append(RenderSlice(image: img, cropTop: safeTop, cropBottom: safeBottom, gapAfter: gapAfter))
        }

        let rawTotalHeight = slices.reduce(0) { $0 + ($1.cropBottom - $1.cropTop) + $1.gapAfter }
        guard rawTotalHeight > 0 else { throw Failure.stitchFailed }

        let safeMaxHeight = max(64, maxHeight)
        let scale = rawTotalHeight > safeMaxHeight ? (Double(safeMaxHeight) / Double(rawTotalHeight)) : 1.0
        let outWidth = rawTotalHeight > safeMaxHeight
            ? max(64, Int((Double(layout.targetWidth) * scale).rounded()))
            : layout.targetWidth
        let outHeight = rawTotalHeight > safeMaxHeight ? safeMaxHeight : rawTotalHeight

        guard let context = CGImage.rgbaContext(width: outWidth, height: outHeight) else {
            throw Failure.stitchFailed
        }
        context.interpolationQuality = scale < 1.0 ? .high : .none
        let hasGap = slices.contains { $0.gapAfter > 0 }
        if hasGap {
            let c = dividerColor.rgba
            context.setFillColor(CGColor(red: c.r, green: c.g, blue: c.b, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: outWidth, height: outHeight))
        }

        if scale < 1.0 {
            var cursorTop: Double = 0
            let lastIdx = slices.count - 1
            for (idx, slice) in slices.enumerated() {
                let sliceH = slice.cropBottom - slice.cropTop
                guard sliceH > 0 else { continue }
                let cropRect = CGRect(x: 0, y: slice.cropTop, width: slice.image.width, height: sliceH)
                guard let cropped = slice.image.cropping(to: cropRect) else { continue }

                let rawDrawH = Double(sliceH) * scale
                let destY = idx == lastIdx ? 0.0 : max(0.0, Double(outHeight) - cursorTop - rawDrawH)
                let destH = idx == lastIdx ? max(1.0, Double(outHeight) - cursorTop) : rawDrawH
                let destRect = CGRect(x: 0, y: destY, width: Double(outWidth), height: destH)
                context.draw(cropped, in: destRect)
                cursorTop += rawDrawH
                if slice.gapAfter > 0 && idx < lastIdx {
                    cursorTop += Double(slice.gapAfter) * scale
                }
            }
        } else {
            var cursorTop = 0
            for (idx, slice) in slices.enumerated() {
                let sliceH = slice.cropBottom - slice.cropTop
                guard sliceH > 0, cursorTop < outHeight else { continue }
                let drawH = min(sliceH, outHeight - cursorTop)
                let cropRect = CGRect(x: 0, y: slice.cropTop, width: layout.targetWidth, height: drawH)
                guard let cropped = slice.image.cropping(to: cropRect) else { continue }

                let destRect = CGRect(
                    x: 0,
                    y: outHeight - cursorTop - drawH,
                    width: outWidth,
                    height: drawH
                )
                context.draw(cropped, in: destRect)
                cursorTop += drawH
                if slice.gapAfter > 0 && idx < slices.count - 1 {
                    cursorTop += slice.gapAfter
                }
            }
        }

        guard let output = context.makeImage() else { throw Failure.stitchFailed }
        let finalOutput = applyCrop(output, crop: crop)
        let overlapCount = layout.duplicateSkips + activeSeams.filter(\.isAutoMatched).count
        return Result(image: finalOutput, frameCount: layout.originalFrameCount, stitchedOverlapCount: overlapCount)
    }

    /// Renders a zoomed vertical slice around seam `previous[prevCutY] -> gap -> current[currStartY]` for interactive fine-tuning.
    static func renderSeamPreview(
        previous: CGImage,
        current: CGImage,
        seam: SeamAdjustment,
        bandPixels: Int = 180,
        dividerColor: CustomColorRGB = defaultDividerColor
    ) -> CGImage? {
        let width = min(previous.width, current.width)
        guard width > 0 else { return nil }
        let safeCutY = max(1, min(previous.height, seam.prevCutY))
        let topStart = max(0, safeCutY - max(24, bandPixels))
        let topH = max(1, safeCutY - topStart)

        let safeCurrStart = max(0, min(current.height - 1, seam.currStartY))
        let botEnd = min(current.height, safeCurrStart + max(24, bandPixels))
        let botH = max(1, botEnd - safeCurrStart)

        let gap = max(0, min(160, seam.gap))
        let totalH = topH + gap + botH
        guard let ctx = CGImage.rgbaContext(width: width, height: totalH) else { return nil }

        if gap > 0 {
            let c = dividerColor.rgba
            ctx.setFillColor(CGColor(red: c.r, green: c.g, blue: c.b, alpha: 1))
            ctx.fill(CGRect(x: 0, y: botH, width: width, height: gap))
        }

        if let topCrop = previous.cropping(to: CGRect(x: 0, y: topStart, width: width, height: topH)) {
            ctx.draw(topCrop, in: CGRect(x: 0, y: botH + gap, width: width, height: topH))
        }
        if let botCrop = current.cropping(to: CGRect(x: 0, y: safeCurrStart, width: width, height: botH)) {
            ctx.draw(botCrop, in: CGRect(x: 0, y: 0, width: width, height: botH))
        }
        return ctx.makeImage()
    }

    /// Crops fractional insets `[0...0.35]` horizontal / `[0...0.25]` vertical from a stitched screenshot.
    static func applyCrop(_ image: CGImage, crop: CropInsets) -> CGImage {
        guard !crop.isZero else { return image }
        let l = max(0, min(0.35, crop.left))
        let r = max(0, min(0.35, crop.right))
        let t = max(0, min(0.25, crop.top))
        let b = max(0, min(0.25, crop.bottom))

        let x0 = min(image.width - 16, max(0, Int((Double(image.width) * l).rounded())))
        let x1 = max(x0 + 16, min(image.width, Int((Double(image.width) * (1.0 - r)).rounded())))
        let y0 = min(image.height - 16, max(0, Int((Double(image.height) * t).rounded())))
        let y1 = max(y0 + 16, min(image.height, Int((Double(image.height) * (1.0 - b)).rounded())))
        let rect = CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
        return image.cropping(to: rect) ?? image
    }

    /// Suggests sensible top/bottom chrome trim cutoffs when two consecutive frames have no shared scroll overlap.
    static func suggestedChromeTrim(previous: CGImage, current: CGImage) -> (prevCutY: Int, currStartY: Int) {
        let aspectA = Double(previous.height) / Double(max(previous.width, 1))
        let aspectB = Double(current.height) / Double(max(current.width, 1))
        let isPortraitPhone = aspectA >= 1.55 || aspectB >= 1.55
        let trimPrevRatio = isPortraitPhone ? 0.895 : 0.94
        let trimCurrRatio = isPortraitPhone ? 0.06 : 0.05
        let prevCutY = max(16, min(previous.height, Int((Double(previous.height) * trimPrevRatio).rounded())))
        let currStartY = max(0, min(current.height - 16, Int((Double(current.height) * trimCurrRatio).rounded())))
        return (prevCutY, currStartY)
    }

    private static func buildVerticalLayout(
        frames: [CGImage],
        smartOverlap: Bool,
        defaultGap: Int,
        isVideo: Bool = false
    ) -> (ordered: [CGImage], seams: [SeamAdjustment], duplicateSkips: Int, totalScore: Double) {
        var ordered: [CGImage] = [frames[0]]
        var seams: [SeamAdjustment] = []
        var prev = frames[0]
        var currMinTop = 0
        var duplicateSkips = 0
        var totalScore = 0.0

        for idx in 1..<frames.count {
            let curr = frames[idx]
            if smartOverlap {
                if isNearDuplicateScreen(prev, curr, tolerance: isVideo ? 5.5 : 3.0) {
                    duplicateSkips += 1
                    totalScore += 50.0
                    continue
                }
                if let match = findVerticalOverlap(previous: prev, current: curr, isVideo: isVideo) {
                    let prevCutY = max(currMinTop + 1, min(prev.height, match.prevCutY))
                    let currStartY = max(0, min(curr.height - 1, match.currStartY))
                    seams.append(SeamAdjustment(
                        prevCutY: prevCutY,
                        currStartY: currStartY,
                        gap: 0,
                        isAutoMatched: true
                    ))
                    ordered.append(curr)
                    currMinTop = currStartY
                    prev = curr
                    totalScore += match.confidence
                    continue
                }
            }
            seams.append(SeamAdjustment(
                prevCutY: prev.height,
                currStartY: 0,
                gap: defaultGap,
                isAutoMatched: false
            ))
            ordered.append(curr)
            currMinTop = 0
            prev = curr
        }

        return (ordered, seams, duplicateSkips, totalScore)
    }

    /// Reconstructs the true scroll sequence from arbitrarily ordered screenshots using a directed
    /// pairwise overlap graph + Bitmask DP Hamiltonian path solver (`n <= 12`) or greedy chain merge (`n > 12`).
    private static func solveOptimalVerticalOrder(
        frames: [CGImage],
        defaultGap: Int,
        isVideo: Bool
    ) -> (ordered: [CGImage], seams: [SeamAdjustment], duplicateSkips: Int, totalScore: Double) {
        var uniqueFrames: [CGImage] = []
        uniqueFrames.reserveCapacity(frames.count)
        var duplicateSkips = 0
        let dupTol = isVideo ? 5.5 : 3.0

        for candidate in frames {
            if uniqueFrames.contains(where: { isNearDuplicateScreen($0, candidate, tolerance: dupTol) }) {
                duplicateSkips += 1
            } else {
                uniqueFrames.append(candidate)
            }
        }

        let n = uniqueFrames.count
        guard n >= 2 else {
            return (uniqueFrames, [], duplicateSkips, Double(duplicateSkips) * 50.0)
        }

        var matchGrid = Array(repeating: [OverlapMatch?](repeating: nil, count: n), count: n)
        for i in 0..<n {
            for j in 0..<n where i != j {
                matchGrid[i][j] = findVerticalOverlap(previous: uniqueFrames[i], current: uniqueFrames[j], isVideo: isVideo)
            }
        }

        // Anti-symmetry pruning: if both (i -> j) and (j -> i) claim an overlap, keep only the clearly
        // stronger direction (breaking close ties <= 10% in favor of original selection order i < j).
        for i in 0..<n {
            for j in (i + 1)..<n {
                if let mIJ = matchGrid[i][j], let mJI = matchGrid[j][i] {
                    if mJI.confidence > mIJ.confidence * 1.10 {
                        matchGrid[i][j] = nil
                    } else {
                        matchGrid[j][i] = nil
                    }
                }
            }
        }

        let order: [Int]
        if n <= 12 {
            let stateCount = 1 << n
            struct DPState {
                var valid: Bool = false
                var matched: Int = 0
                var score: Double = 0
                var breaks: Int = 0
                var prev: Int = -1
            }

            func isBetter(_ a: DPState, than b: DPState) -> Bool {
                if !b.valid { return true }
                if a.matched != b.matched { return a.matched > b.matched }
                if abs(a.score - b.score) > 1e-6 { return a.score > b.score }
                return a.breaks < b.breaks
            }

            var dp = Array(repeating: [DPState](repeating: DPState(), count: n), count: stateCount)
            for i in 0..<n {
                dp[1 << i][i] = DPState(valid: true, matched: 0, score: 0, breaks: i > 0 ? 0 : 0, prev: -1)
            }

            for mask in 1..<stateCount {
                for last in 0..<n {
                    let cur = dp[mask][last]
                    guard cur.valid else { continue }
                    for next in 0..<n {
                        guard (mask & (1 << next)) == 0 else { continue }
                        let nextMask = mask | (1 << next)
                        let cand: DPState
                        if let m = matchGrid[last][next] {
                            cand = DPState(
                                valid: true,
                                matched: cur.matched + 1,
                                score: cur.score + m.confidence,
                                breaks: cur.breaks,
                                prev: last
                            )
                        } else {
                            cand = DPState(
                                valid: true,
                                matched: cur.matched,
                                score: cur.score,
                                breaks: cur.breaks + (next < last ? 1 : 0),
                                prev: last
                            )
                        }
                        if isBetter(cand, than: dp[nextMask][next]) {
                            dp[nextMask][next] = cand
                        }
                    }
                }
            }

            let fullMask = stateCount - 1
            var bestEnd = 0
            for i in 1..<n {
                if dp[fullMask][i].valid && isBetter(dp[fullMask][i], than: dp[fullMask][bestEnd]) {
                    bestEnd = i
                }
            }

            var reversedPath: [Int] = []
            reversedPath.reserveCapacity(n)
            var curMask = fullMask
            var curNode = bestEnd
            while curNode >= 0 {
                reversedPath.append(curNode)
                let p = dp[curMask][curNode].prev
                curMask &= ~(1 << curNode)
                curNode = p
            }
            order = reversedPath.reversed()
        } else {
            // Greedy non-cyclic chain construction for > 12 frames.
            struct Edge {
                let u: Int
                let v: Int
                let score: Double
            }
            var edges: [Edge] = []
            for i in 0..<n {
                for j in 0..<n where i != j {
                    if let m = matchGrid[i][j] {
                        edges.append(Edge(u: i, v: j, score: m.confidence))
                    }
                }
            }
            edges.sort { $0.score > $1.score }

            var nextNode = [Int](repeating: -1, count: n)
            var prevNode = [Int](repeating: -1, count: n)
            var uf = Array(0..<n)
            func findRoot(_ x: Int) -> Int {
                var r = x
                while uf[r] != r { r = uf[r] }
                return r
            }
            for e in edges where nextNode[e.u] == -1 && prevNode[e.v] == -1 {
                let ru = findRoot(e.u), rv = findRoot(e.v)
                guard ru != rv else { continue }
                nextNode[e.u] = e.v
                prevNode[e.v] = e.u
                uf[rv] = ru
            }
            var constructed: [Int] = []
            constructed.reserveCapacity(n)
            for head in 0..<n where prevNode[head] == -1 {
                var cur = head
                while cur != -1 {
                    constructed.append(cur)
                    cur = nextNode[cur]
                }
            }
            order = constructed
        }

        // Assemble final seams along the solved node sequence.
        var ordered: [CGImage] = [uniqueFrames[order[0]]]
        var seams: [SeamAdjustment] = []
        var currMinTop = 0
        var totalScore = Double(duplicateSkips) * 50.0

        for idx in 0..<(order.count - 1) {
            let u = order[idx]
            let v = order[idx + 1]
            let prev = uniqueFrames[u]
            let curr = uniqueFrames[v]
            if let match = matchGrid[u][v] {
                var prevCutY = match.prevCutY
                var currStartY = match.currStartY
                let minCutY = idx == 0 ? 16 : (currMinTop + 16)
                if prevCutY < minCutY {
                    let shift = minCutY - prevCutY
                    if currStartY + shift < curr.height - 16 {
                        prevCutY += shift
                        currStartY += shift
                    } else {
                        prevCutY = max(currMinTop + 1, min(prev.height, match.prevCutY))
                        currStartY = max(0, min(curr.height - 1, match.currStartY))
                    }
                }
                seams.append(SeamAdjustment(
                    prevCutY: prevCutY,
                    currStartY: currStartY,
                    gap: 0,
                    isAutoMatched: true
                ))
                ordered.append(curr)
                currMinTop = currStartY
                totalScore += match.confidence
            } else {
                seams.append(SeamAdjustment(
                    prevCutY: prev.height,
                    currStartY: 0,
                    gap: defaultGap,
                    isAutoMatched: false
                ))
                ordered.append(curr)
                currMinTop = 0
            }
        }

        return (ordered, seams, duplicateSkips, totalScore)
    }

    private static func stitchHorizontal(
        images rawImages: [CGImage],
        options: Options,
        crop: CropInsets = .zero,
        dividerColor: CustomColorRGB = defaultDividerColor
    ) throws -> Result {
        let targetHeight = max(64, min(rawImages[0].height, max(options.maxWidth, 1600)))
        let normalized: [CGImage] = rawImages.compactMap { normalizeHeight($0, targetHeight: targetHeight) }
        guard normalized.count >= 2 else { throw Failure.invalidImage }

        let gap = options.spacing.rawValue
        let gapTotal = gap * max(0, normalized.count - 1)
        let totalWidth = min(options.maxHeight, normalized.reduce(0) { $0 + $1.width } + gapTotal)
        guard totalWidth > 0 else { throw Failure.stitchFailed }

        guard let context = CGImage.rgbaContext(width: totalWidth, height: targetHeight) else {
            throw Failure.stitchFailed
        }
        if gap > 0 {
            let c = dividerColor.rgba
            context.setFillColor(CGColor(red: c.r, green: c.g, blue: c.b, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: totalWidth, height: targetHeight))
        }

        var cursorX = 0
        for (idx, frame) in normalized.enumerated() {
            guard cursorX < totalWidth else { break }
            let drawW = min(frame.width, totalWidth - cursorX)
            let source: CGImage = if drawW < frame.width,
                                     let cropped = frame.cropping(to: CGRect(x: 0, y: 0, width: drawW, height: targetHeight)) {
                cropped
            } else {
                frame
            }
            context.draw(source, in: CGRect(x: cursorX, y: 0, width: drawW, height: targetHeight))
            cursorX += drawW
            if gap > 0 && idx < normalized.count - 1 {
                cursorX += gap
            }
        }

        guard let output = context.makeImage() else { throw Failure.stitchFailed }
        let finalOutput = applyCrop(output, crop: crop)
        return Result(image: finalOutput, frameCount: normalized.count, stitchedOverlapCount: 0)
    }

    // MARK: - Screen Recording Video -> Long Screenshot

    /// Extracts ordered scroll keyframes from a screen recording URL.
    static func extractVideoKeyframes(
        at url: URL,
        options: Options = Options(),
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> [CGImage] {
        let layout = try await stitchVideoLayout(asset: AVURLAsset(url: url), options: options, onProgress: onProgress)
        return layout.orderedImages
    }

    /// Computes an editable `VerticalLayout` from any `AVAsset` (`AVURLAsset` or trimmed `AVComposition`),
    /// discarding stationary pauses, rubber-band bounce-backs, and overlay bookends (e.g. Control Center).
    static func stitchVideoLayout(
        asset: AVAsset,
        options: Options = Options(),
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> VerticalLayout {
        let samples = try await decodeVideoSamples(asset: asset, options: options) { decodeProgress in
            onProgress?(decodeProgress * 0.45)
        }
        onProgress?(0.48)

        let targetWidth = max(64, min(samples[0].width, options.maxWidth))
        let normalized = samples.compactMap { normalizeWidth($0, targetWidth: targetWidth) }
        guard !normalized.isEmpty else { throw Failure.videoHasNoFrames }

        let selected = selectBestVideoScrollChain(samples: normalized) { chainProgress in
            onProgress?(0.48 + chainProgress * 0.47)
        }

        onProgress?(0.98)
        return VerticalLayout(
            orderedImages: selected.ordered,
            seams: selected.seams,
            duplicateSkips: max(0, samples.count - selected.ordered.count),
            originalFrameCount: samples.count,
            targetWidth: targetWidth
        )
    }

    static func stitchVideo(
        at url: URL,
        options: Options = Options(),
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> Result {
        let layout = try await stitchVideoLayout(asset: AVURLAsset(url: url), options: options) { p in
            onProgress?(p * 0.90)
        }
        onProgress?(0.92)
        let rendered = try renderVertical(
            layout: layout,
            seams: layout.seams,
            crop: .zero,
            dividerColor: defaultDividerColor,
            maxHeight: options.maxHeight
        )
        onProgress?(1.0)
        return rendered
    }

    private static func decodeVideoSamples(
        asset: AVAsset,
        options: Options,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> [CGImage] {
        let duration = try await asset.load(.duration)
        let seconds = CMTimeGetSeconds(duration)
        guard seconds.isFinite, seconds > 0.12 else { throw Failure.videoHasNoFrames }

        let prec = options.videoPrecision
        let sampleCount = min(prec.maxSamples, max(8, Int((seconds * prec.framesPerSecond).rounded())))
        let span = max(0, seconds - 0.03)
        let step = span / Double(max(sampleCount - 1, 1))
        let times: [CMTime] = (0..<sampleCount).map { idx in
            let t = min(max(0.015, seconds - 0.015), 0.015 + Double(idx) * step)
            return CMTime(seconds: t, preferredTimescale: 600)
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let tol = prec == .high ? 0.015 : 0.03
        generator.requestedTimeToleranceBefore = CMTime(seconds: tol, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: tol, preferredTimescale: 600)
        generator.maximumSize = CGSize(width: CGFloat(options.maxWidth), height: CGFloat(options.maxWidth) * 3.0)

        var decoded: [CGImage] = []
        decoded.reserveCapacity(times.count)
        var lastSignature: [UInt8]? = nil
        var seenCount = 0

        for await result in generator.images(for: times) {
            try Task.checkCancellation()
            seenCount += 1
            onProgress?(Double(seenCount) / Double(max(times.count, 1)))
            guard case .success(_, let cgImage, _) = result else { continue }
            let sig = frameSignature(cgImage)
            if let prev = lastSignature, meanAbsoluteDiff(prev, sig) < 1.5 {
                continue
            }
            decoded.append(cgImage)
            lastSignature = sig
        }

        if decoded.isEmpty, let firstTime = times.first, let fallback = try? await extractFrame(from: generator, at: firstTime) {
            decoded.append(fallback)
        }
        guard !decoded.isEmpty else { throw Failure.videoHasNoFrames }
        return decoded
    }

    private struct VideoChainCandidate {
        let ordered: [CGImage]
        let seams: [SeamAdjustment]
        let totalScrollPx: Int
    }

    private static func selectBestVideoScrollChain(
        samples: [CGImage],
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) -> VideoChainCandidate {
        guard samples.count >= 2 else {
            return VideoChainCandidate(ordered: samples, seams: [], totalScrollPx: 0)
        }

        var visitedStarts = Set<Int>()
        var nextStartQueue: [Int] = [0]
        var bestChain = VideoChainCandidate(ordered: [samples[0]], seams: [], totalScrollPx: 0)
        let maxChainStarts = min(14, samples.count)
        var chainsExplored = 0

        while !nextStartQueue.isEmpty && chainsExplored < maxChainStarts {
            let startIdx = nextStartQueue.removeFirst()
            guard samples.indices.contains(startIdx), !visitedStarts.contains(startIdx) else { continue }
            visitedStarts.insert(startIdx)
            chainsExplored += 1
            onProgress?(Double(chainsExplored) / Double(maxChainStarts))

            var anchorIdx = startIdx
            var anchor = samples[anchorIdx]
            var ordered: [CGImage] = [anchor]
            var seams: [SeamAdjustment] = []
            var totalScrollPx = 0
            var currMinTop = 0

            var scanIdx = startIdx + 1
            var pendingNext: (index: Int, match: OverlapMatch, stepDy: Int)? = nil
            var missStreak = 0
            var firstMissIdx: Int? = nil

            while scanIdx < samples.count {
                let candidate = samples[scanIdx]
                if isNearDuplicateScreen(anchor, candidate, tolerance: 5.5) || isNearZeroShift(anchor, candidate) {
                    scanIdx += 1
                    continue
                }

                let targetStepPx = max(28, Int((Double(anchor.height) * 0.22).rounded()))
                if let match = findVerticalOverlap(previous: anchor, current: candidate, isVideo: true) {
                    let stepDy = match.prevCutY - match.currStartY
                    let isStrongerReverseBounce = stepDy >= targetStepPx
                        && (findVerticalOverlap(previous: candidate, current: anchor, isVideo: true)?.confidence ?? 0) > match.confidence

                    if !isStrongerReverseBounce {
                        missStreak = 0
                        firstMissIdx = nil

                        if stepDy >= targetStepPx {
                            let minCutY = ordered.count == 1 ? 16 : (currMinTop + 16)
                            var prevCutY = match.prevCutY
                            var currStartY = match.currStartY
                            if prevCutY < minCutY {
                                let shift = minCutY - prevCutY
                                if currStartY + shift < candidate.height - 16 {
                                    prevCutY += shift
                                    currStartY += shift
                                } else {
                                    prevCutY = max(currMinTop + 1, min(anchor.height, match.prevCutY))
                                    currStartY = max(0, min(candidate.height - 1, match.currStartY))
                                }
                            }

                            seams.append(SeamAdjustment(
                                prevCutY: prevCutY,
                                currStartY: currStartY,
                                gap: 0,
                                isAutoMatched: true
                            ))
                            ordered.append(candidate)
                            totalScrollPx += max(1, stepDy)
                            currMinTop = currStartY
                            anchorIdx = scanIdx
                            anchor = candidate
                            pendingNext = nil
                            scanIdx += 1
                            continue
                        } else if stepDy > 0 {
                            if pendingNext == nil || stepDy >= pendingNext!.stepDy {
                                pendingNext = (index: scanIdx, match: match, stepDy: stepDy)
                            }
                            scanIdx += 1
                            continue
                        }
                    }
                }

                // Candidate did not match anchor downward: may be pause noise, rubber-band bounce-up, fast scroll, or Control Center overlay.
                if firstMissIdx == nil {
                    firstMissIdx = scanIdx
                }
                missStreak += 1

                if let pending = pendingNext, missStreak >= 3 {
                    // Commit the last valid overlapping step before scrolling out of range.
                    let candidateNext = samples[pending.index]
                    let minCutY = ordered.count == 1 ? 16 : (currMinTop + 16)
                    var prevCutY = pending.match.prevCutY
                    var currStartY = pending.match.currStartY
                    if prevCutY < minCutY {
                        let shift = minCutY - prevCutY
                        if currStartY + shift < candidateNext.height - 16 {
                            prevCutY += shift
                            currStartY += shift
                        } else {
                            prevCutY = max(currMinTop + 1, min(anchor.height, pending.match.prevCutY))
                            currStartY = max(0, min(candidateNext.height - 1, pending.match.currStartY))
                        }
                    }

                    seams.append(SeamAdjustment(
                        prevCutY: prevCutY,
                        currStartY: currStartY,
                        gap: 0,
                        isAutoMatched: true
                    ))
                    ordered.append(candidateNext)
                    totalScrollPx += max(1, pending.stepDy)
                    currMinTop = currStartY
                    anchorIdx = pending.index
                    anchor = candidateNext
                    pendingNext = nil
                    missStreak = 0
                    firstMissIdx = nil
                    scanIdx = max(scanIdx, anchorIdx + 1)
                    continue
                }

                if missStreak >= 4 {
                    if let missStart = firstMissIdx, !visitedStarts.contains(missStart) {
                        nextStartQueue.append(missStart)
                    }
                    break
                }

                scanIdx += 1
            }

            // Flush any trailing coalesced overlap at end of video.
            if let pending = pendingNext, pending.index > anchorIdx {
                let candidateNext = samples[pending.index]
                let minCutY = ordered.count == 1 ? 16 : (currMinTop + 16)
                var prevCutY = pending.match.prevCutY
                var currStartY = pending.match.currStartY
                if prevCutY < minCutY {
                    let shift = minCutY - prevCutY
                    if currStartY + shift < candidateNext.height - 16 {
                        prevCutY += shift
                        currStartY += shift
                    } else {
                        prevCutY = max(currMinTop + 1, min(anchor.height, pending.match.prevCutY))
                        currStartY = max(0, min(candidateNext.height - 1, pending.match.currStartY))
                    }
                }
                seams.append(SeamAdjustment(
                    prevCutY: prevCutY,
                    currStartY: currStartY,
                    gap: 0,
                    isAutoMatched: true
                ))
                ordered.append(candidateNext)
                totalScrollPx += max(1, pending.stepDy)
            } else if let missStart = firstMissIdx, !visitedStarts.contains(missStart) {
                nextStartQueue.append(missStart)
            }

            if totalScrollPx > bestChain.totalScrollPx || (totalScrollPx == bestChain.totalScrollPx && ordered.count > bestChain.ordered.count) {
                bestChain = VideoChainCandidate(ordered: ordered, seams: seams, totalScrollPx: totalScrollPx)
            }

            // Short-circuit when we already captured almost the entire recording length.
            if bestChain.ordered.count >= 2 && Double(startIdx) / Double(samples.count) < 0.25 && bestChain.totalScrollPx > samples[0].height * 2 && nextStartQueue.isEmpty {
                break
            }
        }

        if bestChain.ordered.count == 1 {
            // If no continuous scroll chain existed, prefer a clean middle non-overlay sample over edge Control Center frames.
            let midSample = samples[samples.count / 2]
            return VideoChainCandidate(ordered: [midSample], seams: [], totalScrollPx: 0)
        }
        return bestChain
    }

    static func makePictureSource(from image: CGImage) throws -> PictureSource {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw Failure.stitchFailed
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw Failure.stitchFailed
        }
        return try PictureSource(data: data as Data)
    }

    // MARK: - 3-Stage Coarse-to-Fine Smart Overlap Detection

    private struct OverlapMatch {
        let prevCutY: Int
        let currStartY: Int
        let confidence: Double
    }

    private struct RGBABuffer {
        let width: Int
        let height: Int
        let stride: Int
        let data: [UInt8]

        init?(image: CGImage, targetWidth: Int? = nil, targetHeight: Int? = nil) {
            let w = targetWidth ?? image.width
            let h = targetHeight ?? image.height
            guard w > 0, h > 0, let ctx = CGImage.rgbaContext(width: w, height: h),
                  let ptr = ctx.data else {
                return nil
            }
            ctx.interpolationQuality = (w == image.width && h == image.height) ? .none : .medium
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            self.width = w
            self.height = h
            self.stride = ctx.bytesPerRow
            self.data = Array(UnsafeBufferPointer(start: ptr.assumingMemoryBound(to: UInt8.self), count: h * ctx.bytesPerRow))
        }
    }

    private static func isNearDuplicateScreen(_ a: CGImage, _ b: CGImage, tolerance: Double = 3.0) -> Bool {
        let w = 64
        let hA = max(32, min(140, Int((Double(a.height) * Double(w) / Double(max(a.width, 1))).rounded())))
        let hB = max(32, min(140, Int((Double(b.height) * Double(w) / Double(max(b.width, 1))).rounded())))
        guard hA == hB,
              let bufA = RGBABuffer(image: a, targetWidth: w, targetHeight: hA),
              let bufB = RGBABuffer(image: b, targetWidth: w, targetHeight: hB) else {
            return false
        }
        let yStart = hA * 18 / 100
        let yEnd = hA * 80 / 100
        let xStart = max(1, w * 4 / 100)
        let xEnd = min(w - 1, w * 94 / 100)
        guard yEnd > yStart, xEnd > xStart else { return false }

        var sum = 0
        var count = 0
        for y in yStart..<yEnd {
            let rowA = y * bufA.stride
            let rowB = y * bufB.stride
            for x in xStart..<xEnd {
                let pA = rowA + x * 4
                let pB = rowB + x * 4
                sum += abs(Int(bufA.data[pA]) - Int(bufB.data[pB]))
                sum += abs(Int(bufA.data[pA + 1]) - Int(bufB.data[pB + 1]))
                sum += abs(Int(bufA.data[pA + 2]) - Int(bufB.data[pB + 2]))
                count += 3
            }
        }
        guard count > 0 else { return false }
        return Double(sum) / Double(count) < tolerance
    }

    private static func isNearZeroShift(_ a: CGImage, _ b: CGImage) -> Bool {
        let w = 64
        let hA = max(32, min(140, Int((Double(a.height) * Double(w) / Double(max(a.width, 1))).rounded())))
        let hB = max(32, min(140, Int((Double(b.height) * Double(w) / Double(max(b.width, 1))).rounded())))
        guard hA == hB,
              let bufA = RGBABuffer(image: a, targetWidth: w, targetHeight: hA),
              let bufB = RGBABuffer(image: b, targetWidth: w, targetHeight: hB) else {
            return false
        }
        let yStart = hA * 18 / 100
        let yEnd = hA * 80 / 100
        let xStart = max(1, w * 4 / 100)
        let xEnd = min(w - 1, w * 94 / 100)
        guard yEnd > yStart + 4, xEnd > xStart else { return false }

        var bestMean = Double.greatestFiniteMagnitude
        for dy in -2...2 {
            var sum = 0
            var count = 0
            for y in yStart..<yEnd {
                let yB = y - dy
                guard yB >= 0 && yB < hB else { continue }
                let rowA = y * bufA.stride
                let rowB = yB * bufB.stride
                for x in xStart..<xEnd {
                    let pA = rowA + x * 4
                    let pB = rowB + x * 4
                    sum += abs(Int(bufA.data[pA]) - Int(bufB.data[pB]))
                    sum += abs(Int(bufA.data[pA + 1]) - Int(bufB.data[pB + 1]))
                    sum += abs(Int(bufA.data[pA + 2]) - Int(bufB.data[pB + 2]))
                    count += 3
                }
            }
            if count > 0 {
                let mean = Double(sum) / Double(count)
                if mean < bestMean {
                    bestMean = mean
                }
            }
        }
        return bestMean < 6.5
    }

    private static func findVerticalOverlap(previous: CGImage, current: CGImage, isVideo: Bool = false) -> OverlapMatch? {
        let minFullH = min(previous.height, current.height)
        guard minFullH >= 120, previous.width > 16 else { return nil }

        // Stage 1: Fast 192px RGB coarse buffer & vertically-smoothed 32-bin row fingerprint scan.
        let coarseW = min(192, previous.width)
        let coarseScale = Double(coarseW) / Double(previous.width)
        let hA = max(48, Int((Double(previous.height) * coarseScale).rounded()))
        let hB = max(48, Int((Double(current.height) * coarseScale).rounded()))

        guard let bufA = RGBABuffer(image: previous, targetWidth: coarseW, targetHeight: hA),
              let bufB = RGBABuffer(image: current, targetWidth: coarseW, targetHeight: hB) else {
            return nil
        }

        // Exclude left 2% and right 5% (ignores iOS right-edge scrollbar & curved corner chrome).
        let xStart = max(1, (coarseW * 2) / 100)
        let xEnd = max(xStart + 24, (coarseW * 95) / 100)
        let bins = 32

        let featA = buildRowFeatures(buffer: bufA, xStart: xStart, xEnd: xEnd, bins: bins)
        let featB = buildRowFeatures(buffer: bufB, xStart: xStart, xEnd: xEnd, bins: bins)

        var isStaticA = [Bool](repeating: false, count: hA)
        var isStaticB = [Bool](repeating: false, count: hB)
        let sharedH = min(hA, hB)

        // Mask hardware chrome (Dynamic Island status bar on B, Home Indicator on A) for portrait phone shots
        // so differing clock/battery or shifting TabView backgrounds never anchor false middle seams.
        let aspectA = Double(previous.height) / Double(max(previous.width, 1))
        let aspectB = Double(current.height) / Double(max(current.width, 1))
        if aspectA >= 1.55 && aspectB >= 1.55 {
            let statusMaskB = max(2, Int((Double(hB) * 0.042).rounded()))
            for y in 0..<min(statusMaskB, hB) {
                isStaticB[y] = true
            }
            let homeMaskA = max(2, Int((Double(hA) * 0.032).rounded()))
            for k in 0..<min(homeMaskA, hA) {
                isStaticA[hA - 1 - k] = true
            }
        }

        // Identify fixed identical top chrome (0...28%) and fixed bottom chrome (bottom 24%).
        let staticRowTol = isVideo ? 16 : 9
        let staticRowFrac = isVideo ? 0.80 : 0.86
        let maxTopStatic = (sharedH * 28) / 100
        for y in 0..<maxTopStatic {
            if featA.informative[y] && featB.informative[y],
               coarseRowMatchFraction(bufA, rowA: y, bufB, rowB: y, xStart: xStart, xEnd: xEnd, tol: staticRowTol) >= staticRowFrac {
                isStaticA[y] = true
                isStaticB[y] = true
            }
        }
        let maxBotStatic = (sharedH * 24) / 100
        for k in 0..<maxBotStatic {
            let yA = hA - 1 - k
            let yB = hB - 1 - k
            if featA.informative[yA] && featB.informative[yB],
               coarseRowMatchFraction(bufA, rowA: yA, bufB, rowB: yB, xStart: xStart, xEnd: xEnd, tol: staticRowTol) >= staticRowFrac {
                isStaticA[yA] = true
                isStaticB[yB] = true
            }
        }

        let minCoarseH = min(hA, hB)
        let minDyRatio = isVideo ? 0.022 : 0.04
        let minDy = max(isVideo ? 4 : 6, Int((Double(minCoarseH) * minDyRatio).rounded()))
        let minOverlapRows = max(6, Int((Double(minCoarseH) * 0.025).rounded()))
        let maxDy = hA - minOverlapRows
        guard maxDy >= minDy else { return nil }

        let s1InfoMaxDiff = isVideo ? 20.0 : 18.0
        let s1InfoMinCorr = isVideo ? 0.50 : 0.52
        let s1StrictMaxDiff = isVideo ? 10.0 : 8.5
        let s1StrictMinCorr = isVideo ? 0.33 : 0.35
        let s1FlatMaxDiff = isVideo ? 11.5 : 10.0

        var shiftScores = [(dy: Int, score: Double)]()
        shiftScores.reserveCapacity(maxDy - minDy + 1)

        var rowPass = [Bool](repeating: false, count: minCoarseH + 2)
        var rowSigDiff = [Double](repeating: 0, count: minCoarseH + 2)
        var rowInfoMatch = [Bool](repeating: false, count: minCoarseH + 2)

        for dy in minDy...maxDy {
            let yEndA = min(hA, hB + dy)
            let overlapCount = yEndA - dy
            guard overlapCount >= minOverlapRows else { continue }

            for idx in 0..<overlapCount {
                let yA = dy + idx
                let yB = yA - dy
                if isStaticA[yA] || isStaticB[yB] {
                    rowPass[idx] = false
                    rowInfoMatch[idx] = false
                } else {
                    let infoA = featA.informative[yA]
                    let infoB = featB.informative[yB]
                    let diff = sigL1Diff(featA.smoothRgbBins, rowA: yA, featB.smoothRgbBins, rowB: yB, bins: bins)
                    rowSigDiff[idx] = diff
                    if infoA || infoB {
                        let normCorr = rowSignatureCorrelation(featA.smoothLumaBins, rowA: yA, featB.smoothLumaBins, rowB: yB, bins: bins)
                        let ok = (diff < s1InfoMaxDiff && normCorr >= s1InfoMinCorr) || (diff < s1StrictMaxDiff && normCorr >= s1StrictMinCorr)
                        rowPass[idx] = ok
                        rowInfoMatch[idx] = ok
                    } else {
                        rowPass[idx] = diff < s1FlatMaxDiff
                        rowInfoMatch[idx] = false
                    }
                }
            }

            // Find best contiguous run (allowing up to 2-row bridges across thin dividers/subpixel aliasing).
            var bestRunScore = 0.0
            var idx = 0
            while idx < overlapCount {
                if !rowPass[idx] {
                    idx += 1
                    continue
                }
                let startIdx = idx
                var infoCount = 0
                var infoDiffSum = 0.0
                var lastPassIdx = idx

                while idx < overlapCount {
                    if rowPass[idx] {
                        if rowInfoMatch[idx] {
                            infoCount += 1
                            infoDiffSum += rowSigDiff[idx]
                        }
                        lastPassIdx = idx
                        idx += 1
                    } else if idx + 1 < overlapCount && rowPass[idx + 1] {
                        idx += 1
                    } else if idx + 2 < overlapCount && rowPass[idx + 2] {
                        idx += 2
                    } else {
                        break
                    }
                }

                let runLen = lastPassIdx - startIdx + 1
                let minInfo = max(3, min(4, minOverlapRows / 2))
                if runLen >= minOverlapRows && infoCount >= minInfo {
                    let meanInfoDiff = infoDiffSum / Double(infoCount)
                    let matchPurity = pow(22.0 / (2.0 + meanInfoDiff), 1.6)
                    let score = matchPurity * log2(Double(infoCount) + 4.0) + Double(infoCount) * 0.6
                    if score > bestRunScore {
                        bestRunScore = score
                    }
                }
            }

            if bestRunScore > 0 {
                shiftScores.append((dy: dy, score: bestRunScore))
            }
        }

        guard !shiftScores.isEmpty else { return nil }

        // Pick top 24 distinct local peak shifts separated by at least 3 rows so repetitive card lists
        // cannot crowd out shorter exact bottom overlaps.
        shiftScores.sort { $0.score > $1.score }
        var peaks: [Int] = []
        peaks.reserveCapacity(24)
        for cand in shiftScores {
            if peaks.allSatisfy({ abs($0 - cand.dy) >= 3 }) {
                peaks.append(cand.dy)
                if peaks.count >= 24 { break }
            }
        }

        // Stage 2: Exact + Half-Coarse-Pixel Phase Verification with Edge/Corner-Resilient ZNCC.
        // Collect top distinct verified shift candidates and let Stage 3 full-res pixel verification pick
        // the true exact match (prevents long repeating list-card templates from outscoring shorter exact overlaps).
        let innerSpan = xEnd - xStart
        let centerXStart = xStart + (innerSpan * 15) / 100
        let centerXEnd = max(centerXStart + 12, xEnd - (innerSpan * 15) / 100)

        struct Stage2Candidate {
            let dy: Int
            let halfStepB: Bool
            let startA: Int
            let endA: Int
            let score: Double
        }
        var stage2Candidates: [Stage2Candidate] = []

        for peak in peaks {
            let lo = max(minDy, peak - 2)
            let hi = min(maxDy, peak + 2)
            for dy in lo...hi {
                for halfStepB in [false, true] {
                    let yEndA = min(hA, hB + dy)
                    let overlapCount = yEndA - dy
                    guard overlapCount >= minOverlapRows else { continue }

                    var pass = [Bool](repeating: false, count: overlapCount)
                    var infoFlags = [Bool](repeating: false, count: overlapCount)
                    var diffs = [Double](repeating: 0, count: overlapCount)
                    var fracs = [Double](repeating: 0, count: overlapCount)
                    var fgMatchFracs = [Double](repeating: 0, count: overlapCount)

                    for i in 0..<overlapCount {
                        let yA = dy + i
                        let yB = yA - dy
                        if isStaticA[yA] || isStaticB[yB] { continue }
                        let info = featA.informative[yA] || featB.informative[yB]
                        let cmp = coarseRowDetailCompare(
                            bufA, rowA: yA, domA: featA.domLuma[yA],
                            bufB, rowB: yB, halfStepB: halfStepB, domB: featB.domLuma[yB],
                            xStart: xStart, xEnd: xEnd
                        )
                        diffs[i] = cmp.meanDiff
                        fracs[i] = cmp.matchFraction
                        fgMatchFracs[i] = cmp.foregroundAgreement
                        infoFlags[i] = info

                        if info {
                            pass[i] = cmp.meanDiff < (isVideo ? 20.0 : 18.0)
                                && cmp.matchFraction >= (isVideo ? 0.70 : 0.72)
                                && cmp.foregroundAgreement >= (isVideo ? 0.54 : 0.56)
                        } else {
                            pass[i] = cmp.meanDiff < (isVideo ? 11.5 : 10.0)
                                && cmp.matchFraction >= (isVideo ? 0.85 : 0.88)
                        }
                    }

                    var i = 0
                    while i < overlapCount {
                        if !pass[i] {
                            i += 1
                            continue
                        }
                        let startIdx = i
                        var endIdx = i
                        var infoRows = 0
                        var infoDiffSum = 0.0
                        var infoFracSum = 0.0
                        var infoFgSum = 0.0

                        while i < overlapCount {
                            if pass[i] {
                                if infoFlags[i] {
                                    infoRows += 1
                                    infoDiffSum += diffs[i]
                                    infoFracSum += fracs[i]
                                    infoFgSum += fgMatchFracs[i]
                                }
                                endIdx = i
                                i += 1
                            } else if i + 1 < overlapCount && pass[i + 1] {
                                i += 1
                            } else if i + 2 < overlapCount && pass[i + 2] {
                                i += 2
                            } else {
                                break
                            }
                        }

                        let stripLen = endIdx - startIdx + 1
                        let minReqInfo = stripLen < 12 ? 3 : 4
                        guard stripLen >= minOverlapRows, infoRows >= minReqInfo else { continue }

                        let meanInfoDiff = infoDiffSum / Double(infoRows)
                        let meanInfoFrac = infoFracSum / Double(infoRows)
                        let meanInfoFg = infoFgSum / Double(infoRows)
                        guard meanInfoDiff < (isVideo ? 16.5 : 15.0),
                              meanInfoFrac >= (isVideo ? 0.75 : 0.78),
                              meanInfoFg >= (isVideo ? 0.62 : 0.64) else {
                            continue
                        }

                        let fullZncc = stripRGBNormalizedCorrelation(
                            bufA, startA: dy + startIdx,
                            bufB, startB: startIdx, halfStepB: halfStepB,
                            height: stripLen,
                            xStart: xStart,
                            xEnd: xEnd
                        )
                        var coreZncc = fullZncc
                        if stripLen >= 14 {
                            let trim = max(2, stripLen / 7)
                            let coreLen = stripLen - trim * 2
                            if coreLen >= 6 {
                                coreZncc = stripRGBNormalizedCorrelation(
                                    bufA, startA: dy + startIdx + trim,
                                    bufB, startB: startIdx + trim, halfStepB: halfStepB,
                                    height: coreLen,
                                    xStart: xStart,
                                    xEnd: xEnd
                                )
                            }
                        }
                        var effectiveZncc = max(fullZncc, coreZncc)
                        if effectiveZncc < (isVideo ? 0.83 : 0.84) {
                            let centerZncc = stripRGBNormalizedCorrelation(
                                bufA, startA: dy + startIdx,
                                bufB, startB: startIdx, halfStepB: halfStepB,
                                height: stripLen,
                                xStart: centerXStart,
                                xEnd: centerXEnd
                            )
                            if centerZncc >= (isVideo ? 0.87 : 0.88) && meanInfoDiff < (isVideo ? 12.0 : 11.0) {
                                effectiveZncc = centerZncc
                            } else {
                                continue
                            }
                        }

                        // Heavily favor precision (effectiveZncc, meanInfoFg, low meanInfoDiff) over raw length.
                        let precision = pow(max(0.0, effectiveZncc), 3.0) * pow(meanInfoFg, 2.0) * (26.0 / (2.0 + meanInfoDiff))
                        let score = precision * log2(Double(infoRows + 4)) + Double(stripLen) * 0.15
                        stage2Candidates.append(Stage2Candidate(
                            dy: dy,
                            halfStepB: halfStepB,
                            startA: dy + startIdx,
                            endA: dy + endIdx,
                            score: score
                        ))
                    }
                }
            }
        }

        guard !stage2Candidates.isEmpty else { return nil }
        stage2Candidates.sort { $0.score > $1.score }
        var topCandidates: [Stage2Candidate] = []
        topCandidates.reserveCapacity(4)
        for cand in stage2Candidates {
            if topCandidates.allSatisfy({ abs($0.dy - cand.dy) >= 4 }) {
                topCandidates.append(cand)
                if topCandidates.count >= 4 { break }
            }
        }

        // Stage 3: Exact 1-pixel full-resolution seam refinement across top Stage 2 candidates.
        guard let fullA = RGBABuffer(image: previous),
              let fullB = RGBABuffer(image: current) else {
            let verified = topCandidates[0]
            let effectiveCoarseDy = Double(verified.dy) - (verified.halfStepB ? 0.5 : 0.0)
            let approxFullDy = max(1, Int((effectiveCoarseDy / coarseScale).rounded()))
            let bandTopA = max(0, Int((Double(verified.startA) / coarseScale).rounded()))
            let bandBotA = min(previous.height - 1, Int((Double(verified.endA) / coarseScale).rounded()))
            let cutA = max(approxFullDy + 1, min(previous.height, bandTopA + (bandBotA - bandTopA) / 2))
            let startB = cutA - approxFullDy
            guard cutA > 0, cutA <= previous.height, startB >= 0, startB < current.height else { return nil }
            return OverlapMatch(prevCutY: cutA, currStartY: startB, confidence: verified.score)
        }

        let fullXStart = max(2, (fullA.width * 4) / 100)
        let fullXEnd = min(fullA.width - 2, (fullA.width * 94) / 100)
        let fullSpan = max(1, fullXEnd - fullXStart)
        let colCount = max(12, min(72, fullSpan / 4))
        var sampleCols: [Int] = []
        sampleCols.reserveCapacity(colCount)
        for c in 0..<colCount {
            let x = fullXStart + (c * max(1, fullSpan - 1)) / max(1, colCount - 1)
            sampleCols.append(x)
        }
        let probeOffsets = [
            fullXStart,
            fullXStart + fullSpan / 4,
            fullXStart + fullSpan / 2,
            fullXStart + (fullSpan * 3) / 4,
            fullXEnd - 1,
        ]
        let radius = max(10, Int(ceil(2.5 / max(coarseScale, 0.05))))
        // Trim only ~6% worst columns per row (tolerates scrollbar/thin overlay while preserving card avatars & text mismatches).
        let trimmedColCount = max(8, sampleCols.count - max(1, (sampleCols.count * 6) / 100))

        struct ColObs {
            let diff: Int
            let isFg: Bool
            let fgMatch: Bool
        }
        var rowColObs: [ColObs] = []
        rowColObs.reserveCapacity(sampleCols.count)

        var bestFinalMatch: OverlapMatch?

        for verified in topCandidates {
            let effectiveCoarseDy = Double(verified.dy) - (verified.halfStepB ? 0.5 : 0.0)
            let approxFullDy = max(1, Int((effectiveCoarseDy / coarseScale).rounded()))
            var bandTopA = max(0, Int((Double(verified.startA) / coarseScale).rounded()))
            var bandBotA = min(previous.height - 1, Int((Double(verified.endA) / coarseScale).rounded()))
            let rawBandH = bandBotA - bandTopA
            let trimEdge = max(4, rawBandH / 10)
            if rawBandH > trimEdge * 2 + 12 {
                bandTopA += trimEdge
                bandBotA -= trimEdge
            }
            guard bandBotA > bandTopA else { continue }

            let candidateRowCount = bandBotA - bandTopA + 1
            let rowStep = max(1, candidateRowCount / 72)
            var informativeRows: [Int] = []
            var evenRows: [Int] = []
            var y = bandTopA
            while y <= bandBotA {
                evenRows.append(y)
                if fullRowHasContrast(fullA, row: y, cols: sampleCols) {
                    informativeRows.append(y)
                }
                y += rowStep
            }

            let chosenSource = informativeRows.count >= 6 ? informativeRows : evenRows
            let sampleRows: [Int]
            if chosenSource.count > 40 {
                sampleRows = (0..<40).map { chosenSource[$0 * chosenSource.count / 40] }
            } else {
                sampleRows = chosenSource
            }
            guard !sampleRows.isEmpty else { continue }

            var rowBgColors: [(r: Int, g: Int, b: Int)] = []
            rowBgColors.reserveCapacity(sampleRows.count)
            for rA in sampleRows {
                let baseA = rA * fullA.stride
                var sortedProbes = probeOffsets.map { x -> (luma: Int, r: Int, g: Int, b: Int) in
                    let p = baseA + x * 4
                    let r = Int(fullA.data[p]), g = Int(fullA.data[p + 1]), b = Int(fullA.data[p + 2])
                    return ((77 * r + 150 * g + 29 * b) >> 8, r, g, b)
                }
                sortedProbes.sort { $0.luma < $1.luma }
                let med = sortedProbes[2]
                rowBgColors.append((med.r, med.g, med.b))
            }

            var bestFullDy = approxFullDy
            var bestFullDiff = Double.greatestFiniteMagnitude
            var bestFullFgMatchFrac = 1.0
            var bestFullFgTotal = 0

            for dyFull in (approxFullDy - radius)...(approxFullDy + radius) where dyFull > 0 {
                var sum = 0
                var n = 0
                var fgTotal = 0
                var fgMatch = 0

                for (rowIdx, rA) in sampleRows.enumerated() {
                    let rB = rA - dyFull
                    guard rB >= 0 && rB < fullB.height else { continue }
                    let baseA = rA * fullA.stride
                    let baseB = rB * fullB.stride
                    let bg = rowBgColors[rowIdx]

                    rowColObs.removeAll(keepingCapacity: true)
                    for x in sampleCols {
                        let pA = baseA + x * 4
                        let pB = baseB + x * 4
                        let rValA = Int(fullA.data[pA]), gValA = Int(fullA.data[pA + 1]), bValA = Int(fullA.data[pA + 2])
                        let rValB = Int(fullB.data[pB]), gValB = Int(fullB.data[pB + 1]), bValB = Int(fullB.data[pB + 2])
                        let dr = abs(rValA - rValB)
                        let dg = abs(gValA - gValB)
                        let db = abs(bValA - bValB)
                        let diffSum = dr + dg + db

                        let bgDevA = max(abs(rValA - bg.r), max(abs(gValA - bg.g), abs(bValA - bg.b)))
                        let bgDevB = max(abs(rValB - bg.r), max(abs(gValB - bg.g), abs(bValB - bg.b)))
                        let isFg = max(bgDevA, bgDevB) >= 20
                        let matchesFg = isFg && max(dr, max(dg, db)) <= (isVideo ? 28 : 26)
                        rowColObs.append(ColObs(diff: diffSum, isFg: isFg, fgMatch: matchesFg))
                    }
                    rowColObs.sort { $0.diff < $1.diff }
                    for idx in 0..<min(trimmedColCount, rowColObs.count) {
                        let obs = rowColObs[idx]
                        sum += obs.diff
                        n += 3
                        if obs.isFg {
                            fgTotal += 1
                            if obs.fgMatch { fgMatch += 1 }
                        }
                    }
                }
                guard n >= trimmedColCount * 3 * 3 else { continue }
                let mean = Double(sum) / Double(n)
                if mean < bestFullDiff {
                    bestFullDiff = mean
                    bestFullDy = dyFull
                    bestFullFgTotal = fgTotal
                    bestFullFgMatchFrac = fgTotal > 0 ? Double(fgMatch) / Double(fgTotal) : 1.0
                }
            }

            guard bestFullDiff < (isVideo ? 15.5 : 14.0), bestFullDy > 0 else { continue }
            if bestFullFgTotal >= 12 && bestFullFgMatchFrac < (isVideo ? 0.78 : 0.80) {
                continue
            }

            // Rank Stage 3 verified matches primarily by full-resolution pixel precision & foreground agreement.
            let fullConfidence = verified.score
                * (24.0 / (0.6 + bestFullDiff))
                * pow(max(0.25, bestFullFgMatchFrac), 2.5)

            // Choose the crispest identical row near the midpoint of the verified overlap band.
            let span = bandBotA - bandTopA
            let midLo = max(bestFullDy + 1, min(previous.height, bandTopA + span / 4))
            let midHi = max(midLo, min(previous.height, bandTopA + (span * 3) / 4))
            let midCenter = (midLo + midHi) / 2
            var bestCutY = midCenter
            var bestCutScore = Double.greatestFiniteMagnitude
            let cutStep = max(1, (midHi - midLo) / 24)
            var rCut = midLo
            var cutColDiffs: [Int] = []
            cutColDiffs.reserveCapacity(sampleCols.count)
            while rCut <= midHi {
                let rB = rCut - bestFullDy
                if rB >= 0 && rB < fullB.height {
                    let baseA = rCut * fullA.stride
                    let baseB = rB * fullB.stride
                    cutColDiffs.removeAll(keepingCapacity: true)
                    for x in sampleCols {
                        let pA = baseA + x * 4
                        let pB = baseB + x * 4
                        let d = abs(Int(fullA.data[pA]) - Int(fullB.data[pB]))
                            + abs(Int(fullA.data[pA + 1]) - Int(fullB.data[pB + 1]))
                            + abs(Int(fullA.data[pA + 2]) - Int(fullB.data[pB + 2]))
                        cutColDiffs.append(d)
                    }
                    cutColDiffs.sort()
                    var rowSum = 0
                    let take = min(trimmedColCount, cutColDiffs.count)
                    for idx in 0..<take { rowSum += cutColDiffs[idx] }
                    let rowMean = Double(rowSum) / Double(max(1, take * 3))
                    let cutScore = rowMean + 0.015 * Double(abs(rCut - midCenter))
                    if cutScore < bestCutScore {
                        bestCutScore = cutScore
                        bestCutY = rCut
                    }
                }
                rCut += cutStep
            }

            let clampedCut = max(bestFullDy + 1, min(previous.height, bestCutY))
            let currStartY = clampedCut - bestFullDy
            guard clampedCut > 0, clampedCut <= previous.height,
                  currStartY >= 0, currStartY < current.height else {
                continue
            }

            if bestFinalMatch == nil || fullConfidence > bestFinalMatch!.confidence {
                bestFinalMatch = OverlapMatch(prevCutY: clampedCut, currStartY: currStartY, confidence: fullConfidence)
            }
        }

        return bestFinalMatch
    }

    // MARK: - Coarse & Full-Resolution Row Helpers

    private struct CoarseRowFeatures {
        let informative: [Bool]
        let domLuma: [Int]
        let lumaBins: [UInt8]
        let rgbBins: [UInt8]
        let smoothLumaBins: [UInt8]
        let smoothRgbBins: [UInt8]
    }

    private static func buildRowFeatures(
        buffer: RGBABuffer,
        xStart: Int,
        xEnd: Int,
        bins: Int
    ) -> CoarseRowFeatures {
        let span = max(1, xEnd - xStart)
        var informative = [Bool](repeating: false, count: buffer.height)
        var domLuma = [Int](repeating: 255, count: buffer.height)
        var lumaBins = [UInt8](repeating: 0, count: buffer.height * bins)
        var rgbBins = [UInt8](repeating: 0, count: buffer.height * bins * 3)

        for y in 0..<buffer.height {
            let rowBase = y * buffer.stride
            var edgeCount = 0
            var minLuma = 255
            var maxLuma = 0

            // Estimate row dominant background luma using 5 evenly spaced border/interior probes (median of 5).
            let p0 = rowBase + xStart * 4
            let p4 = rowBase + (xEnd - 1) * 4
            let p1 = rowBase + (xStart + span / 4) * 4
            let p2 = rowBase + (xStart + span / 2) * 4
            let p3 = rowBase + (xStart + (span * 3) / 4) * 4
            var probes = [
                (77 * Int(buffer.data[p0]) + 150 * Int(buffer.data[p0 + 1]) + 29 * Int(buffer.data[p0 + 2])) >> 8,
                (77 * Int(buffer.data[p1]) + 150 * Int(buffer.data[p1 + 1]) + 29 * Int(buffer.data[p1 + 2])) >> 8,
                (77 * Int(buffer.data[p2]) + 150 * Int(buffer.data[p2 + 1]) + 29 * Int(buffer.data[p2 + 2])) >> 8,
                (77 * Int(buffer.data[p3]) + 150 * Int(buffer.data[p3 + 1]) + 29 * Int(buffer.data[p3 + 2])) >> 8,
                (77 * Int(buffer.data[p4]) + 150 * Int(buffer.data[p4 + 1]) + 29 * Int(buffer.data[p4 + 2])) >> 8,
            ]
            probes.sort()
            let bgLuma = probes[2]
            domLuma[y] = bgLuma

            var devCount = 0
            for x in xStart..<xEnd {
                let p = rowBase + x * 4
                let r = Int(buffer.data[p])
                let g = Int(buffer.data[p + 1])
                let b = Int(buffer.data[p + 2])
                let luma = (77 * r + 150 * g + 29 * b) >> 8
                if luma < minLuma { minLuma = luma }
                if luma > maxLuma { maxLuma = luma }
                if abs(luma - bgLuma) >= 18 {
                    devCount += 1
                }
                if x > xStart {
                    let prev = rowBase + (x - 1) * 4
                    let jump = abs(r - Int(buffer.data[prev]))
                        + abs(g - Int(buffer.data[prev + 1]))
                        + abs(b - Int(buffer.data[prev + 2]))
                    if jump >= 28 {
                        edgeCount += 1
                    }
                }
            }
            informative[y] = (maxLuma - minLuma >= 16) || (edgeCount >= 2) || (devCount >= 2)

            let lBase = y * bins
            let rgbBase = y * bins * 3
            for b in 0..<bins {
                let bx0 = xStart + (b * span) / bins
                let bx1 = max(bx0 + 1, xStart + ((b + 1) * span) / bins)
                let count = bx1 - bx0
                var rs = 0, gs = 0, bs = 0, ls = 0
                for x in bx0..<bx1 {
                    let p = rowBase + x * 4
                    let r = Int(buffer.data[p])
                    let g = Int(buffer.data[p + 1])
                    let bv = Int(buffer.data[p + 2])
                    rs += r; gs += g; bs += bv
                    ls += (77 * r + 150 * g + 29 * bv) >> 8
                }
                lumaBins[lBase + b] = UInt8(min(255, ls / count))
                rgbBins[rgbBase + b * 3] = UInt8(min(255, rs / count))
                rgbBins[rgbBase + b * 3 + 1] = UInt8(min(255, gs / count))
                rgbBins[rgbBase + b * 3 + 2] = UInt8(min(255, bs / count))
            }
        }

        // 3-tap vertical smoothing [0.25, 0.5, 0.25] absorbs subpixel scroll phase offsets on 3x Retina text.
        var smoothLumaBins = lumaBins
        var smoothRgbBins = rgbBins
        if buffer.height >= 3 {
            let rgbStride = bins * 3
            for y in 1..<(buffer.height - 1) {
                let lCur = y * bins
                let lPrev = (y - 1) * bins
                let lNext = (y + 1) * bins
                for i in 0..<bins {
                    let v = (Int(lumaBins[lPrev + i]) + 2 * Int(lumaBins[lCur + i]) + Int(lumaBins[lNext + i])) >> 2
                    smoothLumaBins[lCur + i] = UInt8(v)
                }
                let rCur = y * rgbStride
                let rPrev = (y - 1) * rgbStride
                let rNext = (y + 1) * rgbStride
                for i in 0..<rgbStride {
                    let v = (Int(rgbBins[rPrev + i]) + 2 * Int(rgbBins[rCur + i]) + Int(rgbBins[rNext + i])) >> 2
                    smoothRgbBins[rCur + i] = UInt8(v)
                }
            }
        }

        return CoarseRowFeatures(
            informative: informative,
            domLuma: domLuma,
            lumaBins: lumaBins,
            rgbBins: rgbBins,
            smoothLumaBins: smoothLumaBins,
            smoothRgbBins: smoothRgbBins
        )
    }

    private static func sigL1Diff(_ a: [UInt8], rowA: Int, _ b: [UInt8], rowB: Int, bins: Int) -> Double {
        let len = bins * 3
        let baseA = rowA * len
        let baseB = rowB * len
        var sum = 0
        for i in 0..<len {
            sum += abs(Int(a[baseA + i]) - Int(b[baseB + i]))
        }
        return Double(sum) / Double(len)
    }

    private static func rowSignatureCorrelation(_ a: [UInt8], rowA: Int, _ b: [UInt8], rowB: Int, bins: Int) -> Double {
        let baseA = rowA * bins
        let baseB = rowB * bins
        var sumA = 0.0, sumB = 0.0
        for i in 0..<bins {
            sumA += Double(a[baseA + i])
            sumB += Double(b[baseB + i])
        }
        let meanA = sumA / Double(bins)
        let meanB = sumB / Double(bins)
        var num = 0.0, denA = 0.0, denB = 0.0
        for i in 0..<bins {
            let da = Double(a[baseA + i]) - meanA
            let db = Double(b[baseB + i]) - meanB
            num += da * db
            denA += da * da
            denB += db * db
        }
        let denom = sqrt(denA * denB)
        guard denom > 24.0 else {
            return abs(meanA - meanB) < 8.0 ? 1.0 : 0.0
        }
        return num / denom
    }

    private static func coarseRowMatchFraction(
        _ a: RGBABuffer, rowA: Int,
        _ b: RGBABuffer, rowB: Int,
        xStart: Int, xEnd: Int,
        tol: Int
    ) -> Double {
        let span = max(1, xEnd - xStart)
        let baseA = rowA * a.stride
        let baseB = rowB * b.stride
        var matches = 0
        for x in xStart..<xEnd {
            let pA = baseA + x * 4
            let pB = baseB + x * 4
            let dr = abs(Int(a.data[pA]) - Int(b.data[pB]))
            let dg = abs(Int(a.data[pA + 1]) - Int(b.data[pB + 1]))
            let db = abs(Int(a.data[pA + 2]) - Int(b.data[pB + 2]))
            if max(dr, max(dg, db)) <= tol {
                matches += 1
            }
        }
        return Double(matches) / Double(span)
    }

    private static func coarseRowDetailCompare(
        _ a: RGBABuffer, rowA: Int, domA: Int,
        _ b: RGBABuffer, rowB: Int, halfStepB: Bool, domB: Int,
        xStart: Int, xEnd: Int
    ) -> (meanDiff: Double, matchFraction: Double, foregroundAgreement: Double) {
        let baseA = rowA * a.stride
        let baseB0 = rowB * b.stride
        let nextRowB = halfStepB ? min(b.height - 1, rowB + 1) : rowB
        let baseB1 = nextRowB * b.stride
        var sum = 0
        var count = 0
        var matches = 0
        var fgTotal = 0
        var fgMatch = 0

        for x in Swift.stride(from: xStart, to: xEnd, by: 2) {
            let pA = baseA + x * 4
            let pB0 = baseB0 + x * 4
            let rA = Int(a.data[pA]), gA = Int(a.data[pA + 1]), bA = Int(a.data[pA + 2])
            let rB: Int, gB: Int, bB: Int
            if halfStepB {
                let pB1 = baseB1 + x * 4
                rB = (Int(b.data[pB0]) + Int(b.data[pB1])) >> 1
                gB = (Int(b.data[pB0 + 1]) + Int(b.data[pB1 + 1])) >> 1
                bB = (Int(b.data[pB0 + 2]) + Int(b.data[pB1 + 2])) >> 1
            } else {
                rB = Int(b.data[pB0])
                gB = Int(b.data[pB0 + 1])
                bB = Int(b.data[pB0 + 2])
            }
            let dr = abs(rA - rB)
            let dg = abs(gA - gB)
            let db = abs(bA - bB)
            let maxC = max(dr, max(dg, db))
            sum += dr + dg + db
            count += 1
            if maxC <= 22 {
                matches += 1
            }
            let lA = (77 * rA + 150 * gA + 29 * bA) >> 8
            let lB = (77 * rB + 150 * gB + 29 * bB) >> 8
            if abs(lA - domA) >= 16 || abs(lB - domB) >= 16 {
                fgTotal += 1
                if maxC <= 24 {
                    fgMatch += 1
                }
            }
        }
        let denom = max(1, count)
        let fgAgree = fgTotal >= 2 ? Double(fgMatch) / Double(fgTotal) : Double(matches) / Double(denom)
        return (Double(sum) / Double(denom * 3), Double(matches) / Double(denom), fgAgree)
    }

    private static func stripRGBNormalizedCorrelation(
        _ a: RGBABuffer, startA: Int,
        _ b: RGBABuffer, startB: Int, halfStepB: Bool,
        height: Int,
        xStart: Int,
        xEnd: Int
    ) -> Double {
        let cols = Swift.stride(from: xStart, to: xEnd, by: 2)
        var count = 0
        var sumR_A = 0.0, sumG_A = 0.0, sumB_A = 0.0
        var sumR_B = 0.0, sumG_B = 0.0, sumB_B = 0.0

        for dy in 0..<height {
            let rowA = (startA + dy) * a.stride
            let rB0 = min(b.height - 1, startB + dy)
            let rowB0 = rB0 * b.stride
            let rowB1 = (halfStepB ? min(b.height - 1, rB0 + 1) : rB0) * b.stride
            for x in cols {
                let pA = rowA + x * 4
                let pB0 = rowB0 + x * 4
                sumR_A += Double(a.data[pA]); sumG_A += Double(a.data[pA + 1]); sumB_A += Double(a.data[pA + 2])
                if halfStepB {
                    let pB1 = rowB1 + x * 4
                    sumR_B += 0.5 * (Double(b.data[pB0]) + Double(b.data[pB1]))
                    sumG_B += 0.5 * (Double(b.data[pB0 + 1]) + Double(b.data[pB1 + 1]))
                    sumB_B += 0.5 * (Double(b.data[pB0 + 2]) + Double(b.data[pB1 + 2]))
                } else {
                    sumR_B += Double(b.data[pB0]); sumG_B += Double(b.data[pB0 + 1]); sumB_B += Double(b.data[pB0 + 2])
                }
                count += 1
            }
        }
        guard count > 0 else { return 0 }
        let n = Double(count)
        let mRA = sumR_A / n, mGA = sumG_A / n, mBA = sumB_A / n
        let mRB = sumR_B / n, mGB = sumG_B / n, mBB = sumB_B / n

        var num = 0.0, denA = 0.0, denB = 0.0
        for dy in 0..<height {
            let rowA = (startA + dy) * a.stride
            let rB0 = min(b.height - 1, startB + dy)
            let rowB0 = rB0 * b.stride
            let rowB1 = (halfStepB ? min(b.height - 1, rB0 + 1) : rB0) * b.stride
            for x in cols {
                let pA = rowA + x * 4
                let pB0 = rowB0 + x * 4
                let dRA = Double(a.data[pA]) - mRA, dGA = Double(a.data[pA + 1]) - mGA, dBA = Double(a.data[pA + 2]) - mBA
                let dRB: Double, dGB: Double, dBB: Double
                if halfStepB {
                    let pB1 = rowB1 + x * 4
                    dRB = 0.5 * (Double(b.data[pB0]) + Double(b.data[pB1])) - mRB
                    dGB = 0.5 * (Double(b.data[pB0 + 1]) + Double(b.data[pB1 + 1])) - mGB
                    dBB = 0.5 * (Double(b.data[pB0 + 2]) + Double(b.data[pB1 + 2])) - mBB
                } else {
                    dRB = Double(b.data[pB0]) - mRB
                    dGB = Double(b.data[pB0 + 1]) - mGB
                    dBB = Double(b.data[pB0 + 2]) - mBB
                }
                num += dRA * dRB + dGA * dGB + dBA * dBB
                denA += dRA * dRA + dGA * dGA + dBA * dBA
                denB += dRB * dRB + dGB * dGB + dBB * dBB
            }
        }
        let denom = sqrt(denA * denB)
        guard denom > 100.0 else { return 0 }
        return num / denom
    }

    private static func fullRowHasContrast(_ buf: RGBABuffer, row: Int, cols: [Int]) -> Bool {
        guard cols.count >= 2 else { return false }
        let base = row * buf.stride
        var minL = 255
        var maxL = 0
        for x in cols {
            let p = base + x * 4
            let luma = (77 * Int(buf.data[p]) + 150 * Int(buf.data[p + 1]) + 29 * Int(buf.data[p + 2])) >> 8
            if luma < minL { minL = luma }
            if luma > maxL { maxL = luma }
            if maxL - minL >= 18 { return true }
        }
        return false
    }

    // MARK: - Low-Level Image Helpers

    private static func extractFrame(from generator: AVAssetImageGenerator, at time: CMTime) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            generator.generateCGImageAsynchronously(for: time) { cgImage, _, error in
                if let cgImage {
                    continuation.resume(returning: cgImage)
                } else {
                    continuation.resume(throwing: error ?? Failure.videoHasNoFrames)
                }
            }
        }
    }

    private static func normalizeWidth(_ image: CGImage, targetWidth: Int) -> CGImage? {
        if image.width == targetWidth { return image }
        let ratio = CGFloat(targetWidth) / CGFloat(max(image.width, 1))
        let targetHeight = max(1, Int((CGFloat(image.height) * ratio).rounded()))
        guard let ctx = CGImage.rgbaContext(width: targetWidth, height: targetHeight) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        return ctx.makeImage()
    }

    private static func normalizeHeight(_ image: CGImage, targetHeight: Int) -> CGImage? {
        if image.height == targetHeight { return image }
        let ratio = CGFloat(targetHeight) / CGFloat(max(image.height, 1))
        let targetWidth = max(1, Int((CGFloat(image.width) * ratio).rounded()))
        guard let ctx = CGImage.rgbaContext(width: targetWidth, height: targetHeight) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        return ctx.makeImage()
    }

    private static func grayscaleBytes(of image: CGImage, width: Int, height: Int) -> [UInt8]? {
        var buffer = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let ok = buffer.withUnsafeMutableBytes { ptr -> Bool in
            guard let base = ptr.baseAddress,
                  let ctx = CGContext(
                      data: base,
                      width: width,
                      height: height,
                      bitsPerComponent: 8,
                      bytesPerRow: width,
                      space: colorSpace,
                      bitmapInfo: CGImageAlphaInfo.none.rawValue
                  ) else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return ok ? buffer : nil
    }

    private static func frameSignature(_ image: CGImage) -> [UInt8] {
        grayscaleBytes(of: image, width: 32, height: 48) ?? []
    }

    private static func meanAbsoluteDiff(_ a: [UInt8], _ b: [UInt8]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 255 }
        var sum = 0
        for i in 0..<a.count {
            sum += abs(Int(a[i]) - Int(b[i]))
        }
        return Double(sum) / Double(a.count)
    }
}
