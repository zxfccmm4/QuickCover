import SwiftUI

/// One row of Review Each Item (design.md §7.4.3, §9.3): what the row is, with its footnote under
/// it when copy.md gives it one (4.5.14), and a switch at the right. The switch covers or uncovers
/// that item; a tap on the words shows the item in the picture (4.4.4). To VoiceOver the row is one
/// element: its name,「已遮」or「沒遮」, the hint 7.2, and 4.4.4 as its one custom action.
struct ChecklistRow: View {
    let item: MaskItem
    ///「人臉 2」: which one of its kind, nil when it is the only one (`EditorModel.ordinal(of:)`).
    let number: Int?
    @Binding var isOn: Bool
    let locate: @MainActor () -> Void

    private var title: String {
        L10n.rowTitle(item.rowKind, number: number)
    }

    var body: some View {
        RowContent(systemImage: item.rowKind.systemImage,
                    title: Text(verbatim: title),
                    footnote: item.rowKind.footnoteKey.map { Text(LocalizedStringKey($0)) }) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(nil)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: locate)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(Text(isOn ? "4.5.15" : "4.5.16"))
        .accessibilityHint("7.2")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default) { isOn.toggle() }
        .accessibilityAction(named: Text("4.4.4")) { locate() }
    }

    /// The name, then the footnote when there is one (§9.3).
    private var label: Text {
        guard let footnote = item.rowKind.footnoteKey else { return Text(verbatim: title) }
        return Text("\(Text(verbatim: title)), \(Text(LocalizedStringKey(footnote)))")
    }
}

/// The row「遮住所有文字」(design.md §7.4.3): 4.6.1 with 4.6.2 under it and a switch. No tile, as
/// the mockup has none. Read as one element: 4.6.1, 4.6.2, then the state.
struct CoverAllTextRow: View {
    let isOn: Bool
    let setOn: @MainActor (Bool) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("4.6.1")
                    .font(.body)
                    .foregroundStyle(Theme.body)
                    .lineLimit(2)
                Text("4.6.2")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryLabel)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Toggle("", isOn: Binding(get: { isOn }, set: setOn))
                .labelsHidden()
                .tint(nil)
                .padding(.top, 3)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .frame(minHeight: Metrics.rowMinHeight)
        .contentShape(Rectangle())
        .onTapGesture { setOn(!isOn) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(Text("4.6.1")), \(Text("4.6.2"))"))
        .accessibilityValue(Text(isOn ? "4.5.15" : "4.5.16"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default) { setOn(!isOn) }
    }
}

/// The reminder between the cards of text (design.md §7.4.3): 4.4.3 with a 15 pt
/// `exclamationmark.triangle` in `#C86A00`, and the text button 4.8.3 at the right. It is a line,
/// not a card (the mockup `7-4-review` has no ground under it). Read as 4.4.3, then the button.
struct UncoveredTextReminder: View {
    let draw: @MainActor () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.blurNoticeIcon)
                .accessibilityHidden(true)
            Text("4.4.3")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryLabel)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextButton(title: "4.8.3", action: draw)
                // 36 high, but 44 to the touch (§9.5).
                .frame(minHeight: Metrics.minimumTarget)
                .contentShape(Rectangle())
        }
        .padding(.horizontal, 16)
    }
}

/// A card of the sheet (design.md §4): corner 12, `#1C1C1E`, rows one under the other with a
/// 0.5 pt line between them from 16 in to the right edge.
struct ChecklistCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous).fill(Theme.card))
    }
}

/// The line between two rows of a card (design.md §4).
struct RowSeparator: View {
    var body: some View {
        Rectangle()
            .fill(Theme.separator)
            .frame(height: 0.5)
            .padding(.leading, Metrics.pageInset)
            .accessibilityHidden(true)
    }
}
