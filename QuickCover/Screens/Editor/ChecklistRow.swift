import SwiftUI

/// Native checklist row for ReviewSheet: tapping the label locates the item in the canvas; toggling
/// the switch covers or uncovers it; VoiceOver combines the row with a custom "Show in Image" action.
struct ChecklistRow: View {
    let item: MaskItem
    let number: Int?
    @Binding var isOn: Bool
    let locate: @MainActor () -> Void

    private var title: String {
        L10n.rowTitle(item.rowKind, number: number)
    }

    var body: some View {
        RowContent(
            systemImage: item.rowKind.systemImage,
            title: Text(verbatim: title),
            footnote: item.rowKind.footnoteKey.map { Text(LocalizedStringKey($0)) },
            ground: isOn ? Theme.accent.opacity(0.14) : Theme.fill,
            tint: isOn ? Theme.accent : Theme.tertiary
        ) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(nil)
                .accessibilityHidden(true)
        }
        .contentShape(.rect)
        .onTapGesture(perform: locate)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(Text(isOn ? "4.5.15" : "4.5.16"))
        .accessibilityHint("7.2")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default) { isOn.toggle() }
        .accessibilityAction(named: Text("4.4.4")) { locate() }
    }

    private var label: Text {
        guard let footnote = item.rowKind.footnoteKey else { return Text(verbatim: title) }
        return Text("\(Text(verbatim: title)), \(Text(LocalizedStringKey(footnote)))")
    }
}

/// "Cover All Text" toggle row in ReviewSheet.
struct CoverAllTextRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let isOn: Bool
    let setOn: @MainActor (Bool) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("4.6.1")
                    .font(.body)
                    .foregroundStyle(Theme.body)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                Text("4.6.2")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryLabel)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: Binding(get: { isOn }, set: { setOn($0) }))
                .labelsHidden()
                .tint(nil)
                .padding(.top, 2)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 3)
        .contentShape(.rect)
        .onTapGesture { setOn(!isOn) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(Text("4.6.1")), \(Text("4.6.2"))"))
        .accessibilityValue(Text(isOn ? "4.5.15" : "4.5.16"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default) { setOn(!isOn) }
    }
}

/// Adaptive inline reminder shown under "Cover All Text" when uncovered text remains.
/// Uses `ViewThatFits` so narrow screens and large text stack cleanly without clipping.
struct UncoveredTextReminder: View {
    let draw: @MainActor () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                stacked
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 8) {
                        icon
                        Text("4.4.3")
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryLabel)
                            .fixedSize(horizontal: true, vertical: false)
                        Spacer(minLength: 8)
                        TextButton(title: "4.8.3", action: draw)
                    }
                    stacked
                }
            }
        }
        .textCase(nil)
    }

    private var stacked: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                icon
                    .padding(.top, 1)
                Text("4.4.3")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            TextButton(title: "4.8.3", action: draw)
                .padding(.leading, 15)
        }
    }

    private var icon: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.footnote)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(Theme.blurNoticeIcon)
            .accessibilityHidden(true)
    }
}
