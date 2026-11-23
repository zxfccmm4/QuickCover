import SwiftUI

/// The style at the bottom of Review Each Item (design.md §7.4.4): pinned, a line on top, 6 above
/// and below the bottom safe area, the small title 4.7.1 and the system segmented control
/// 4.7.2–4.7.4 16 from the sides. The control is not coloured here: what it looks like in the dark
/// is the system's. Picking「模糊」puts the line 4.7.5 under it, 8 below, until another style is
/// picked; the style that was left last time doesn't (the export page says that one, §7.5).
struct StylePicker: View {
    @Environment(EditorModel.self) private var model
    @State private var blurNoticeShown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Theme.separator)
                .frame(height: 0.5)
            VStack(alignment: .leading, spacing: 7) {
                Text("4.7.1")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryLabel)
                    .textCase(.uppercase)
                    .padding(.leading, Metrics.pageInset)
                Picker("4.7.1", selection: Binding(get: { model.preferences.style }, set: pick)) {
                    Text("4.7.2").tag(MaskStyle.mosaic)
                    Text("4.7.3").tag(MaskStyle.solid)
                    Text("4.7.4").tag(MaskStyle.blur)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("4.7.1")
                if blurNoticeShown {
                    BlurNotice()
                        .padding(.top, 1)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, Metrics.pageInset)
            .padding(.vertical, 6)
        }
        .background(Theme.page)
    }

    private func pick(_ style: MaskStyle) {
        guard style != model.preferences.style else { return }
        Haptics.styleChanged()
        model.setStyle(style)
        withAnimation(.easeInOut(duration: 0.2)) { blurNoticeShown = style == .blur }
    }
}

/// The line 4.7.5 (§7.4.4, `7-4-review-blur-note.png`): a 15 pt `exclamationmark.triangle` in
/// `#C86A00` and the words in `.footnote` secondary, 32 from the edge like everything in the sheet.
/// No ground: the mockup has none, and §7.4.4 calls it a line, not a bar. Read as 4.7.5, with no
/// button (§9.3).
private struct BlurNotice: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.blurNoticeIcon)
                .accessibilityHidden(true)
                .padding(.top, 1)
            Text("4.7.5")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryLabel)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, Metrics.pageInset)
    }
}
