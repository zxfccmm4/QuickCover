import SwiftUI
import UIKit

/// Review Each Item (design.md §7.4, copy.md §4.4–§4.6): a sheet 300 under the top of the screen
/// that pulls up to full screen and down to close; shown by `EditorModel.reviewShown`. Top to
/// bottom: the grabber and 4.4.1, `SummaryText`, 4.4.2, the cards of §7.4.3 (the picture, the
/// items by kind, the text lines with their switch off until turned on), and the style picker
/// 4.7.1–4.7.5 pinned at the bottom. The rows go under the title as the sheet scrolls, and the
/// last card's bottom is 20 above the picker, so the sheet can be pulled up by anything that is
/// left under it.
///
/// One row is one item, one switch, also when the item holds two boxes (`MaskItem.quads`, a value
/// wrapped onto two lines); the summary above counts boxes (`EditorModel.found`). A row's switch
/// covers or uncovers its item; a tap on its words shows the item in the picture (4.4.4), and the
/// sheet stays up so it can be switched off right after.
struct ReviewSheet: View {
    @Environment(EditorModel.self) private var model
    @Environment(ShellModel.self) private var shell
    /// Whether this presentation has had its top edge measured (see `SheetGeometry.extra`).
    @State private var measuredExtra = false

    private var suggestions: [MaskItem] { ReviewSheetSections.suggestions(in: model.items) }
    private var textLines: [MaskItem] { ReviewSheetSections.textLines(in: model.items) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    summary
                    cards
                        .padding(.bottom, Metrics.cardSpacing)
                }
                .padding(.horizontal, EditorLayout.sheetInset)
            }
            .scrollBounceBehavior(.basedOnSize)
            StylePicker()
        }
        .background(Theme.page)
        .safeAreaInset(edge: .top, spacing: 0) { title }
        .presentationDetents([.height(Screen.size.height - EditorLayout.sheetTop - SheetGeometry.shared.extra), .large])
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { top in
            let geometry = SheetGeometry.shared
            geometry.top = top
            if !measuredExtra {
                measuredExtra = true
                geometry.extra = SheetGeometry.addition(sheetTop: EditorLayout.sheetTop, extraBefore: geometry.extra, top: top)
            }
        }
        .onDisappear { measuredExtra = false }
        .presentationCornerRadius(Metrics.cardRadius)
        .presentationBackground(Theme.page)
        .presentationBackgroundInteraction(.enabled)
        .task { AccessibilityNotification.Announcement(L10n.text("4.4.1")).post() }
    }

    /// 4.4.1, 19 under the sheet's edge (under the system's grabber) and 8 over the summary.
    private var title: some View {
        Text("4.4.1")
            .font(.headline)
            .foregroundStyle(Theme.body)
            .frame(maxWidth: .infinity)
            .padding(.top, 19)
            .padding(.bottom, 8)
            .background(Theme.page)
    }

    // MARK: - Summary

    @ViewBuilder private var summary: some View {
        if !model.found.isEmpty {
            SummaryText(found: model.found)
            Text("4.4.2")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryLabel)
                .padding(.top, 6)
                .padding(.bottom, 14)
        }
    }

    // MARK: - Cards

    /// One column, so that what `body` adds below the cards is added once (a bare group of views
    /// takes a modifier on each of them).
    private var cards: some View {
        VStack(alignment: .leading, spacing: 0) {
            ChecklistCard {
                ToggleRow(systemImage: "eye", title: Text("7.3"), isOn: originalBinding, stateKeys: nil, hint: nil)
            }

            if !suggestions.isEmpty {
                Color.clear.frame(height: Metrics.cardSpacing)
                ChecklistCard {
                    ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { RowSeparator() }
                        ChecklistRow(item: item, number: model.ordinal(of: item), isOn: binding(item)) {
                            locate(item)
                        }
                    }
                }
            }

            if !textLines.isEmpty {
                Color.clear.frame(height: Metrics.cardSpacing)
                ChecklistCard {
                    CoverAllTextRow(isOn: model.coversAllText) { model.setAllText($0) }
                }

                if model.hasUncoveredTextLines {
                    UncoveredTextReminder(draw: startDrawing)
                        .padding(.vertical, 12)
                } else {
                    Color.clear.frame(height: Metrics.cardSpacing)
                }

                ChecklistCard {
                    ForEach(Array(textLines.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { RowSeparator() }
                        ChecklistRow(item: item, number: numbered(textLines, at: index), isOn: binding(item)) {
                            locate(item)
                        }
                    }
                }
            }
        }
    }

    ///「文字 2」: 1, 2, … when the list has several of a kind, nil when it is the only one (the
    /// model numbers its own list this way; the text lines are listed here, not there).
    private func numbered(_ list: [MaskItem], at index: Int) -> Int? {
        list.count > 1 ? index + 1 : nil
    }

    // MARK: - Actions

    private func binding(_ item: MaskItem) -> Binding<Bool> {
        Binding(get: { item.isOn }, set: { model.setOn(item.id, $0) })
    }

    private var originalBinding: Binding<Bool> {
        Binding(get: { model.showsOriginal }, set: { model.showsOriginal = $0 })
    }

    /// §7.4.3 (4.4.4): the sheet stays where it is; the picture moves so the item sits over the
    /// middle of what shows above the sheet, and the ring lights there.
    private func locate(_ item: MaskItem) {
        model.requestLocate(item.id)
    }

    /// 4.8.3: the sheet goes down and the drawing tool goes on.
    private func startDrawing() {
        shell.hideReview()
        model.drawToolOn = true
    }
}

/// The screen the app is on; only its height is wanted here, for the sheet's 300-from-the-top.
@MainActor
private enum Screen {
    static var size: CGSize {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let height = scenes.first?.screen.bounds.height ?? 874
        return CGSize(width: scenes.first?.screen.bounds.width ?? 402, height: height)
    }
}
