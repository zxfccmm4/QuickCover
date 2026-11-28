import CoreGraphics
import CoreImage
import CoreText
import Foundation
import ImageIO
import UIKit

/// Top-level Apple product categories available in `DeviceFrameStudioView`.
enum DeviceCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case none
    case iPhone
    case iPad
    case macBook
    case iMac
    case macMini
    case macStudio
    case appleWatch
    case appleTV

    var id: String { rawValue }

    var titleKey: String { "frame.cat.\(rawValue)" }

    var systemImage: String {
        switch self {
        case .none: "photo"
        case .iPhone: "iphone"
        case .iPad: "ipad"
        case .macBook: "laptopcomputer"
        case .iMac: "desktopcomputer"
        case .macMini: "macmini"
        case .macStudio: "macstudio"
        case .appleWatch: "applewatch"
        case .appleTV: "appletv"
        }
    }

    var models: [AppleDeviceModel] {
        AppleDeviceModel.allCases.filter { $0.category == self }
    }
}

/// Specific selectable Apple 2026 hardware models across all 8 product lines (29 models).
enum AppleDeviceModel: String, CaseIterable, Identifiable, Codable, Sendable {
    // iPhone (2026 Lineup)
    case iPhone18ProMax
    case iPhone18Pro
    case iPhoneDuo
    case iPhoneAir
    case iPhone17
    case iPhone17e

    // iPad (2026 Lineup)
    case iPadPro13M5
    case iPadPro11M5
    case iPadAir13M4
    case iPadAir11M4
    case iPadMiniOLED
    case iPadA16

    // MacBook (2026 Lineup)
    case macBookPro16M5Max
    case macBookPro14M6
    case macBookAir15M5
    case macBookAir13M5
    case macBookNeo13

    // iMac & Studio Display (2026 Lineup)
    case iMac24M4
    case studioDisplay2026

    // Mac mini (2026 Lineup)
    case macMiniM6Studio
    case macMiniM5ProXDR

    // Mac Studio (2026 Lineup)
    case macStudioM5Max
    case macStudioM5Ultra

    // Apple Watch & Apple Watch Ultra (2026 Lineup)
    case watchUltra4
    case watchSeries12_46
    case watchSeries12_42
    case watchSE3

    // Apple TV (2026 Lineup)
    case appleTV4KGen4
    case appleTV4KStudio

    var id: String { rawValue }

    var category: DeviceCategory {
        switch self {
        case .iPhone18ProMax, .iPhone18Pro, .iPhoneDuo, .iPhoneAir, .iPhone17, .iPhone17e:
            .iPhone
        case .iPadPro13M5, .iPadPro11M5, .iPadAir13M4, .iPadAir11M4, .iPadMiniOLED, .iPadA16:
            .iPad
        case .macBookPro16M5Max, .macBookPro14M6, .macBookAir15M5, .macBookAir13M5, .macBookNeo13:
            .macBook
        case .iMac24M4, .studioDisplay2026:
            .iMac
        case .macMiniM6Studio, .macMiniM5ProXDR:
            .macMini
        case .macStudioM5Max, .macStudioM5Ultra:
            .macStudio
        case .watchUltra4, .watchSeries12_46, .watchSeries12_42, .watchSE3:
            .appleWatch
        case .appleTV4KGen4, .appleTV4KStudio:
            .appleTV
        }
    }

    /// Official Apple product name (consistent globally across languages).
    var displayName: String {
        switch self {
        case .iPhone18ProMax: "iPhone 18 Pro Max"
        case .iPhone18Pro: "iPhone 18 Pro"
        case .iPhoneDuo: "iPhone Duo"
        case .iPhoneAir: "iPhone Air"
        case .iPhone17: "iPhone 17"
        case .iPhone17e: "iPhone 17e"
        case .iPadPro13M5: "iPad Pro 13\" (M5)"
        case .iPadPro11M5: "iPad Pro 11\" (M5)"
        case .iPadAir13M4: "iPad Air 13\" (M4)"
        case .iPadAir11M4: "iPad Air 11\" (M4)"
        case .iPadMiniOLED: "iPad mini (OLED)"
        case .iPadA16: "iPad (A16)"
        case .macBookPro16M5Max: "MacBook Pro 16\""
        case .macBookPro14M6: "MacBook Pro 14\""
        case .macBookAir15M5: "MacBook Air 15\""
        case .macBookAir13M5: "MacBook Air 13\""
        case .macBookNeo13: "MacBook Neo 13\""
        case .iMac24M4: "iMac 24\" (M4)"
        case .studioDisplay2026: "Studio Display (2026)"
        case .macMiniM6Studio: "Mac mini (M6)"
        case .macMiniM5ProXDR: "Mac mini (M5 Pro)"
        case .macStudioM5Max: "Mac Studio (M5 Max)"
        case .macStudioM5Ultra: "Mac Studio (M5 Ultra)"
        case .watchUltra4: "Apple Watch Ultra 4"
        case .watchSeries12_46: "Watch Series 12 46mm"
        case .watchSeries12_42: "Watch Series 12 42mm"
        case .watchSE3: "Apple Watch SE 3"
        case .appleTV4KGen4: "Apple TV 4K (4th Gen)"
        case .appleTV4KStudio: "Apple TV 4K + Studio"
        }
    }

    /// Compact spec tag shown beneath the model name in the picker card.
    var specTag: String {
        switch self {
        case .iPhone18ProMax: "6.9\" · A20 Pro"
        case .iPhone18Pro: "6.3\" · A20 Pro"
        case .iPhoneDuo: "7.6\" · Foldable"
        case .iPhoneAir: "6.6\" · Ultra-Thin"
        case .iPhone17: "6.3\" · A19"
        case .iPhone17e: "6.1\" · A19"
        case .iPadPro13M5: "M5 · Tandem OLED"
        case .iPadPro11M5: "M5 · Tandem OLED"
        case .iPadAir13M4: "M4 · Pastel"
        case .iPadAir11M4: "M4 · Pastel"
        case .iPadMiniOLED: "8.3\" · 5.4mm OLED"
        case .iPadA16: "11\" · Colorful"
        case .macBookPro16M5Max: "M5 Max · PROLED XDR"
        case .macBookPro14M6: "M6 · PROLED XDR"
        case .macBookAir15M5: "M5 · Slim Deck"
        case .macBookAir13M5: "M5 · Portable"
        case .macBookNeo13: "13\" · Vibrant Colors"
        case .iMac24M4: "4.5K · 7 Colors"
        case .studioDisplay2026: "27\" · 5K · TB5"
        case .macMiniM6Studio: "+ Studio Display"
        case .macMiniM5ProXDR: "+ Pro Display XDR"
        case .macStudioM5Max: "+ Studio Display"
        case .macStudioM5Ultra: "+ Pro Display XDR"
        case .watchUltra4: "49mm · Grade 5 Ti"
        case .watchSeries12_46: "46mm · Wide OLED"
        case .watchSeries12_42: "42mm · Wide OLED"
        case .watchSE3: "44mm · S10"
        case .appleTV4KGen4: "A19 · Siri AI + OLED"
        case .appleTV4KStudio: "A19 · Studio Display"
        }
    }

    var systemImage: String { category.systemImage }

    var availableFinishes: [DeviceFinish] {
        switch self {
        case .iPhone18ProMax, .iPhone18Pro:
            [.spaceBlack, .silver, .glacier, .burgundy]
        case .iPhoneDuo:
            [.starWhite, .nightSky]
        case .iPhoneAir:
            [.silver, .spaceBlack, .skyBlue, .gold]
        case .iPhone17:
            [.spaceBlack, .silver, .blue, .mint, .rose]
        case .iPhone17e:
            [.spaceBlack, .silver, .starlight]
        case .iPadPro13M5, .iPadPro11M5:
            [.spaceBlack, .silver]
        case .iPadAir13M4, .iPadAir11M4, .iPadMiniOLED:
            [.spaceBlack, .silver, .blue, .purple, .starlight]
        case .iPadA16:
            [.silver, .blue, .rose, .yellow]
        case .macBookPro16M5Max, .macBookPro14M6:
            [.spaceBlack, .silver]
        case .macBookAir15M5, .macBookAir13M5:
            [.midnight, .starlight, .silver, .skyBlue]
        case .macBookNeo13:
            [.blush, .citrus, .indigo, .silver]
        case .iMac24M4:
            [.silver, .blue, .mint, .rose, .yellow, .orange, .purple]
        case .studioDisplay2026, .macMiniM6Studio, .macMiniM5ProXDR, .macStudioM5Max, .macStudioM5Ultra, .appleTV4KStudio:
            [.silver]
        case .watchUltra4:
            [.naturalTitanium, .blackTitanium]
        case .watchSeries12_46, .watchSeries12_42:
            [.spaceBlack, .silver, .rose, .gold, .glacier]
        case .watchSE3:
            [.midnight, .starlight, .silver]
        case .appleTV4KGen4:
            [.spaceBlack, .silver]
        }
    }
}

/// Official Apple 2026 hardware enclosure finishes.
enum DeviceFinish: String, CaseIterable, Identifiable, Codable, Sendable {
    case blackTitanium
    case naturalTitanium
    case desertTitanium
    case spaceBlack
    case silver
    case midnight
    case starlight
    case skyBlue
    case gold
    case blue
    case mint
    case rose
    case yellow
    case orange
    case purple
    case red
    case glacier
    case burgundy
    case starWhite
    case nightSky
    case blush
    case citrus
    case indigo

    var id: String { rawValue }

    var titleKey: String { "frame.finish.\(rawValue)" }

    var primaryRGB: (CGFloat, CGFloat, CGFloat) {
        switch self {
        case .blackTitanium: (0.16, 0.16, 0.18)
        case .naturalTitanium: (0.66, 0.64, 0.60)
        case .desertTitanium: (0.77, 0.67, 0.57)
        case .spaceBlack: (0.18, 0.19, 0.21)
        case .silver: (0.84, 0.85, 0.87)
        case .midnight: (0.16, 0.20, 0.27)
        case .starlight: (0.88, 0.85, 0.80)
        case .skyBlue: (0.69, 0.79, 0.88)
        case .gold: (0.84, 0.75, 0.58)
        case .blue: (0.43, 0.60, 0.78)
        case .mint: (0.44, 0.69, 0.63)
        case .rose: (0.86, 0.55, 0.60)
        case .yellow: (0.91, 0.80, 0.44)
        case .orange: (0.91, 0.55, 0.37)
        case .purple: (0.58, 0.55, 0.78)
        case .red: (0.78, 0.18, 0.22)
        case .glacier: (0.74, 0.84, 0.90)
        case .burgundy: (0.47, 0.16, 0.22)
        case .starWhite: (0.93, 0.93, 0.91)
        case .nightSky: (0.14, 0.19, 0.30)
        case .blush: (0.94, 0.72, 0.75)
        case .citrus: (0.91, 0.86, 0.42)
        case .indigo: (0.31, 0.35, 0.71)
        }
    }

    var highlightRGB: (CGFloat, CGFloat, CGFloat) {
        let (r, g, b) = primaryRGB
        return (min(1, r + 0.14), min(1, g + 0.14), min(1, b + 0.14))
    }

    var shadowRGB: (CGFloat, CGFloat, CGFloat) {
        let (r, g, b) = primaryRGB
        return (max(0, r - 0.17), max(0, g - 0.17), max(0, b - 0.17))
    }

    var cgColor: CGColor {
        let (r, g, b) = primaryRGB
        return CGColor(
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            components: [r, g, b, 1]
        )!
    }
}

/// App Store-inspired promotional presentation directions & layout templates.
enum DeviceShowcaseTemplate: String, CaseIterable, Identifiable, Codable, Sendable {
    case centered
    case tiltLeft
    case tiltRight
    case perspectiveLeft
    case perspectiveRight
    case heroTopTitle
    case bottomBleed
    case topBleed
    case duoFloat

    var id: String { rawValue }

    var titleKey: String { "frame.tpl.\(rawValue)" }

    var systemImage: String {
        switch self {
        case .centered: "rectangle.portrait"
        case .tiltLeft: "rotate.left"
        case .tiltRight: "rotate.right"
        case .perspectiveLeft: "cube"
        case .perspectiveRight: "cube.fill"
        case .heroTopTitle: "textformat.size"
        case .bottomBleed: "rectangle.bottomthird.inset.filled"
        case .topBleed: "rectangle.topthird.inset.filled"
        case .duoFloat: "rectangle.on.rectangle.angled"
        }
    }
}

/// Type of studio background behind the framed device or frameless canvas when `showsBackground` is enabled.
enum DeviceBackdropKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case gradient
    case solidColor
    case customImage
    case adaptiveBlur

    var id: String { rawValue }

    var titleKey: String { "frame.bgKind.\(rawValue)" }
}

/// Direction & geometry for preset and custom-synthesized background gradients.
enum GradientDirection: String, CaseIterable, Identifiable, Codable, Sendable {
    case diagonalDown
    case diagonalUp
    case vertical
    case horizontal
    case radial

    var id: String { rawValue }

    var titleKey: String { "frame.gradDir.\(rawValue)" }

    var systemImage: String {
        switch self {
        case .diagonalDown: "arrow.down.right"
        case .diagonalUp: "arrow.up.right"
        case .vertical: "arrow.down"
        case .horizontal: "arrow.right"
        case .radial: "circle.circle"
        }
    }
}

/// Equatable wrapper holding a user-selected custom backdrop `CGImage`.
struct CustomBackdropImage: Equatable, Sendable {
    let id: UUID
    let image: CGImage

    init(id: UUID = UUID(), image: CGImage) {
        self.id = id
        self.image = image
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

/// Curated studio gradients inspired by Apple marketing & App Store showcase banners.
enum DeviceGradientPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case mist
    case ocean
    case sunset
    case aurora
    case lavender
    case peach
    case emerald
    case obsidian

    var id: String { rawValue }

    var titleKey: String { "frame.grad.\(rawValue)" }

    var stops: [(CGFloat, CGFloat, CGFloat)] {
        switch self {
        case .mist:
            [(0.89, 0.92, 0.97), (0.95, 0.94, 0.98)]
        case .ocean:
            [(0.11, 0.36, 0.74), (0.14, 0.68, 0.86)]
        case .sunset:
            [(0.98, 0.55, 0.38), (0.86, 0.27, 0.54)]
        case .aurora:
            [(0.18, 0.14, 0.45), (0.12, 0.56, 0.65), (0.28, 0.80, 0.62)]
        case .lavender:
            [(0.74, 0.66, 0.96), (0.95, 0.74, 0.88)]
        case .peach:
            [(0.99, 0.84, 0.72), (0.97, 0.67, 0.64)]
        case .emerald:
            [(0.07, 0.40, 0.38), (0.22, 0.72, 0.58)]
        case .obsidian:
            [(0.08, 0.09, 0.12), (0.18, 0.20, 0.26)]
        }
    }

    var isDark: Bool {
        switch self {
        case .obsidian, .aurora, .ocean, .emerald: true
        case .mist, .sunset, .lavender, .peach: false
        }
    }
}

/// Output canvas aspect ratio when a studio background is shown.
enum DeviceCanvasAspect: String, CaseIterable, Identifiable, Codable, Sendable {
    case auto
    case square1x1
    case portrait4x5
    case portrait3x4
    case landscape16x9
    case story9x16

    var id: String { rawValue }

    var titleKey: String { "frame.aspect.\(rawValue)" }

    var ratio: CGFloat? {
        switch self {
        case .auto: nil
        case .square1x1: 1.0
        case .portrait4x5: 4.0 / 5.0
        case .portrait3x4: 3.0 / 4.0
        case .landscape16x9: 16.0 / 9.0
        case .story9x16: 9.0 / 16.0
        }
    }
}

/// Complete post-redaction Apple device framing, App Store template, background, and scaling config.
struct DeviceFrameOptions: Equatable, Sendable {
    var model: AppleDeviceModel? = nil
    var finish: DeviceFinish = .spaceBlack
    var template: DeviceShowcaseTemplate = .centered
    var heroTitle: String = ""
    var heroSubtitle: String = ""
    /// When `false`, exports a tight-cropped transparent PNG of the hardware frame or cutout with zero backdrop.
    var showsBackground: Bool = true
    var backdropKind: DeviceBackdropKind = .gradient
    var gradientPreset: DeviceGradientPreset = .mist
    var solidBackgroundColor: CustomColorRGB = CustomColorRGB(red: 0.95, green: 0.96, blue: 0.98)
    var canvasAspect: DeviceCanvasAspect = .auto
    /// Scales the hardware device or frameless cutout inside the studio background canvas (`0.50...1.00`).
    var deviceScale: Double = 0.86
    /// Scales the final post-frame output pixel resolution (`0.40...1.00`) with or without background.
    var outputScale: Double = 1.0
    var showsShadow: Bool = true

    /// Enables full studio background, corner rounding, shadow, and templates even without an Apple hardware frame.
    var enableFramelessBackdrop: Bool = false
    /// Corner radius ratio (`0.00...0.16`) applied to the screenshot when `enableFramelessBackdrop` is active without a frame.
    var framelessCornerRadius: Double = 0.045
    /// Uses custom multi-stop gradient stops (`customGradientStart` / optional `customGradientMid` / `customGradientEnd`).
    var usesCustomGradient: Bool = false
    var customGradientStart: CustomColorRGB = CustomColorRGB(red: 0.24, green: 0.48, blue: 0.98)
    var customGradientMid: CustomColorRGB? = nil
    var customGradientEnd: CustomColorRGB = CustomColorRGB(red: 0.88, green: 0.34, blue: 0.72)
    var gradientDirection: GradientDirection = .diagonalDown
    /// User-imported custom image for `.customImage` backdrop compositing.
    var customBackgroundImage: CustomBackdropImage? = nil
    var customImageBlur: Double = 0.0
    var customImageDim: Double = 0.0

    var isActive: Bool { model != nil }

    /// True whenever either an Apple device mockup OR frameless studio backdrop/layout is enabled.
    var isStudioCanvasActive: Bool { model != nil || enableFramelessBackdrop }

    var category: DeviceCategory { model?.category ?? .none }

    /// Transparent cutout without studio background requires PNG alpha preservation.
    var needsPNG: Bool { isStudioCanvasActive && !showsBackground }

    /// Guarantees the chosen finish is valid for the active Apple device model.
    var resolvedFinish: DeviceFinish {
        guard let model else { return finish }
        let allowed = model.availableFinishes
        if allowed.contains(finish) { return finish }
        return allowed.first ?? .silver
    }

    /// Active gradient RGB stops (either user-synthesized 2/3-stop mix or curated preset).
    var activeGradientStops: [(CGFloat, CGFloat, CGFloat)] {
        if usesCustomGradient {
            var stops: [(CGFloat, CGFloat, CGFloat)] = [customGradientStart.rgba]
            if let mid = customGradientMid {
                stops.append(mid.rgba)
            }
            stops.append(customGradientEnd.rgba)
            return stops
        }
        return gradientPreset.stops
    }

    /// Estimates whether the rendered background is dark so captions and badges choose high contrast.
    var hasDarkBackground: Bool {
        guard showsBackground else { return false }
        switch backdropKind {
        case .gradient:
            if usesCustomGradient {
                let stops = activeGradientStops
                let avgLuma = stops.reduce(0.0) {
                    $0 + (0.299 * Double($1.0) + 0.587 * Double($1.1) + 0.114 * Double($1.2))
                } / Double(max(stops.count, 1))
                return avgLuma < 0.50
            }
            return gradientPreset.isDark
        case .solidColor:
            let luma = 0.299 * solidBackgroundColor.red + 0.587 * solidBackgroundColor.green + 0.114 * solidBackgroundColor.blue
            return luma < 0.48
        case .customImage:
            if let img = customBackgroundImage?.image, let tiny = CGImage.rgbaContext(width: 4, height: 4), let ptr = tiny.data {
                tiny.interpolationQuality = .low
                tiny.draw(img, in: CGRect(x: 0, y: 0, width: 4, height: 4))
                let bytes = ptr.assumingMemoryBound(to: UInt8.self)
                var sum = 0.0
                for idx in 0..<16 {
                    let base = idx * 4
                    let r = Double(bytes[base]) / 255.0
                    let g = Double(bytes[base + 1]) / 255.0
                    let b = Double(bytes[base + 2]) / 255.0
                    sum += 0.299 * r + 0.587 * g + 0.114 * b
                }
                let effective = (sum / 16.0) * (1.0 - min(max(customImageDim, 0), 0.7))
                return effective < 0.48
            }
            return customImageDim >= 0.22
        case .adaptiveBlur:
            return false
        }
    }

    static let none = DeviceFrameOptions()

    /// Expanded 18-swatch studio color palette organized across neutrals, soft pastels, and vivid/dark tones.
    static let solidSwatches: [CustomColorRGB] = [
        // Neutrals & Warm Whites
        CustomColorRGB(red: 1.00, green: 1.00, blue: 1.00),
        CustomColorRGB(red: 0.96, green: 0.96, blue: 0.98),
        CustomColorRGB(red: 0.94, green: 0.91, blue: 0.86),
        CustomColorRGB(red: 0.85, green: 0.87, blue: 0.90),
        CustomColorRGB(red: 0.16, green: 0.17, blue: 0.20),
        CustomColorRGB(red: 0.05, green: 0.05, blue: 0.07),
        // Soft Pastels
        CustomColorRGB(red: 0.86, green: 0.93, blue: 1.00),
        CustomColorRGB(red: 0.91, green: 0.87, blue: 0.99),
        CustomColorRGB(red: 0.99, green: 0.88, blue: 0.91),
        CustomColorRGB(red: 0.99, green: 0.95, blue: 0.82),
        CustomColorRGB(red: 0.85, green: 0.95, blue: 0.88),
        CustomColorRGB(red: 0.83, green: 0.95, blue: 0.94),
        // Vivid & Studio Deep Tones
        CustomColorRGB(red: 0.05, green: 0.48, blue: 0.98),
        CustomColorRGB(red: 0.35, green: 0.34, blue: 0.84),
        CustomColorRGB(red: 0.69, green: 0.32, blue: 0.87),
        CustomColorRGB(red: 0.96, green: 0.24, blue: 0.42),
        CustomColorRGB(red: 0.98, green: 0.47, blue: 0.22),
        CustomColorRGB(red: 0.11, green: 0.66, blue: 0.48),
    ]

    /// Curated 2/3-stop gradient recipes for 1-tap gradient mixing inspiration.
    static let customGradientRecipes: [(CustomColorRGB, CustomColorRGB?, CustomColorRGB)] = [
        (CustomColorRGB(red: 0.24, green: 0.48, blue: 0.98), CustomColorRGB(red: 0.66, green: 0.38, blue: 0.95), CustomColorRGB(red: 0.97, green: 0.38, blue: 0.66)),
        (CustomColorRGB(red: 0.09, green: 0.72, blue: 0.68), nil, CustomColorRGB(red: 0.16, green: 0.35, blue: 0.88)),
        (CustomColorRGB(red: 0.99, green: 0.74, blue: 0.48), CustomColorRGB(red: 0.98, green: 0.45, blue: 0.56), CustomColorRGB(red: 0.64, green: 0.34, blue: 0.88)),
        (CustomColorRGB(red: 0.93, green: 0.95, blue: 1.00), nil, CustomColorRGB(red: 0.84, green: 0.89, blue: 0.98)),
        (CustomColorRGB(red: 0.07, green: 0.09, blue: 0.16), CustomColorRGB(red: 0.15, green: 0.24, blue: 0.46), CustomColorRGB(red: 0.09, green: 0.44, blue: 0.52)),
        (CustomColorRGB(red: 0.99, green: 0.89, blue: 0.92), CustomColorRGB(red: 0.95, green: 0.91, blue: 0.99), CustomColorRGB(red: 0.86, green: 0.95, blue: 0.99)),
    ]
}

extension DeviceFrameOptions: Codable {
    private enum CodingKeys: String, CodingKey {
        case model, finish, template, heroTitle, heroSubtitle
        case showsBackground, backdropKind, gradientPreset, solidBackgroundColor
        case canvasAspect, deviceScale, outputScale, showsShadow
        case enableFramelessBackdrop, framelessCornerRadius
        case usesCustomGradient, customGradientStart, customGradientMid, customGradientEnd, gradientDirection
        case customImageBlur, customImageDim
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        model = try c.decodeIfPresent(AppleDeviceModel.self, forKey: .model)
        finish = try c.decodeIfPresent(DeviceFinish.self, forKey: .finish) ?? .spaceBlack
        template = try c.decodeIfPresent(DeviceShowcaseTemplate.self, forKey: .template) ?? .centered
        heroTitle = try c.decodeIfPresent(String.self, forKey: .heroTitle) ?? ""
        heroSubtitle = try c.decodeIfPresent(String.self, forKey: .heroSubtitle) ?? ""
        showsBackground = try c.decodeIfPresent(Bool.self, forKey: .showsBackground) ?? true
        backdropKind = try c.decodeIfPresent(DeviceBackdropKind.self, forKey: .backdropKind) ?? .gradient
        gradientPreset = try c.decodeIfPresent(DeviceGradientPreset.self, forKey: .gradientPreset) ?? .mist
        solidBackgroundColor = try c.decodeIfPresent(CustomColorRGB.self, forKey: .solidBackgroundColor)
            ?? CustomColorRGB(red: 0.95, green: 0.96, blue: 0.98)
        canvasAspect = try c.decodeIfPresent(DeviceCanvasAspect.self, forKey: .canvasAspect) ?? .auto
        deviceScale = try c.decodeIfPresent(Double.self, forKey: .deviceScale) ?? 0.86
        outputScale = try c.decodeIfPresent(Double.self, forKey: .outputScale) ?? 1.0
        showsShadow = try c.decodeIfPresent(Bool.self, forKey: .showsShadow) ?? true
        enableFramelessBackdrop = try c.decodeIfPresent(Bool.self, forKey: .enableFramelessBackdrop) ?? false
        framelessCornerRadius = try c.decodeIfPresent(Double.self, forKey: .framelessCornerRadius) ?? 0.045
        usesCustomGradient = try c.decodeIfPresent(Bool.self, forKey: .usesCustomGradient) ?? false
        customGradientStart = try c.decodeIfPresent(CustomColorRGB.self, forKey: .customGradientStart)
            ?? CustomColorRGB(red: 0.24, green: 0.48, blue: 0.98)
        customGradientMid = try c.decodeIfPresent(CustomColorRGB.self, forKey: .customGradientMid)
        customGradientEnd = try c.decodeIfPresent(CustomColorRGB.self, forKey: .customGradientEnd)
            ?? CustomColorRGB(red: 0.88, green: 0.34, blue: 0.72)
        gradientDirection = try c.decodeIfPresent(GradientDirection.self, forKey: .gradientDirection) ?? .diagonalDown
        customBackgroundImage = nil
        customImageBlur = try c.decodeIfPresent(Double.self, forKey: .customImageBlur) ?? 0.0
        customImageDim = try c.decodeIfPresent(Double.self, forKey: .customImageDim) ?? 0.0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(model, forKey: .model)
        try c.encode(finish, forKey: .finish)
        try c.encode(template, forKey: .template)
        try c.encode(heroTitle, forKey: .heroTitle)
        try c.encode(heroSubtitle, forKey: .heroSubtitle)
        try c.encode(showsBackground, forKey: .showsBackground)
        try c.encode(backdropKind, forKey: .backdropKind)
        try c.encode(gradientPreset, forKey: .gradientPreset)
        try c.encode(solidBackgroundColor, forKey: .solidBackgroundColor)
        try c.encode(canvasAspect, forKey: .canvasAspect)
        try c.encode(deviceScale, forKey: .deviceScale)
        try c.encode(outputScale, forKey: .outputScale)
        try c.encode(showsShadow, forKey: .showsShadow)
        try c.encode(enableFramelessBackdrop, forKey: .enableFramelessBackdrop)
        try c.encode(framelessCornerRadius, forKey: .framelessCornerRadius)
        try c.encode(usesCustomGradient, forKey: .usesCustomGradient)
        try c.encode(customGradientStart, forKey: .customGradientStart)
        try c.encodeIfPresent(customGradientMid, forKey: .customGradientMid)
        try c.encode(customGradientEnd, forKey: .customGradientEnd)
        try c.encode(gradientDirection, forKey: .gradientDirection)
        try c.encode(customImageBlur, forKey: .customImageBlur)
        try c.encode(customImageDim, forKey: .customImageDim)
    }
}

/// High-precision procedural Apple hardware mockup compositor built on CoreGraphics + CoreImage.
/// Stage 1 renders any of the 29 concrete 2026 Apple devices onto a tight transparent cutout.
/// Stage 2 applies directional & App Store showcase templates (tilts, 3D perspective, hero headers,
/// bleed crops, duo cascade), customizable studio backgrounds, silhouette shadows, post-frame
/// scaling, and watermarks.
enum DeviceFrameRenderer {

    private static let sRGB = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    static func render(
        screen: CGImage,
        options: DeviceFrameOptions,
        watermark: WatermarkOptions = .off,
        targetAspectOverride: CGFloat? = nil
    ) -> CGImage {
        let cutout: CGImage
        let modelName: String?
        if let model = options.model {
            cutout = renderHardwareCutout(screen: screen, model: model, finish: options.resolvedFinish)
            modelName = model.displayName
        } else if options.enableFramelessBackdrop {
            cutout = renderFramelessCutout(screen: screen, cornerRatio: options.framelessCornerRadius)
            modelName = nil
        } else {
            return screen
        }

        // Stage 2: Apply directional/App Store showcase template, studio background, aspect ratio,
        // device scale, post-frame canvas watermark, and final output resolution scaling.
        return composeFinalCanvas(
            cutout: cutout,
            screen: screen,
            modelName: modelName,
            options: options,
            watermark: watermark,
            targetAspectOverride: targetAspectOverride
        )
    }

    /// Creates a clean rounded-rectangle foreground cutout (capped safely at `2600px`) for frameless studio compositing.
    private static func renderFramelessCutout(screen: CGImage, cornerRatio: Double) -> CGImage {
        var sW = CGFloat(screen.width)
        var sH = CGFloat(screen.height)
        guard sW > 0, sH > 0 else { return screen }
        let maxEdge: CGFloat = 2600
        let longest = max(sW, sH)
        if longest > maxEdge {
            let scale = maxEdge / longest
            sW = (sW * scale).rounded()
            sH = (sH * scale).rounded()
        }
        let outW = max(32, Int(sW))
        let outH = max(32, Int(sH))
        guard let ctx = CGImage.rgbaContext(width: outW, height: outH) else { return screen }
        ctx.clear(CGRect(x: 0, y: 0, width: outW, height: outH))

        let rect = CGRect(x: 0, y: 0, width: CGFloat(outW), height: CGFloat(outH))
        let ratio = CGFloat(min(max(cornerRatio, 0.0), 0.16))
        let radius = min(rect.width, rect.height) * ratio
        let clipPath = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

        ctx.saveGState()
        ctx.addPath(clipPath)
        ctx.clip()
        ctx.interpolationQuality = .high
        ctx.draw(screen, in: rect)
        ctx.restoreGState()

        if radius > 1 {
            ctx.saveGState()
            ctx.addPath(clipPath)
            ctx.setStrokeColor(rgbColor((0.5, 0.52, 0.56), alpha: 0.22))
            ctx.setLineWidth(max(1.5, min(rect.width, rect.height) * 0.0022))
            ctx.strokePath()
            ctx.restoreGState()
        }
        return ctx.makeImage() ?? screen
    }

    static func drawAdaptiveBlurBackdrop(screen: CGImage, in ctx: CGContext, rect: CGRect) {
        if let tiny = CGImage.rgbaContext(width: 16, height: 16) {
            tiny.interpolationQuality = .high
            tiny.draw(screen, in: CGRect(x: 0, y: 0, width: 16, height: 16))
            if let ambient = tiny.makeImage() {
                ctx.saveGState()
                ctx.interpolationQuality = .high
                ctx.draw(ambient, in: rect)
                ctx.setFillColor(rgbColor((1, 1, 1), alpha: 0.22))
                ctx.fill(rect)
                ctx.restoreGState()
            }
        }
    }

    /// Scales any `CGImage` cleanly by a factor in `0.2...1.0`.
    static func scaleImage(_ image: CGImage, factor: Double) -> CGImage {
        let clamped = min(max(factor, 0.2), 1.0)
        guard clamped < 0.995 else { return image }
        let w = max(32, Int((Double(image.width) * clamped).rounded()))
        let h = max(32, Int((Double(image.height) * clamped).rounded()))
        guard let ctx = CGImage.rgbaContext(width: w, height: h) else { return image }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage() ?? image
    }

    // MARK: - Official Apple Product Bezels Catalog & Compositing

    enum OfficialBezelCatalog {
        struct Entry: Decodable, Sendable {
            let file: String
            let width: Int
            let height: Int
            let screenRect: [Double]
            let cornerRadius: Double
            let alignTop: Bool
        }

        private final class BundleToken {}

        static let manifest: [String: Entry] = loadManifest()

        static var isAvailable: Bool { !manifest.isEmpty }

        static func entry(for model: AppleDeviceModel, finish: DeviceFinish) -> Entry? {
            if let exact = manifest["\(model.rawValue).\(finish.rawValue)"] {
                return exact
            }
            return manifest[model.rawValue]
        }

        static func bezelCGImage(for entry: Entry) -> CGImage? {
            let ns = entry.file as NSString
            let stem = ns.deletingPathExtension
            let ext = ns.pathExtension.isEmpty ? "png" : ns.pathExtension
            guard let url = resourceURL(name: stem, ext: ext),
                  let src = CGImageSourceCreateWithURL(url as CFURL, nil) else {
                return nil
            }
            return CGImageSourceCreateImageAtIndex(src, 0, nil)
        }

        private static func resourceURL(name: String, ext: String) -> URL? {
            let bundles = [Bundle.main, Bundle(for: BundleToken.self)]
            for bundle in bundles {
                if let url = bundle.url(forResource: name, withExtension: ext) {
                    return url
                }
                if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "Bezels") {
                    return url
                }
                if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "Resources/Bezels") {
                    return url
                }
            }
            return nil
        }

        private static func loadManifest() -> [String: Entry] {
            guard let url = resourceURL(name: "BezelManifest", ext: "json"),
                  let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) else {
                return [:]
            }
            return decoded
        }
    }

    /// Draws `screen` directly into the exact transparent screen aperture of an official Apple bezel PNG,
    /// then overlays the authentic Apple hardware bezel on top. When `allowsVerticalStretch` is enabled
    /// (iPhone frames) and a long stitched screenshot exceeds normal phone aspect ratios, seamlessly
    /// 3-band stretches the vertical frame rails so the full long screenshot renders without truncation.
    private static func compositeOfficialBezel(
        screen: CGImage,
        bezelImage: CGImage,
        entry: OfficialBezelCatalog.Entry,
        desktopUnit: DesktopUnitStyle = .none,
        allowsVerticalStretch: Bool = false
    ) -> CGImage? {
        guard entry.screenRect.count == 4 else { return nil }
        let outW = bezelImage.width
        let outH = bezelImage.height
        guard outW >= 32, outH >= 32 else { return nil }

        let w = CGFloat(outW)
        let h = CGFloat(outH)
        let nx = CGFloat(entry.screenRect[0])
        let nyTop = CGFloat(entry.screenRect[1])
        let nw = CGFloat(entry.screenRect[2])
        let nh = CGFloat(entry.screenRect[3])

        let apertureW0 = nw * w
        let apertureH0 = nh * h
        let screenHOverW = CGFloat(screen.height) / max(CGFloat(screen.width), 1)
        let apertureHOverW = apertureH0 / max(apertureW0, 1)

        if allowsVerticalStretch && screenHOverW > 2.30 && screenHOverW > apertureHOverW * 1.06 {
            var s = min(1.8, max(1.0, min(CGFloat(screen.width), 1080) / max(apertureW0, 1)))
            let topMargin0 = nyTop * h
            let botMargin0 = (1.0 - nyTop - nh) * h
            let targetApertureH0 = apertureW0 * screenHOverW
            let baseOutH = topMargin0 + targetApertureH0 + botMargin0

            if baseOutH * s > 14_000 {
                s = min(s, 14_000 / max(baseOutH, 1))
            }
            if (w * s) * (baseOutH * s) > 16_000_000 {
                s = min(s, sqrt(16_000_000 / max(w * baseOutH, 1)))
            }
            s = max(s, 64.0 / max(w, 1))

            let finalW = max(32, Int((w * s).rounded()))
            let finalH = max(Int((h * s).rounded()), Int((baseOutH * s).rounded()))
            guard let ctx = CGImage.rgbaContext(width: finalW, height: finalH) else {
                return nil
            }
            ctx.clear(CGRect(x: 0, y: 0, width: finalW, height: finalH))

            let topMargin = topMargin0 * s
            let botMargin = botMargin0 * s
            let apertureW = apertureW0 * s
            let rawRect = CGRect(
                x: nx * CGFloat(finalW),
                y: botMargin,
                width: apertureW,
                height: max(16, CGFloat(finalH) - topMargin - botMargin)
            )
            let bleed = max(1.5, min(3.0, apertureW * 0.004))
            let drawRect = rawRect.insetBy(dx: -bleed, dy: -bleed)
            let cornerRadius = max(2.0, apertureW * CGFloat(entry.cornerRadius) * 1.04)

            let clipPath = CGPath(roundedRect: drawRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            ctx.saveGState()
            ctx.addPath(clipPath)
            ctx.clip()
            ctx.setFillColor(rgbColor((0.06, 0.06, 0.07)))
            ctx.fill(drawRect)
            ctx.interpolationQuality = .high
            ctx.draw(screen, in: drawRect)
            ctx.restoreGState()

            let bezelW = outW
            let bezelH = outH
            let splitTopY = Int((Double(bezelH) * 0.74).rounded())
            let splitBotY = Int((Double(bezelH) * 0.83).rounded())
            let botSrcH = bezelH - splitBotY
            let topDestH = (CGFloat(splitTopY) * s).rounded()
            let botDestH = (CGFloat(botSrcH) * s).rounded()
            let midDestH = max(1, CGFloat(finalH) - topDestH - botDestH)

            ctx.saveGState()
            ctx.interpolationQuality = .high
            if let topSlice = bezelImage.cropping(to: CGRect(x: 0, y: 0, width: bezelW, height: splitTopY)) {
                ctx.draw(topSlice, in: CGRect(x: 0, y: CGFloat(finalH) - topDestH, width: CGFloat(finalW), height: topDestH))
            }
            if splitBotY > splitTopY,
               let midSlice = bezelImage.cropping(to: CGRect(x: 0, y: splitTopY, width: bezelW, height: splitBotY - splitTopY)) {
                ctx.draw(midSlice, in: CGRect(x: 0, y: botDestH, width: CGFloat(finalW), height: midDestH))
            }
            if botSrcH > 0,
               let botSlice = bezelImage.cropping(to: CGRect(x: 0, y: splitBotY, width: bezelW, height: botSrcH)) {
                ctx.draw(botSlice, in: CGRect(x: 0, y: 0, width: CGFloat(finalW), height: botDestH))
            }
            ctx.restoreGState()

            return ctx.makeImage()
        }

        guard let ctx = CGImage.rgbaContext(width: outW, height: outH) else {
            return nil
        }
        ctx.clear(CGRect(x: 0, y: 0, width: outW, height: outH))

        let rawRect = CGRect(
            x: nx * w,
            y: (1.0 - nyTop - nh) * h,
            width: nw * w,
            height: nh * h
        )
        // Slight outward bleed (1.5-2.5 px) tucks screen content cleanly under anti-aliased inner bezel rims.
        let bleed = max(1.5, min(2.5, min(rawRect.width, rawRect.height) * 0.004))
        let drawRect = rawRect.insetBy(dx: -bleed, dy: -bleed)
        let cornerRadius = max(2.0, rawRect.width * CGFloat(entry.cornerRadius) * 1.04)

        drawScreenContent(
            screen,
            in: ctx,
            rect: drawRect,
            cornerRadius: cornerRadius,
            alignTop: entry.alignTop
        )

        ctx.saveGState()
        ctx.interpolationQuality = .high
        ctx.draw(bezelImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        ctx.restoreGState()

        if desktopUnit != .none {
            let unitW: CGFloat = (desktopUnit == .macMiniM4) ? w * 0.22 : w * 0.29
            let unitH: CGFloat = (desktopUnit == .macMiniM4) ? unitW * 0.36 : unitW * 0.49
            let unitCorner: CGFloat = (desktopUnit == .macMiniM4) ? unitW * 0.10 : unitW * 0.095
            let unitRect = CGRect(x: w * 0.72, y: 12, width: unitW, height: unitH)
            drawDesktopUnit(in: ctx, rect: unitRect, cornerRadius: unitCorner, unit: desktopUnit)
        }

        return ctx.makeImage()
    }

    // MARK: - Stage 1 Dispatch (29 Apple 2026 Models)

    private static func renderHardwareCutout(
        screen: CGImage,
        model: AppleDeviceModel,
        finish: DeviceFinish
    ) -> CGImage {
        if let entry = OfficialBezelCatalog.entry(for: model, finish: finish),
           let bezelImg = OfficialBezelCatalog.bezelCGImage(for: entry) {
            let unit: DesktopUnitStyle = switch model {
            case .macMiniM6Studio, .macMiniM5ProXDR: .macMiniM4
            case .macStudioM5Max, .macStudioM5Ultra: .macStudio
            default: .none
            }
            if let composed = compositeOfficialBezel(
                screen: screen,
                bezelImage: bezelImg,
                entry: entry,
                desktopUnit: unit,
                allowsVerticalStretch: model.category == .iPhone
            ) {
                return composed
            }
        }

        switch model {
        case .iPhone18ProMax:
            return renderModernIPhone(screen: screen, finish: finish, bezelRatio: 0.030, rimRatio: 0.013, cornerRatio: 0.165, baseWidthCap: 1340, islandScale: 0.22)
        case .iPhone18Pro:
            return renderModernIPhone(screen: screen, finish: finish, bezelRatio: 0.032, rimRatio: 0.014, cornerRatio: 0.168, baseWidthCap: 1240, islandScale: 0.22)
        case .iPhoneDuo:
            return renderIPhoneDuoFoldable(screen: screen, finish: finish)
        case .iPhoneAir:
            return renderModernIPhone(screen: screen, finish: finish, bezelRatio: 0.033, rimRatio: 0.010, cornerRatio: 0.162, baseWidthCap: 1260, islandScale: 0.27)
        case .iPhone17:
            return renderModernIPhone(screen: screen, finish: finish, bezelRatio: 0.042, rimRatio: 0.014, cornerRatio: 0.165, baseWidthCap: 1200, islandScale: 0.27)
        case .iPhone17e:
            return renderModernIPhone(screen: screen, finish: finish, bezelRatio: 0.052, rimRatio: 0.015, cornerRatio: 0.162, baseWidthCap: 1170, islandScale: 0.28)

        case .iPadPro13M5:
            return renderIPad(screen: screen, finish: finish, longSide: 1520, shortSide: 1140, bezelRatio: 0.036, cornerRatio: 0.060)
        case .iPadPro11M5:
            return renderIPad(screen: screen, finish: finish, longSide: 1430, shortSide: 1005, bezelRatio: 0.040, cornerRatio: 0.064)
        case .iPadAir13M4:
            return renderIPad(screen: screen, finish: finish, longSide: 1480, shortSide: 1110, bezelRatio: 0.048, cornerRatio: 0.065)
        case .iPadAir11M4:
            return renderIPad(screen: screen, finish: finish, longSide: 1400, shortSide: 980, bezelRatio: 0.050, cornerRatio: 0.068)
        case .iPadMiniOLED:
            return renderIPad(screen: screen, finish: finish, longSide: 1300, shortSide: 875, bezelRatio: 0.055, cornerRatio: 0.084)
        case .iPadA16:
            return renderIPad(screen: screen, finish: finish, longSide: 1390, shortSide: 970, bezelRatio: 0.058, cornerRatio: 0.072)

        case .macBookPro16M5Max:
            return renderMacBook(screen: screen, finish: finish, dispW: 1560, dispH: 975, deckH: 34, lidBezel: 22, hasDynamicIsland: true, isThinChassis: false)
        case .macBookPro14M6:
            return renderMacBook(screen: screen, finish: finish, dispW: 1440, dispH: 930, deckH: 32, lidBezel: 24, hasDynamicIsland: true, isThinChassis: false)
        case .macBookAir15M5:
            return renderMacBook(screen: screen, finish: finish, dispW: 1500, dispH: 940, deckH: 24, lidBezel: 28, hasDynamicIsland: false, isThinChassis: true)
        case .macBookAir13M5:
            return renderMacBook(screen: screen, finish: finish, dispW: 1380, dispH: 895, deckH: 22, lidBezel: 28, hasDynamicIsland: false, isThinChassis: true)
        case .macBookNeo13:
            return renderMacBook(screen: screen, finish: finish, dispW: 1340, dispH: 860, deckH: 26, lidBezel: 32, hasDynamicIsland: false, isThinChassis: true)

        case .iMac24M4:
            return renderIMac24(screen: screen, finish: finish)
        case .studioDisplay2026:
            return renderStandaloneDisplay(screen: screen, style: .studioDisplay)

        case .macMiniM6Studio:
            return renderDesktopSetup(screen: screen, display: .studioDisplay, unit: .macMiniM4)
        case .macMiniM5ProXDR:
            return renderDesktopSetup(screen: screen, display: .proDisplayXDR, unit: .macMiniM4)
        case .macStudioM5Max:
            return renderDesktopSetup(screen: screen, display: .studioDisplay, unit: .macStudio)
        case .macStudioM5Ultra:
            return renderDesktopSetup(screen: screen, display: .proDisplayXDR, unit: .macStudio)

        case .watchUltra4:
            return renderWatchUltra(screen: screen, finish: finish)
        case .watchSeries12_46:
            return renderWatchSeries(screen: screen, finish: finish, dispW: 728, dispH: 888, bezelRatio: 0.068, isSE: false)
        case .watchSeries12_42:
            return renderWatchSeries(screen: screen, finish: finish, dispW: 668, dispH: 808, bezelRatio: 0.074, isSE: false)
        case .watchSE3:
            return renderWatchSeries(screen: screen, finish: finish, dispW: 660, dispH: 810, bezelRatio: 0.110, isSE: true)

        case .appleTV4KGen4:
            return renderAppleTVSetup(screen: screen, finish: finish, usesStudioDisplay: false)
        case .appleTV4KStudio:
            return renderAppleTVSetup(screen: screen, finish: finish, usesStudioDisplay: true)
        }
    }

    // MARK: - Stage 2: App Store Showcase Templates + Background + Scaling + Watermark

    private static func composeFinalCanvas(
        cutout: CGImage,
        screen: CGImage,
        modelName: String?,
        options: DeviceFrameOptions,
        watermark: WatermarkOptions,
        targetAspectOverride: CGFloat? = nil
    ) -> CGImage {
        // Transform hardware cutout orientation according to directional templates first.
        let primaryCutout: CGImage = switch options.template {
        case .tiltLeft:
            rotateImage(cutout, radians: .pi * -10 / 180)
        case .tiltRight:
            rotateImage(cutout, radians: .pi * 10 / 180)
        case .perspectiveLeft:
            applyPerspective(cutout: cutout, leanLeft: true)
        case .perspectiveRight:
            applyPerspective(cutout: cutout, leanLeft: false)
        default:
            cutout
        }

        let cutW = CGFloat(primaryCutout.width)
        let cutH = CGFloat(primaryCutout.height)
        let wantsBadge = watermark.isActive && watermark.placement == .bottomBadge
        let wantsFullTiled = watermark.isActive && watermark.placement == .fullCanvasTiled

        let composed: CGImage
        if !options.showsBackground {
            if options.template == .duoFloat {
                composed = composeTransparentDuo(cutout: cutout, watermark: watermark, modelName: modelName)
            } else {
                let extraBottom: CGFloat = wantsBadge ? max(78, (min(cutW, cutH) * 0.10).rounded()) : 0
                let outW = Int(cutW)
                let outH = Int(cutH + extraBottom)
                if extraBottom == 0 && !wantsFullTiled {
                    composed = primaryCutout
                } else if let ctx = CGImage.rgbaContext(width: outW, height: outH) {
                    ctx.clear(CGRect(x: 0, y: 0, width: outW, height: outH))
                    ctx.interpolationQuality = .high
                    ctx.draw(primaryCutout, in: CGRect(x: 0, y: extraBottom, width: cutW, height: cutH))
                    if wantsFullTiled {
                        MaskRenderer.drawWatermark(in: ctx, size: CGSize(width: outW, height: outH), options: watermark)
                    }
                    if wantsBadge {
                        drawBottomBadge(
                            in: ctx,
                            canvasSize: CGSize(width: outW, height: outH),
                            bandHeight: extraBottom,
                            watermark: watermark,
                            modelName: modelName,
                            onDarkBackground: false,
                            usePillBacking: true
                        )
                    }
                    composed = ctx.makeImage() ?? primaryCutout
                } else {
                    composed = primaryCutout
                }
            }
        } else {
            // Full studio canvas with customizable background, App Store template layout, aspect ratio, & scale.
            let basePad = max(140, (min(cutW, cutH) * 0.22).rounded())
            var canvasW = cutW + basePad * 2
            var canvasH = cutH + basePad * 2 + (wantsBadge ? max(70, min(cutW, cutH) * 0.08) : 0)

            if options.template == .heroTopTitle {
                canvasH += max(220, cutH * 0.24)
            } else if options.template == .duoFloat {
                canvasW += cutW * 0.24
            }

            if let targetRatio = targetAspectOverride ?? options.canvasAspect.ratio {
                let currentRatio = canvasW / max(canvasH, 1)
                if currentRatio < targetRatio {
                    canvasW = (canvasH * targetRatio).rounded()
                } else {
                    canvasH = (canvasW / targetRatio).rounded()
                }
            } else if options.template == .heroTopTitle && canvasW > canvasH * 0.85 {
                // Default App Store portrait showcase aspect when no explicit aspect ratio is chosen.
                canvasH = max(canvasH, (canvasW * 1.32).rounded())
            }

            let maxW: CGFloat = 3400
            let maxH: CGFloat = 14_000
            let maxPixels: CGFloat = 16_000_000
            var shrink: CGFloat = 1.0
            if canvasW > maxW { shrink = min(shrink, maxW / canvasW) }
            if canvasH > maxH { shrink = min(shrink, maxH / canvasH) }
            let area = (canvasW * shrink) * (canvasH * shrink)
            if area > maxPixels { shrink *= sqrt(maxPixels / area) }
            if shrink < 1.0 {
                canvasW = (canvasW * shrink).rounded()
                canvasH = (canvasH * shrink).rounded()
            }

            let cW = max(64, Int(canvasW))
            let cH = max(64, Int(canvasH))
            guard let ctx = CGImage.rgbaContext(width: cW, height: cH) else {
                return scaleImage(primaryCutout, factor: options.outputScale)
            }

            let canvasRect = CGRect(x: 0, y: 0, width: cW, height: cH)
            drawStudioBackdrop(in: ctx, rect: canvasRect, options: options, screen: screen)

            let badgeBandH: CGFloat = wantsBadge ? max(72, (min(CGFloat(cW), CGFloat(cH)) * 0.075).rounded()) : 0
            let clampedDeviceScale = CGFloat(min(max(options.deviceScale, 0.50), 1.00))

            switch options.template {
            case .heroTopTitle:
                let titleBandH = CGFloat(cH) * 0.23
                let heroText = options.heroTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                let resolvedTitle = heroText.isEmpty ? (modelName ?? "QuickCover") : heroText
                let heroSub = options.heroSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
                drawAppStoreHeroHeader(
                    in: ctx,
                    canvasSize: canvasRect.size,
                    bandHeight: titleBandH,
                    title: resolvedTitle,
                    subtitle: heroSub,
                    onDarkBackground: options.hasDarkBackground
                )
                let availH = max(64, CGFloat(cH) - titleBandH - badgeBandH * 0.82)
                let fitRatio = min((CGFloat(cW) * 0.90) / cutW, (availH * 1.06) / cutH)
                let applied = fitRatio * clampedDeviceScale
                let drawW = (cutW * applied).rounded()
                let drawH = (cutH * applied).rounded()
                let bleedOffset = drawH * 0.08
                let drawRect = CGRect(
                    x: (CGFloat(cW) - drawW) / 2,
                    y: badgeBandH * 0.82 - bleedOffset,
                    width: drawW,
                    height: drawH
                )
                drawShadowedCutout(primaryCutout, in: ctx, rect: drawRect, options: options)

            case .bottomBleed:
                let availH = max(64, CGFloat(cH) - badgeBandH * 0.82)
                let fitRatio = min((CGFloat(cW) * 0.92) / cutW, (availH * 1.12) / cutH)
                let applied = fitRatio * clampedDeviceScale
                let drawW = (cutW * applied).rounded()
                let drawH = (cutH * applied).rounded()
                let bleedOffset = drawH * 0.14
                let drawRect = CGRect(
                    x: (CGFloat(cW) - drawW) / 2,
                    y: badgeBandH * 0.82 - bleedOffset,
                    width: drawW,
                    height: drawH
                )
                drawShadowedCutout(primaryCutout, in: ctx, rect: drawRect, options: options)

            case .topBleed:
                let fitRatio = min((CGFloat(cW) * 0.92) / cutW, (CGFloat(cH) * 1.12) / cutH)
                let applied = fitRatio * clampedDeviceScale
                let drawW = (cutW * applied).rounded()
                let drawH = (cutH * applied).rounded()
                let bleedOffset = drawH * 0.14
                let drawRect = CGRect(
                    x: (CGFloat(cW) - drawW) / 2,
                    y: CGFloat(cH) - drawH + bleedOffset,
                    width: drawW,
                    height: drawH
                )
                drawShadowedCutout(primaryCutout, in: ctx, rect: drawRect, options: options)

            case .duoFloat:
                let safeH = max(64, CGFloat(cH) - badgeBandH * 0.82)
                let leftTilt = rotateImage(cutout, radians: .pi * -11 / 180)
                let rightTilt = rotateImage(cutout, radians: .pi * 5 / 180)
                let baseFit = min((CGFloat(cW) * 0.72) / CGFloat(cutout.width), (safeH * 0.84) / CGFloat(cutout.height)) * clampedDeviceScale

                let backScale = baseFit * 0.86
                let backW = CGFloat(leftTilt.width) * backScale
                let backH = CGFloat(leftTilt.height) * backScale
                let backRect = CGRect(
                    x: CGFloat(cW) * 0.36 - backW / 2,
                    y: badgeBandH * 0.82 + safeH * 0.44 - backH / 2,
                    width: backW,
                    height: backH
                )
                drawShadowedCutout(leftTilt, in: ctx, rect: backRect, options: options, extraAlpha: 0.92)

                let frontScale = baseFit * 0.96
                let frontW = CGFloat(rightTilt.width) * frontScale
                let frontH = CGFloat(rightTilt.height) * frontScale
                let frontRect = CGRect(
                    x: CGFloat(cW) * 0.62 - frontW / 2,
                    y: badgeBandH * 0.82 + safeH * 0.54 - frontH / 2,
                    width: frontW,
                    height: frontH
                )
                drawShadowedCutout(rightTilt, in: ctx, rect: frontRect, options: options)

            default:
                let safeArea = CGRect(
                    x: 0,
                    y: badgeBandH * 0.82,
                    width: CGFloat(cW),
                    height: max(64, CGFloat(cH) - badgeBandH * 0.82)
                )
                let fitRatio = min((safeArea.width * 0.92) / cutW, (safeArea.height * 0.92) / cutH)
                let appliedScale = fitRatio * clampedDeviceScale
                let drawW = (cutW * appliedScale).rounded()
                let drawH = (cutH * appliedScale).rounded()
                let drawRect = CGRect(
                    x: (safeArea.midX - drawW / 2).rounded(),
                    y: (safeArea.midY - drawH / 2).rounded(),
                    width: drawW,
                    height: drawH
                )
                drawShadowedCutout(primaryCutout, in: ctx, rect: drawRect, options: options)
            }

            if wantsFullTiled {
                MaskRenderer.drawWatermark(in: ctx, size: canvasRect.size, options: watermark)
            }
            if wantsBadge {
                drawBottomBadge(
                    in: ctx,
                    canvasSize: canvasRect.size,
                    bandHeight: badgeBandH,
                    watermark: watermark,
                    modelName: modelName,
                    onDarkBackground: options.hasDarkBackground,
                    usePillBacking: false
                )
            }

            composed = ctx.makeImage() ?? primaryCutout
        }

        return scaleImage(composed, factor: options.outputScale)
    }

    private static func composeTransparentDuo(
        cutout: CGImage,
        watermark: WatermarkOptions,
        modelName: String?
    ) -> CGImage {
        let leftTilt = rotateImage(cutout, radians: .pi * -10 / 180)
        let rightTilt = rotateImage(cutout, radians: .pi * 5 / 180)
        let outW = Int(CGFloat(max(leftTilt.width, rightTilt.width)) * 1.48)
        let extraBottom: CGFloat = (watermark.isActive && watermark.placement == .bottomBadge)
            ? max(78, (CGFloat(outW) * 0.08).rounded()) : 0
        let outH = Int(CGFloat(max(leftTilt.height, rightTilt.height)) * 1.15 + extraBottom)
        guard let ctx = CGImage.rgbaContext(width: outW, height: outH) else { return cutout }
        ctx.clear(CGRect(x: 0, y: 0, width: outW, height: outH))

        let backW = CGFloat(leftTilt.width) * 0.85
        let backH = CGFloat(leftTilt.height) * 0.85
        let backRect = CGRect(x: CGFloat(outW) * 0.34 - backW / 2, y: extraBottom + CGFloat(outH - Int(extraBottom)) * 0.44 - backH / 2, width: backW, height: backH)
        ctx.saveGState()
        ctx.setAlpha(0.92)
        ctx.interpolationQuality = .high
        ctx.draw(leftTilt, in: backRect)
        ctx.restoreGState()

        let frontW = CGFloat(rightTilt.width) * 0.95
        let frontH = CGFloat(rightTilt.height) * 0.95
        let frontRect = CGRect(x: CGFloat(outW) * 0.64 - frontW / 2, y: extraBottom + CGFloat(outH - Int(extraBottom)) * 0.54 - frontH / 2, width: frontW, height: frontH)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: -10, height: -8), blur: 32, color: rgbColor((0, 0, 0), alpha: 0.25))
        ctx.interpolationQuality = .high
        ctx.draw(rightTilt, in: frontRect)
        ctx.restoreGState()

        if watermark.isActive && watermark.placement == .fullCanvasTiled {
            MaskRenderer.drawWatermark(in: ctx, size: CGSize(width: outW, height: outH), options: watermark)
        } else if extraBottom > 0 {
            drawBottomBadge(
                in: ctx,
                canvasSize: CGSize(width: outW, height: outH),
                bandHeight: extraBottom,
                watermark: watermark,
                modelName: modelName,
                onDarkBackground: false,
                usePillBacking: true
            )
        }
        return ctx.makeImage() ?? cutout
    }

    private static func drawShadowedCutout(
        _ image: CGImage,
        in ctx: CGContext,
        rect: CGRect,
        options: DeviceFrameOptions,
        extraAlpha: CGFloat = 1.0
    ) {
        ctx.saveGState()
        ctx.setAlpha(extraAlpha)
        if options.showsShadow {
            let blur = max(24, min(rect.width, rect.height) * 0.075)
            let offsetY = -max(10, min(rect.width, rect.height) * 0.028)
            let shadowAlpha: CGFloat = options.hasDarkBackground ? 0.62 : 0.30
            ctx.setShadow(
                offset: CGSize(width: 0, height: offsetY),
                blur: blur,
                color: rgbColor((0, 0, 0), alpha: shadowAlpha)
            )
        }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: rect)
        ctx.restoreGState()
    }

    private static func drawAppStoreHeroHeader(
        in ctx: CGContext,
        canvasSize: CGSize,
        bandHeight: CGFloat,
        title: String,
        subtitle: String,
        onDarkBackground: Bool
    ) {
        let shortSide = min(canvasSize.width, canvasSize.height)
        let titleSize = max(36, min(92, (shortSide * 0.056).rounded()))
        let subSize = max(20, (titleSize * 0.50).rounded())
        let titleColor = onDarkBackground ? UIColor.white : UIColor(red: 0.08, green: 0.09, blue: 0.12, alpha: 1)
        let subColor = titleColor.withAlphaComponent(0.72)

        let titleAttr = NSAttributedString(
            string: title,
            attributes: [
                .font: UIFont.systemFont(ofSize: titleSize, weight: .bold),
                .foregroundColor: titleColor,
                .kern: -titleSize * 0.02,
            ]
        )
        let titleLine = CTLineCreateWithAttributedString(titleAttr)
        let titleBounds = CTLineGetBoundsWithOptions(titleLine, .useOpticalBounds)

        let centerBandY = canvasSize.height - bandHeight * 0.52
        let hasSub = !subtitle.isEmpty
        let titleY = hasSub ? centerBandY + subSize * 0.35 : centerBandY - titleBounds.height / 2 - titleBounds.origin.y

        ctx.saveGState()
        ctx.textPosition = CGPoint(
            x: canvasSize.width / 2 - titleBounds.width / 2 - titleBounds.origin.x,
            y: titleY
        )
        CTLineDraw(titleLine, ctx)

        if hasSub {
            let subAttr = NSAttributedString(
                string: subtitle,
                attributes: [
                    .font: UIFont.systemFont(ofSize: subSize, weight: .medium),
                    .foregroundColor: subColor,
                ]
            )
            let subLine = CTLineCreateWithAttributedString(subAttr)
            let subBounds = CTLineGetBoundsWithOptions(subLine, .useOpticalBounds)
            ctx.textPosition = CGPoint(
                x: canvasSize.width / 2 - subBounds.width / 2 - subBounds.origin.x,
                y: titleY - subBounds.height - subSize * 0.45
            )
            CTLineDraw(subLine, ctx)
        }
        ctx.restoreGState()
    }

    // MARK: - Geometric Transform Helpers (Tilt & 3D Perspective)

    private static func rotateImage(_ image: CGImage, radians: CGFloat) -> CGImage {
        let w = CGFloat(image.width)
        let h = CGFloat(image.height)
        guard w > 0, h > 0 else { return image }
        let cosA = abs(cos(radians))
        let sinA = abs(sin(radians))
        let newW = Int((w * cosA + h * sinA).rounded(.up))
        let newH = Int((w * sinA + h * cosA).rounded(.up))
        guard let ctx = CGImage.rgbaContext(width: newW, height: newH) else { return image }
        ctx.clear(CGRect(x: 0, y: 0, width: newW, height: newH))
        ctx.interpolationQuality = .high
        ctx.translateBy(x: CGFloat(newW) / 2, y: CGFloat(newH) / 2)
        ctx.rotate(by: radians)
        ctx.draw(image, in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
        return ctx.makeImage() ?? image
    }

    private static func applyPerspective(cutout: CGImage, leanLeft: Bool) -> CGImage {
        let w = CGFloat(cutout.width)
        let h = CGFloat(cutout.height)
        guard w > 16, h > 16 else { return cutout }

        let ciInput = CIImage(cgImage: cutout)
        guard let filter = CIFilter(name: "CIPerspectiveTransform") else { return cutout }
        filter.setValue(ciInput, forKey: kCIInputImageKey)

        // CoreImage uses bottom-left coordinates matching CoreGraphics.
        let topLeft: CGPoint
        let topRight: CGPoint
        let botRight: CGPoint
        let botLeft: CGPoint

        if leanLeft {
            // Left edge tilted slightly closer / right edge foreshortened into depth.
            topLeft = CGPoint(x: w * 0.03, y: h * 0.99)
            topRight = CGPoint(x: w * 0.94, y: h * 0.91)
            botRight = CGPoint(x: w * 0.96, y: h * 0.07)
            botLeft = CGPoint(x: w * 0.03, y: h * 0.01)
        } else {
            // Right edge closer / left edge foreshortened into depth.
            topLeft = CGPoint(x: w * 0.06, y: h * 0.91)
            topRight = CGPoint(x: w * 0.97, y: h * 0.99)
            botRight = CGPoint(x: w * 0.97, y: h * 0.01)
            botLeft = CGPoint(x: w * 0.04, y: h * 0.07)
        }

        filter.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: botRight), forKey: "inputBottomRight")
        filter.setValue(CIVector(cgPoint: botLeft), forKey: "inputBottomLeft")

        guard let output = filter.outputImage else { return cutout }
        let extent = output.extent.integral
        guard extent.width >= 16, extent.height >= 16 else { return cutout }
        return ciContext.createCGImage(output, from: extent, format: .RGBA8, colorSpace: sRGB) ?? cutout
    }

    /// Draws a sleek Picsew / Leica-inspired typographic watermark badge along the bottom of the canvas.
    static func drawBottomBadge(
        in ctx: CGContext,
        canvasSize: CGSize,
        bandHeight: CGFloat,
        watermark: WatermarkOptions,
        modelName: String?,
        onDarkBackground: Bool,
        usePillBacking: Bool
    ) {
        let baseText = watermark.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullText: String
        if watermark.showsDeviceModel, let modelName, !modelName.isEmpty {
            fullText = baseText.isEmpty ? modelName : "\(baseText)  ·  \(modelName)"
        } else {
            fullText = baseText
        }
        guard !fullText.isEmpty else { return }

        let shortSide = min(canvasSize.width, canvasSize.height)
        let fontSize = max(16, min(38, (shortSide * 0.025).rounded()))
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let alpha = CGFloat(min(max(watermark.opacity * 2.1, 0.45), 0.96))
        let textColor: UIColor = switch watermark.tint {
        case .white:
            UIColor.white.withAlphaComponent(alpha)
        case .red:
            UIColor(red: 0.88, green: 0.20, blue: 0.22, alpha: alpha)
        case .slate:
            onDarkBackground
                ? UIColor.white.withAlphaComponent(alpha)
                : UIColor(red: 0.14, green: 0.15, blue: 0.18, alpha: alpha)
        }

        let attr = NSAttributedString(
            string: fullText,
            attributes: [
                .font: font,
                .foregroundColor: textColor,
                .kern: fontSize * 0.04,
            ]
        )
        let line = CTLineCreateWithAttributedString(attr)
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        let centerY = max(bandHeight * 0.52, bounds.height * 0.9)

        if usePillBacking {
            let padX = fontSize * 1.0
            let padY = fontSize * 0.48
            let pillW = bounds.width + padX * 2
            let pillH = bounds.height + padY * 2
            let pillRect = CGRect(
                x: canvasSize.width / 2 - pillW / 2,
                y: centerY - pillH / 2,
                width: pillW,
                height: pillH
            )
            let pillPath = CGPath(roundedRect: pillRect, cornerWidth: pillH / 2, cornerHeight: pillH / 2, transform: nil)
            ctx.saveGState()
            ctx.addPath(pillPath)
            let bgTone: (CGFloat, CGFloat, CGFloat) = (watermark.tint == .white) ? (0.10, 0.10, 0.12) : (0.96, 0.96, 0.98)
            ctx.setFillColor(rgbColor(bgTone, alpha: 0.88))
            ctx.fillPath()
            ctx.addPath(pillPath)
            ctx.setStrokeColor(rgbColor((0.5, 0.5, 0.55), alpha: 0.28))
            ctx.setLineWidth(1.5)
            ctx.strokePath()
            ctx.restoreGState()
        }

        ctx.saveGState()
        ctx.textPosition = CGPoint(
            x: canvasSize.width / 2 - bounds.width / 2 - bounds.origin.x,
            y: centerY - bounds.height / 2 - bounds.origin.y
        )
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }

    // MARK: - iPhone (2026 Models + iPhone Duo Foldable)

    private static func renderModernIPhone(
        screen: CGImage,
        finish: DeviceFinish,
        bezelRatio: CGFloat,
        rimRatio: CGFloat,
        cornerRatio: CGFloat,
        baseWidthCap: CGFloat,
        islandScale: CGFloat
    ) -> CGImage {
        let sW = CGFloat(screen.width)
        let sH = CGFloat(screen.height)
        let clampedH = min(max(sH, sW * 1.92), sW * 16.0)
        let baseW = min(max(sW, 760), baseWidthCap)
        var scale = baseW / max(sW, 1)
        if clampedH * scale > 14_000 {
            scale = min(scale, 14_000 / max(clampedH, 1))
        }
        let dispW = (sW * scale).rounded()
        let dispH = (clampedH * scale).rounded()

        let bezel = (dispW * bezelRatio).rounded()
        let frameRim = max(6, (dispW * rimRatio).rounded())
        let bodyW = dispW + (bezel + frameRim) * 2
        let bodyH = dispH + (bezel + frameRim) * 2
        let btnW = max(4, (frameRim * 0.68).rounded())
        let padX = btnW + 8
        let padY: CGFloat = 10

        let canvasW = Int(bodyW + padX * 2)
        let canvasH = Int(bodyH + padY * 2)
        guard let ctx = CGImage.rgbaContext(width: canvasW, height: canvasH) else { return screen }

        let bodyRect = CGRect(x: padX, y: padY, width: bodyW, height: bodyH)
        let outerRadius = dispW * cornerRatio
        let innerBezelRect = bodyRect.insetBy(dx: frameRim, dy: frameRim)
        let screenRect = innerBezelRect.insetBy(dx: bezel, dy: bezel)
        let screenRadius = max(24, outerRadius - bezel - frameRim)

        let btnColor = rgbColor(finish.shadowRGB)
        drawSideButton(in: ctx, rect: CGRect(x: bodyRect.minX - btnW * 0.85, y: bodyRect.maxY - bodyH * 0.21, width: btnW, height: bodyW * 0.072), color: btnColor)
        drawSideButton(in: ctx, rect: CGRect(x: bodyRect.minX - btnW * 0.85, y: bodyRect.maxY - bodyH * 0.31, width: btnW, height: bodyW * 0.132), color: btnColor)
        drawSideButton(in: ctx, rect: CGRect(x: bodyRect.minX - btnW * 0.85, y: bodyRect.maxY - bodyH * 0.41, width: btnW, height: bodyW * 0.132), color: btnColor)
        drawSideButton(in: ctx, rect: CGRect(x: bodyRect.maxX - btnW * 0.15, y: bodyRect.maxY - bodyH * 0.34, width: btnW, height: bodyW * 0.18), color: btnColor)

        drawMetallicRoundedRect(in: ctx, rect: bodyRect, cornerRadius: outerRadius, finish: finish)

        let bezelPath = CGPath(roundedRect: innerBezelRect, cornerWidth: outerRadius - frameRim, cornerHeight: outerRadius - frameRim, transform: nil)
        ctx.saveGState()
        ctx.addPath(bezelPath)
        ctx.setFillColor(rgbColor((0.03, 0.03, 0.04)))
        ctx.fillPath()
        ctx.restoreGState()

        drawScreenContent(screen, in: ctx, rect: screenRect, cornerRadius: screenRadius, alignTop: true)

        let islandW = dispW * islandScale
        let islandH = dispW * 0.068
        let islandRect = CGRect(
            x: screenRect.midX - islandW / 2,
            y: screenRect.maxY - islandH - dispW * 0.024,
            width: islandW,
            height: islandH
        )
        let islandPath = CGPath(roundedRect: islandRect, cornerWidth: islandH / 2, cornerHeight: islandH / 2, transform: nil)
        ctx.saveGState()
        ctx.addPath(islandPath)
        ctx.setFillColor(rgbColor((0.02, 0.02, 0.03)))
        ctx.fillPath()
        let lensD = islandH * 0.42
        let lensRect = CGRect(x: islandRect.maxX - islandH * 0.72, y: islandRect.midY - lensD / 2, width: lensD, height: lensD)
        ctx.setFillColor(rgbColor((0.10, 0.14, 0.24)))
        ctx.fillEllipse(in: lensRect)
        ctx.setFillColor(rgbColor((0.35, 0.50, 0.78), alpha: 0.55))
        ctx.fillEllipse(in: lensRect.insetBy(dx: lensD * 0.28, dy: lensD * 0.28))
        ctx.restoreGState()

        return ctx.makeImage() ?? screen
    }

    private static func renderIPhoneDuoFoldable(screen: CGImage, finish: DeviceFinish) -> CGImage {
        let dispW: CGFloat = 1360
        let dispH: CGFloat = 1500
        let bezel: CGFloat = 34
        let rim: CGFloat = 14
        let bodyW = dispW + (bezel + rim) * 2
        let bodyH = dispH + (bezel + rim) * 2
        let hingeProtusion: CGFloat = 14
        let pad: CGFloat = 16

        let canvasW = Int(bodyW + pad * 2)
        let canvasH = Int(bodyH + hingeProtusion * 2 + pad * 2)
        guard let ctx = CGImage.rgbaContext(width: canvasW, height: canvasH) else { return screen }

        let bodyRect = CGRect(x: pad, y: pad + hingeProtusion, width: bodyW, height: bodyH)
        let outerRadius: CGFloat = 78

        // Grade 5 aluminum spine hinge caps at top and bottom center
        let hingeW: CGFloat = 94
        drawMetallicRoundedRect(
            in: ctx,
            rect: CGRect(x: bodyRect.midX - hingeW / 2, y: bodyRect.maxY - 12, width: hingeW, height: 22),
            cornerRadius: 8,
            finish: finish
        )
        drawMetallicRoundedRect(
            in: ctx,
            rect: CGRect(x: bodyRect.midX - hingeW / 2, y: bodyRect.minY - 10, width: hingeW, height: 22),
            cornerRadius: 8,
            finish: finish
        )

        drawMetallicRoundedRect(in: ctx, rect: bodyRect, cornerRadius: outerRadius, finish: finish)

        let innerBezel = bodyRect.insetBy(dx: rim, dy: rim)
        let bezelPath = CGPath(roundedRect: innerBezel, cornerWidth: outerRadius - rim, cornerHeight: outerRadius - rim, transform: nil)
        ctx.saveGState()
        ctx.addPath(bezelPath)
        ctx.setFillColor(rgbColor((0.03, 0.03, 0.04)))
        ctx.fillPath()
        ctx.restoreGState()

        let screenRect = innerBezel.insetBy(dx: bezel, dy: bezel)
        let screenRadius: CGFloat = max(32, outerRadius - rim - bezel * 0.7)
        drawScreenContent(screen, in: ctx, rect: screenRect, cornerRadius: screenRadius, alignTop: false)

        // Subtle center fold highlight & micro pinhole camera in top-right bezel
        ctx.saveGState()
        ctx.setFillColor(rgbColor((1, 1, 1), alpha: 0.07))
        ctx.fill(CGRect(x: screenRect.midX - 2, y: screenRect.minY, width: 4, height: screenRect.height))
        ctx.setFillColor(rgbColor((0.14, 0.19, 0.28)))
        ctx.fillEllipse(in: CGRect(x: screenRect.maxX - 88, y: screenRect.maxY + (bezel - 12) / 2, width: 12, height: 12))
        ctx.restoreGState()

        return ctx.makeImage() ?? screen
    }

    // MARK: - iPad (M5 Pro / M4 Air / OLED mini / A16)

    private static func renderIPad(
        screen: CGImage,
        finish: DeviceFinish,
        longSide: CGFloat,
        shortSide: CGFloat,
        bezelRatio: CGFloat,
        cornerRatio: CGFloat
    ) -> CGImage {
        let isLandscape = screen.width >= screen.height
        let dispW = isLandscape ? longSide : shortSide
        let dispH = isLandscape ? shortSide : longSide

        let ref = min(dispW, dispH)
        let bezel = (ref * bezelRatio).rounded()
        let rim = max(7, (ref * 0.011).rounded())
        let bodyW = dispW + (bezel + rim) * 2
        let bodyH = dispH + (bezel + rim) * 2
        let pad: CGFloat = 12

        let canvasW = Int(bodyW + pad * 2)
        let canvasH = Int(bodyH + pad * 2)
        guard let ctx = CGImage.rgbaContext(width: canvasW, height: canvasH) else { return screen }

        let bodyRect = CGRect(x: pad, y: pad, width: bodyW, height: bodyH)
        let outerRadius = ref * cornerRatio
        let innerBezelRect = bodyRect.insetBy(dx: rim, dy: rim)
        let screenRect = innerBezelRect.insetBy(dx: bezel, dy: bezel)
        let screenRadius = max(14, outerRadius - bezel * 0.52)

        drawMetallicRoundedRect(in: ctx, rect: bodyRect, cornerRadius: outerRadius, finish: finish)

        let bezelPath = CGPath(roundedRect: innerBezelRect, cornerWidth: outerRadius - rim, cornerHeight: outerRadius - rim, transform: nil)
        ctx.saveGState()
        ctx.addPath(bezelPath)
        ctx.setFillColor(rgbColor((0.035, 0.035, 0.045)))
        ctx.fillPath()
        ctx.restoreGState()

        drawScreenContent(screen, in: ctx, rect: screenRect, cornerRadius: screenRadius, alignTop: false)

        let camD = max(7, bezel * 0.24)
        ctx.setFillColor(rgbColor((0.15, 0.18, 0.26)))
        ctx.fillEllipse(in: CGRect(x: bodyRect.midX - camD / 2, y: screenRect.maxY + (bezel - camD) / 2, width: camD, height: camD))

        return ctx.makeImage() ?? screen
    }

    // MARK: - MacBook (Pro M5 Max / M6 PROLED with Dynamic Island, Air M5, MacBook Neo 13")

    private static func renderMacBook(
        screen: CGImage,
        finish: DeviceFinish,
        dispW: CGFloat,
        dispH: CGFloat,
        deckH: CGFloat,
        lidBezel: CGFloat,
        hasDynamicIsland: Bool,
        isThinChassis: Bool
    ) -> CGImage {
        let bezelTop = lidBezel
        let bezelBottom = lidBezel + 16
        let lidRim: CGFloat = isThinChassis ? 6 : 8

        let lidW = dispW + (lidBezel + lidRim) * 2
        let lidH = dispH + bezelTop + bezelBottom + lidRim * 2
        let baseW = lidW * (isThinChassis ? 1.13 : 1.15)
        let footH: CGFloat = isThinChassis ? 5 : 8
        let pad: CGFloat = 12

        let canvasW = Int(baseW + pad * 2)
        let canvasH = Int(lidH + deckH + footH + pad * 2)
        guard let ctx = CGImage.rgbaContext(width: canvasW, height: canvasH) else { return screen }

        let baseRect = CGRect(x: pad, y: pad + footH, width: baseW, height: deckH)
        let lidRect = CGRect(x: baseRect.midX - lidW / 2, y: baseRect.maxY - 2, width: lidW, height: lidH)
        let lidRadius: CGFloat = 26

        ctx.setFillColor(rgbColor((0.08, 0.08, 0.09)))
        let footW: CGFloat = isThinChassis ? 48 : 60
        ctx.fill(CGRect(x: baseRect.minX + 54, y: pad, width: footW, height: footH + 2))
        ctx.fill(CGRect(x: baseRect.maxX - 54 - footW, y: pad, width: footW, height: footH + 2))

        drawMetallicRoundedRect(in: ctx, rect: lidRect, cornerRadius: lidRadius, finish: finish)
        let innerLid = lidRect.insetBy(dx: lidRim, dy: lidRim)
        let innerPath = CGPath(roundedRect: innerLid, cornerWidth: lidRadius - lidRim, cornerHeight: lidRadius - lidRim, transform: nil)
        ctx.saveGState()
        ctx.addPath(innerPath)
        ctx.setFillColor(rgbColor((0.03, 0.03, 0.04)))
        ctx.fillPath()
        ctx.restoreGState()

        let screenRect = CGRect(x: innerLid.minX + lidBezel, y: innerLid.minY + bezelBottom, width: dispW, height: dispH)
        drawScreenContent(screen, in: ctx, rect: screenRect, cornerRadius: 9, alignTop: false)

        if hasDynamicIsland {
            // PROLED MacBook Pro floating Dynamic Island pill
            let islandW: CGFloat = 166
            let islandH: CGFloat = 28
            let islandRect = CGRect(x: screenRect.midX - islandW / 2, y: screenRect.maxY - islandH - 12, width: islandW, height: islandH)
            let p = CGPath(roundedRect: islandRect, cornerWidth: islandH / 2, cornerHeight: islandH / 2, transform: nil)
            ctx.saveGState()
            ctx.addPath(p)
            ctx.setFillColor(rgbColor((0.02, 0.02, 0.03)))
            ctx.fillPath()
            let camD: CGFloat = 10
            ctx.setFillColor(rgbColor((0.14, 0.19, 0.28)))
            ctx.fillEllipse(in: CGRect(x: islandRect.maxX - 24, y: islandRect.midY - camD / 2, width: camD, height: camD))
            ctx.restoreGState()
        } else {
            let notchW: CGFloat = 164
            let notchH: CGFloat = 28
            let notchRect = CGRect(x: screenRect.midX - notchW / 2, y: screenRect.maxY - notchH + 2, width: notchW, height: notchH)
            let notchPath = CGPath(roundedRect: notchRect, cornerWidth: 10, cornerHeight: 10, transform: nil)
            ctx.saveGState()
            ctx.addPath(notchPath)
            ctx.setFillColor(rgbColor((0.03, 0.03, 0.04)))
            ctx.fillPath()
            let camD: CGFloat = 8
            ctx.setFillColor(rgbColor((0.14, 0.19, 0.28)))
            ctx.fillEllipse(in: CGRect(x: notchRect.midX - camD / 2, y: notchRect.midY - camD / 2, width: camD, height: camD))
            ctx.restoreGState()
        }

        let basePath = CGPath(roundedRect: baseRect, cornerWidth: isThinChassis ? 10 : 14, cornerHeight: isThinChassis ? 10 : 14, transform: nil)
        ctx.saveGState()
        ctx.addPath(basePath)
        ctx.clip()
        if let grad = CGGradient(
            colorsSpace: sRGB,
            colors: [
                rgbColor(finish.shadowRGB),
                rgbColor(finish.highlightRGB),
                rgbColor(finish.primaryRGB),
                rgbColor(finish.highlightRGB),
                rgbColor(finish.shadowRGB),
            ] as CFArray,
            locations: [0.0, 0.14, 0.50, 0.86, 1.0]
        ) {
            ctx.drawLinearGradient(
                grad,
                start: CGPoint(x: baseRect.minX, y: baseRect.midY),
                end: CGPoint(x: baseRect.maxX, y: baseRect.midY),
                options: []
            )
        }
        ctx.setFillColor(rgbColor(finish.shadowRGB, alpha: 0.42))
        ctx.fill(CGRect(x: baseRect.minX, y: baseRect.minY, width: baseW, height: deckH * 0.34))
        let scoopW: CGFloat = 204
        let scoopH: CGFloat = isThinChassis ? 10 : 13
        let scoopRect = CGRect(x: baseRect.midX - scoopW / 2, y: baseRect.maxY - scoopH + 2, width: scoopW, height: scoopH)
        let scoopPath = CGPath(roundedRect: scoopRect, cornerWidth: scoopH / 2, cornerHeight: scoopH / 2, transform: nil)
        ctx.addPath(scoopPath)
        ctx.setFillColor(rgbColor(finish.shadowRGB, alpha: 0.72))
        ctx.fillPath()
        ctx.restoreGState()

        return ctx.makeImage() ?? screen
    }

    // MARK: - iMac 24" (M4 · 7 Colors)

    private static func renderIMac24(screen: CGImage, finish: DeviceFinish) -> CGImage {
        let dispW: CGFloat = 1520
        let dispH: CGFloat = 855
        let bezel: CGFloat = 46
        let chinH: CGFloat = 136
        let standNeckW: CGFloat = 228
        let standNeckH: CGFloat = 186
        let standFootW: CGFloat = 330
        let standFootH: CGFloat = 16

        let bodyW = dispW + bezel * 2
        let bodyH = dispH + bezel + chinH
        let pad: CGFloat = 12

        let canvasW = Int(bodyW + pad * 2)
        let canvasH = Int(bodyH + standNeckH + standFootH + pad * 2)
        guard let ctx = CGImage.rgbaContext(width: canvasW, height: canvasH) else { return screen }

        let centerX = CGFloat(canvasW) / 2
        let footRect = CGRect(x: centerX - standFootW / 2, y: pad, width: standFootW, height: standFootH)
        let neckRect = CGRect(x: centerX - standNeckW / 2, y: footRect.maxY - 2, width: standNeckW, height: standNeckH + 10)
        let bodyRect = CGRect(x: pad, y: footRect.maxY + standNeckH, width: bodyW, height: bodyH)
        let outerRadius: CGFloat = 24

        drawMetallicRoundedRect(in: ctx, rect: neckRect, cornerRadius: 4, finish: finish)
        ctx.setFillColor(rgbColor((0, 0, 0), alpha: 0.16))
        ctx.fill(CGRect(x: neckRect.minX, y: bodyRect.minY - 28, width: standNeckW, height: 28))
        drawMetallicRoundedRect(in: ctx, rect: footRect, cornerRadius: 6, finish: finish)

        let bodyPath = CGPath(roundedRect: bodyRect, cornerWidth: outerRadius, cornerHeight: outerRadius, transform: nil)
        ctx.saveGState()
        ctx.addPath(bodyPath)
        ctx.clip()

        ctx.setFillColor(rgbColor((0.95, 0.96, 0.97)))
        ctx.fill(bodyRect)

        let chinRect = CGRect(x: bodyRect.minX, y: bodyRect.minY, width: bodyW, height: chinH)
        if let chinGrad = CGGradient(
            colorsSpace: sRGB,
            colors: [rgbColor(finish.highlightRGB), rgbColor(finish.primaryRGB)] as CFArray,
            locations: [0.0, 1.0]
        ) {
            ctx.drawLinearGradient(
                chinGrad,
                start: CGPoint(x: chinRect.midX, y: chinRect.maxY),
                end: CGPoint(x: chinRect.midX, y: chinRect.minY),
                options: []
            )
        }
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(bodyPath)
        ctx.setStrokeColor(rgbColor(finish.shadowRGB, alpha: 0.45))
        ctx.setLineWidth(3)
        ctx.strokePath()
        ctx.restoreGState()

        let screenRect = CGRect(x: bodyRect.minX + bezel, y: bodyRect.minY + chinH, width: dispW, height: dispH)
        drawScreenContent(screen, in: ctx, rect: screenRect, cornerRadius: 4, alignTop: false)

        let camD: CGFloat = 10
        ctx.setFillColor(rgbColor((0.18, 0.20, 0.24)))
        ctx.fillEllipse(in: CGRect(x: bodyRect.midX - camD / 2, y: screenRect.maxY + (bezel - camD) / 2, width: camD, height: camD))

        return ctx.makeImage() ?? screen
    }

    // MARK: - Studio Display (2026) / Pro Display XDR + Mac mini / Mac Studio

    private enum DisplayStyle {
        case studioDisplay
        case proDisplayXDR
    }

    private enum DesktopUnitStyle {
        case none
        case macMiniM4
        case macStudio
    }

    private static func renderStandaloneDisplay(screen: CGImage, style: DisplayStyle) -> CGImage {
        renderDesktopSetup(screen: screen, display: style, unit: .none)
    }

    private static func renderDesktopSetup(
        screen: CGImage,
        display: DisplayStyle,
        unit: DesktopUnitStyle
    ) -> CGImage {
        let dispW: CGFloat = (display == .proDisplayXDR) ? 1600 : 1520
        let dispH: CGFloat = (display == .proDisplayXDR) ? 900 : 855
        let bezel: CGFloat = (display == .proDisplayXDR) ? 18 : 34
        let rim: CGFloat = (display == .proDisplayXDR) ? 8 : 6
        let displayW = dispW + (bezel + rim) * 2
        let displayH = dispH + (bezel + rim) * 2

        let standNeckW: CGFloat = (display == .proDisplayXDR) ? 144 : 210
        let standNeckH: CGFloat = (display == .proDisplayXDR) ? 265 : 235
        let standFootW: CGFloat = (display == .proDisplayXDR) ? 310 : 340
        let standFootH: CGFloat = 14
        let pad: CGFloat = 12

        let canvasW = Int(displayW + pad * 2)
        let canvasH = Int(displayH + standNeckH + standFootH + pad * 2)
        guard let ctx = CGImage.rgbaContext(width: canvasW, height: canvasH) else { return screen }

        let centerX = CGFloat(canvasW) / 2
        let footRect = CGRect(x: centerX - standFootW / 2, y: pad, width: standFootW, height: standFootH)
        let neckRect = CGRect(x: centerX - standNeckW / 2, y: footRect.maxY - 2, width: standNeckW, height: standNeckH + 14)
        let displayRect = CGRect(x: pad, y: footRect.maxY + standNeckH, width: displayW, height: displayH)

        drawMetallicRoundedRect(in: ctx, rect: neckRect, cornerRadius: 4, finish: .silver)
        if display == .proDisplayXDR {
            let slotW: CGFloat = 34
            let slotH: CGFloat = 86
            let slotRect = CGRect(x: neckRect.midX - slotW / 2, y: neckRect.minY + 46, width: slotW, height: slotH)
            let slotPath = CGPath(roundedRect: slotRect, cornerWidth: slotW / 2, cornerHeight: slotW / 2, transform: nil)
            ctx.saveGState()
            ctx.setBlendMode(.clear)
            ctx.addPath(slotPath)
            ctx.fillPath()
            ctx.restoreGState()
            ctx.saveGState()
            ctx.addPath(slotPath)
            ctx.setStrokeColor(rgbColor((0.55, 0.56, 0.60), alpha: 0.7))
            ctx.setLineWidth(2.5)
            ctx.strokePath()
            ctx.restoreGState()
        }
        ctx.setFillColor(rgbColor((0, 0, 0), alpha: 0.18))
        ctx.fill(CGRect(x: neckRect.minX, y: displayRect.minY - 30, width: standNeckW, height: 30))
        drawMetallicRoundedRect(in: ctx, rect: footRect, cornerRadius: 5, finish: .silver)

        let outerR: CGFloat = (display == .proDisplayXDR) ? 10 : 16
        drawMetallicRoundedRect(in: ctx, rect: displayRect, cornerRadius: outerR, finish: .silver)
        let glassRect = displayRect.insetBy(dx: rim, dy: rim)
        let glassPath = CGPath(roundedRect: glassRect, cornerWidth: max(4, outerR - rim), cornerHeight: max(4, outerR - rim), transform: nil)
        ctx.saveGState()
        ctx.addPath(glassPath)
        ctx.setFillColor(rgbColor((0.03, 0.03, 0.04)))
        ctx.fillPath()
        ctx.restoreGState()

        let screenRect = glassRect.insetBy(dx: bezel, dy: bezel)
        drawScreenContent(screen, in: ctx, rect: screenRect, cornerRadius: 3, alignTop: false)

        if display == .studioDisplay {
            let camD: CGFloat = 9
            ctx.setFillColor(rgbColor((0.15, 0.19, 0.26)))
            ctx.fillEllipse(in: CGRect(x: displayRect.midX - camD / 2, y: screenRect.maxY + (bezel - camD) / 2, width: camD, height: camD))
        }

        if unit != .none {
            let unitW: CGFloat = (unit == .macMiniM4) ? 286 : 382
            let unitH: CGFloat = (unit == .macMiniM4) ? 104 : 186
            let unitCorner: CGFloat = (unit == .macMiniM4) ? 28 : 36
            let unitRect = CGRect(x: displayRect.maxX - unitW - 44, y: pad + 6, width: unitW, height: unitH)
            drawDesktopUnit(in: ctx, rect: unitRect, cornerRadius: unitCorner, unit: unit)
        }

        return ctx.makeImage() ?? screen
    }

    private static func drawDesktopUnit(
        in ctx: CGContext,
        rect: CGRect,
        cornerRadius: CGFloat,
        unit: DesktopUnitStyle
    ) {
        let baseLipRect = CGRect(x: rect.minX + 20, y: rect.minY - 6, width: rect.width - 40, height: 12)
        let lipPath = CGPath(roundedRect: baseLipRect, cornerWidth: 6, cornerHeight: 6, transform: nil)
        ctx.saveGState()
        ctx.addPath(lipPath)
        ctx.setFillColor(rgbColor((0.10, 0.10, 0.11)))
        ctx.fillPath()
        ctx.restoreGState()

        let unitPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        ctx.saveGState()
        ctx.addPath(unitPath)
        ctx.clip()
        if let bodyGrad = CGGradient(
            colorsSpace: sRGB,
            colors: [
                rgbColor((0.72, 0.73, 0.76)),
                rgbColor((0.91, 0.92, 0.94)),
                rgbColor((0.83, 0.84, 0.87)),
                rgbColor((0.92, 0.93, 0.95)),
                rgbColor((0.70, 0.71, 0.74)),
            ] as CFArray,
            locations: [0.0, 0.16, 0.50, 0.84, 1.0]
        ) {
            ctx.drawLinearGradient(
                bodyGrad,
                start: CGPoint(x: rect.minX, y: rect.midY),
                end: CGPoint(x: rect.maxX, y: rect.midY),
                options: []
            )
        }
        ctx.setFillColor(rgbColor((1, 1, 1), alpha: 0.48))
        ctx.fill(CGRect(x: rect.minX, y: rect.maxY - 6, width: rect.width, height: 6))
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(unitPath)
        ctx.setStrokeColor(rgbColor((0.55, 0.56, 0.60), alpha: 0.55))
        ctx.setLineWidth(2)
        ctx.strokePath()
        ctx.restoreGState()

        let portColor = rgbColor((0.11, 0.11, 0.13))
        switch unit {
        case .macMiniM4:
            let portY = rect.minY + rect.height * 0.42
            for offset in [0, 30] {
                let usbC = CGRect(x: rect.minX + 48 + CGFloat(offset), y: portY, width: 10, height: 22)
                let p = CGPath(roundedRect: usbC, cornerWidth: 5, cornerHeight: 5, transform: nil)
                ctx.addPath(p); ctx.setFillColor(portColor); ctx.fillPath()
            }
            ctx.setFillColor(portColor)
            ctx.fillEllipse(in: CGRect(x: rect.minX + 112, y: portY + 5, width: 12, height: 12))
            ctx.setFillColor(rgbColor((0.97, 0.99, 1.0), alpha: 0.95))
            ctx.fillEllipse(in: CGRect(x: rect.maxX - 42, y: portY + 8, width: 6, height: 6))
        case .macStudio:
            let portY = rect.minY + rect.height * 0.25
            for offset in [0, 32] {
                let tb = CGRect(x: rect.minX + 56 + CGFloat(offset), y: portY, width: 11, height: 24)
                let p = CGPath(roundedRect: tb, cornerWidth: 5.5, cornerHeight: 5.5, transform: nil)
                ctx.addPath(p); ctx.setFillColor(portColor); ctx.fillPath()
            }
            let sdSlot = CGRect(x: rect.minX + 128, y: portY + 8, width: 54, height: 8)
            let sdPath = CGPath(roundedRect: sdSlot, cornerWidth: 4, cornerHeight: 4, transform: nil)
            ctx.addPath(sdPath); ctx.setFillColor(portColor); ctx.fillPath()
            ctx.setFillColor(rgbColor((0.97, 0.99, 1.0), alpha: 0.95))
            ctx.fillEllipse(in: CGRect(x: rect.maxX - 52, y: portY + 9, width: 7, height: 7))
        case .none:
            break
        }
    }

    // MARK: - Apple Watch Ultra 4 & Series 12 / SE 3

    private static func renderWatchUltra(screen: CGImage, finish: DeviceFinish) -> CGImage {
        let dispW: CGFloat = 716
        let dispH: CGFloat = 868
        let bezel: CGFloat = 58
        let titaniumLip: CGFloat = 34
        let bodyW = dispW + (bezel + titaniumLip) * 2
        let bodyH = dispH + (bezel + titaniumLip) * 2
        let lugH: CGFloat = 112
        let leftActionW: CGFloat = 24
        let rightGuardW: CGFloat = 56
        let pad: CGFloat = 18

        let canvasW = Int(bodyW + leftActionW + rightGuardW + pad * 2)
        let canvasH = Int(bodyH + lugH * 2 + pad * 2)
        guard let ctx = CGImage.rgbaContext(width: canvasW, height: canvasH) else { return screen }

        let bodyRect = CGRect(x: pad + leftActionW, y: pad + lugH, width: bodyW, height: bodyH)
        let outerRadius: CGFloat = 178

        let strapW = bodyW * 0.62
        let strapColor = (finish == .blackTitanium) ? rgbColor((0.14, 0.15, 0.17)) : rgbColor((0.88, 0.36, 0.14))
        let topStrap = CGRect(x: bodyRect.midX - strapW / 2, y: bodyRect.maxY - 22, width: strapW, height: lugH + 22)
        let botStrap = CGRect(x: bodyRect.midX - strapW / 2, y: pad, width: strapW, height: lugH + 22)
        for strap in [topStrap, botStrap] {
            let p = CGPath(roundedRect: strap, cornerWidth: 26, cornerHeight: 26, transform: nil)
            ctx.saveGState()
            ctx.addPath(p)
            ctx.setFillColor(strapColor)
            ctx.fillPath()
            ctx.clip()
            ctx.setStrokeColor(rgbColor((0, 0, 0), alpha: 0.16))
            ctx.setLineWidth(4)
            var y = strap.minY + 14
            while y < strap.maxY {
                ctx.move(to: CGPoint(x: strap.minX, y: y))
                ctx.addLine(to: CGPoint(x: strap.maxX, y: y))
                y += 16
            }
            ctx.strokePath()
            ctx.restoreGState()
        }

        let lugW = strapW + 46
        drawMetallicRoundedRect(
            in: ctx,
            rect: CGRect(x: bodyRect.midX - lugW / 2, y: bodyRect.maxY - 26, width: lugW, height: 48),
            cornerRadius: 18,
            finish: finish
        )
        drawMetallicRoundedRect(
            in: ctx,
            rect: CGRect(x: bodyRect.midX - lugW / 2, y: bodyRect.minY - 22, width: lugW, height: 48),
            cornerRadius: 18,
            finish: finish
        )

        let actionRect = CGRect(
            x: bodyRect.minX - leftActionW + 6,
            y: bodyRect.midY - 96,
            width: leftActionW + 10,
            height: 172
        )
        let actionPath = CGPath(roundedRect: actionRect, cornerWidth: 11, cornerHeight: 11, transform: nil)
        ctx.saveGState()
        ctx.addPath(actionPath)
        ctx.setFillColor(rgbColor((0.97, 0.36, 0.10)))
        ctx.fillPath()
        ctx.addPath(actionPath)
        ctx.setStrokeColor(rgbColor((0.72, 0.22, 0.04), alpha: 0.8))
        ctx.setLineWidth(2)
        ctx.strokePath()
        ctx.restoreGState()

        let guardRect = CGRect(
            x: bodyRect.maxX - 38,
            y: bodyRect.minY + bodyH * 0.20,
            width: 68,
            height: bodyH * 0.56
        )
        drawMetallicRoundedRect(in: ctx, rect: guardRect, cornerRadius: 30, finish: finish)

        let crownRect = CGRect(
            x: guardRect.maxX - 18,
            y: bodyRect.maxY - bodyH * 0.42,
            width: 36,
            height: 152
        )
        drawMetallicRoundedRect(in: ctx, rect: crownRect, cornerRadius: 14, finish: finish)
        ctx.saveGState()
        ctx.setStrokeColor(rgbColor((0.15, 0.15, 0.17), alpha: 0.55))
        ctx.setLineWidth(3)
        var gy = crownRect.minY + 14
        while gy < crownRect.maxY - 10 {
            ctx.move(to: CGPoint(x: crownRect.minX + 6, y: gy))
            ctx.addLine(to: CGPoint(x: crownRect.maxX - 4, y: gy))
            gy += 12
        }
        ctx.strokePath()
        ctx.setFillColor(rgbColor((0.97, 0.36, 0.10)))
        ctx.fill(CGRect(x: crownRect.minX + 4, y: crownRect.minY + 24, width: 6, height: crownRect.height - 48))
        ctx.restoreGState()

        let sideBtnRect = CGRect(
            x: guardRect.maxX - 10,
            y: bodyRect.minY + bodyH * 0.25,
            width: 18,
            height: 126
        )
        drawMetallicRoundedRect(in: ctx, rect: sideBtnRect, cornerRadius: 7, finish: finish)

        drawMetallicRoundedRect(in: ctx, rect: bodyRect, cornerRadius: outerRadius, finish: finish)

        let lipInner = bodyRect.insetBy(dx: titaniumLip, dy: titaniumLip)
        let lipPath = CGPath(roundedRect: lipInner, cornerWidth: outerRadius - titaniumLip, cornerHeight: outerRadius - titaniumLip, transform: nil)
        ctx.saveGState()
        ctx.addPath(lipPath)
        ctx.setFillColor(rgbColor((0.025, 0.025, 0.03)))
        ctx.fillPath()
        ctx.addPath(lipPath)
        ctx.setStrokeColor(rgbColor(finish.highlightRGB, alpha: 0.65))
        ctx.setLineWidth(3)
        ctx.strokePath()
        ctx.restoreGState()

        let screenRect = lipInner.insetBy(dx: bezel, dy: bezel)
        let screenRadius = max(48, outerRadius - titaniumLip - bezel)
        drawScreenContent(screen, in: ctx, rect: screenRect, cornerRadius: screenRadius, alignTop: false)

        return ctx.makeImage() ?? screen
    }

    private static func renderWatchSeries(
        screen: CGImage,
        finish: DeviceFinish,
        dispW: CGFloat,
        dispH: CGFloat,
        bezelRatio: CGFloat,
        isSE: Bool
    ) -> CGImage {
        let bezel = (dispW * bezelRatio).rounded()
        let caseRim: CGFloat = 24
        let bodyW = dispW + (bezel + caseRim) * 2
        let bodyH = dispH + (bezel + caseRim) * 2
        let lugH: CGFloat = 104
        let crownExtra: CGFloat = 40
        let pad: CGFloat = 16

        let canvasW = Int(bodyW + crownExtra + pad * 2)
        let canvasH = Int(bodyH + lugH * 2 + pad * 2)
        guard let ctx = CGImage.rgbaContext(width: canvasW, height: canvasH) else { return screen }

        let bodyRect = CGRect(x: pad, y: pad + lugH, width: bodyW, height: bodyH)
        let outerRadius: CGFloat = bodyW * 0.235

        let strapW = bodyW * 0.58
        let strapColor = (finish == .silver || finish == .starlight)
            ? rgbColor((0.86, 0.87, 0.89))
            : rgbColor((0.16, 0.17, 0.19))
        let topStrap = CGRect(x: bodyRect.midX - strapW / 2, y: bodyRect.maxY - 24, width: strapW, height: lugH + 24)
        let botStrap = CGRect(x: bodyRect.midX - strapW / 2, y: pad, width: strapW, height: lugH + 24)
        for strap in [topStrap, botStrap] {
            let p = CGPath(roundedRect: strap, cornerWidth: 28, cornerHeight: 28, transform: nil)
            ctx.saveGState()
            ctx.addPath(p)
            ctx.setFillColor(strapColor)
            ctx.fillPath()
            ctx.restoreGState()
        }

        let crownRect = CGRect(
            x: bodyRect.maxX - 10,
            y: bodyRect.maxY - bodyH * 0.40,
            width: 34,
            height: 132
        )
        drawMetallicRoundedRect(in: ctx, rect: crownRect, cornerRadius: 14, finish: finish)
        ctx.saveGState()
        ctx.setStrokeColor(rgbColor(finish.shadowRGB, alpha: 0.65))
        ctx.setLineWidth(2.5)
        var gy = crownRect.minY + 14
        while gy < crownRect.maxY - 10 {
            ctx.move(to: CGPoint(x: crownRect.minX + 6, y: gy))
            ctx.addLine(to: CGPoint(x: crownRect.maxX - 4, y: gy))
            gy += 11
        }
        ctx.strokePath()
        ctx.restoreGState()

        let sideBtn = CGRect(
            x: bodyRect.maxX - 6,
            y: bodyRect.minY + bodyH * 0.24,
            width: 14,
            height: 122
        )
        drawMetallicRoundedRect(in: ctx, rect: sideBtn, cornerRadius: 6, finish: finish)

        drawMetallicRoundedRect(in: ctx, rect: bodyRect, cornerRadius: outerRadius, finish: finish)

        let glassRect = bodyRect.insetBy(dx: caseRim, dy: caseRim)
        let glassRadius = max(36, outerRadius - caseRim)
        let glassPath = CGPath(roundedRect: glassRect, cornerWidth: glassRadius, cornerHeight: glassRadius, transform: nil)
        ctx.saveGState()
        ctx.addPath(glassPath)
        ctx.setFillColor(rgbColor((0.02, 0.02, 0.03)))
        ctx.fillPath()
        ctx.restoreGState()

        let screenRect = glassRect.insetBy(dx: bezel, dy: bezel)
        let screenRadius = max(28, glassRadius - bezel * (isSE ? 0.65 : 0.85))
        drawScreenContent(screen, in: ctx, rect: screenRect, cornerRadius: screenRadius, alignTop: false)

        return ctx.makeImage() ?? screen
    }

    // MARK: - Apple TV 4K (4th Gen)

    private static func renderAppleTVSetup(
        screen: CGImage,
        finish: DeviceFinish,
        usesStudioDisplay: Bool
    ) -> CGImage {
        let dispW: CGFloat = 1600
        let dispH: CGFloat = 900
        let bezel: CGFloat = usesStudioDisplay ? 30 : 14
        let rim: CGFloat = usesStudioDisplay ? 7 : 5
        let tvW = dispW + (bezel + rim) * 2
        let tvH = dispH + (bezel + rim) * 2
        let deckSpaceH: CGFloat = 210
        let pad: CGFloat = 16

        let canvasW = Int(tvW + pad * 2)
        let canvasH = Int(tvH + deckSpaceH + pad * 2)
        guard let ctx = CGImage.rgbaContext(width: canvasW, height: canvasH) else { return screen }

        let centerX = CGFloat(canvasW) / 2
        let tvRect = CGRect(x: pad, y: pad + deckSpaceH, width: tvW, height: tvH)

        if usesStudioDisplay {
            let neckW: CGFloat = 196
            let footW: CGFloat = 320
            drawMetallicRoundedRect(in: ctx, rect: CGRect(x: centerX - neckW / 2, y: pad + 10, width: neckW, height: deckSpaceH), cornerRadius: 4, finish: .silver)
            drawMetallicRoundedRect(in: ctx, rect: CGRect(x: centerX - footW / 2, y: pad, width: footW, height: 14), cornerRadius: 5, finish: .silver)
        } else {
            let standNeckW: CGFloat = 140
            let standFootW: CGFloat = 460
            drawMetallicRoundedRect(in: ctx, rect: CGRect(x: centerX - standNeckW / 2, y: pad + 12, width: standNeckW, height: deckSpaceH - 6), cornerRadius: 6, finish: finish)
            drawMetallicRoundedRect(in: ctx, rect: CGRect(x: centerX - standFootW / 2, y: pad, width: standFootW, height: 16), cornerRadius: 7, finish: finish)
        }

        drawMetallicRoundedRect(in: ctx, rect: tvRect, cornerRadius: usesStudioDisplay ? 16 : 12, finish: usesStudioDisplay ? .silver : finish)
        let glassRect = tvRect.insetBy(dx: rim, dy: rim)
        let glassPath = CGPath(roundedRect: glassRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
        ctx.saveGState()
        ctx.addPath(glassPath)
        ctx.setFillColor(rgbColor((0.02, 0.02, 0.03)))
        ctx.fillPath()
        ctx.restoreGState()

        let screenRect = glassRect.insetBy(dx: bezel, dy: bezel)
        drawScreenContent(screen, in: ctx, rect: screenRect, cornerRadius: 4, alignTop: false)

        let boxW: CGFloat = 296
        let boxH: CGFloat = 88
        let boxRect = CGRect(x: tvRect.minX + 68, y: pad + 4, width: boxW, height: boxH)
        let boxPath = CGPath(roundedRect: boxRect, cornerWidth: 24, cornerHeight: 24, transform: nil)
        ctx.saveGState()
        ctx.addPath(boxPath)
        ctx.clip()
        if let grad = CGGradient(
            colorsSpace: sRGB,
            colors: [
                rgbColor((0.05, 0.05, 0.06)),
                rgbColor((0.15, 0.16, 0.19)),
                rgbColor((0.07, 0.07, 0.09)),
                rgbColor((0.14, 0.15, 0.18)),
                rgbColor((0.04, 0.04, 0.05)),
            ] as CFArray,
            locations: [0.0, 0.18, 0.50, 0.82, 1.0]
        ) {
            ctx.drawLinearGradient(
                grad,
                start: CGPoint(x: boxRect.minX, y: boxRect.midY),
                end: CGPoint(x: boxRect.maxX, y: boxRect.midY),
                options: []
            )
        }
        ctx.setFillColor(rgbColor((1, 1, 1), alpha: 0.18))
        ctx.fill(CGRect(x: boxRect.minX, y: boxRect.maxY - 5, width: boxW, height: 5))
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(boxPath)
        ctx.setStrokeColor(rgbColor((0.28, 0.29, 0.33), alpha: 0.65))
        ctx.setLineWidth(2)
        ctx.strokePath()
        ctx.setFillColor(rgbColor((0.98, 0.99, 1.0), alpha: 0.96))
        ctx.fillEllipse(in: CGRect(x: boxRect.maxX - 42, y: boxRect.midY - 4, width: 8, height: 8))
        ctx.restoreGState()

        let remW: CGFloat = 104
        let remH: CGFloat = 336
        let remRect = CGRect(x: tvRect.maxX - remW - 76, y: pad + 2, width: remW, height: remH)
        drawDropShadow(in: ctx, rect: remRect, cornerRadius: 24, blur: 26, offsetY: -6, alpha: 0.42)
        drawMetallicRoundedRect(in: ctx, rect: remRect, cornerRadius: 24, finish: .silver)

        ctx.setFillColor(rgbColor((0.15, 0.16, 0.18)))
        ctx.fillEllipse(in: CGRect(x: remRect.maxX - 30, y: remRect.maxY - 34, width: 14, height: 14))

        let padD: CGFloat = 68
        let padRect = CGRect(x: remRect.midX - padD / 2, y: remRect.maxY - 122, width: padD, height: padD)
        ctx.saveGState()
        ctx.setFillColor(rgbColor((0.08, 0.08, 0.09)))
        ctx.fillEllipse(in: padRect)
        ctx.setStrokeColor(rgbColor((0.24, 0.25, 0.27)))
        ctx.setLineWidth(6)
        ctx.strokeEllipse(in: padRect.insetBy(dx: 5, dy: 5))
        ctx.restoreGState()

        let btnD: CGFloat = 24
        let leftColX = remRect.minX + 18
        let rightColX = remRect.maxX - 18 - btnD
        ctx.setFillColor(rgbColor((0.10, 0.10, 0.12)))
        ctx.fillEllipse(in: CGRect(x: leftColX, y: padRect.minY - 42, width: btnD, height: btnD))
        ctx.fillEllipse(in: CGRect(x: rightColX, y: padRect.minY - 42, width: btnD, height: btnD))
        ctx.fillEllipse(in: CGRect(x: leftColX, y: padRect.minY - 78, width: btnD, height: btnD))
        ctx.fillEllipse(in: CGRect(x: leftColX, y: padRect.minY - 114, width: btnD, height: btnD))
        let volRect = CGRect(x: rightColX, y: padRect.minY - 114, width: btnD, height: 60)
        let volPath = CGPath(roundedRect: volRect, cornerWidth: btnD / 2, cornerHeight: btnD / 2, transform: nil)
        ctx.addPath(volPath)
        ctx.fillPath()

        return ctx.makeImage() ?? screen
    }

    // MARK: - Shared Backdrop & Drawing Helpers

    private static func drawStudioBackdrop(
        in ctx: CGContext,
        rect: CGRect,
        options: DeviceFrameOptions,
        screen: CGImage
    ) {
        switch options.backdropKind {
        case .gradient:
            let stops = options.activeGradientStops
            let colors = stops.map { rgbColor($0) }
            let locations: [CGFloat] = stops.count == 3 ? [0.0, 0.50, 1.0] : [0.0, 1.0]
            if let grad = CGGradient(colorsSpace: sRGB, colors: colors as CFArray, locations: locations) {
                switch options.gradientDirection {
                case .diagonalDown:
                    ctx.drawLinearGradient(
                        grad,
                        start: CGPoint(x: rect.minX, y: rect.maxY),
                        end: CGPoint(x: rect.maxX, y: rect.minY),
                        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                    )
                case .diagonalUp:
                    ctx.drawLinearGradient(
                        grad,
                        start: CGPoint(x: rect.minX, y: rect.minY),
                        end: CGPoint(x: rect.maxX, y: rect.maxY),
                        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                    )
                case .vertical:
                    ctx.drawLinearGradient(
                        grad,
                        start: CGPoint(x: rect.midX, y: rect.maxY),
                        end: CGPoint(x: rect.midX, y: rect.minY),
                        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                    )
                case .horizontal:
                    ctx.drawLinearGradient(
                        grad,
                        start: CGPoint(x: rect.minX, y: rect.midY),
                        end: CGPoint(x: rect.maxX, y: rect.midY),
                        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                    )
                case .radial:
                    let center = CGPoint(x: rect.midX, y: rect.midY)
                    let radius = hypot(rect.width, rect.height) * 0.55
                    ctx.drawRadialGradient(
                        grad,
                        startCenter: center,
                        startRadius: 0,
                        endCenter: center,
                        endRadius: radius,
                        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                    )
                }
            }

        case .solidColor:
            ctx.setFillColor(options.solidBackgroundColor.cgColor)
            ctx.fill(rect)

        case .customImage:
            if let bgImage = options.customBackgroundImage?.image {
                let sourceImage: CGImage
                if options.customImageBlur > 0.01 {
                    let ciInput = CIImage(cgImage: bgImage)
                    let sigma = min(48.0, max(0.0, options.customImageBlur * 42.0))
                    let blurred = ciInput
                        .clampedToExtent()
                        .applyingGaussianBlur(sigma: sigma)
                        .cropped(to: ciInput.extent)
                    sourceImage = ciContext.createCGImage(blurred, from: ciInput.extent, format: .RGBA8, colorSpace: sRGB) ?? bgImage
                } else {
                    sourceImage = bgImage
                }

                // Aspect-fill (cover) custom background image cleanly inside studio canvas.
                let srcW = CGFloat(max(sourceImage.width, 1))
                let srcH = CGFloat(max(sourceImage.height, 1))
                let scale = max(rect.width / srcW, rect.height / srcH)
                let drawW = srcW * scale
                let drawH = srcH * scale
                let drawRect = CGRect(
                    x: rect.midX - drawW / 2,
                    y: rect.midY - drawH / 2,
                    width: drawW,
                    height: drawH
                )
                ctx.saveGState()
                ctx.clip(to: rect)
                ctx.interpolationQuality = .high
                ctx.draw(sourceImage, in: drawRect)
                if options.customImageDim > 0.005 {
                    let dimAlpha = CGFloat(min(0.65, max(0.0, options.customImageDim)))
                    ctx.setFillColor(rgbColor((0, 0, 0), alpha: dimAlpha))
                    ctx.fill(rect)
                }
                ctx.restoreGState()
            } else {
                drawAdaptiveBlurBackdrop(screen: screen, in: ctx, rect: rect)
            }

        case .adaptiveBlur:
            drawAdaptiveBlurBackdrop(screen: screen, in: ctx, rect: rect)
        }
    }

    private static func drawScreenContent(
        _ screen: CGImage,
        in ctx: CGContext,
        rect: CGRect,
        cornerRadius: CGFloat,
        alignTop: Bool
    ) {
        let clipPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        ctx.saveGState()
        ctx.addPath(clipPath)
        ctx.clip()

        ctx.setFillColor(rgbColor((0.06, 0.06, 0.07)))
        ctx.fill(rect)

        let srcW = CGFloat(screen.width)
        let srcH = CGFloat(screen.height)
        guard srcW > 0, srcH > 0 else {
            ctx.restoreGState()
            return
        }

        let srcAspect = srcW / srcH
        let dstAspect = rect.width / rect.height

        let drawRect: CGRect
        if alignTop && srcAspect < dstAspect * 1.18 && srcAspect > dstAspect * 0.42 {
            let w = rect.width
            let h = w / srcAspect
            drawRect = CGRect(x: rect.minX, y: rect.maxY - h, width: w, height: h)
        } else if abs(srcAspect - dstAspect) / max(dstAspect, 0.01) < 0.24 {
            let scale = max(rect.width / srcW, rect.height / srcH)
            let w = srcW * scale
            let h = srcH * scale
            drawRect = CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)
        } else {
            if let wallGrad = CGGradient(
                colorsSpace: sRGB,
                colors: [
                    rgbColor((0.08, 0.16, 0.24)),
                    rgbColor((0.12, 0.22, 0.34)),
                    rgbColor((0.18, 0.16, 0.32)),
                ] as CFArray,
                locations: [0.0, 0.52, 1.0]
            ) {
                ctx.drawLinearGradient(
                    wallGrad,
                    start: CGPoint(x: rect.minX, y: rect.minY),
                    end: CGPoint(x: rect.maxX, y: rect.maxY),
                    options: []
                )
            }
            if let tiny = CGImage.rgbaContext(width: 12, height: 12) {
                tiny.interpolationQuality = .high
                tiny.draw(screen, in: CGRect(x: 0, y: 0, width: 12, height: 12))
                if let bg = tiny.makeImage() {
                    ctx.saveGState()
                    ctx.setAlpha(0.28)
                    ctx.interpolationQuality = .high
                    ctx.draw(bg, in: rect)
                    ctx.restoreGState()
                }
            }
            let inset = rect.insetBy(dx: rect.width * 0.04, dy: rect.height * 0.05)
            let scale = min(inset.width / srcW, inset.height / srcH)
            let w = srcW * scale
            let h = srcH * scale
            let cardRect = CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)
            let cardRadius = min(w, h) * 0.04
            drawDropShadow(in: ctx, rect: cardRect, cornerRadius: cardRadius, blur: 24, offsetY: -6, alpha: 0.38)
            let cardPath = CGPath(roundedRect: cardRect, cornerWidth: cardRadius, cornerHeight: cardRadius, transform: nil)
            ctx.addPath(cardPath)
            ctx.clip()
            drawRect = cardRect
        }

        ctx.interpolationQuality = .high
        ctx.draw(screen, in: drawRect)
        ctx.restoreGState()
    }

    private static func drawMetallicRoundedRect(
        in ctx: CGContext,
        rect: CGRect,
        cornerRadius: CGFloat,
        finish: DeviceFinish
    ) {
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        if let grad = CGGradient(
            colorsSpace: sRGB,
            colors: [
                rgbColor(finish.highlightRGB),
                rgbColor(finish.primaryRGB),
                rgbColor(finish.shadowRGB),
            ] as CFArray,
            locations: [0.0, 0.48, 1.0]
        ) {
            ctx.drawLinearGradient(
                grad,
                start: CGPoint(x: rect.minX, y: rect.maxY),
                end: CGPoint(x: rect.maxX, y: rect.minY),
                options: []
            )
        }
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(path)
        ctx.setStrokeColor(rgbColor(finish.highlightRGB, alpha: 0.52))
        ctx.setLineWidth(2)
        ctx.strokePath()
        ctx.restoreGState()
    }

    private static func drawDropShadow(
        in ctx: CGContext,
        rect: CGRect,
        cornerRadius: CGFloat,
        blur: CGFloat,
        offsetY: CGFloat,
        alpha: CGFloat
    ) {
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: offsetY), blur: blur, color: rgbColor((0, 0, 0), alpha: alpha))
        ctx.addPath(path)
        ctx.setFillColor(rgbColor((0, 0, 0), alpha: 0.9))
        ctx.fillPath()
        ctx.restoreGState()
    }

    private static func drawSideButton(in ctx: CGContext, rect: CGRect, color: CGColor) {
        let path = CGPath(roundedRect: rect, cornerWidth: rect.width / 2, cornerHeight: rect.width / 2, transform: nil)
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setFillColor(color)
        ctx.fillPath()
        ctx.restoreGState()
    }

    private static func rgbColor(_ rgb: (CGFloat, CGFloat, CGFloat), alpha: CGFloat = 1) -> CGColor {
        CGColor(colorSpace: sRGB, components: [rgb.0, rgb.1, rgb.2, alpha])!
    }
}
