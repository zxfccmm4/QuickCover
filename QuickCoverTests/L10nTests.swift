import SwiftUI
import Testing
import UIKit

@testable import QuickCover

/// The strings of copy.md as the app reads them: by number, in all three languages.
struct L10nTests {

    private let languages = ["zh-Hans", "zh-Hant", "en"]

    private func bundle(_ language: String) -> Bundle {
        let bundle = L10n.bundle(for: language)
        #expect(bundle.bundlePath.hasSuffix("\(language).lproj"), "the app has no \(language).lproj")
        return bundle
    }

    @Test
    func everyRowKindHasANameInEveryLanguage() {
        for language in languages {
            let bundle = bundle(language)
            for kind in RowKind.allCases {
                let title = L10n.text(kind.rawValue, bundle: bundle)
                #expect(!title.isEmpty, "\(language) \(kind.rawValue)")
                #expect(title != kind.rawValue, "\(language) \(kind.rawValue) isn't in the catalog")
                if let footnote = kind.footnoteKey {
                    #expect(L10n.text(footnote, bundle: bundle) != footnote, "\(language) \(footnote)")
                }
            }
        }
    }

    @Test
    func theCatalogHoldsEveryNumberedRow() throws {
        // The compiled catalog of each language: the numbered rows in Localizable.strings, the
        // four {n} rows in Localizable.stringsdict.
        for language in languages {
            let bundle = bundle(language)
            let table = try #require(bundle.path(forResource: "Localizable", ofType: "strings"))
            let strings = try #require(NSDictionary(contentsOfFile: table) as? [String: String])
            #expect(strings["3.1.1"] != nil, "\(language)")
            #expect(strings["4.5.13"] != nil, "\(language)")
            #expect(strings["4.9.1"] != nil, "\(language)")
            #expect(strings["7.1.lead"] != nil, "\(language)")
            #expect(strings["4.3.sep"] != nil, "\(language)")
            #expect(strings["7.1.join"] != nil, "\(language)")
            #expect(strings["7.1.lastJoin"] != nil, "\(language)")
            let plurals = try #require(bundle.path(forResource: "Localizable", ofType: "stringsdict"))
            let dict = try #require(NSDictionary(contentsOfFile: plurals) as? [String: Any])
            for key in ["4.3.1", "4.3.2", "4.3.3", "4.3.4"] {
                #expect(dict[key] != nil, "\(language) \(key)")
            }
        }
    }

    @Test
    func theFourCountRowsHaveTheirPluralForms() {
        let en = bundle("en"), hans = bundle("zh-Hans"), hant = bundle("zh-Hant")
        #expect(L10n.faces(1, bundle: en) == "1 face")
        #expect(L10n.faces(2, bundle: en) == "2 faces")
        #expect(L10n.textLines(1, bundle: en) == "1 line of text")
        #expect(L10n.textLines(5, bundle: en) == "5 lines of text")
        #expect(L10n.qrCodes(1, bundle: en) == "1 QR Code")
        #expect(L10n.qrCodes(2, bundle: en) == "2 QR Codes")
        #expect(L10n.barcodes(1, bundle: en) == "1 barcode")
        #expect(L10n.barcodes(3, bundle: en) == "3 barcodes")
        #expect(L10n.faces(1, bundle: hans) == "1 张人脸")
        #expect(L10n.textLines(5, bundle: hans) == "5 处文字")
        #expect(L10n.faces(2, bundle: hant) == "2 張人臉")
        #expect(L10n.qrCodes(1, bundle: hant) == "1 個 QR Code")
        #expect(L10n.barcodes(1, bundle: hant) == "1 個條碼")
    }

    @Test
    func theScreenReaderSummaryIsTheExampleOfCopyMD() {
        let found = FoundCounts(faces: 2, textLines: 5, qrCodes: 1, barcodes: 0)
        #expect(L10n.screenReaderSummary(found, bundle: bundle("zh-Hans")) == "找到 2 张人脸、5 处文字、1 个二维码")
        #expect(L10n.screenReaderSummary(found, bundle: bundle("zh-Hant")) == "找到 2 張人臉、5 處文字、1 個 QR Code")
        #expect(L10n.screenReaderSummary(found, bundle: bundle("en")) == "Found 2 faces, 5 lines of text and 1 QR Code")
    }

    @Test
    func theScreenReaderSummaryFollowsTheRuleForOtherCounts() {
        let en = bundle("en"), hant = bundle("zh-Hant")
        // One kind: nothing to join. Two: only "and" before the last. Nothing: no sentence.
        #expect(L10n.screenReaderSummary(FoundCounts(faces: 1), bundle: en) == "Found 1 face")
        #expect(L10n.screenReaderSummary(FoundCounts(faces: 3, barcodes: 2), bundle: en) == "Found 3 faces and 2 barcodes")
        #expect(L10n.screenReaderSummary(FoundCounts(textLines: 1, qrCodes: 1, barcodes: 1), bundle: en)
                == "Found 1 line of text, 1 QR Code and 1 barcode")
        #expect(L10n.screenReaderSummary(FoundCounts(), bundle: en) == "")
        #expect(L10n.screenReaderSummary(FoundCounts(faces: 3, textLines: 2, qrCodes: 1, barcodes: 1), bundle: hant)
                == "找到 3 張人臉、2 處文字、1 個 QR Code、1 個條碼")
        #expect(L10n.screenReaderSummary(FoundCounts(barcodes: 1), bundle: hant) == "找到 1 個條碼")
        #expect(L10n.screenReaderSummary(FoundCounts(), bundle: hant) == "")
    }

    @Test
    func theSummaryJoinsWithTheDot() {
        let separator = "\u{00a0}\u{00b7}\u{00a0}"
        let found = FoundCounts(faces: 2, textLines: 5, qrCodes: 1)
        #expect(L10n.summary(found, bundle: bundle("en")) == "2 faces\(separator)5 lines of text\(separator)1 QR Code")
        #expect(L10n.summary(found, bundle: bundle("zh-Hans")) == "2 张人脸\(separator)5 处文字\(separator)1 个二维码")
        #expect(L10n.summary(FoundCounts(barcodes: 1), bundle: bundle("en")) == "1 barcode")
        #expect(L10n.summary(FoundCounts(), bundle: bundle("en")) == "")
    }

    @Test
    func aRowIsNumberedOnlyWhenItsKindHasSeveral() {
        let hant = bundle("zh-Hant"), en = bundle("en")
        #expect(L10n.rowTitle(.face, number: nil, bundle: hant) == "人臉")
        #expect(L10n.rowTitle(.face, number: 2, bundle: hant) == "人臉 2")
        #expect(L10n.rowTitle(.manual, number: 1, bundle: en) == "Box You Drew 1")
        #expect(L10n.rowTitle(.ipv4, number: nil, bundle: en) == "IP Address")
    }

    @Test
    func everySymbolTheSpecNamesExists() {
        let names = RowKind.allCases.map(\.systemImage) + MaskStyle.allCases.map(\.systemImage) + [
            "camera.viewfinder", "photo", "photo.on.rectangle.angled", "folder", "clipboard", "chevron.right",
            "doc.viewfinder", "photo.on.rectangle", "list.bullet", "arrow.uturn.backward",
            "arrow.uturn.forward", "rectangle.dashed", "eye", "exclamationmark.triangle",
            "exclamationmark.circle", "checkmark", "checkmark.circle.fill", "checkmark.shield.fill",
            "shield", "lock.shield", "lock.shield.fill", "location.slash.fill", "sparkles", "viewfinder",
            "square.and.arrow.up", "checkerboard.shield", "checkerboard.rectangle", "swatchpalette", "trash",
            "person.crop.rectangle", "text.quote", "qrcode", "arrow.down.right.and.arrow.up.left",
            "pawprint", "plus", "wand.and.stars", "info.circle", "hand.raised.fill", "doc.text.fill",
            "heart.fill", "doc.on.doc", "arrow.up.right", "safari.fill", "person.2.fill", "eye.fill",
            "swift", "hammer.fill", "iphone", "photo.badge.checkmark", "shippingbox.fill", "swatchpalette.fill",
        ]
        for name in names {
            #expect(UIImage(systemName: name) != nil, "\(name)")
        }
        for asset in ["IconArtwork", "symbol.twitter.icon", "Telegramicon", "Mail", "github-mark", "github-mark-white"] {
            #expect(UIImage(named: asset) != nil, "Missing image asset \(asset)")
        }
        #expect(EmojiPreset.all.count >= 48)
    }

    @Test
    func coveredCountFormatsCleanlyInEveryLanguage() {
        #expect(L10n.coveredCount(4, bundle: bundle("zh-Hans")) == "已遮 4 处")
        #expect(L10n.coveredCount(0, bundle: bundle("zh-Hans")) == "未遮挡")
        #expect(L10n.coveredCount(3, bundle: bundle("zh-Hant")) == "已遮 3 處")
        #expect(L10n.coveredCount(2, bundle: bundle("en")) == "2 Covered")
        #expect(L10n.coveredCount(0, bundle: bundle("en")) == "None Covered")
        #expect(L10n.intelligenceAdded(2, bundle: bundle("zh-Hans")) == "已智能补充遮挡 2 处")
        #expect(L10n.intelligenceAdded(2, bundle: bundle("en")) == "Smart-masked 2 more")
        #expect(L10n.aboutVersion("1.0", build: "3", bundle: bundle("zh-Hans")) == "版本 1.0 (3)")
        #expect(L10n.aboutVersion("1.0", build: "3", bundle: bundle("en")) == "Version 1.0 (3)")
        #expect(L10n.aboutVersion("1.0", build: "3", bundle: bundle("zh-Hant")) == "版本 1.0 (3)")
    }
}
