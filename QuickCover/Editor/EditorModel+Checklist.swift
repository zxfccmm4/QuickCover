import CoreGraphics
import Foundation

/// What the recognizer found, counted the way the summary counts (copy.md §4.3): it doesn't matter
/// whether anything is on, and hand-drawn boxes aren't counted.
struct FoundCounts: Equatable, Sendable {
    var faces = 0
    var textLines = 0
    var qrCodes = 0
    var barcodes = 0

    /// Nothing at all: there is no summary then, and the callout of design.md §7.3.4 instead.
    var isEmpty: Bool { faces == 0 && textLines == 0 && qrCodes == 0 && barcodes == 0 }
}

/// The kinds of row Review Each Item lists, in the fixed order of design.md §7.4.3. Each one's raw
/// value is the number of the copy.md row that names it (§4.5).
enum RowKind: String, CaseIterable, Sendable, Equatable {
    case face = "4.5.01"
    case phone = "4.5.02"
    case idNumber = "4.5.03"
    case bankCard = "4.5.04"
    case email = "4.5.05"
    case url = "4.5.06"
    case ipv4 = "4.5.07"
    case reference = "4.5.08"
    case plate = "4.5.09"
    case qrCode = "4.5.11"
    case barcode = "4.5.12"
    case manual = "4.5.13"
    case text = "4.5.10"

    /// The symbol design.md §10.3 gives the row.
    var systemImage: String {
        switch self {
        case .face: "face.smiling"
        case .phone: "phone.fill"
        case .idNumber: "person.text.rectangle"
        case .bankCard: "creditcard.fill"
        case .email: "envelope.fill"
        case .url: "link"
        case .ipv4: "network"
        case .reference: "number"
        case .plate: "car.fill"
        case .qrCode: "qrcode"
        case .barcode: "barcode"
        case .manual: "rectangle.dashed"
        case .text: "text.alignleft"
        }
    }

    /// The copy.md number of the row's name.
    var titleKey: String { rawValue }

    /// The small text under the row when copy.md gives it one (4.5.14, under「可能是車牌」).
    var footnoteKey: String? {
        self == .plate ? "4.5.14" : nil
    }

    /// Which kind of row an item is.
    init(of item: MaskItem) {
        switch (item.group, item.origin, item.rule) {
        case (.face, _, _):
            self = .face
        case (_, .manual, _):
            self = .manual
        case (.text, _, .some(let rule)):
            switch rule {
            case .phone: self = .phone
            case .idNumber: self = .idNumber
            case .bankCard: self = .bankCard
            case .email: self = .email
            case .url: self = .url
            case .ipv4: self = .ipv4
            case .reference: self = .reference
            case .plate: self = .plate
            }
        case (.text, _, nil):
            self = .text
        case (.code, _, _):
            self = item.codeKind == .qr ? .qrCode : .barcode
        }
    }
}

extension MaskItem {
    /// QR Code or Barcode: the two rows copy.md has for codes (4.3.3, 4.3.4, 4.5.11, 4.5.12).
    enum CodeKind: String, Sendable, Equatable {
        case qr
        case barcode
    }

    /// Which kind of code this is; nil for everything else. The recognizer doesn't tell which
    /// symbology it saw, so the shape decides: a QR code is square, a one-dimensional barcode is
    /// long. A square code of another symbology (Data Matrix, Aztec) is listed as a QR code.
    var codeKind: CodeKind? {
        guard group == .code else { return nil }
        let bounds = Geometry.bounds(of: quad)
        guard bounds.height > 0 else { return nil }
        let aspect = bounds.width / bounds.height
        return (0.75...1.33).contains(aspect) ? .qr : .barcode
    }

    /// The row of copy.md §4.5 that names this item in Review Each Item.
    var rowKind: RowKind { RowKind(of: self) }
}

extension EditorModel {

    /// What was found, the way copy.md §4.3 counts it.
    var found: FoundCounts {
        var counts = FoundCounts()
        for item in items where item.origin != .manual {
            switch item.group {
            case .face:
                counts.faces += 1
            case .text:
                counts.textLines += 1
            case .code:
                if item.codeKind == .qr { counts.qrCodes += 1 } else { counts.barcodes += 1 }
            }
        }
        return counts
    }

    /// Whether the picture has text lines at all: the text section of Review Each Item exists only
    /// then (design.md §7.4.3).
    var hasTextLines: Bool {
        items.contains { $0.origin == .textLine }
    }

    /// Whether some text line is still uncovered: the 4.4.3 notice exists only then (§7.4.3).
    var hasUncoveredTextLines: Bool {
        items.contains { $0.origin == .textLine && !$0.isOn }
    }

    /// The items Review Each Item lists, in its fixed order (design.md §7.4.3): by kind, and within
    /// a kind in reading order (top to bottom, then left to right); hand-drawn boxes after the
    /// codes, text lines last.
    var checklistOrder: [MaskItem] {
        checklist.sorted { a, b in
            let (ka, kb) = (a.rowKind, b.rowKind)
            if ka != kb {
                return RowKind.allCases.firstIndex(of: ka)! < RowKind.allCases.firstIndex(of: kb)!
            }
            let (ba, bb) = (Geometry.bounds(of: a.quad), Geometry.bounds(of: b.quad))
            if ba.minY != bb.minY { return ba.minY < bb.minY }
            if ba.minX != bb.minX { return ba.minX < bb.minX }
            return a.id < b.id
        }
    }

    /// 1, 2, … for an item whose kind has several in the list, numbered in the order of
    /// `checklistOrder`; nil when it is the only one (copy.md §4.5 numbers a kind only when there
    /// are several:「人臉 2」).
    func ordinal(of item: MaskItem) -> Int? {
        let sameKind = checklistOrder.filter { $0.rowKind == item.rowKind }
        guard sameKind.count > 1, let index = sameKind.firstIndex(where: { $0.id == item.id }) else { return nil }
        return index + 1
    }
}
