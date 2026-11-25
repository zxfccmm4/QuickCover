import SwiftUI

/// Continuous-corner icon badge matching Apple Settings & Files visual craft.
struct IconTile: View {
    let systemImage: String
    var ground: Color = Theme.fill
    var tint: Color = Theme.accent

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        Image(systemName: systemImage)
            .font(.tileIcon)
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(tint)
            .frame(width: 30, height: 30)
            .background(shape.fill(ground))
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

/// Tactile Apple Settings-style row highlight on press for grouped cards outside `List`.
private struct GroupedRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Theme.fill : Color.clear)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

/// Interactive row for grouped cards on PickerScreen with native disclosure chevron and press highlight.
struct PickerRow: View {
    let systemImage: String
    let title: LocalizedStringKey
    var footnote: LocalizedStringKey? = nil
    var footnoteTint: Color = Theme.secondaryLabel
    var isEnabled = true
    var ground: Color = Theme.fill
    var tint: Color = Theme.accent
    var horizontalPadding: CGFloat = 16
    var verticalPadding: CGFloat = 10
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
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(minHeight: Metrics.rowMinHeight)
            .contentShape(.rect)
        }
        .buttonStyle(GroupedRowButtonStyle())
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
