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
}
