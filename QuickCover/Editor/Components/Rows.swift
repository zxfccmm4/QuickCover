import SwiftUI

/// Rounded icon badge matching Apple Settings & Files visual craft, using concentric geometry.
struct IconTile: View {
    let systemImage: String
    var ground: Color = Theme.fill
    var tint: Color = Theme.accent

    var body: some View {
        Image(systemName: systemImage)
            .font(.tileIcon)
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(tint)
            .frame(width: 30, height: 30)
            .background(
                ConcentricRectangle(corners: .concentric(minimum: 8), isUniform: true)
                    .fill(ground)
            )
            .accessibilityHidden(true)
    }
}

/// Reusable Apple-style list row layout with leading icon badge, adaptive body/footnote stack, and
/// trailing control.
struct RowContent<Trailing: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let systemImage: String
    let title: Text
    var footnote: Text? = nil
    var footnoteTint: Color = Theme.secondaryLabel
    var ground: Color = Theme.fill
    var tint: Color = Theme.accent
    var isDimmed = false
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: footnote == nil ? .center : .top, spacing: 12) {
            IconTile(
                systemImage: systemImage,
                ground: isDimmed ? Theme.fill : ground,
                tint: isDimmed ? Theme.tertiary : tint
            )
            .padding(.top, footnote == nil ? 0 : 2)

            VStack(alignment: .leading, spacing: 2) {
                title
                    .font(.body)
                    .foregroundStyle(isDimmed ? Theme.tertiary : Theme.body)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                if let footnote {
                    footnote
                        .font(.footnote)
                        .foregroundStyle(footnoteTint)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing()
        }
        .padding(.vertical, 3)
    }
}

/// Interactive row for the native `List` on PickerScreen with system-style disclosure indicator.
struct PickerRow: View {
    let systemImage: String
    let title: LocalizedStringKey
    var footnote: LocalizedStringKey? = nil
    var footnoteTint: Color = Theme.secondaryLabel
    var isEnabled = true
    var ground: Color = Theme.fill
    var tint: Color = Theme.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RowContent(
                systemImage: systemImage,
                title: Text(title),
                footnote: footnote.map { Text($0) },
                footnoteTint: footnoteTint,
                ground: ground,
                tint: tint,
                isDimmed: !isEnabled
            ) {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

/// Full-row switch with combined VoiceOver semantics.
struct ToggleRow: View {
    let systemImage: String
    let title: Text
    var footnote: Text? = nil
    @Binding var isOn: Bool
    var stateKeys: (on: LocalizedStringKey, off: LocalizedStringKey)? = ("4.5.15", "4.5.16")
    var hint: LocalizedStringKey? = "7.2"

    var body: some View {
        RowContent(systemImage: systemImage, title: title, footnote: footnote) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(nil)
                .accessibilityHidden(true)
        }
        .contentShape(.rect)
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
    @ViewBuilder func accessibilityValue(_ key: LocalizedStringKey?) -> some View {
        if let key { accessibilityValue(Text(key)) } else { self }
    }

    @ViewBuilder func accessibilityHint(_ key: LocalizedStringKey?) -> some View {
        if let key { accessibilityHint(Text(key)) } else { self }
    }
}
