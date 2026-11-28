import SwiftUI

/// Location-metadata toggle row for ExportScreen with semantic leading icon badge, native switch,
/// and combined VoiceOver semantics.
struct ExportToggleRow: View {
    let title: LocalizedStringKey
    let footnote: LocalizedStringKey
    @Binding var isOn: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IconTile(
                systemImage: "location.slash.fill",
                ground: isOn
                    ? Theme.accent.opacity(colorScheme == .dark ? 0.22 : 0.13)
                    : Theme.fill,
                tint: isOn ? Theme.accent : Theme.tertiary
            )
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(Theme.body)
                Text(footnote)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryLabel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(nil)
                .padding(.top, 2)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: Metrics.rowMinHeight)
        .contentShape(.rect)
        .onTapGesture { isOn.toggle() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(Text(title)), \(Text(footnote))"))
        .accessibilityAddTraits([.isButton, .isToggle])
        .accessibilityAction(.default) { isOn.toggle() }
    }
}
