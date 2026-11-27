import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import QuickCover

struct EditorModelTests {

    private func quad(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> [CGPoint] {
        [CGPoint(x: x, y: y), CGPoint(x: x + w, y: y), CGPoint(x: x + w, y: y + h), CGPoint(x: x, y: y + h)]
    }

    @MainActor
    private func makeModel() throws -> EditorModel {
        // A 600×300 picture; the preview is asked at 300, so everything doubles into full pixels.
        let source = try PictureSource(data: Sample.jpeg(Sample.text("13812345678", at: CGPoint(x: 20, y: 20))))
        let defaults = try #require(UserDefaults(suiteName: "EditorModelTests"))
        defaults.removePersistentDomain(forName: "EditorModelTests")
        return EditorModel(picture: source, previewLongSide: 300, defaults: defaults)
    }

    private func sampleResult() -> RecognitionResult {
        RecognitionResult(
            size: CGSize(width: 300, height: 150),
            findings: [
                Finding(kind: .face, quad: quad(10, 10, 100, 100)),
                Finding(kind: .text, rule: .phone, quad: quad(10, 100, 150, 15)),
                Finding(kind: .code, quad: quad(200, 20, 80, 40)),
            ],
            textLines: [TextLine(quad: quad(10, 80, 200, 15), text: "收货人张三")]
        )
    }

    @Test
    @MainActor
    func suggestionsArriveOnAndInFullPixels() throws {
        let model = try makeModel()
        #expect(model.preview.width == 300)
        #expect(model.previewScale == CGSize(width: 2, height: 2))
        model.adopt(sampleResult())
        #expect(model.items.count == 4)
        #expect(model.checklist.count == 3)
        #expect(model.counts == (1, 1, 1))
        #expect(model.enabledItems.count == 3)
        #expect(model.items[0].quad[0] == CGPoint(x: 20, y: 20))
        #expect(model.items[0].quad[2] == CGPoint(x: 220, y: 220))
        #expect(!model.coversAllText)
    }

    @Test
    @MainActor
    func togglingIsUndoable() throws {
        let model = try makeModel()
        model.adopt(sampleResult())
        let face = model.items[0].id
        model.toggle(face)
        #expect(model.enabledItems.count == 2)
        #expect(model.checklist.count == 3)      // still listed, so it can be switched back on
        #expect(model.counts == (0, 1, 1))
        model.undo()
        #expect(model.enabledItems.count == 3)
        model.redo()
        #expect(model.enabledItems.count == 2)
        model.setOn(face, false)                 // no-op edits leave the history alone
        #expect(model.canUndo)
    }

    @Test
    @MainActor
    func allTextCoversPlainLines() throws {
        let model = try makeModel()
        model.adopt(sampleResult())
        let line = try #require(model.items.first { $0.origin == .textLine })
        #expect(!line.isOn)
        #expect(!model.checklist.contains { $0.id == line.id })
        model.setAllText(true)
        #expect(model.coversAllText)
        #expect(model.checklist.contains { $0.id == line.id })
        #expect(model.counts.texts == 2)
        model.setAllText(false)
        #expect(!model.coversAllText)
        #expect(model.counts.texts == 1)
    }

    @Test
    @MainActor
    func handDrawnBoxIsListedAndUndoable() throws {
        let model = try makeModel()
        model.adopt(sampleResult())
        model.addManualBox(CGRect(x: 10, y: 10, width: 50, height: 50))
        model.addManualBox(CGRect(x: 1, y: 1, width: 2, height: 2))     // too small to be a box
        #expect(model.items.count == 5)
        #expect(model.checklist.count == 4)
        #expect(model.counts.texts == 2)
        let manual = try #require(model.items.first { $0.origin == .manual })
        model.setOn(manual.id, false)
        #expect(model.counts.texts == 1)
        #expect(model.checklist.count == 4)     // still listed, switched off
        model.undo()
        #expect(model.counts.texts == 2)
        model.remove(manual.id)
        #expect(model.items.count == 4)
        model.undo()
        #expect(model.items.count == 5)
        model.undo()                             // back to before the box was drawn
        #expect(model.items.count == 4)
        #expect(!model.canUndo)
        model.redo()
        #expect(model.items.count == 5)
    }

    @Test
    @MainActor
    func styleAndMetadataChoiceAreRemembered() throws {
        let defaults = try #require(UserDefaults(suiteName: "EditorModelTests"))
        let model = try makeModel()
        #expect(model.preferences.style == .mosaic)
        #expect(model.preferences.stripMetadata)
        model.setStyle(.solid)
        model.setStripMetadata(false)
        #expect(EditorModel.Preferences.load(from: defaults) == .init(style: .solid, stripMetadata: false))
        model.setStyle(.solid)                   // same value: nothing saved again, nothing changes
        #expect(model.preferences.style == .solid)
    }

    @Test
    @MainActor
    func exportCoversOnlyWhatIsOn() async throws {
        let model = try makeModel()
        model.adopt(sampleResult())
        model.setStyle(.solid)
        model.setOn(model.items[0].id, false)    // the face stays visible
        let data = try await model.exportData()
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 600)
        #expect(image.height == 300)
        #expect(Sample.brightness(image, x: 100, y: 100) > 0.8)     // face area: white paper, uncovered
        #expect(Sample.brightness(image, x: 250, y: 215) < 0.05)    // phone number area: covered
        #expect(Sample.brightness(image, x: 480, y: 80) < 0.05)     // code area: covered
    }

    @Test
    @MainActor
    func tappingAnUncoveredTextLineFindsItAndIgnoresCoveredOnes() throws {
        let model = try makeModel()
        model.adopt(sampleResult())
        // Plain text line is at (20, 160, 400, 30) in full pixels and starts off.
        let hit = try #require(model.uncoveredItem(at: CGPoint(x: 100, y: 175), minimumSide: 44, smallTargetPad: 8))
        #expect(hit.origin == .textLine)
        // Small-target margin catches a tap slightly outside a thin text line.
        let nearHit = try #require(model.uncoveredItem(at: CGPoint(x: 100, y: 154), minimumSide: 44, smallTargetPad: 8))
        #expect(nearHit.id == hit.id)
        // Once covered, tapping the same point returns nil.
        model.setOn(hit.id, true)
        #expect(model.uncoveredItem(at: CGPoint(x: 100, y: 175), minimumSide: 44, smallTargetPad: 8) == nil)
    }

    @Test
    @MainActor
    func categoryBatchTogglesAreUndoableAndScopedToSuggestions() throws {
        let model = try makeModel()
        model.adopt(sampleResult())
        #expect(model.isGroupCovered(.face))
        #expect(model.isGroupCovered(.text))
        #expect(model.isGroupCovered(.code))

        model.setGroupCovered(.face, false)
        #expect(!model.isGroupCovered(.face))
        #expect(model.counts == (0, 1, 1))
        model.undo()
        #expect(model.isGroupCovered(.face))
        #expect(model.counts == (1, 1, 1))
    }

    @Test
    @MainActor
    func manualBoxCanBeHitMovedClampedAndUndone() throws {
        let model = try makeModel()
        model.adopt(sampleResult())
        model.addManualBox(CGRect(x: 100, y: 100, width: 80, height: 40))
        let manual = try #require(model.items.first { $0.origin == .manual })

        let hit = try #require(model.hitItem(at: CGPoint(x: 140, y: 120), minimumSide: 44, smallTargetPad: 8))
        #expect(hit.id == manual.id)

        // Move far beyond right edge: clamps cleanly inside 600×300 image bounds.
        model.moveManualBox(manual.id, by: CGSize(width: 900, height: 50))
        let moved = try #require(model.items.first { $0.id == manual.id })
        #expect(moved.bounds.maxX == 600)
        #expect(moved.bounds.minY == 150)

        model.undo()
        let restored = try #require(model.items.first { $0.id == manual.id })
        #expect(restored.bounds.minX == 100)
        #expect(restored.bounds.minY == 100)
    }

    @Test
    @MainActor
    func extendedPreferencesPersistAcrossLaunches() throws {
        let defaults = try #require(UserDefaults(suiteName: "EditorModelTests"))
        let model = try makeModel()
        model.setStyle(.emoji)
        model.setSolidColor(.teal)
        model.setEmoji("🐱")
        model.setStrength(.coarse)
        model.setExportFormat(.png)

        let loaded = EditorModel.Preferences.load(from: defaults)
        #expect(loaded.style == .emoji)
        #expect(loaded.solidColor == .teal)
        #expect(loaded.emoji == "🐱")
        #expect(loaded.strength == .coarse)
        #expect(loaded.exportFormat == .png)
    }

    @Test
    @MainActor
    func customColorsMosaicTintRecentEmojisAndAIPreferencePersist() throws {
        let defaults = try #require(UserDefaults(suiteName: "EditorModelTests"))
        let model = try makeModel()
        let custom = CustomColorRGB(red: 0.25, green: 0.55, blue: 0.90)
        model.setCustomSolidColor(custom)
        model.setMosaicTint(.color(.preset(.rose)))
        model.setEmoji("🦊")
        model.setEmoji("🐼")
        model.setAutoAppleIntelligence(false)

        let loaded = EditorModel.Preferences.load(from: defaults)
        #expect(loaded.customSolidColor == custom)
        #expect(loaded.mosaicTint == .color(.preset(.rose)))
        #expect(loaded.emoji == "🐼")
        #expect(loaded.recentEmojis.prefix(2) == ["🐼", "🦊"])
        #expect(!loaded.autoAppleIntelligence)
    }

    @Test
    @MainActor
    func appleIntelligenceContextualScanCoversSensitiveTextLinesAndEmitsMagicBurst() async throws {
        let model = try makeModel()
        model.adopt(
            RecognitionResult(
                size: CGSize(width: 300, height: 150),
                findings: [Finding(kind: .face, quad: quad(10, 10, 80, 80))],
                textLines: [
                    TextLine(quad: quad(10, 95, 180, 16), text: "地址：上海市徐汇区漕河泾路 88 号"),
                    TextLine(quad: quad(10, 115, 120, 16), text: "欢迎光临"),
                    TextLine(quad: quad(10, 132, 160, 16), text: "订单号：QC-2026-8849102"),
                ]
            )
        )
        #expect(model.enabledItems.count == 1)

        let added = await model.runAppleIntelligenceScan(applyMagicErase: true)
        #expect(added == 2)
        #expect(model.enabledItems.count == 3)
        #expect(model.preferences.style == .conceal)
        #expect(model.magicBurst?.kind == .erase)

        model.undo()
        #expect(model.enabledItems.count == 1)
    }
}
