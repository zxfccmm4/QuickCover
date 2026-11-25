import CoreGraphics
import SwiftUI

/// Pure derived display rules for `ExportScreen`, cleanly testable without UI.
struct ExportFacts: Equatable {
    let style: MaskStyle
    let stripMetadata: Bool
    /// Whether the user explicitly selected blur during this editing session (§7.5.2).
    let blurPickedThisTime: Bool
    /// Whether any enabled cover is recognized text (`EditorModel.coversText`).
    let coversText: Bool

    /// Advisory shown when blur was carried over from a previous launch rather than picked now (§7.5.2).
    var showsBlurNotice: Bool { style == .blur && !blurPickedThisTime }
    /// Mosaic retains cell luminance variation over text (copy.md 6.3.3).
    var showsMosaicNotice: Bool { style == .mosaic && coversText }
    /// Stripes retain cell luminance variation inside diagonal bars over text (copy.md 6.3.5).
    var showsStripesNotice: Bool { style == .stripes && coversText }
    /// Whether an advisory banner appears beneath the export settings card.
    var showsNotice: Bool { showsBlurNotice || showsMosaicNotice || showsStripesNotice }

    /// Localization key for the active advisory banner, if any.
    var noticeKey: LocalizedStringKey? {
        if showsMosaicNotice { return "6.3.3" }
        if showsStripesNotice { return "6.3.5" }
        if showsBlurNotice { return "6.3.1" }
        return nil
    }

    /// Confirmation line (`6.2.4`) shown for zero-trace opaque styles (solid, conceal, emoji).
    var showsCoveredLine: Bool { style.leavesNoTrace }
    /// Metadata row footnote: `6.2.2` when stripping metadata, `6.2.3` when keeping it.
    var footnote: LocalizedStringKey { stripMetadata ? "6.2.2" : "6.2.3" }
    /// Maximum preview height reserves extra breathing room when an advisory banner is visible.
    var pictureMaxHeight: CGFloat { showsNotice ? 285 : 380 }

    /// Fitted preview dimensions preserving the picture's aspect ratio.
    func pictureSize(aspect: CGFloat, maxWidth: CGFloat = 300) -> CGSize {
        PictureFit.size(aspect: aspect, maxWidth: maxWidth, maxHeight: pictureMaxHeight)
    }
}

/// Scales an aspect ratio cleanly inside a bounding box.
enum PictureFit {
    static func size(aspect: CGFloat, maxWidth: CGFloat, maxHeight: CGFloat) -> CGSize {
        guard aspect.isFinite, aspect > 0 else { return .zero }
        if maxWidth / aspect <= maxHeight {
            return CGSize(width: maxWidth, height: maxWidth / aspect)
        }
        return CGSize(width: maxHeight * aspect, height: maxHeight)
    }
}

/// Toast animation timings for "Saved to Photos" / "Copied" (§8, §7.5.4).
enum ExportToastTiming {
    static let fadeIn: Double = 0.25
    static let fadeOut: Double = 0.3
    static let shows: Duration = .seconds(1.6)
    static let clears: Duration = .seconds(fadeOut + 0.1)
}
