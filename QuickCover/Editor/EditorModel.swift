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
    /// The boxes of the item, each top-left, top-right, bottom-right, bottom-left, in upright
    /// full-size pixels.
    var quads: [[CGPoint]]
    var isOn: Bool
    /// What was read there. For the checklist's accessibility label and for tests.
    var evidence: String
    /// Text the recognizer read, a rule's hit or a text line. Not a box drawn by hand.
    var isTextRead: Bool { group == .text && origin != .manual }

    /// Height of Vision's box before any padding, in upright full-size pixels.
    var textHeight: CGFloat?

    init(id: Int, group: Group, origin: Origin, rule: TextRule?, quads: [[CGPoint]], isOn: Bool, evidence: String,
         textHeight: CGFloat? = nil) {
        precondition(!quads.isEmpty, "an item is at least one box")
        self.id = id
        self.group = group
        self.origin = origin
        self.rule = rule
        self.quads = quads
        self.isOn = isOn
        self.evidence = evidence
        self.textHeight = textHeight
    }

    init(id: Int, group: Group, origin: Origin, rule: TextRule?, quad: [CGPoint], isOn: Bool, evidence: String,
         textHeight: CGFloat? = nil) {
        self.init(id: id, group: group, origin: origin, rule: rule, quads: [quad], isOn: isOn, evidence: evidence,
                  textHeight: textHeight)
    }

    var quad: [CGPoint] { quads[0] }

    var bounds: CGRect {
        quads.map { Geometry.bounds(of: $0) }.reduce(CGRect.null) { $0.union($1) }
    }

    var isListed: Bool { origin != .textLine || isOn }

    var finding: Finding { findings[0] }

    var findings: [Finding] {
        quads.map {
            Finding(kind: Kind.of(group), rule: rule, quad: $0, evidence: evidence,
                    textHeight: textHeight, drawnByHand: origin == .manual)
        }
    }

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

/// Interactive magic animation burst emitted whenever covers are added, erased, removed, or restyled.
struct MagicBurstEvent: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case cover
        case erase
        case uncover
        case styleMorph
        case aiScan
    }

    let id: UUID
    /// Bounding rects in upright full-size pixels where the particle/shimmer wave originates.
    let rects: [CGRect]
    let kind: Kind
    let createdAt: TimeInterval

    init(rects: [CGRect], kind: Kind, createdAt: TimeInterval = Date().timeIntervalSinceReferenceDate) {
        self.id = UUID()
        self.rects = rects
        self.kind = kind
        self.createdAt = createdAt
    }
}

/// The picture being worked on: covers, Apple Intelligence semantic scan, style/color/emoji/granularity,
/// interactive magic animation events, anti-theft watermark, and export.
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
        var solidColor: SolidColorPreset = .black
        var customSolidColor: CustomColorRGB? = nil
        var mosaicTint: MosaicTint = .original
        var emoji: String = EmojiPreset.default
        var recentEmojis: [String] = []
        var strength: MaskStrength = .standard
        var exportFormat: ExportFormat = .original
        var autoAppleIntelligence: Bool = true

        static let styleKey = "editor.style"
        static let stripMetadataKey = "editor.stripMetadata"
        static let solidColorKey = "editor.solidColor"
        static let customSolidColorKey = "editor.customSolidColor"
        static let mosaicTintKey = "editor.mosaicTint"
        static let emojiKey = "editor.emoji"
        static let recentEmojisKey = "editor.recentEmojis"
        static let strengthKey = "editor.strength"
        static let exportFormatKey = "editor.exportFormat"
        static let autoAppleIntelligenceKey = "editor.autoAppleIntelligence"

        init(
            style: MaskStyle,
            stripMetadata: Bool,
            solidColor: SolidColorPreset = .black,
            customSolidColor: CustomColorRGB? = nil,
            mosaicTint: MosaicTint = .original,
            emoji: String = EmojiPreset.default,
            recentEmojis: [String] = [],
            strength: MaskStrength = .standard,
            exportFormat: ExportFormat = .original,
            autoAppleIntelligence: Bool = true
        ) {
            self.style = style
            self.stripMetadata = stripMetadata
            self.solidColor = solidColor
            self.customSolidColor = customSolidColor
            self.mosaicTint = mosaicTint
            self.emoji = emoji
            self.recentEmojis = recentEmojis
            self.strength = strength
            self.exportFormat = exportFormat
            self.autoAppleIntelligence = autoAppleIntelligence
        }

        static func load(from defaults: UserDefaults = .standard) -> Preferences {
            let style = defaults.string(forKey: styleKey).flatMap(MaskStyle.init(rawValue:)) ?? .default
            let strip = defaults.object(forKey: stripMetadataKey) == nil ? true : defaults.bool(forKey: stripMetadataKey)
            let solidColor = defaults.string(forKey: solidColorKey).flatMap(SolidColorPreset.init(rawValue:)) ?? .black
            let customSolid = defaults.data(forKey: customSolidColorKey).flatMap {
                try? JSONDecoder().decode(CustomColorRGB.self, from: $0)
            }
            let mosaicTint = defaults.data(forKey: mosaicTintKey).flatMap {
                try? JSONDecoder().decode(MosaicTint.self, from: $0)
            } ?? .original
            let emoji = defaults.string(forKey: emojiKey) ?? EmojiPreset.default
            let recentEmojis = defaults.stringArray(forKey: recentEmojisKey) ?? []
            let strength = defaults.string(forKey: strengthKey).flatMap(MaskStrength.init(rawValue:)) ?? .standard
            let format = defaults.string(forKey: exportFormatKey).flatMap(ExportFormat.init(rawValue:)) ?? .original
            let autoAI = defaults.object(forKey: autoAppleIntelligenceKey) == nil ? true : defaults.bool(forKey: autoAppleIntelligenceKey)
            return Preferences(
                style: style,
                stripMetadata: strip,
                solidColor: solidColor,
                customSolidColor: customSolid,
                mosaicTint: mosaicTint,
                emoji: emoji,
                recentEmojis: recentEmojis,
                strength: strength,
                exportFormat: format,
                autoAppleIntelligence: autoAI
            )
        }

        func save(to defaults: UserDefaults = .standard) {
            defaults.set(style.rawValue, forKey: Self.styleKey)
            defaults.set(stripMetadata, forKey: Self.stripMetadataKey)
            defaults.set(solidColor.rawValue, forKey: Self.solidColorKey)
            if let customSolidColor, let encoded = try? JSONEncoder().encode(customSolidColor) {
                defaults.set(encoded, forKey: Self.customSolidColorKey)
            } else {
                defaults.removeObject(forKey: Self.customSolidColorKey)
            }
            if let encoded = try? JSONEncoder().encode(mosaicTint) {
                defaults.set(encoded, forKey: Self.mosaicTintKey)
            }
            defaults.set(emoji, forKey: Self.emojiKey)
            defaults.set(recentEmojis, forKey: Self.recentEmojisKey)
            defaults.set(strength.rawValue, forKey: Self.strengthKey)
            defaults.set(exportFormat.rawValue, forKey: Self.exportFormatKey)
            defaults.set(autoAppleIntelligence, forKey: Self.autoAppleIntelligenceKey)
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
    /// Per-image anti-theft watermark settings (intentionally off by default on each new image).
    var watermark: WatermarkOptions = .off
    /// Whether the watermark configuration sheet is presented.
    var watermarkShown = false
    /// Whether the expanded emoji catalog picker sheet is presented.
    var emojiPickerShown = false
    /// Whether the floating in-editor quick style tray is expanded.
    var styleTrayShown = false
    /// Selected hand-drawn box ID for quick reposition or delete on canvas.
    var selectedManualID: Int?
    /// While true the picture is shown without its covers (hold to see the original).
    var showsOriginal = false
    /// Whether Review Each Item is up.
    var reviewShown = false
    /// Whether the drawing tool is selected.
    var drawToolOn = false
    /// The item the picture should scroll to, set by "locate", cleared by the picture once there.
    var locateRequest: Int?

    /// Live status for Apple Intelligence on-device semantic privacy detection.
    private(set) var isRunningIntelligence = false
    private(set) var lastIntelligenceAddedCount: Int?
    private(set) var lastIntelligenceEngine: AppleIntelligenceAdvisor.Engine?
    /// Latest interactive magic sparkle / shimmer burst for `EditorPicture` to render.
    private(set) var magicBurst: MagicBurstEvent?

    private var nextID = 1
    private var undoStack: [[MaskItem]] = []
    private var redoStack: [[MaskItem]] = []
    private var recognitionTask: Task<Void, Never>?
    var recognitionTimeout: Duration = .seconds(8)
    @ObservationIgnored var onStyleChanged: ((MaskStyle) -> Void)?

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

    /// Combined appearance state for preview & export rendering.
    var maskAppearance: MaskAppearance {
        MaskAppearance(
            style: preferences.style,
            solidColor: preferences.solidColor,
            customSolidColor: preferences.customSolidColor,
            mosaicTint: preferences.mosaicTint,
            emoji: preferences.emoji,
            strength: preferences.strength,
            watermark: watermark
        )
    }

    /// Resolved export options for `MaskRenderer.encode` and `CoveredImageExport`.
    var exportOptions: MaskRenderer.Options {
        MaskRenderer.Options(
            style: preferences.style,
            solidColor: preferences.solidColor,
            customSolidColor: preferences.customSolidColor,
            mosaicTint: preferences.mosaicTint,
            emoji: preferences.emoji,
            strength: preferences.strength,
            watermark: watermark,
            stripMetadata: preferences.stripMetadata,
            format: preferences.exportFormat
        )
    }

    /// Quick-bar emojis merging recently picked custom emojis ahead of curated defaults.
    var quickBarEmojis: [String] {
        var combined: [String] = []
        for symbol in ([preferences.emoji] + preferences.recentEmojis + EmojiPreset.quickBar) {
            guard !symbol.isEmpty, !combined.contains(symbol) else { continue }
            combined.append(symbol)
            if combined.count >= 10 { break }
        }
        return combined
    }

    // MARK: - Recognition & Apple Intelligence

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

    func retryRecognition() {
        cancelRecognition()
        items = []
        undoStack = []
        redoStack = []
        locateRequest = nil
        selectedManualID = nil
        showsOriginal = false
        drawToolOn = false
        lastIntelligenceAddedCount = nil
        lastIntelligenceEngine = nil
        recognition = .running
        startRecognition()
    }

    func resetTransientState() {
        showsOriginal = false
        drawToolOn = false
        reviewShown = false
        watermarkShown = false
        emojiPickerShown = false
        styleTrayShown = false
        selectedManualID = nil
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
            let initialRects = enabledItems.map(\.bounds)
            if !initialRects.isEmpty {
                emitBurst(rects: initialRects, kind: preferences.style == .conceal ? .erase : .cover)
            }
            if preferences.autoAppleIntelligence && AppleIntelligenceAdvisor.isAppleIntelligenceAvailable {
                await runAppleIntelligenceScan(applyMagicErase: false, silentWhenNone: true)
            }
        } else {
            recognition = .failed
        }
        recognitionTask = nil
    }

    /// Runs on-device Apple Intelligence (`FoundationModels` / contextual privacy advisor) over
    /// uncovered text lines to automatically detect personal names, addresses, handles, and order codes.
    /// Optionally switches active masking style to seamless Magic Erase (`.conceal`).
    @discardableResult
    func runAppleIntelligenceScan(applyMagicErase: Bool = false, silentWhenNone: Bool = false) async -> Int {
        guard !isRunningIntelligence else { return 0 }
        isRunningIntelligence = true
        defer { isRunningIntelligence = false }

        let candidates = items.enumerated().filter { $0.element.origin == .textLine && !$0.element.isOn }
        let candidateTexts = candidates.map(\.element.evidence)
        let advice = await AppleIntelligenceAdvisor.detectSensitiveLines(candidateTexts)
        guard !Task.isCancelled else { return 0 }

        var newlyCoveredRects: [CGRect] = []
        let targetIndices = advice.sensitiveLineIndices.compactMap { idx -> Int? in
            guard idx >= 0, idx < candidates.count else { return nil }
            return candidates[idx].offset
        }

        if !targetIndices.isEmpty {
            pushUndo()
            for itemIndex in targetIndices {
                items[itemIndex].isOn = true
                newlyCoveredRects.append(items[itemIndex].bounds)
            }
        }

        if applyMagicErase && preferences.style != .conceal {
            setStyle(.conceal)
        }

        lastIntelligenceEngine = advice.engine
        if !silentWhenNone || !newlyCoveredRects.isEmpty {
            lastIntelligenceAddedCount = newlyCoveredRects.count
        }

        let burstRects = !newlyCoveredRects.isEmpty ? newlyCoveredRects : enabledItems.map(\.bounds)
        if !burstRects.isEmpty {
            emitBurst(rects: burstRects, kind: applyMagicErase ? .erase : .aiScan)
        }

        return newlyCoveredRects.count
    }

    /// Turns a recognition of the preview picture into items in full-size pixels.
    func adopt(_ result: RecognitionResult) {
        var scale = CGSize(width: size.width / max(result.size.width, 1), height: size.height / max(result.size.height, 1))
        if result.size == .zero { scale = CGSize(width: 1, height: 1) }
        var new: [MaskItem] = []
        for finding in result.findings {
            let scaled = finding.scaled(by: scale)
            new.append(MaskItem(id: nextID, group: group(of: finding), origin: .suggestion, rule: finding.rule,
                                quads: scaled.quads, isOn: true, evidence: finding.evidence, textHeight: scaled.textHeight))
            nextID += 1
        }
        for line in result.textLines {
            new.append(MaskItem(id: nextID, group: .text, origin: .textLine, rule: nil,
                                quads: [line.quad.map { CGPoint(x: $0.x * scale.width, y: $0.y * scale.height) }],
                                isOn: false, evidence: line.text, textHeight: line.lineHeight.map { $0 * scale.height }))
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

    var coversText: Bool { enabledItems.contains { $0.isTextRead } }

    var checklist: [MaskItem] { items.filter(\.isListed) }

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

    var coversAllText: Bool {
        let lines = items.filter { $0.origin == .textLine }
        return !lines.isEmpty && lines.allSatisfy(\.isOn)
    }

    /// Suggested items belonging to a given category (`face`, `text` suggestions, or `code`).
    func suggestionItems(in group: MaskItem.Group) -> [MaskItem] {
        items.filter { $0.origin == .suggestion && $0.group == group }
    }

    /// Whether every suggested item in `group` is currently covered.
    func isGroupCovered(_ group: MaskItem.Group) -> Bool {
        let matched = suggestionItems(in: group)
        return !matched.isEmpty && matched.allSatisfy(\.isOn)
    }

    /// Batch toggles all auto-detected items in a category (`face`, sensitive `text`, or `code`).
    func setGroupCovered(_ group: MaskItem.Group, _ on: Bool) {
        let changedIndices = items.indices.filter {
            items[$0].origin == .suggestion && items[$0].group == group && items[$0].isOn != on
        }
        guard !changedIndices.isEmpty else { return }
        pushUndo()
        var rects: [CGRect] = []
        for index in changedIndices {
            items[index].isOn = on
            rects.append(items[index].bounds)
        }
        emitBurst(rects: rects, kind: on ? activeCoverBurstKind : .uncover)
    }

    // MARK: - Edits (each one undoable)

    func setOn(_ id: Int, _ on: Bool) {
        guard let index = items.firstIndex(where: { $0.id == id }), items[index].isOn != on else { return }
        pushUndo()
        items[index].isOn = on
        emitBurst(rects: [items[index].bounds], kind: on ? activeCoverBurstKind : .uncover)
    }

    func toggle(_ id: Int) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        setOn(id, !item.isOn)
    }

    func remove(_ id: Int) {
        guard let removed = items.first(where: { $0.id == id }) else { return }
        pushUndo()
        items.removeAll { $0.id == id }
        if selectedManualID == id { selectedManualID = nil }
        emitBurst(rects: [removed.bounds], kind: .uncover)
    }

    /// Adds a box drawn by hand. `rect` is in full-size upright pixels.
    func addManualBox(_ rect: CGRect) {
        guard rect.width >= 4, rect.height >= 4 else { return }
        pushUndo()
        items.append(MaskItem(id: nextID, group: .text, origin: .manual, rule: nil,
                              quads: [[CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
                                      CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)]],
                              isOn: true, evidence: ""))
        nextID += 1
        emitBurst(rects: [rect], kind: activeCoverBurstKind)
    }

    /// Moves a hand-drawn box by `(dx, dy)` in full-size upright pixels, clamped within the image bounds.
    func moveManualBox(_ id: Int, by delta: CGSize) {
        guard let index = items.firstIndex(where: { $0.id == id && $0.origin == .manual }) else { return }
        let bounds = items[index].bounds
        let clampedDX = min(max(delta.width, -bounds.minX), size.width - bounds.maxX)
        let clampedDY = min(max(delta.height, -bounds.minY), size.height - bounds.maxY)
        guard abs(clampedDX) >= 1 || abs(clampedDY) >= 1 else { return }
        pushUndo()
        items[index].quads = items[index].quads.map { quad in
            quad.map { CGPoint(x: $0.x + clampedDX, y: $0.y + clampedDY) }
        }
    }

    func setAllText(_ on: Bool) {
        let changedIndices = items.indices.filter { items[$0].origin == .textLine && items[$0].isOn != on }
        guard !changedIndices.isEmpty else { return }
        pushUndo()
        var rects: [CGRect] = []
        for index in changedIndices {
            items[index].isOn = on
            rects.append(items[index].bounds)
        }
        emitBurst(rects: rects, kind: on ? activeCoverBurstKind : .uncover)
    }

    func setStyle(_ style: MaskStyle) {
        guard preferences.style != style else { return }
        preferences.style = style
        preferences.save(to: defaults)
        onStyleChanged?(style)
        let rects = enabledItems.map(\.bounds)
        if !rects.isEmpty {
            emitBurst(rects: rects, kind: style == .conceal ? .erase : .styleMorph)
        }
    }

    func setSolidColor(_ preset: SolidColorPreset) {
        guard preferences.solidColor != preset || preferences.customSolidColor != nil else { return }
        preferences.solidColor = preset
        preferences.customSolidColor = nil
        preferences.save(to: defaults)
        emitStyleMorphIfActive()
    }

    func setCustomSolidColor(_ color: CustomColorRGB) {
        guard preferences.customSolidColor != color else { return }
        preferences.customSolidColor = color
        preferences.save(to: defaults)
        emitStyleMorphIfActive()
    }

    func setMosaicTint(_ tint: MosaicTint) {
        guard preferences.mosaicTint != tint else { return }
        preferences.mosaicTint = tint
        preferences.save(to: defaults)
        emitStyleMorphIfActive()
    }

    func setEmoji(_ emoji: String) {
        let cleaned = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        let singleEmoji = String(cleaned.prefix(1))
        var recents = preferences.recentEmojis.filter { $0 != singleEmoji }
        recents.insert(singleEmoji, at: 0)
        if recents.count > 12 { recents = Array(recents.prefix(12)) }
        let changed = preferences.emoji != singleEmoji || preferences.recentEmojis != recents
        guard changed else { return }
        preferences.emoji = singleEmoji
        preferences.recentEmojis = recents
        preferences.save(to: defaults)
        emitStyleMorphIfActive()
    }

    func setStrength(_ strength: MaskStrength) {
        guard preferences.strength != strength else { return }
        preferences.strength = strength
        preferences.save(to: defaults)
        emitStyleMorphIfActive()
    }

    func setExportFormat(_ format: ExportFormat) {
        guard preferences.exportFormat != format else { return }
        preferences.exportFormat = format
        preferences.save(to: defaults)
    }

    func setAutoAppleIntelligence(_ on: Bool) {
        guard preferences.autoAppleIntelligence != on else { return }
        preferences.autoAppleIntelligence = on
        preferences.save(to: defaults)
    }

    private var activeCoverBurstKind: MagicBurstEvent.Kind {
        preferences.style == .conceal ? .erase : .cover
    }

    private func emitStyleMorphIfActive() {
        let rects = enabledItems.map(\.bounds)
        if !rects.isEmpty {
            emitBurst(rects: rects, kind: .styleMorph)
        }
    }

    private func emitBurst(rects: [CGRect], kind: MagicBurstEvent.Kind) {
        guard !rects.isEmpty else { return }
        magicBurst = MagicBurstEvent(rects: rects, kind: kind)
    }

    /// Finds an uncovered item hit by a tap in upright full-size pixels.
    func uncoveredItem(at point: CGPoint, minimumSide: CGFloat, smallTargetPad: CGFloat) -> MaskItem? {
        items.first { item in
            guard !item.isOn else { return false }
            return hits(item, at: point, minimumSide: minimumSide, smallTargetPad: smallTargetPad)
        }
    }

    /// Finds the topmost item (preferring hand-drawn boxes, then covered suggestions, then uncovered
    /// text lines) at `point` in upright full-size pixels for direct tap-to-toggle/select on canvas.
    func hitItem(at point: CGPoint, minimumSide: CGFloat, smallTargetPad: CGFloat) -> MaskItem? {
        if let manual = items.reversed().first(where: {
            $0.origin == .manual && $0.isOn && hits($0, at: point, minimumSide: minimumSide, smallTargetPad: smallTargetPad)
        }) {
            return manual
        }
        if let active = items.reversed().first(where: {
            $0.isOn && hits($0, at: point, minimumSide: minimumSide, smallTargetPad: smallTargetPad)
        }) {
            return active
        }
        return uncoveredItem(at: point, minimumSide: minimumSide, smallTargetPad: smallTargetPad)
    }

    private func hits(_ item: MaskItem, at point: CGPoint, minimumSide: CGFloat, smallTargetPad: CGFloat) -> Bool {
        item.quads.contains { quad in
            var rect = Geometry.bounds(of: quad)
            if rect.width < minimumSide || rect.height < minimumSide {
                rect = rect.insetBy(dx: -smallTargetPad, dy: -smallTargetPad)
            }
            return rect.contains(point)
        }
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
        if let selected = selectedManualID, !items.contains(where: { $0.id == selected }) {
            selectedManualID = nil
        }
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(items)
        items = next
    }

    // MARK: - Export

    /// The result file, same pixel size as the original, covers & optional watermark pressed in.
    func exportData() async throws -> Data {
        let picture = picture
        let findings = enabledItems.flatMap(\.findings)
        let options = exportOptions
        return try await Task.detached(priority: .userInitiated) {
            try MaskRenderer.encode(picture.source, orientation: picture.orientation, findings: findings, options: options)
        }.value
    }
}

extension CGImage {
    /// A blank 1×1 picture, for a source whose preview could not be decoded.
    static var blank: CGImage { CGImage.rgbaContext(width: 1, height: 1)!.makeImage()! }
}
