import Foundation

/// Text from docs/ios/copy.md, by number.
///
/// The number is the key in Localizable.xcstrings, which `tools/l10n/sync.py` generates from
/// copy.md. In a view a literal is enough: `Text("4.4.1")`, `Button("5.1.3") {}`,
/// `.accessibilityLabel("4.8.1")`. These helpers are for strings that have to be made in code:
/// the four `{n}` rows, the summary, and the title of a checklist row.
enum L10n {

    /// The text of one numbered row, for code that can't hold a literal.
    static func text(_ number: String, bundle: Bundle? = nil) -> String {
        String(localized: String.LocalizationValue(number), bundle: bundle)
    }

    // The four {n} rows of copy.md §4.3, with the plural forms of each language.

    /// 4.3.1:「{n} 張人臉」, "{n} faces".
    static func faces(_ n: Int, bundle: Bundle? = nil) -> String {
        plural("4.3.1", count: n, bundle: bundle)
    }

    /// 4.3.2:「{n} 處文字」, "{n} lines of text".
    static func textLines(_ n: Int, bundle: Bundle? = nil) -> String {
        plural("4.3.2", count: n, bundle: bundle)
    }

    /// 4.3.3:「{n} 個 QR Code」, "{n} QR Codes".
    static func qrCodes(_ n: Int, bundle: Bundle? = nil) -> String {
        plural("4.3.3", count: n, bundle: bundle)
    }

    /// 4.3.4:「{n} 個條碼」, "{n} barcodes".
    static func barcodes(_ n: Int, bundle: Bundle? = nil) -> String {
        plural("4.3.4", count: n, bundle: bundle)
    }

    /// Evaluates `.stringsdict` plural rules using the target `.lproj` bundle's language locale so
    /// singular/plural grammar is always accurate even when the host locale differs.
    private static func plural(_ key: String, count: Int, bundle: Bundle?) -> String {
        let target = bundle ?? .main
        let format = target.localizedString(forKey: key, value: nil, table: nil)
        let locale = bundle.flatMap(locale(for:)) ?? .current
        return String(format: format, locale: locale, count)
    }

    private static func locale(for bundle: Bundle) -> Locale? {
        let name = bundle.bundleURL.lastPathComponent
        guard name.hasSuffix(".lproj") else { return nil }
        let identifier = String(name.dropLast(".lproj".count))
        return identifier.isEmpty ? nil : Locale(identifier: identifier)
    }

    /// The parts of the summary that have something, in the fixed order of copy.md §4.3: faces,
    /// text, QR codes, barcodes. What is zero is left out.
    static func parts(_ found: FoundCounts, bundle: Bundle? = nil) -> [String] {
        var parts: [String] = []
        if found.faces > 0 { parts.append(faces(found.faces, bundle: bundle)) }
        if found.textLines > 0 { parts.append(textLines(found.textLines, bundle: bundle)) }
        if found.qrCodes > 0 { parts.append(qrCodes(found.qrCodes, bundle: bundle)) }
        if found.barcodes > 0 { parts.append(barcodes(found.barcodes, bundle: bundle)) }
        return parts
    }

    /// What the top of Review Each Item shows (design.md §7.4.2): the parts with「 · 」between, the
    /// dot held to its neighbours by no-break spaces so it never ends a line alone. Empty when
    /// nothing was found, in which case there is no summary (copy.md §4.3).
    static func summary(_ found: FoundCounts, bundle: Bundle? = nil) -> String {
        parts(found, bundle: bundle).joined(separator: text("4.3.sep", bundle: bundle))
    }

    /// The same for VoiceOver (copy.md §7 rule), a sentence:「找到 2 張人臉、5 處文字和 1 個 QR Code」,
    /// "Found 2 faces, 5 lines of text and 1 QR Code". Empty when nothing was found.
    static func screenReaderSummary(_ found: FoundCounts, bundle: Bundle? = nil) -> String {
        let parts = parts(found, bundle: bundle)
        guard let last = parts.last else { return "" }
        let head = parts.dropLast().joined(separator: text("7.1.join", bundle: bundle))
        let join = parts.count > 1 ? text("7.1.lastJoin", bundle: bundle) : ""
        return text("7.1.lead", bundle: bundle) + " " + head + join + last
    }

    /// The title of a checklist row (copy.md §4.5):「人臉」, or「人臉 2」when the kind has several;
    /// "Face 2" in English.
    static func rowTitle(_ kind: RowKind, number: Int?, bundle: Bundle? = nil) -> String {
        let name = text(kind.rawValue, bundle: bundle)
        return number.map { "\(name) \($0)" } ?? name
    }

    /// Compact live badge for how many areas are currently masked (e.g. "已遮 4 处" / "4 Covered").
    static func coveredCount(_ count: Int, bundle: Bundle? = nil) -> String {
        guard count > 0 else { return text("editor.noCoverYet", bundle: bundle) }
        let format = text("editor.coveredFormat", bundle: bundle)
        let locale = bundle.flatMap(locale(for:)) ?? .current
        return String(format: format, locale: locale, count)
    }

    /// Toast message when Apple Intelligence smart scan adds extra covered items.
    static func intelligenceAdded(_ count: Int, bundle: Bundle? = nil) -> String {
        let format = text("ai.addedFormat", bundle: bundle)
        let locale = bundle.flatMap(locale(for:)) ?? .current
        return String(format: format, locale: locale, count)
    }

    /// Formatted app version string for the About screen header (e.g. "Version 1.0 (3)" / "版本 1.0 (3)").
    static func aboutVersion(_ version: String, build: String, bundle: Bundle? = nil) -> String {
        let format = text("about.versionFormat", bundle: bundle)
        let locale = bundle.flatMap(locale(for:)) ?? .current
        return String(format: format, locale: locale, version, build)
    }

    /// Formatted version pill inside the What's New header (e.g. "Version 1.0 (5)" / "版本 1.0 (5)").
    static func whatsNewVersion(_ version: String, bundle: Bundle? = nil) -> String {
        let format = text("whatsnew.versionFormat", bundle: bundle)
        let locale = bundle.flatMap(locale(for:)) ?? .current
        return String(format: format, locale: locale, version)
    }

    /// Search result count heading in EmojiPickerSheet (e.g. "找到 12 个表情" / "12 matches").
    static func emojiSearchCount(_ count: Int, bundle: Bundle? = nil) -> String {
        let format = text("emoji.searchCountFormat", bundle: bundle)
        let locale = bundle.flatMap(locale(for:)) ?? .current
        return String(format: format, locale: locale, count)
    }

    /// Apple Photos-style subtitle count for All Photos (e.g. "128 张照片" / "128 Photos").
    static func libraryPhotoCount(_ count: Int, bundle: Bundle? = nil) -> String {
        let format = text("library.photoCountFormat", bundle: bundle)
        let locale = bundle.flatMap(locale(for:)) ?? .current
        return String(format: format, locale: locale, count)
    }

    /// Apple Photos-style subtitle count for Screenshots (e.g. "24 张截图" / "24 Screenshots").
    static func libraryScreenshotCount(_ count: Int, bundle: Bundle? = nil) -> String {
        let format = text("library.screenshotCountFormat", bundle: bundle)
        let locale = bundle.flatMap(locale(for:)) ?? .current
        return String(format: format, locale: locale, count)
    }

    /// Multi-select stitch button title (e.g. "拼成长截图 (3)" / "Stitch Long (3)").
    static func longshotStitchButton(_ count: Int, bundle: Bundle? = nil) -> String {
        let format = text("longshot.stitchButtonFormat", bundle: bundle)
        let locale = bundle.flatMap(locale(for:)) ?? .current
        return String(format: format, locale: locale, count)
    }

    /// Subtitle while multi-selecting frames inside Library grid.
    static func longshotSelectHint(_ count: Int, bundle: Bundle? = nil) -> String {
        guard count > 0 else { return text("longshot.selectZero", bundle: bundle) }
        let format = text("longshot.selectCountFormat", bundle: bundle)
        let locale = bundle.flatMap(locale(for:)) ?? .current
        return String(format: format, locale: locale, count)
    }

    /// Detected overlap count badge in stitched preview (e.g. "自动去重 2 处" / "2 overlaps merged").
    static func longshotOverlapCount(_ count: Int, bundle: Bundle? = nil) -> String {
        let format = text("longshot.overlapFormat", bundle: bundle)
        let locale = bundle.flatMap(locale(for:)) ?? .current
        return String(format: format, locale: locale, count)
    }

    /// Seam pill title in long-screenshot seam adjuster (e.g. "接缝 1" / "Seam 1").
    static func longshotSeamTitle(_ index: Int, bundle: Bundle? = nil) -> String {
        let format = text("longshot.seamFormat", bundle: bundle)
        let locale = bundle.flatMap(locale(for:)) ?? .current
        return String(format: format, locale: locale, index)
    }

    /// Hub CTA title for starting stitch with selected count (e.g. "开始拼接 (3)" / "Stitch (3)").
    static func longshotStartStitch(_ count: Int, bundle: Bundle? = nil) -> String {
        let format = text("longshot.hub.startStitchFormat", bundle: bundle)
        let locale = bundle.flatMap(locale(for:)) ?? .current
        return String(format: format, locale: locale, count)
    }

    /// The app's strings in one language ("en", "zh-Hans", "zh-Hant"), for tests and previews.
    static func bundle(for language: String) -> Bundle {
        if let path = Bundle.main.path(forResource: language, ofType: "lproj"), let bundle = Bundle(path: path) {
            return bundle
        }
        return .main
    }
}
