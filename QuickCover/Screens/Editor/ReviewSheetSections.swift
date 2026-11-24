import CoreGraphics
import Foundation

/// What Review Each Item lists, in the order of design.md §7.4.3, from the editor's items. The
/// model lists a text line only once it is on (`EditorModel.checklist`); the sheet's text card
/// lists every text line, each with its switch off until it is turned on (§7.4.3), so they are
/// taken from the items and put in reading order here, the way the model orders its own list.
enum ReviewSheetSections {

    /// Everything that is not a plain text line, in the model's order: by kind (faces, phone
    /// numbers, …, codes, hand-drawn boxes), then top to bottom, left to right.
    static func suggestions(in items: [MaskItem]) -> [MaskItem] {
        items.filter { $0.origin != .textLine }.sorted(by: isBefore)
    }

    /// The text lines no rule matched, top to bottom, left to right:「文字 1」「文字 2」…
    static func textLines(in items: [MaskItem]) -> [MaskItem] {
        items.filter { $0.origin == .textLine }.sorted(by: isBefore)
    }

    private static func isBefore(_ a: MaskItem, _ b: MaskItem) -> Bool {
        let (ka, kb) = (a.rowKind, b.rowKind)
        if ka != kb, let ia = RowKind.allCases.firstIndex(of: ka), let ib = RowKind.allCases.firstIndex(of: kb) {
            return ia < ib
        }
        let (ba, bb) = (a.bounds, b.bounds)
        if ba.minY != bb.minY { return ba.minY < bb.minY }
        if ba.minX != bb.minX { return ba.minX < bb.minX }
        return a.id < b.id
    }
}
