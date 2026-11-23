import SwiftUI
import UIKit

/// The colours and type of design.md §2–§3. The app has one look, dark (§11.1), so each use has a
/// single value. Six colours are the asset catalog's colour sets and carry the names the spec uses;
/// Any and Dark hold the same value, so a screen that forgot to force dark shows nothing odd either.
enum Theme {
    /// `#6FE0DA`: what can be tapped and the selected tool. 13.3:1 on black, 10.8:1 on a card.
    static let accent = Color("AccentColor")
    /// `#6FE0DA`, on the picture and on glass: the drawn and located edges, the selected tool,
    /// button text on the picture.
    static let accentOnBlack = Color("AccentOnBlack")
    /// `#0B7A7A`: the ground of the primary button, of「匯出」and of the picker's first icon tile. White
    /// on it is 5.2:1.
    static let accentButton = Color("AccentButton")
    /// `#A5A5AA`: explanatory text. Not `.secondary`, which follows the appearance and the material.
    static let secondaryLabel = Color("SecondaryLabel")
    /// `#1C1C1E`: cards, and the callout at the bottom of the editor.
    static let card = Color("CalloutBackground")
    /// `#A5A5AA`: the body of the callout.
    static let calloutText = Color("CalloutSecondaryText")

    // The rest of the §2 table. The spec asks for six colour sets only, so these are made here.
    /// `#FFFFFF`.
    static let body = Color.white
    /// `#6C6C70`: what is switched off and what is only decoration (the chevrons). Never text to read.
    static let tertiary = Color(hex: 0x6C6C70)
    /// `#545458` at 55%.
    static let separator = Color(hex: 0x545458).opacity(0.55)
    /// `#767680` at 24%: the track of the style picker, the ground of a leading icon tile.
    static let fill = Color(.tertiarySystemFill)
    /// `#787880` at 30%: secondary buttons, the track of a switch, the save-failed notice.
    static let fillTwo = Color(.quaternarySystemFill)
    /// `#FF9F0A` at 16%: the blur notice. Its symbol is `#C86A00`, 3.3:1 on it.
    static let blurNotice = Color(hex: 0xFF9F0A).opacity(0.16)
    static let blurNoticeIcon = Color(hex: 0xC86A00)
    /// `#0B3B3F`: the symbol on the selected tool, on `Theme.accent`. 7.8:1. The one place it is used,
    /// so the spec asks for no colour set (§2).
    static let onAccent = Color(hex: 0x0B3B3F)
    /// `#6FE0A0`: the checkmark of the「已存到照片」toast.
    static let saved = Color(hex: 0x6FE0A0)
    /// The symbol of a notice that failed: `#FF3B30` on the second fill, `#FF453A` on a card.
    static let errorIcon = Color(hex: 0xFF3B30)
    /// What can't be used is drawn at 42% (§2, §6).
    static let disabledOpacity = 0.42
    /// The page: pure black. The picture is the only bright thing (§1).
    static let page = Color.black
}

extension Color {
    /// sRGB, the way design.md writes its values.
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

extension Font {
    /// 21 pt semibold: the symbols on glass (§6, §10.3). Fixed: a symbol isn't text to read.
    static let glassIcon = Font.system(size: 21, weight: .semibold)
    /// 18 pt medium: the symbol in a leading icon tile (§4).
    static let tileIcon = Font.system(size: 18, weight: .medium)
    /// 20 pt: the symbol of a notice bar and of the toast (§4, §10.3).
    static let noticeIcon = Font.system(size: 20, weight: .medium)
    /// 17 pt semibold at the default size: the text of every button but the plain one (§3, §6). It
    /// follows the text size like all text does.
    static let buttonText = Font.system(.body).weight(.semibold)
    /// 15 pt semibold at the default size: the small button and the text button (§6).
    static let smallButtonText = Font.system(.subheadline).weight(.semibold)
}

/// design.md §4, the sizes every page shares.
enum Metrics {
    /// 16: the page's sides, and the inside of a card.
    static let pageInset: CGFloat = 16
    /// 12: the corner of a card (the system's own when `List` is used).
    static let cardRadius: CGFloat = 12
    /// 20: between two cards.
    static let cardSpacing: CGFloat = 20
    /// 52: the least height of a row.
    static let rowMinHeight: CGFloat = 52
    /// 44: the least thing that can be tapped (§9.5).
    static let minimumTarget: CGFloat = 44
}
