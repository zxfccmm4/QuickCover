import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// How a covered area looks in the result.
enum MaskStyle: String, CaseIterable, Codable, Sendable, Identifiable {
    case mosaic
    case stripes
    case conceal
    case solid
    case blur
    case emoji

    var id: String { rawValue }

    /// Mosaic is the default: it hides well and still reads as "this was something".
    static let `default` = MaskStyle.mosaic

    /// SF Symbol representing this style in the quick style tray and menus.
    var systemImage: String {
        switch self {
        case .mosaic: "squareshape.split.3x3"
        case .stripes: "line.diagonal"
        case .conceal: "wand.and.stars"
        case .solid: "rectangle.fill"
        case .blur: "drop.halffull"
        case .emoji: "face.smiling"
        }
    }

    /// Localization key for the style's display name.
    var titleKey: String {
        switch self {
        case .mosaic: "4.7.2"
        case .stripes: "4.7.6"
        case .conceal: "style.conceal"
        case .solid: "4.7.3"
        case .blur: "4.7.4"
        case .emoji: "style.emoji"
        }
    }

    /// Whether this style completely replaces covered pixels with flat/inpainted/opaque content
    /// (zero residual luminance trace of underlying text).
    var leavesNoTrace: Bool {
        switch self {
        case .solid, .conceal, .emoji: true
        case .mosaic, .stripes, .blur: false
        }
    }

    /// Whether mosaic/blur granularity controls apply to this style.
    var supportsStrength: Bool {
        switch self {
        case .mosaic, .stripes, .blur: true
        case .conceal, .solid, .emoji: false
        }
    }

    /// Whether color palette customization applies to this style.
    var supportsColor: Bool {
        switch self {
        case .mosaic, .stripes, .solid: true
        case .conceal, .blur, .emoji: false
        }
    }
}

/// Arbitrary sRGB color picked via native SwiftUI `ColorPicker`.
struct CustomColorRGB: Equatable, Codable, Sendable, Hashable {
    var red: Double
    var green: Double
    var blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
    }

    init?(cgColor: CGColor) {
        guard let srgb = CGColorSpace(name: CGColorSpace.sRGB),
              let converted = cgColor.converted(to: srgb, intent: .defaultIntent, options: nil),
              let comps = converted.components, comps.count >= 3 else {
            return nil
        }
        self.init(red: Double(comps[0]), green: Double(comps[1]), blue: Double(comps[2]))
    }

    var rgba: (r: CGFloat, g: CGFloat, b: CGFloat) {
        (CGFloat(red), CGFloat(green), CGFloat(blue))
    }

    var cgColor: CGColor {
        CGColor(
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            components: [CGFloat(red), CGFloat(green), CGFloat(blue), 1]
        )!
    }
}

/// Curated Apple iOS 26/27 palette for solid blocks, colored mosaics, and colored diagonal stripes.
enum SolidColorPreset: String, CaseIterable, Codable, Sendable, Identifiable {
    case black
    case white
    case graphite
    case teal
    case sand
    case sky
    case indigo
    case lavender
    case rose
    case coral
    case amber
    case mint

    var id: String { rawValue }

    var rgba: (r: CGFloat, g: CGFloat, b: CGFloat) {
        switch self {
        case .black: (0.0, 0.0, 0.0)
        case .white: (1.0, 1.0, 1.0)
        case .graphite: (0.173, 0.173, 0.180)
        case .teal: (0.043, 0.478, 0.478)
        case .sand: (0.910, 0.886, 0.839)
        case .sky: (0.039, 0.518, 1.0)
        case .indigo: (0.369, 0.361, 0.902)
        case .lavender: (0.749, 0.353, 0.949)
        case .rose: (1.0, 0.216, 0.373)
        case .coral: (1.0, 0.412, 0.380)
        case .amber: (1.0, 0.800, 0.0)
        case .mint: (0.188, 0.820, 0.345)
        }
    }

    var cgColor: CGColor {
        let c = rgba
        return CGColor(
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            components: [c.r, c.g, c.b, 1]
        )!
    }

    var titleKey: String {
        "color.\(rawValue)"
    }
}

/// Color option supporting either a curated Apple preset or any custom `ColorPicker` RGB color.
enum MaskColorOption: Equatable, Codable, Sendable, Hashable {
    case preset(SolidColorPreset)
    case custom(CustomColorRGB)

    var rgba: (r: CGFloat, g: CGFloat, b: CGFloat) {
        switch self {
        case .preset(let preset): preset.rgba
        case .custom(let custom): custom.rgba
        }
    }

    var cgColor: CGColor {
        switch self {
        case .preset(let preset): preset.cgColor
        case .custom(let custom): custom.cgColor
        }
    }
}

/// Color mode for `.mosaic` and `.stripes`: either original image cell tones (default) or a rich
/// tinted palette chosen by the user.
enum MosaicTint: Equatable, Codable, Sendable, Hashable {
    case original
    case color(MaskColorOption)

    var resolvedColor: MaskColorOption? {
        switch self {
        case .original: nil
        case .color(let option): option
        }
    }
}

/// Adjustable mosaic/blur granularity while keeping `.standard` identical to the security baseline.
enum MaskStrength: String, CaseIterable, Codable, Sendable, Identifiable {
    case fine
    case standard
    case coarse

    var id: String { rawValue }

    var multiplier: CGFloat {
        switch self {
        case .fine: 0.75
        case .standard: 1.0
        case .coarse: 1.45
        }
    }

    var titleKey: String {
        "strength.\(rawValue)"
    }
}

/// Export container format choice.
enum ExportFormat: String, CaseIterable, Codable, Sendable, Identifiable {
    case original
    case jpeg
    case png

    var id: String { rawValue }

    var titleKey: String {
        "export.format.\(rawValue)"
    }

    func utType(original: UTType?) -> UTType {
        switch self {
        case .original: original ?? .jpeg
        case .jpeg: .jpeg
        case .png: .png
        }
    }
}

/// Categorized emoji catalog for `.emoji` sticker covering.
struct EmojiCategory: Identifiable, Sendable {
    let id: String
    let titleKey: String
    let systemImage: String
    let emojis: [String]
}

/// Curated emojis for `.emoji` sticker covering (48 presets across 4 categories + custom keyboard).
enum EmojiPreset {
    static let quickBar = ["😎", "🙂", "🫣", "🐱", "🐶", "🦊", "🐼", "🌸", "✨", "🙈"]
    static let `default` = "😎"

    static let categories: [EmojiCategory] = [
        EmojiCategory(
            id: "faces",
            titleKey: "emoji.cat.faces",
            systemImage: "face.smiling",
            emojis: ["😎", "🙂", "😊", "🥳", "🤩", "🥹", "🤫", "🤭", "🫣", "😶‍🌫️", "🤖", "👽"]
        ),
        EmojiCategory(
            id: "animals",
            titleKey: "emoji.cat.animals",
            systemImage: "pawprint",
            emojis: ["🐱", "🐶", "🦊", "🐼", "🐨", "🐰", "🐻‍❄️", "🦄", "🐸", "🐧", "🦋", "🐥"]
        ),
        EmojiCategory(
            id: "nature",
            titleKey: "emoji.cat.nature",
            systemImage: "sparkles",
            emojis: ["🌸", "🌼", "🌻", "🍀", "🌈", "✨", "⭐️", "💫", "🔥", "💎", "🎀", "🫧"]
        ),
        EmojiCategory(
            id: "privacy",
            titleKey: "emoji.cat.privacy",
            systemImage: "lock.shield",
            emojis: ["🙈", "🙉", "🙊", "🔒", "🛡️", "🚫", "⛔️", "🪪", "🎭", "👾", "👀", "💯"]
        ),
    ]

    static let all: [String] = categories.flatMap(\.emojis)
}

/// Anti-theft tiled diagonal watermark settings for ID cards, licenses, and documents.
struct WatermarkOptions: Equatable, Codable, Sendable {
    enum Density: String, CaseIterable, Codable, Sendable, Identifiable {
        case sparse
        case medium
        case dense

        var id: String { rawValue }

        var titleKey: String { "wm.density.\(rawValue)" }

        /// Vertical spacing in multiples of font size.
        var rowSpacingFactor: CGFloat {
            switch self {
            case .sparse: 5.2
            case .medium: 3.4
            case .dense: 2.3
            }
        }

        /// Horizontal gap between repeated labels in multiples of font size.
        var columnGapFactor: CGFloat {
            switch self {
            case .sparse: 4.0
            case .medium: 2.6
            case .dense: 1.7
            }
        }
    }

    enum Tint: String, CaseIterable, Codable, Sendable, Identifiable {
        case white
        case slate
        case red

        var id: String { rawValue }

        var titleKey: String { "wm.color.\(rawValue)" }

        func uiColor(alpha: CGFloat) -> UIColor {
            switch self {
            case .white: UIColor.white.withAlphaComponent(alpha)
            case .slate: UIColor(red: 0.16, green: 0.16, blue: 0.18, alpha: alpha)
            case .red: UIColor(red: 0.85, green: 0.16, blue: 0.16, alpha: alpha)
            }
        }
    }

    var isEnabled: Bool = false
    var text: String = ""
    var opacity: Double = 0.28
    var density: Density = .medium
    var tint: Tint = .slate

    var isActive: Bool {
        isEnabled && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static let off = WatermarkOptions()
}

/// Appearance bundle passed consistently to both preview (`CoverPainter`) and full-res export (`MaskRenderer`).
struct MaskAppearance: Equatable, Codable, Sendable {
    var style: MaskStyle = .default
    var solidColor: SolidColorPreset = .black
    var customSolidColor: CustomColorRGB? = nil
    var mosaicTint: MosaicTint = .original
    var emoji: String = EmojiPreset.default
    var strength: MaskStrength = .standard
    var watermark: WatermarkOptions = .off

    var resolvedSolidOption: MaskColorOption {
        if let customSolidColor { return .custom(customSolidColor) }
        return .preset(solidColor)
    }

    var resolvedSolidCGColor: CGColor {
        resolvedSolidOption.cgColor
    }

    static let `default` = MaskAppearance()
}

/// Presses the masks (and optional anti-theft watermark) permanently into image pixels.
/// Pure CoreGraphics, keeping peak memory bounded even on 48 MP photos.
enum MaskRenderer {

    struct Options: Sendable {
        var style: MaskStyle = .default
        var solidColor: SolidColorPreset = .black
        var customSolidColor: CustomColorRGB? = nil
        var mosaicTint: MosaicTint = .original
        var emoji: String = EmojiPreset.default
        var strength: MaskStrength = .standard
        var watermark: WatermarkOptions = .off
        /// The export leaves out location and other metadata of the original.
        var stripMetadata = true
        var format: ExportFormat = .original
        var quality = 0.95
        /// How coarse the blur is. The app leaves it at the shipped grain; the probe tries others.
        var blurGrain: BlurGrain = .default

        var appearance: MaskAppearance {
            MaskAppearance(
                style: style,
                solidColor: solidColor,
                customSolidColor: customSolidColor,
                mosaicTint: mosaicTint,
                emoji: emoji,
                strength: strength,
                watermark: watermark
            )
        }
    }

    struct BlurGrain: Equatable, Sendable {
        var divisor: CGFloat
        var floor: CGFloat

        func cell(forHeight height: CGFloat) -> CGFloat { max(floor, height / divisor) }

        static let `default` = BlurGrain(divisor: 6, floor: 12)
    }

    struct Grid: Equatable, Sendable {
        let columns: Int
        let rows: Int

        func grain(in bounds: CGRect) -> CGSize {
            CGSize(width: bounds.width / CGFloat(columns), height: bounds.height / CGFloat(rows))
        }
    }

    static let mosaicFloor: CGFloat = 12

    static func onShrunkPicture(shrink: CGSize, blurGrain: BlurGrain = .default)
        -> (blurGrain: BlurGrain, floor: CGFloat) {
        let by = min(shrink.width, shrink.height)
        return (BlurGrain(divisor: blurGrain.divisor, floor: blurGrain.floor / by), mosaicFloor / by)
    }

    enum Failure: Error {
        case cannotDecode
        case cannotEncode
    }

    /// The encoded result file: same pixel size as the source, upright, masks & optional watermark pressed in.
    static func encode(_ source: CGImageSource, orientation: CGImagePropertyOrientation,
                       findings: [Finding], options: Options = Options()) throws -> Data {
        let decode = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let raw = CGImageSourceCreateImageAtIndex(source, 0, decode) else { throw Failure.cannotDecode }
        let upright = raw.oriented(orientation)
        let flat = flatten(
            upright,
            findings: findings,
            appearance: options.appearance,
            blurGrain: options.blurGrain
        )

        let sourceType = (CGImageSourceGetType(source) as String?).flatMap(UTType.init)
        let targetType = options.format.utType(original: sourceType)
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, targetType.identifier as CFString, 1, nil) else {
            throw Failure.cannotEncode
        }
        var properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: options.quality]
        if !options.stripMetadata, let original = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            var tiff = original[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
            tiff[kCGImagePropertyTIFFOrientation] = 1
            properties[kCGImagePropertyTIFFDictionary] = tiff
            if let exif = original[kCGImagePropertyExifDictionary] { properties[kCGImagePropertyExifDictionary] = exif }
            if let gps = original[kCGImagePropertyGPSDictionary] { properties[kCGImagePropertyGPSDictionary] = gps }
        }
        CGImageDestinationAddImage(destination, flat, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw Failure.cannotEncode }
        return data as Data
    }

    /// Convenience entry point keeping full source compatibility with existing callers and tests.
    static func flatten(_ image: CGImage, findings: [Finding], style: MaskStyle,
                        blurGrain: BlurGrain = .default, floor: CGFloat = mosaicFloor) -> CGImage {
        flatten(
            image,
            findings: findings,
            appearance: MaskAppearance(style: style),
            blurGrain: blurGrain,
            floor: floor
        )
    }

    /// Full-featured pixel flattening supporting all 6 masking styles, Magic Erase multi-directional
    /// inpainting, rich mosaic/stripe/solid colors, granularity, and diagonal anti-theft watermarks.
    static func flatten(
        _ image: CGImage,
        findings: [Finding],
        appearance: MaskAppearance,
        blurGrain: BlurGrain = .default,
        floor: CGFloat = mosaicFloor,
        stripeOrigin: CGPoint = .zero,
        medianTextHeight: CGFloat? = nil
    ) -> CGImage {
        let hasWatermark = appearance.watermark.isActive
        guard (!findings.isEmpty || hasWatermark),
              let context = CGImage.rgbaContext(width: image.width, height: image.height) else {
            return image
        }
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let resolvedMedianTextHeight = medianTextHeight ?? computeMedianTextHeight(in: findings)

        // Top-left pixel coordinates matching findings.
        context.saveGState()
        context.translateBy(x: 0, y: height)
        context.scaleBy(x: 1, y: -1)

        for finding in findings {
            for quad in finding.quads {
                let path = quadPath(quad)
                let rect = Geometry.bounds(of: quad)
                switch appearance.style {
                case .solid:
                    context.setFillColor(appearance.resolvedSolidCGColor)
                    context.addPath(path)
                    context.fillPath()
                case .conceal:
                    magicErase(from: image, rect: rect, path: path, into: context)
                case .emoji:
                    drawEmojiCover(
                        from: image,
                        rect: rect,
                        path: path,
                        emoji: appearance.emoji,
                        into: context
                    )
                case .mosaic, .blur:
                    cover(
                        from: image,
                        rect: rect,
                        path: path,
                        finding: finding,
                        into: context,
                        style: appearance.style,
                        tint: appearance.style == .mosaic ? appearance.mosaicTint : .original,
                        strength: appearance.strength,
                        blurGrain: blurGrain,
                        floor: floor
                    )
                case .stripes:
                    drawStripes(
                        from: image,
                        rect: rect,
                        path: path,
                        finding: finding,
                        into: context,
                        tint: appearance.mosaicTint,
                        strength: appearance.strength,
                        blurGrain: blurGrain,
                        floor: floor,
                        stripeOrigin: stripeOrigin,
                        medianTextHeight: resolvedMedianTextHeight
                    )
                }
            }
        }
        context.restoreGState()

        if hasWatermark {
            drawWatermark(in: context, size: CGSize(width: width, height: height), options: appearance.watermark)
        }

        return context.makeImage() ?? image
    }

    // MARK: - Grid sizing

    static func grid(over bounds: CGRect, hiding finding: Finding, style: MaskStyle,
                     blurGrain: BlurGrain = .default, floor: CGFloat = mosaicFloor,
                     strength: MaskStrength = .standard) -> Grid {
        guard style != .solid, style != .conceal, style != .emoji else {
            return Grid(columns: 1, rows: 1)
        }
        let scale = strength.multiplier
        let scaledFloor = floor * scale
        if finding.kind == .face {
            let effectiveGrain = BlurGrain(divisor: blurGrain.divisor / scale, floor: blurGrain.floor * scale)
            let cell = (style == .mosaic || style == .stripes)
                ? max(scaledFloor, bounds.height / (6 / scale))
                : effectiveGrain.cell(forHeight: bounds.height)
            return Grid(columns: max(1, Int((bounds.width / cell).rounded(.up))),
                        rows: max(1, Int((bounds.height / cell).rounded(.up))))
        }
        if finding.drawnByHand {
            return Grid(columns: max(1, whole(bounds.width / max(bounds.height * scale, scaledFloor))), rows: 1)
        }
        let baseSize = base(over: bounds, textHeight: finding.textHeight.map { $0 * scale }, floor: scaledFloor)
        return grid(over: bounds, base: baseSize)
    }

    static func base(over bounds: CGRect, textHeight: CGFloat?, floor: CGFloat = mosaicFloor) -> CGFloat {
        max(floor, bounds.height / 2, textHeight ?? 0)
    }

    static func grid(over bounds: CGRect, base: CGFloat) -> Grid {
        Grid(columns: max(1, whole(bounds.width / base)),
             rows: max(1, min(2, whole(bounds.height / base))))
    }

    private static func whole(_ value: CGFloat) -> Int {
        value.isFinite ? max(0, Int((value + 1e-9).rounded(.down))) : 0
    }

    static func computeMedianTextHeight(in findings: [Finding]) -> CGFloat? {
        let heights = findings.compactMap(\.textHeight).sorted()
        guard !heights.isEmpty else { return nil }
        return heights[heights.count / 2]
    }

    // MARK: - Mosaic & Blur (with Optional Rich Color Tinting)

    private static func cover(from image: CGImage, rect: CGRect, path: CGPath, finding: Finding, into context: CGContext,
                              style: MaskStyle, tint: MosaicTint, strength: MaskStrength,
                              blurGrain: BlurGrain, floor: CGFloat) {
        let bounds = rect.intersection(CGRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height)))
        guard bounds.width >= 2, bounds.height >= 2 else { return }
        let cut = grid(over: bounds, hiding: finding, style: style, blurGrain: blurGrain, floor: floor, strength: strength)
        guard let small = CGImage.rgbaContext(width: cut.columns, height: cut.rows), let grains = small.data,
              let picture = context.data else { return }
        fillGrains(grains.assumingMemoryBound(to: UInt8.self), grainStride: small.bytesPerRow,
                   from: picture.assumingMemoryBound(to: UInt8.self), stride: context.bytesPerRow,
                   bounds: bounds, columns: cut.columns, rows: cut.rows)

        if let colorOption = tint.resolvedColor {
            applyColorTint(
                to: grains.assumingMemoryBound(to: UInt8.self),
                grainStride: small.bytesPerRow,
                columns: cut.columns,
                rows: cut.rows,
                color: colorOption
            )
        }

        guard let grainImage = small.makeImage() else { return }

        context.saveGState()
        context.addPath(path)
        context.clip()
        context.interpolationQuality = style == .mosaic ? .none : .high
        context.translateBy(x: bounds.minX, y: bounds.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(grainImage, in: CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height))
        context.restoreGState()
    }

    /// Stylizes mosaic grains into a vibrant tonal mosaic of the selected color while maintaining
    /// pixel-cell visual texture and obscuring underlying glyph contours.
    private static func applyColorTint(
        to grains: UnsafeMutablePointer<UInt8>,
        grainStride: Int,
        columns: Int,
        rows: Int,
        color: MaskColorOption
    ) {
        let base = color.rgba
        let br = Double(base.r) * 255
        let bg = Double(base.g) * 255
        let bb = Double(base.b) * 255
        let isNearBlack = (br + bg + bb) < 42
        let isNearWhite = (br + bg + bb) > 720

        for row in 0..<rows {
            for col in 0..<columns {
                let p = grains + row * grainStride + col * 4
                let luma = (0.299 * Double(p[0]) + 0.587 * Double(p[1]) + 0.114 * Double(p[2])) / 255.0
                // Deterministic micro-checker jitter ensures crisp visible mosaic blocks even on flat areas.
                let hash = ((row &* 73856093) ^ (col &* 19349663)) & 7
                let jitter = (Double(hash) / 7.0 - 0.5) * 0.14
                let checker = ((row + col) % 2 == 0) ? 0.05 : -0.05

                let nr: Double
                let ng: Double
                let nb: Double
                if isNearBlack {
                    let v = min(max(24 + luma * 38 + (jitter + checker) * 90, 8), 86)
                    nr = v; ng = v; nb = v
                } else if isNearWhite {
                    let v = min(max(210 + luma * 34 + (jitter + checker) * 70, 185), 255)
                    nr = v; ng = v; nb = v
                } else {
                    let tone = min(max(0.74 + luma * 0.34 + jitter + checker, 0.56), 1.24)
                    if tone <= 1.0 {
                        nr = br * tone
                        ng = bg * tone
                        nb = bb * tone
                    } else {
                        let lift = tone - 1.0
                        nr = br + (255 - br) * lift
                        ng = bg + (255 - bg) * lift
                        nb = bb + (255 - bb) * lift
                    }
                }
                p[0] = UInt8(min(max(Int(nr.rounded()), 0), 255))
                p[1] = UInt8(min(max(Int(ng.rounded()), 0), 255))
                p[2] = UInt8(min(max(Int(nb.rounded()), 0), 255))
                p[3] = 255
            }
        }
    }

    // MARK: - Diagonal Stripes (design.md §7.3.2, with Optional Colored Bars)

    /// Draws the exact same average-color cell grid as mosaic masked through 45° diagonal bars
    /// aligned to the picture's top-left corner, alternating with solid black (or user-chosen tint).
    private static func drawStripes(
        from image: CGImage,
        rect: CGRect,
        path: CGPath,
        finding: Finding,
        into context: CGContext,
        tint: MosaicTint,
        strength: MaskStrength,
        blurGrain: BlurGrain,
        floor: CGFloat,
        stripeOrigin: CGPoint,
        medianTextHeight: CGFloat?
    ) {
        let bounds = rect.intersection(CGRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height)))
        guard bounds.width >= 2, bounds.height >= 2 else { return }
        let cut = grid(over: bounds, hiding: finding, style: .stripes, blurGrain: blurGrain, floor: floor, strength: strength)
        guard let small = CGImage.rgbaContext(width: cut.columns, height: cut.rows), let grains = small.data,
              let picture = context.data else { return }
        fillGrains(grains.assumingMemoryBound(to: UInt8.self), grainStride: small.bytesPerRow,
                   from: picture.assumingMemoryBound(to: UInt8.self), stride: context.bytesPerRow,
                   bounds: bounds, columns: cut.columns, rows: cut.rows)
        guard let grainImage = small.makeImage() else { return }

        let cellHeight = bounds.height / CGFloat(cut.rows)
        let refTextHeight = finding.textHeight ?? medianTextHeight
        let q: CGFloat = if let t = refTextHeight, t > 0 {
            min(cellHeight, 1.75 * t)
        } else {
            cellHeight
        }
        let period = max(4, q / 2)
        let stripeWidth = period / 2

        context.saveGState()
        context.addPath(path)
        context.clip()

        // Fill base bar color between mosaic stripes (pure black by default, or user-chosen tint).
        let barColor = tint.resolvedColor?.cgColor ?? CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        context.setFillColor(barColor)
        context.fill(bounds)

        // Build 45° diagonal stripe clip aligned to global (stripeOrigin + (x, y)).
        let stripePath = CGMutablePath()
        let gx0 = bounds.minX + stripeOrigin.x
        let gx1 = bounds.maxX + stripeOrigin.x
        let gy0 = bounds.minY + stripeOrigin.y
        let gy1 = bounds.maxY + stripeOrigin.y
        let minDiff = gx0 - gy1
        let maxDiff = gx1 - gy0
        let firstK = Int(((minDiff - stripeWidth) / period).rounded(.down))
        let lastK = Int((maxDiff / period).rounded(.up))

        for k in firstK...lastK {
            let d0 = CGFloat(k) * period
            let d1 = d0 + stripeWidth
            let yTop = bounds.minY - 2
            let yBot = bounds.maxY + 2
            let xTop0 = d0 + (yTop + stripeOrigin.y) - stripeOrigin.x
            let xTop1 = d1 + (yTop + stripeOrigin.y) - stripeOrigin.x
            let xBot1 = d1 + (yBot + stripeOrigin.y) - stripeOrigin.x
            let xBot0 = d0 + (yBot + stripeOrigin.y) - stripeOrigin.x
            stripePath.move(to: CGPoint(x: xTop0, y: yTop))
            stripePath.addLine(to: CGPoint(x: xTop1, y: yTop))
            stripePath.addLine(to: CGPoint(x: xBot1, y: yBot))
            stripePath.addLine(to: CGPoint(x: xBot0, y: yBot))
            stripePath.closeSubpath()
        }

        context.addPath(stripePath)
        context.clip()
        context.interpolationQuality = .none
        context.translateBy(x: bounds.minX, y: bounds.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(grainImage, in: CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height))
        context.restoreGState()
    }

    // MARK: - Magic Erase (Multi-Directional Seamless Inpainting)

    /// Reconstructs covered pixels strictly from exterior boundary samples using inverse-distance
    /// weighted multi-directional interpolation plus organic surface grain preservation.
    /// Never reads a single pixel inside `rect`, guaranteeing zero residual text trace while
    /// blending smoothly across gradients, chat bubbles, soft shadows, and paper textures.
    private static func magicErase(from image: CGImage, rect: CGRect, path: CGPath, into context: CGContext) {
        let bounds = rect.intersection(CGRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height)))
        guard bounds.width >= 2, bounds.height >= 2, let rawData = context.data else {
            let color = sampledBackgroundColor(around: rect, in: context, width: image.width, height: image.height)
            context.saveGState()
            context.setFillColor(color)
            context.addPath(path)
            context.fillPath()
            context.restoreGState()
            return
        }

        let width = image.width
        let height = image.height
        let pixels = rawData.assumingMemoryBound(to: UInt8.self)
        let stride = context.bytesPerRow

        let x0 = max(0, min(width - 1, Int(bounds.minX.rounded(.down))))
        let x1 = max(x0 + 1, min(width, Int(bounds.maxX.rounded(.up))))
        let y0 = max(0, min(height - 1, Int(bounds.minY.rounded(.down))))
        let y1 = max(y0 + 1, min(height, Int(bounds.maxY.rounded(.up))))
        let patchW = x1 - x0
        let patchH = y1 - y0

        guard patchW >= 1, patchH >= 1,
              let patchCtx = CGImage.rgbaContext(width: patchW, height: patchH),
              let patchData = patchCtx.data else {
            return
        }

        // Helper reading robust 3-sample median strictly outside the box to reject edge ink bleed.
        func sampleRGB(_ sx: Int, _ sy: Int) -> (Double, Double, Double) {
            let cx = max(0, min(width - 1, sx))
            let cy = max(0, min(height - 1, sy))
            let p = pixels + cy * stride + cx * 4
            return (Double(p[0]), Double(p[1]), Double(p[2]))
        }

        func median3(_ a: Double, _ b: Double, _ c: Double) -> Double {
            if a > b {
                if b > c { return b }
                return a > c ? c : a
            } else {
                if a > c { return a }
                return b > c ? c : b
            }
        }

        func robustEdgeSample(x: Int, y: Int, dx: Int, dy: Int) -> (Double, Double, Double) {
            // Skip the immediate 1px fringe where anti-aliased adjacent glyphs can bleed into the boundary.
            let s1 = sampleRGB(x + dx * 2, y + dy * 2)
            let s2 = sampleRGB(x + dx * 3, y + dy * 3)
            let s3 = sampleRGB(x + dx * 4, y + dy * 4)
            return (
                median3(s1.0, s2.0, s3.0),
                median3(s1.1, s2.1, s3.1),
                median3(s1.2, s2.2, s3.2)
            )
        }

        let hasTop = y0 > 0
        let hasBottom = y1 < height
        let hasLeft = x0 > 0
        let hasRight = x1 < width

        var topEdge = [(Double, Double, Double)](repeating: (242, 242, 242), count: patchW)
        var bottomEdge = [(Double, Double, Double)](repeating: (242, 242, 242), count: patchW)
        var leftEdge = [(Double, Double, Double)](repeating: (242, 242, 242), count: patchH)
        var rightEdge = [(Double, Double, Double)](repeating: (242, 242, 242), count: patchH)

        for i in 0..<patchW {
            let gx = x0 + i
            if hasTop {
                topEdge[i] = robustEdgeSample(x: gx, y: y0, dx: 0, dy: -1)
            }
            if hasBottom {
                bottomEdge[i] = robustEdgeSample(x: gx, y: y1 - 1, dx: 0, dy: 1)
            }
        }
        for j in 0..<patchH {
            let gy = y0 + j
            if hasLeft {
                leftEdge[j] = robustEdgeSample(x: x0, y: gy, dx: -1, dy: 0)
            }
            if hasRight {
                rightEdge[j] = robustEdgeSample(x: x1 - 1, y: gy, dx: 1, dy: 0)
            }
        }

        // Remove adjacent foreground glyph bleed (e.g. a colon "：" right before a phone number)
        // using a sliding median (which preserves linear gradients exactly) plus corner-consistent
        // outlier rejection on narrow edges, followed by a light radius-2 smoothing pass.
        func cleanEdge(
            _ edge: [(Double, Double, Double)],
            cornerStart: (Double, Double, Double)? = nil,
            cornerEnd: (Double, Double, Double)? = nil
        ) -> [(Double, Double, Double)] {
            guard edge.count >= 5 else { return edge }
            let radius = min(8, max(3, edge.count / 4))
            var denoised = edge
            var rs: [Double] = []
            var gs: [Double] = []
            var bs: [Double] = []
            rs.reserveCapacity(radius * 2 + 1)
            gs.reserveCapacity(radius * 2 + 1)
            bs.reserveCapacity(radius * 2 + 1)

            for i in 0..<edge.count {
                rs.removeAll(keepingCapacity: true)
                gs.removeAll(keepingCapacity: true)
                bs.removeAll(keepingCapacity: true)
                let lo = max(0, i - radius)
                let hi = min(edge.count - 1, i + radius)
                for k in lo...hi {
                    rs.append(edge[k].0)
                    gs.append(edge[k].1)
                    bs.append(edge[k].2)
                }
                rs.sort()
                gs.sort()
                bs.sort()
                let mid = rs.count / 2
                var c = (rs[mid], gs[mid], bs[mid])

                if let c0 = cornerStart, let c1 = cornerEnd {
                    let cornerDelta = abs(c0.0 - c1.0) + abs(c0.1 - c1.1) + abs(c0.2 - c1.2)
                    if cornerDelta < 75 {
                        let t = Double(i) / Double(max(1, edge.count - 1))
                        let expected = (
                            c0.0 + (c1.0 - c0.0) * t,
                            c0.1 + (c1.1 - c0.1) * t,
                            c0.2 + (c1.2 - c0.2) * t
                        )
                        let diff = abs(c.0 - expected.0) + abs(c.1 - expected.1) + abs(c.2 - expected.2)
                        if diff > 42 {
                            c = expected
                        }
                    }
                }
                denoised[i] = c
            }

            var out = denoised
            for i in 0..<denoised.count {
                var sr = 0.0, sg = 0.0, sb = 0.0, count = 0.0
                for k in max(0, i - 2)...min(denoised.count - 1, i + 2) {
                    sr += denoised[k].0; sg += denoised[k].1; sb += denoised[k].2; count += 1
                }
                out[i] = (sr / count, sg / count, sb / count)
            }
            return out
        }

        if hasTop { topEdge = cleanEdge(topEdge) }
        if hasBottom { bottomEdge = cleanEdge(bottomEdge) }
        if hasLeft {
            leftEdge = cleanEdge(
                leftEdge,
                cornerStart: hasTop ? topEdge.first : nil,
                cornerEnd: hasBottom ? bottomEdge.first : nil
            )
        }
        if hasRight {
            rightEdge = cleanEdge(
                rightEdge,
                cornerStart: hasTop ? topEdge.last : nil,
                cornerEnd: hasBottom ? bottomEdge.last : nil
            )
        }

        // Estimate subtle natural exterior grain from cleaned edges (0 on flat digital cards; gentle 1..4 on photos).
        var lumas: [Double] = []
        lumas.reserveCapacity((patchW + patchH) * 2)
        if hasTop { for c in topEdge { lumas.append(0.299 * c.0 + 0.587 * c.1 + 0.114 * c.2) } }
        if hasBottom { for c in bottomEdge { lumas.append(0.299 * c.0 + 0.587 * c.1 + 0.114 * c.2) } }
        if hasLeft { for c in leftEdge { lumas.append(0.299 * c.0 + 0.587 * c.1 + 0.114 * c.2) } }
        if hasRight { for c in rightEdge { lumas.append(0.299 * c.0 + 0.587 * c.1 + 0.114 * c.2) } }

        let grainAmplitude: Double = {
            guard lumas.count >= 8 else { return 0 }
            var diffSum = 0.0
            for idx in 1..<lumas.count {
                diffSum += min(abs(lumas[idx] - lumas[idx - 1]), 12.0)
            }
            let avgStep = diffSum / Double(lumas.count - 1)
            return avgStep < 1.5 ? 0 : min(avgStep * 0.45, 4.5)
        }()

        let outBuf = patchData.assumingMemoryBound(to: UInt8.self)
        let outStride = patchCtx.bytesPerRow

        for j in 0..<patchH {
            let dTop = Double(j + 1)
            let dBot = Double(patchH - j)
            let wTop = hasTop ? 1.0 / (dTop * dTop) : 0.0
            let wBot = hasBottom ? 1.0 / (dBot * dBot) : 0.0
            let lColor = leftEdge[j]
            let rColor = rightEdge[j]

            for i in 0..<patchW {
                let dLeft = Double(i + 1)
                let dRight = Double(patchW - i)
                let wLeft = hasLeft ? 1.0 / (dLeft * dLeft) : 0.0
                let wRight = hasRight ? 1.0 / (dRight * dRight) : 0.0
                let wSum = wTop + wBot + wLeft + wRight

                var r = 242.0, g = 242.0, b = 242.0
                if wSum > 0 {
                    let tColor = topEdge[i]
                    let bColor = bottomEdge[i]
                    r = (tColor.0 * wTop + bColor.0 * wBot + lColor.0 * wLeft + rColor.0 * wRight) / wSum
                    g = (tColor.1 * wTop + bColor.1 * wBot + lColor.1 * wLeft + rColor.1 * wRight) / wSum
                    b = (tColor.2 * wTop + bColor.2 * wBot + lColor.2 * wLeft + rColor.2 * wRight) / wSum
                }

                if grainAmplitude > 0 {
                    let seed = ((x0 + i) &* 374761393) ^ ((y0 + j) &* 668265263)
                    let mixed = (seed ^ (seed >> 13)) &* 1274126177
                    let noise = (Double(mixed & 0xFF) / 255.0 - 0.5) * 2.0 * grainAmplitude
                    r += noise; g += noise; b += noise
                }

                let dst = outBuf + j * outStride + i * 4
                dst[0] = UInt8(min(max(Int(r.rounded()), 0), 255))
                dst[1] = UInt8(min(max(Int(g.rounded()), 0), 255))
                dst[2] = UInt8(min(max(Int(b.rounded()), 0), 255))
                dst[3] = 255
            }
        }

        guard let erasedImage = patchCtx.makeImage() else { return }

        context.saveGState()
        context.addPath(path)
        context.clip()
        context.interpolationQuality = .high
        context.translateBy(x: CGFloat(x0), y: CGFloat(y1))
        context.scaleBy(x: 1, y: -1)
        context.draw(erasedImage, in: CGRect(x: 0, y: 0, width: CGFloat(patchW), height: CGFloat(patchH)))
        context.restoreGState()
    }

    static func sampledBackgroundColor(around rect: CGRect, in context: CGContext, width: Int, height: Int) -> CGColor {
        let fallback = CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                               components: [0.95, 0.95, 0.95, 1])!
        guard let data = context.data, width > 0, height > 0 else { return fallback }
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        let stride = context.bytesPerRow

        let x0 = max(0, min(width - 1, Int(rect.minX.rounded(.down))))
        let x1 = max(0, min(width - 1, Int(rect.maxX.rounded(.up))))
        let y0 = max(0, min(height - 1, Int(rect.minY.rounded(.down))))
        let y1 = max(0, min(height - 1, Int(rect.maxY.rounded(.up))))

        let topY = max(0, y0 - 2)
        let botY = min(height - 1, y1 + 2)
        let leftX = max(0, x0 - 2)
        let rightX = min(width - 1, x1 + 2)

        var rs: [UInt8] = []
        var gs: [UInt8] = []
        var bs: [UInt8] = []

        func sample(_ x: Int, _ y: Int) {
            let p = pixels + y * stride + x * 4
            rs.append(p[0]); gs.append(p[1]); bs.append(p[2])
        }

        let stepX = max(1, (x1 - x0) / 24)
        for x in Swift.stride(from: x0, through: x1, by: stepX) {
            sample(x, topY)
            sample(x, botY)
        }
        let stepY = max(1, (y1 - y0) / 16)
        for y in Swift.stride(from: y0, through: y1, by: stepY) {
            sample(leftX, y)
            sample(rightX, y)
        }

        guard !rs.isEmpty else { return fallback }
        rs.sort(); gs.sort(); bs.sort()
        let mid = rs.count / 2
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        return CGColor(
            colorSpace: space,
            components: [CGFloat(rs[mid]) / 255, CGFloat(gs[mid]) / 255, CGFloat(bs[mid]) / 255, 1]
        ) ?? fallback
    }

    // MARK: - Emoji Sticker Cover

    /// Permanently conceals underlying pixels with the surrounding background color first, then
    /// stamps crisp centered/tiled Emoji stickers so no sensitive strokes can ever peek past the edges.
    private static func drawEmojiCover(
        from image: CGImage,
        rect: CGRect,
        path: CGPath,
        emoji: String,
        into context: CGContext
    ) {
        let bounds = rect.intersection(CGRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height)))
        guard bounds.width >= 2, bounds.height >= 2 else { return }

        // 1. Seamless magic-erase backing guarantees zero pixel leakage AND smooth blending under emoji.
        magicErase(from: image, rect: bounds, path: path, into: context)

        context.saveGState()
        context.addPath(path)
        context.clip()

        // 2. Render crisp emoji stamp(s) scaled cleanly to box height.
        let symbol = emoji.isEmpty ? EmojiPreset.default : emoji
        let fontSize = max(12, min(bounds.width, bounds.height) * 0.78)
        let font = CTFontCreateWithName("AppleColorEmoji" as CFString, fontSize, nil)
        let attr = NSAttributedString(string: symbol, attributes: [kCTFontAttributeName as NSAttributedString.Key: font])
        let line = CTLineCreateWithAttributedString(attr)
        let glyphBounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)

        // Repeat cleanly across wide horizontal text bars; center single emoji on faces/squares.
        let spacing = max(glyphBounds.width * 1.15, fontSize * 1.1)
        let count = bounds.width > bounds.height * 1.9 ? max(1, Int((bounds.width / spacing).rounded(.down))) : 1
        let step = bounds.width / CGFloat(count)

        // Flip locally back to upright CoreText coordinate space (y-up).
        context.translateBy(x: 0, y: bounds.minY + bounds.maxY)
        context.scaleBy(x: 1, y: -1)
        for index in 0..<count {
            let cx = bounds.minX + (CGFloat(index) + 0.5) * step
            let cy = bounds.midY
            let x = cx - glyphBounds.width / 2 - glyphBounds.origin.x
            let y = cy - glyphBounds.height / 2 - glyphBounds.origin.y
            context.textPosition = CGPoint(x: x, y: y)
            CTLineDraw(line, context)
        }
        context.restoreGState()
    }

    // MARK: - Anti-Theft Diagonal Watermark

    /// Draws tiled diagonal anti-theft watermark text across the entire image in standard CG coordinates.
    static func drawWatermark(in context: CGContext, size: CGSize, options: WatermarkOptions) {
        let trimmed = options.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard options.isEnabled, !trimmed.isEmpty, size.width > 0, size.height > 0 else { return }

        let shortSide = min(size.width, size.height)
        let fontSize = max(14, (shortSide * 0.036).rounded())
        let color = options.tint.uiColor(alpha: CGFloat(options.opacity))
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
        ]
        let attrString = NSAttributedString(string: trimmed, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrString)
        let textBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        let textWidth = max(textBounds.width, fontSize * 2)

        let stepX = textWidth + fontSize * options.density.columnGapFactor
        let stepY = fontSize * options.density.rowSpacingFactor
        let diagonal = hypot(size.width, size.height)

        context.saveGState()
        context.translateBy(x: size.width / 2, y: size.height / 2)
        context.rotate(by: .pi / 6) // +30° in y-up CG space = visually -30° rising bottom-left to top-right

        var row = 0
        var y = -diagonal / 2
        while y <= diagonal / 2 {
            let stagger = (row % 2 == 0) ? 0 : stepX / 2
            var x = -diagonal / 2 - stagger
            while x <= diagonal / 2 {
                context.textPosition = CGPoint(x: x, y: y)
                CTLineDraw(line, context)
                x += stepX
            }
            y += stepY
            row += 1
        }
        context.restoreGState()
    }

    // MARK: - Cell Averaging

    private static func fillGrains(_ grains: UnsafeMutablePointer<UInt8>, grainStride: Int,
                                   from picture: UnsafePointer<UInt8>, stride: Int,
                                   bounds: CGRect, columns: Int, rows: Int) {
        let across = bounds.width / CGFloat(columns), up = bounds.height / CGFloat(rows)
        for row in 0..<rows {
            let top = bounds.minY + CGFloat(row) * up
            let from = Int((top - 0.5).rounded(.up)), under = Int((top + up - 0.5).rounded(.up))
            for column in 0..<columns {
                let left = bounds.minX + CGFloat(column) * across
                let first = Int((left - 0.5).rounded(.up)), past = Int((left + across - 0.5).rounded(.up))
                var red = 0, green = 0, blue = 0, alpha = 0
                for y in from..<under {
                    var pixel = picture + y * stride + first * 4
                    for _ in first..<past {
                        red += Int(pixel[0]); green += Int(pixel[1]); blue += Int(pixel[2]); alpha += Int(pixel[3])
                        pixel += 4
                    }
                }
                let count = max(1, (under - from) * (past - first))
                let grain = grains + row * grainStride + column * 4
                for (component, sum) in [red, green, blue, alpha].enumerated() {
                    grain[component] = UInt8((sum + count / 2) / count)
                }
            }
        }
    }

    static func quadPath(_ quad: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = quad.first else { return path }
        path.move(to: first)
        for p in quad.dropFirst() { path.addLine(to: p) }
        path.closeSubpath()
        return path
    }
}
