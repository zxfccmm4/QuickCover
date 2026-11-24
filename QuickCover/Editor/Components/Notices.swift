import SwiftUI

/// A notice bar (design.md §4「提醒条」): corner 12, 12 left, 8 right, 8 above and below, a 20 pt
/// symbol, a `.footnote` in the body colour, and a small or a text button at the right end when
/// there is one. The blur notice is this twice: in Review Each Item as 4.7.5 with nothing at the end
/// (`trailing: { EmptyView() }`), on the export page as 6.3.1 with the small button 6.3.2「改用純色」
/// (design.md §7.4.4, §7.5). The save-failed notice (6.4.2) is it too.
/// From AX1 on the words are too wide to share a line with a button: the button goes under the
/// text, 12 below and to the left (design.md §9.5, nothing cut to an ellipsis).
struct NoticeBar<Trailing: View>: View {
    let systemImage: String
    let tint: Color
    let ground: Color
    let text: LocalizedStringKey
    @ViewBuilder let trailing: () -> Trailing
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        symbol
                        words
                    }
                    trailing()
                }
            } else {
                HStack(spacing: 8) {
                    symbol
                    words
                    // The button keeps its whole name; the text wraps instead, up to its three lines.
                    trailing()
                        .layoutPriority(1)
                }
            }
        }
        .padding(insets)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ground))
    }

    private var symbol: some View {
        Image(systemName: systemImage)
            .font(.noticeIcon)
            .foregroundStyle(tint)
            .accessibilityHidden(true)
    }

    private var words: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Theme.body)
            // Under the accessibility sizes the text wraps instead of the button, up to its three lines;
            // from AX1 on the button is under it, so the text takes every line it needs.
            .lineLimit(typeSize.isAccessibilitySize ? nil : 3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var insets: EdgeInsets {
        EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 8)
    }
}

/// The card at the bottom of the editor (design.md §4「提示卡」): corner 16, 18 above, 16 left and
/// right, 14 below, centred: a 40 pt symbol, a `.headline` white title, a `.footnote` `#A5A5AA`
/// body 4 under it, a button 12 under that. Nothing Found (§7.3.4) and Hasn't Been Checked (§7.3.5).
struct CalloutCard<Action: View>: View {
    let systemImage: String
    var tint: Color = Theme.accent
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    /// Whether the title and the message are read as one static text (design.md §9.2, the editor's
    /// card). Off by default: the two stay two texts.
    var readsTogether = false
    @ViewBuilder let action: () -> Action

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            if readsTogether {
                VStack(spacing: 0) { words }
                    .accessibilityElement(children: .combine)
            } else {
                words
            }
            action()
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
    }

    @ViewBuilder private var words: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(Theme.body)
            .multilineTextAlignment(.center)
            .padding(.top, 10)
        Text(message)
            .font(.footnote)
            .foregroundStyle(Theme.calloutText)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }
}

/// 「已存到照片」and「已拷貝」on the export page (design.md §7.5.4, §4): a capsule of glass, 40 high,
/// corner 20, a 20 pt checkmark in `#6FE0A0`, white `.subheadline`, 12 left and 16 right. It fades
/// in 0.25 s and out 0.3 s (design.md §8); where it stands and how long it stays is the page's business.
struct Toast: View {
    let text: LocalizedStringKey
    let isShown: Bool
    var fadeIn: Double = 0.25
    var fadeOut: Double = 0.3

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.saved)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.body)
                .lineLimit(1)
        }
        .padding(.leading, 12)
        .padding(.trailing, 16)
        .frame(height: 40)
        .glassEffect(.regular, in: .capsule)
        .opacity(isShown ? 1 : 0)
        .offset(y: isShown ? 0 : 8)
        .animation(.easeInOut(duration: isShown ? fadeIn : fadeOut), value: isShown)
        .allowsHitTesting(false)
    }
}

/// The summary at the top of Review Each Item (design.md §7.4.2): 4.3.1–4.3.4 in a fixed order with
///「 · 」between, `.title2` bold; it wraps rather than shrinks. VoiceOver gets the sentence of
/// copy.md §7 instead (`L10n.screenReaderSummary`).
struct SummaryText: View {
    let found: FoundCounts

    var body: some View {
        Text(L10n.summary(found))
            .font(.title2.bold())
            .foregroundStyle(Theme.body)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(L10n.screenReaderSummary(found))
    }
}

/// The app icon's picture on the primer (design.md §10.2): 132 pt, corners 29.5 continuous, a 1 pt
/// white 14% edge so the dark square shows against the black page.
struct IconArtwork: View {
    var body: some View {
        Image("IconArtwork")
            .resizable()
            .frame(width: 132, height: 132)
            .clipShape(RoundedRectangle(cornerRadius: 29.5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 29.5, style: .continuous)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }
}
