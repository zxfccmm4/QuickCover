import SwiftUI

/// Review Each Item (design.md §7.4, copy.md §4.4–§4.6): a sheet that starts 300 from the top of the
/// screen, pulls up to full screen and down to close; shown by `EditorModel.reviewShown`. Top to
/// bottom: the grabber and 4.4.1, `SummaryText`, 4.4.2, the cards of §7.4.3 in the order of
/// `EditorModel.checklistOrder`, and the style picker 4.7.1–4.7.5 at the bottom.
///
/// One row is one item, one switch, also when the item holds two boxes (`MaskItem.quads`, a value
/// wrapped onto two lines); the summary above counts boxes (`EditorModel.found`). The style picker
/// is the system segmented control, its selected segment left in the system's own colour (design.md
/// §7.4.4). Only when the user taps「模糊」now does 4.7.5 come under it, `exclamationmark.triangle`
/// and the text, with no button (`NoticeBar` with an empty end); a blur left from last time
/// doesn't.
///
/// Only declared here; the page is still to be built.
struct ReviewSheet: View {
    @Environment(EditorModel.self) private var model

    var body: some View {
        Theme.page.ignoresSafeArea()
    }
}
