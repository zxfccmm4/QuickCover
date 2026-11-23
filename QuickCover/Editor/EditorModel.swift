import CoreGraphics
import Foundation
import Observation

/// One thing on the picture that is covered, or can be.
struct MaskItem: Identifiable, Equatable, Sendable {
    enum Group: String, Sendable {
        case face, text, code
    }

    enum Origin: Sendable, Equatable {
        /// Found by the recognizer and on by default.
        case suggestion
        /// Drawn by hand.
        case manual
        /// A text line no rule matched; off until asked for.
        case textLine
    }

    let id: Int
    var group: Group
    var origin: Origin
    /// For text that matched a rule, which one.
    var rule: TextRule?
    /// Top-left, top-right, bottom-right, bottom-left, in upright full-size pixels.
    var quad: [CGPoint]
    var isOn: Bool
    /// What was read there. For the checklist's accessibility label and for tests.
    var evidence: String

    /// Whether the checklist shows it: suggestions and hand-drawn boxes always, plain text lines
    /// only once they are on.
    var isListed: Bool { origin != .textLine || isOn }

    var finding: Finding { Finding(kind: Kind.of(group), rule: rule, quad: quad, evidence: evidence) }

    private enum Kind {
        static func of(_ group: Group) -> Finding.Kind {
            switch group {
            case .face: .face
            case .text: .text
            case .code: .code
            }
        }
    }
}

/// The picture being worked on: what is covered, in which style, and the export.
@MainActor
@Observable
final class EditorModel {

    enum Recognition: Equatable {
        case running
        case done
        /// Nothing was found in time or the recognizer failed: only hand-drawn boxes are available.
        case failed
    }

    /// Defaults that survive launches. Local only.
    struct Preferences: Equatable, Sendable {
        var style: MaskStyle
        var stripMetadata: Bool

        static let styleKey = "editor.style"
        static let stripMetadataKey = "editor.stripMetadata"

        static func load(from defaults: UserDefaults = .standard) -> Preferences {
            let style = defaults.string(forKey: styleKey).flatMap(MaskStyle.init(rawValue:)) ?? .default
            let strip: Bool
            if defaults.object(forKey: stripMetadataKey) == nil { strip = true } else { strip = defaults.bool(forKey: stripMetadataKey) }
            return Preferences(style: style, stripMetadata: strip)
        }

        func save(to defaults: UserDefaults = .standard) {
            defaults.set(style.rawValue, forKey: Self.styleKey)
            defaults.set(stripMetadata, forKey: Self.stripMetadataKey)
        }
    }

    let picture: PictureSource
    /// Upright full-size pixels.
    let size: CGSize
    /// Upright, long side at most `previewLongSide`. The screen shows this, never the full pixels.
    let preview: CGImage
    let previewScale: CGSize

    private(set) var recognition: Recognition = .running
    private(set) var items: [MaskItem] = []
    private(set) var preferences: Preferences
    /// While true the picture is shown without its covers (hold to see the original).
    var showsOriginal = false
    /// Whether Review Each Item is up (design.md §7.4). It goes off by itself when the sheet
    /// closes, when the editor is left and when the app goes to the background.
    var reviewShown = false
    /// Whether the drawing tool is selected (design.md §7.3.7): the next drag on the picture draws a
    /// box. Selecting it again, opening Review Each Item or leaving the editor switches it off.
    var drawToolOn = false
    /// The item the picture should scroll to, set by "locate", cleared by the picture once there.
    var locateRequest: Int?
    private var nextID = 1
    private var undoStack: [[MaskItem]] = []
    private var redoStack: [[MaskItem]] = []
    private var recognitionTask: Task<Void, Never>?
    /// How long to wait for suggestions before giving up and leaving only the hand-drawn boxes.
    var recognitionTimeout: Duration = .seconds(8)

    init(picture: PictureSource, previewLongSide: Int = 2048, defaults: UserDefaults = .standard) {
        self.picture = picture
        size = picture.size
        preview = picture.thumbnail(maxLongSide: previewLongSide) ?? .blank
        previewScale = CGSize(width: preview.width > 0 ? size.width / CGFloat(preview.width) : 1,
                              height: preview.height > 0 ? size.height / CGFloat(preview.height) : 1)
        preferences = Preferences.load(from: defaults)
        self.defaults = defaults
    }

    private let defaults: UserDefaults

    // MARK: - Recognition

    func startRecognition() {
        guard recognitionTask == nil else { return }
        recognitionTask = Task { [weak self] in
            await self?.recognize()
        }
    }

    func cancelRecognition() {
        recognitionTask?.cancel()
        recognitionTask = nil
    }

    /// 「再試一次」after recognition failed (design.md §7.3.5): a fresh look at the picture, from the
    /// beginning, with nothing left of the previous one.
    func retryRecognition() {
        cancelRecognition()
        items = []
        undoStack = []
        redoStack = []
        locateRequest = nil
        showsOriginal = false
        drawToolOn = false
        recognition = .running
        startRecognition()
    }

    /// What has to go off by itself when the editor is left, the export page or the picker opens,
    /// or the app goes to the background (copy.md 7.3, design.md §7.3.7).
    func resetTransientState() {
        showsOriginal = false
        drawToolOn = false
        reviewShown = false
    }

    private func recognize() async {
        let recognizer = Recognizer()
        let preview = preview
        let timeout = recognitionTimeout
        let outcome = await withTaskGroup(of: RecognitionResult?.self) { group in
            group.addTask { try? await recognizer.recognize(preview) }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        guard !Task.isCancelled else { return }
        if let result = outcome {
            adopt(result)
            recognition = .done
        } else {
            recognition = .failed
        }
        recognitionTask = nil
    }

    /// Turns a recognition of the preview picture into items in full-size pixels.
    func adopt(_ result: RecognitionResult) {
        var scale = CGSize(width: size.width / max(result.size.width, 1), height: size.height / max(result.size.height, 1))
        if result.size == .zero { scale = CGSize(width: 1, height: 1) }
        var new: [MaskItem] = []
        for finding in result.findings {
            let scaled = finding.scaled(by: scale)
            new.append(MaskItem(id: nextID, group: group(of: finding), origin: .suggestion, rule: finding.rule,
                                quad: scaled.quad, isOn: true, evidence: finding.evidence))
            nextID += 1
        }
        for line in result.textLines {
            new.append(MaskItem(id: nextID, group: .text, origin: .textLine, rule: nil,
                                quad: line.quad.map { CGPoint(x: $0.x * scale.width, y: $0.y * scale.height) },
                                isOn: false, evidence: line.text))
            nextID += 1
        }
        items = new
        undoStack = []
        redoStack = []
    }

    private func group(of finding: Finding) -> MaskItem.Group {
        switch finding.kind {
        case .face: .face
        case .text: .text
        case .code: .code
        }
    }

    // MARK: - What is covered

    var enabledItems: [MaskItem] { items.filter(\.isOn) }

    var checklist: [MaskItem] { items.filter(\.isListed) }

    /// What is covered right now, for the checklist's headline.
    var counts: (faces: Int, texts: Int, codes: Int) {
        var faces = 0, texts = 0, codes = 0
        for item in checklist where item.isOn {
            switch item.group {
            case .face: faces += 1
            case .text: texts += 1
            case .code: codes += 1
            }
        }
        return (faces, texts, codes)
    }

    /// True when every text line the recognizer read is covered.
    var coversAllText: Bool {
        let lines = items.filter { $0.origin == .textLine }
        return !lines.isEmpty && lines.allSatisfy(\.isOn)
    }

    // MARK: - Edits (each one undoable)

    func setOn(_ id: Int, _ on: Bool) {
        guard let index = items.firstIndex(where: { $0.id == id }), items[index].isOn != on else { return }
        pushUndo()
        items[index].isOn = on
    }

    func toggle(_ id: Int) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        setOn(id, !item.isOn)
    }

    func remove(_ id: Int) {
        guard items.contains(where: { $0.id == id }) else { return }
        pushUndo()
        items.removeAll { $0.id == id }
    }

    /// Adds a box drawn by hand. `rect` is in full-size upright pixels.
    func addManualBox(_ rect: CGRect) {
        guard rect.width >= 4, rect.height >= 4 else { return }
        pushUndo()
        items.append(MaskItem(id: nextID, group: .text, origin: .manual, rule: nil,
                              quad: [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
                                     CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)],
                              isOn: true, evidence: ""))
        nextID += 1
    }

    func setAllText(_ on: Bool) {
        let changed = items.contains { $0.origin == .textLine && $0.isOn != on }
        guard changed else { return }
        pushUndo()
        for index in items.indices where items[index].origin == .textLine {
            items[index].isOn = on
        }
    }

    func setStyle(_ style: MaskStyle) {
        guard preferences.style != style else { return }
        preferences.style = style
        preferences.save(to: defaults)
    }

    func setStripMetadata(_ on: Bool) {
        guard preferences.stripMetadata != on else { return }
        preferences.stripMetadata = on
        preferences.save(to: defaults)
    }

    func requestLocate(_ id: Int) { locateRequest = id }

    // MARK: - Undo / redo

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    private func pushUndo() {
        undoStack.append(items)
        if undoStack.count > 50 { undoStack.removeFirst() }
        redoStack = []
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(items)
        items = previous
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(items)
        items = next
    }

    // MARK: - Export

    /// The result file, same pixel size as the original, covers pressed in. Encoded off the main actor.
    func exportData() async throws -> Data {
        let picture = picture
        let findings = enabledItems.map(\.finding)
        let options = MaskRenderer.Options(style: preferences.style, stripMetadata: preferences.stripMetadata)
        return try await Task.detached(priority: .userInitiated) {
            try MaskRenderer.encode(picture.source, orientation: picture.orientation, findings: findings, options: options)
        }.value
    }
}

extension CGImage {
    /// A blank 1×1 picture, for a source whose preview could not be decoded.
    static var blank: CGImage { CGImage.rgbaContext(width: 1, height: 1)!.makeImage()! }
}
