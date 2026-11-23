import SwiftUI

/// The 29×29 tile at the start of a row (design.md §4): corner 7, the first fill as its ground, an
/// 18 pt medium symbol in the accent colour. The first row of the picker is the one exception:
/// `#7B2FE0` and white.
struct IconTile: View {
    let systemImage: String
    var ground: Color = Theme.fill
    var tint: Color = Theme.accent

    var body: some View {
        Image(systemName: systemImage)
            .font(.tileIcon)
            .foregroundStyle(tint)
            .frame(width: 29, height: 29)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(ground))
    }
}

/// What a list row is made of (design.md §4「行」): the tile, then the text (`.body`, two lines at
/// most) with a `.footnote` 2 under it when it has one, then whatever closes the row on the right.
/// At least 52 high, 9 above and below, 16 on each side. A row with a footnote keeps to the top.
struct RowContent<Trailing: View>: View {
    let systemImage: String
    let title: Text
    var footnote: Text? = nil
    var ground: Color = Theme.fill
    var tint: Color = Theme.accent
    /// A row that can't be used (design.md §7.1.3): text, arrow and symbol in the tertiary colour,
    /// the tile on the first fill.
    var isDimmed = false
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: footnote == nil ? .center : .top, spacing: 12) {
            IconTile(systemImage: systemImage,
                     ground: isDimmed ? Theme.fill : ground,
                     tint: isDimmed ? Theme.tertiary : tint)
            VStack(alignment: .leading, spacing: 2) {
                title
                    .font(.body)
                    .foregroundStyle(isDimmed ? Theme.tertiary : Theme.body)
                    .lineLimit(2)
                if let footnote {
                    footnote
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryLabel)
                        .lineLimit(3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .frame(minHeight: Metrics.rowMinHeight)
    }
}

/// A row of the picker (design.md §7.1.1): a `chevron.right` in the tertiary colour on the right,
/// the whole row tappable. A row that can't be used doesn't answer (§7.1.3).
struct PickerRow: View {
    let systemImage: String
    let title: LocalizedStringKey
    var isEnabled = true
    var ground: Color = Theme.fill
    var tint: Color = Theme.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RowContent(systemImage: systemImage, title: Text(title),
                       ground: ground, tint: tint, isDimmed: !isEnabled) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.tertiary)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

/// A row that switches something on or off (design.md §4, §9.5): the whole row answers a tap, not
/// only the switch. VoiceOver reads the title (and the footnote when there is one), then the state
/// when the row has words for it (「已遮」/「沒遮」, 4.5.15 and 4.5.16), then the hint (7.2); the switch
/// itself stays out of its way.
struct ToggleRow: View {
    let systemImage: String
    let title: Text
    var footnote: Text? = nil
    @Binding var isOn: Bool
    /// The numbers of the words for on and off; nil when the switch's own on and off is what's
    /// read (the「看原圖」row, copy.md 7.3).
    var stateKeys: (on: LocalizedStringKey, off: LocalizedStringKey)? = ("4.5.15", "4.5.16")
    var hint: LocalizedStringKey? = "7.2"

    var body: some View {
        RowContent(systemImage: systemImage, title: title, footnote: footnote) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .onTapGesture { isOn.toggle() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(stateKeys.map { isOn ? $0.on : $0.off })
        .accessibilityHint(hint)
        .accessibilityAddTraits(stateKeys == nil ? [.isButton, .isToggle] : [.isButton])
        .accessibilityAction(.default) { isOn.toggle() }
    }
}

private extension View {
    /// `accessibilityValue(_:)` and `accessibilityHint(_:)` for a copy.md number that may be absent.
    @ViewBuilder func accessibilityValue(_ key: LocalizedStringKey?) -> some View {
        if let key { accessibilityValue(Text(key)) } else { self }
    }

    @ViewBuilder func accessibilityHint(_ key: LocalizedStringKey?) -> some View {
        if let key { accessibilityHint(Text(key)) } else { self }
    }
}
