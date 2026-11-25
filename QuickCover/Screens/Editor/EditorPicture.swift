import SwiftUI

/// Interactive photo canvas with covers, live anti-theft watermark, pinch & double-tap zoom, pan,
/// hold-to-compare, direct tap-to-toggle on any detected area, subtle uncovered-suggestion hints,
/// draggable/deletable Markup-style manual boxes, and Liquid Glass status capsules.
struct EditorPicture: View {
    let area: CGSize
    var reviewVisibleHeight: CGFloat = 0
    var isBlurred = false
    var zoomResetTrigger: Int = 0
    var onZoomChanged: ((CGFloat) -> Void)? = nil
    var onTapOutsideReview: (() -> Void)? = nil

    @Environment(EditorModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var capsuleNamespace

    @State private var zoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var patches: [CoverPatch] = []
    @State private var coversAppeared = false
    @State private var drag: DragState?
    @State private var manualDrag: ManualDragState?
    @State private var pinch: PinchState?
    @State private var isHolding = false
    @State private var holdTask: Task<Void, Never>?
    @State private var draft: Draft?
    @State private var ring: CGRect?
    @State private var ringLit = false
    @State private var ringTask: Task<Void, Never>?
    @State private var hintShown = false
    @State private var hintTask: Task<Void, Never>?
    @State private var lastEmptyTap: (point: CGPoint, time: ContinuousClock.Instant)?
    @State private var holdFeedbackCount = 0
    @State private var boxFeedbackCount = 0
    @State private var selectionFeedbackCount = 0

    private struct DragState {
        var startOffset: CGSize
        var startLocation: CGPoint
        var moved = false
        var magnified = false
        var startedAt = ContinuousClock.now
    }

    private struct ManualDragState {
        var itemID: Int
        var liveOffset: CGSize = .zero
    }

    private struct PinchState {
        var zoom: CGFloat
        var offset: CGSize
    }

    private struct Draft {
        var start: CGPoint
        var end: CGPoint
    }

    // MARK: - Geometry

    private var previewSize: CGSize {
        CGSize(width: model.preview.width, height: model.preview.height)
    }

    private var fitted: CGRect { EditorGeometry.fitted(size: previewSize, in: area) }
    private var areaCentre: CGPoint { CGPoint(x: area.width / 2, y: area.height / 2) }
    private var pointsPerPixel: CGFloat {
        previewSize.width > 0 ? fitted.width / previewSize.width : 1
    }

    private var visible: CGRect {
        let height = model.reviewShown && reviewVisibleHeight > 0 ? reviewVisibleHeight : area.height
        return CGRect(x: 0, y: 0, width: area.width, height: height)
    }

    private var coverKey: CoverKey { CoverKey(items: model.items, appearance: model.maskAppearance) }

    private var appearanceIdentity: String {
        let p = model.preferences
        return "\(p.style.rawValue).\(p.solidColor.rawValue).\(p.emoji).\(p.strength.rawValue)"
    }

    private var selectedManualItem: MaskItem? {
        guard let id = model.selectedManualID, !model.showsOriginal, !model.reviewShown else { return nil }
        return model.items.first { $0.id == id && $0.origin == .manual && $0.isOn }
    }

    private var uncoveredSuggestions: [MaskItem] {
        guard !model.showsOriginal else { return [] }
        return model.items.filter { $0.origin == .suggestion && !$0.isOn }
    }

    // MARK: - Body

    var body: some View {
        let fitted = fitted
        let shown = CGSize(width: fitted.width * zoom, height: fitted.height * zoom)
        let pictureShape = RoundedRectangle(cornerRadius: zoom > 1.01 ? 0 : 14, style: .continuous)
        let picture = ZStack(alignment: .topLeading) {
            Image(decorative: model.preview, scale: 1)
                .resizable()
                .frame(width: shown.width, height: shown.height)

            covers(pointsPerPixel: pointsPerPixel * zoom)
                .frame(width: shown.width, height: shown.height)

            if model.watermark.isActive {
                WatermarkLiveOverlay(options: model.watermark)
                    .frame(width: shown.width, height: shown.height)
                    .opacity(model.showsOriginal ? 0 : 1)
                    .animation(.easeInOut(duration: 0.15), value: model.showsOriginal)
            }

            ForEach(uncoveredSuggestions) { item in
                UncoveredSuggestionOutline(rect: scaled(fittedRect(for: item.bounds)))
                    .transition(.opacity)
            }

            if let selected = selectedManualItem {
                let baseRect = scaled(fittedRect(for: selected.bounds))
                let liveShift = manualDrag?.itemID == selected.id ? (manualDrag?.liveOffset ?? .zero) : .zero
                let shiftedRect = baseRect.offsetBy(dx: liveShift.width, dy: liveShift.height)
                SelectedManualBoxFrame(rect: shiftedRect)
            }

            if let ring {
                LocateRing(rect: scaled(ring))
                    .opacity(ringLit ? 1 : 0)
            }

            if let draft, let box = EditorGeometry.drawnBox(from: draft.start, to: draft.end) {
                DrawBoxOverlay(
                    rect: scaled(
                        EditorGeometry.pictureRect(
                            of: box,
                            fitted: fitted,
                            zoom: zoom,
                            offset: offset,
                            areaCentre: areaCentre
                        )
                    )
                )
            }
        }
        .frame(width: shown.width, height: shown.height)
        .clipShape(pictureShape)
        .overlay(
            pictureShape.stroke(Color.white.opacity(zoom > 1.01 ? 0 : 0.14), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(zoom > 1.01 ? 0 : 0.5), radius: 22, y: 10)
        .position(x: fitted.midX + offset.width, y: fitted.midY + offset.height)
        .blur(radius: isBlurred ? 14 : 0)
        .animation(.easeInOut(duration: 0.25), value: isBlurred)

        ZStack {
            picture
            selectedManualDeleteButton(fitted: fitted, shown: shown)
            capsules(pictureTop: max(fitted.midY + offset.height - shown.height / 2, 0))
        }
        .frame(width: area.width, height: area.height)
        .contentShape(.rect)
        .gesture(dragGesture)
        .simultaneousGesture(magnifyGesture)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: holdFeedbackCount)
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.6), trigger: boxFeedbackCount)
        .sensoryFeedback(.selection, trigger: selectionFeedbackCount)
        .animation(.easeInOut(duration: 0.2), value: capsulesKey)
        .task(id: coverKey) { await renderCovers() }
        .onChange(of: zoom) { _, newZoom in
            onZoomChanged?(newZoom)
        }
        .onChange(of: zoomResetTrigger) { _, _ in
            resetZoom()
        }
        .onChange(of: model.reviewShown) { _, shown in
            if !shown { resetZoom() }
            if shown { model.selectedManualID = nil }
        }
        .onChange(of: model.drawToolOn) { _, on in
            if on { model.selectedManualID = nil }
        }
        .onChange(of: model.locateRequest) { _, id in
            if let id { locate(id) }
        }
        .onChange(of: model.recognition) { _, state in
            if state == .done, !model.found.isEmpty, HoldHint.isDue() { showHint() }
        }
        .onDisappear { cancelEverything() }
    }

    // MARK: - Selected Manual Box Delete Control

    @ViewBuilder
    private func selectedManualDeleteButton(fitted: CGRect, shown: CGSize) -> some View {
        if let selected = selectedManualItem, manualDrag == nil {
            let picOriginX = fitted.midX + offset.width - shown.width / 2
            let picOriginY = fitted.midY + offset.height - shown.height / 2
            let boxInShown = scaled(fittedRect(for: selected.bounds))
            let boxMinYInArea = picOriginY + boxInShown.minY
            let boxMaxYInArea = picOriginY + boxInShown.maxY
            let centerX = min(max(picOriginX + boxInShown.midX, 70), max(70, area.width - 70))
            let placeAbove = boxMinYInArea > 56
            let targetY = placeAbove
                ? max(28, boxMinYInArea - 26)
                : min(max(28, area.height - 28), boxMaxYInArea + 26)

            Button {
                model.remove(selected.id)
                selectionFeedbackCount += 1
            } label: {
                Label("editor.deleteBox", systemImage: "trash")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .glassEffect(.regular.tint(Color.red.opacity(0.88)).interactive(), in: .capsule)
            }
            .buttonStyle(PressStyle(scale: 0.94))
            .position(x: centerX, y: targetY)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }

    // MARK: - Covers

    private func covers(pointsPerPixel: CGFloat) -> some View {
        let appearanceID = appearanceIdentity
        return ZStack(alignment: .topLeading) {
            ForEach(patches) { patch in
                CoverPatchView(patch: patch, pointsPerPixel: pointsPerPixel)
                    .id("\(patch.id).\(appearanceID)")
                    .transition(.opacity)
                    .scaleEffect(coversAppeared || reduceMotion ? 1 : 0.6)
                    .opacity(coversAppeared || reduceMotion ? 1 : 0)
            }
        }
        .opacity(model.showsOriginal ? 0 : 1)
        .animation(.easeInOut(duration: 0.15), value: model.showsOriginal)
    }

    private func renderCovers() async {
        let key = coverKey
        let drawn = CoverPainter.patches(for: key, preview: model.preview, scale: model.previewScale)
        withAnimation(.easeInOut(duration: 0.2)) { patches = drawn }
        guard !drawn.isEmpty, !coversAppeared else { return }
        if reduceMotion {
            coversAppeared = true
            return
        }
        try? await Task.sleep(for: .milliseconds(32))
        guard !Task.isCancelled else { return }
        withAnimation(.spring(duration: 0.26, bounce: 0.2)) { coversAppeared = true }
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in dragChanged(value) }
            .onEnded { value in dragEnded(value) }
    }

    private func dragChanged(_ value: DragGesture.Value) {
        if drag == nil {
            drag = DragState(startOffset: offset, startLocation: value.startLocation)

            if pinch == nil, !model.reviewShown, !model.drawToolOn,
               let selected = selectedManualItem,
               hitTestFullPoint(value.startLocation, hits: selected) {
                manualDrag = ManualDragState(itemID: selected.id)
            } else if pinch == nil, !model.reviewShown, model.recognition != .running {
                beginHold()
            }
        }
        guard var state = drag else { return }
        if isHolding { return }
        let distance = hypot(value.translation.width, value.translation.height)
        if distance > EditorGeometry.holdSlop, !state.moved {
            state.moved = true
            cancelHold()
        }
        if pinch != nil {
            state.magnified = true
            manualDrag = nil
            drag = state
            return
        }
        drag = state

        if var draggingManual = manualDrag {
            guard state.moved else { return }
            draggingManual.liveOffset = value.translation
            manualDrag = draggingManual
            return
        }

        if model.drawToolOn {
            draft = state.magnified ? nil : Draft(start: value.startLocation, end: value.location)
            return
        }
        guard state.moved else { return }
        offset = EditorGeometry.clamped(
            CGSize(
                width: state.startOffset.width + value.translation.width,
                height: state.startOffset.height + value.translation.height
            ),
            picture: fitted.size,
            zoom: zoom,
            areaCentre: areaCentre,
            visible: visible
        )
    }

    private func dragEnded(_ value: DragGesture.Value) {
        let state = drag
        let wasHolding = isHolding
        let finishedManualDrag = manualDrag
        drag = nil
        manualDrag = nil
        endHold()

        if let finishedManualDrag, state?.moved == true, state?.magnified == false, pointsPerPixel > 0 {
            let scaleX = model.previewScale.width / (pointsPerPixel * zoom)
            let scaleY = model.previewScale.height / (pointsPerPixel * zoom)
            let pixelDelta = CGSize(
                width: finishedManualDrag.liveOffset.width * scaleX,
                height: finishedManualDrag.liveOffset.height * scaleY
            )
            model.moveManualBox(finishedManualDrag.itemID, by: pixelDelta)
            return
        }

        if model.drawToolOn, let draft, state?.magnified == false,
           let box = EditorGeometry.drawnBox(from: draft.start, to: draft.end) {
            close(box)
            self.draft = nil
            return
        }
        self.draft = nil

        // Quick tap without drag, pinch, or hold-to-original:
        // dismiss ReviewSheet if open, select/deselect manual boxes, toggle any detected area,
        // or double-tap empty canvas to smoothly zoom in/out (Apple Photos muscle memory).
        if let state, !state.moved, !state.magnified, !wasHolding,
           state.startedAt.duration(to: .now) < EditorGeometry.holdDelay {
            if model.reviewShown {
                onTapOutsideReview?()
            } else if model.recognition == .done {
                handleCanvasTap(at: value.location)
            }
        }
    }

    private func handleCanvasTap(at areaPoint: CGPoint) {
        guard pointsPerPixel > 0 else { return }
        let fullPoint = fullImagePoint(for: areaPoint)
        let scaleX = model.previewScale.width / pointsPerPixel
        let scaleY = model.previewScale.height / pointsPerPixel
        let fullPerScreenPoint = max(scaleX, scaleY) / max(zoom, 1)

        if let hit = model.hitItem(
            at: fullPoint,
            minimumSide: Metrics.minimumTarget * fullPerScreenPoint,
            smallTargetPad: 8 * fullPerScreenPoint
        ) {
            lastEmptyTap = nil
            if hit.origin == .manual {
                withAnimation(.snappy(duration: 0.2)) {
                    model.selectedManualID = model.selectedManualID == hit.id ? nil : hit.id
                }
            } else {
                model.selectedManualID = nil
                model.toggle(hit.id)
            }
            selectionFeedbackCount += 1
        } else {
            if model.selectedManualID != nil {
                withAnimation(.snappy(duration: 0.2)) {
                    model.selectedManualID = nil
                }
                lastEmptyTap = nil
                return
            }
            // Double-tap empty area toggles 1× ↔ 2.2× centered on the finger.
            let now = ContinuousClock.now
            if let prev = lastEmptyTap,
               prev.time.duration(to: now) < .milliseconds(320),
               hypot(prev.point.x - areaPoint.x, prev.point.y - areaPoint.y) < 42 {
                lastEmptyTap = nil
                toggleDoubleTapZoom(at: areaPoint)
            } else {
                lastEmptyTap = (areaPoint, now)
            }
        }
    }

    private func toggleDoubleTapZoom(at anchor: CGPoint) {
        if zoom > 1.05 {
            resetZoom()
        } else {
            let targetZoom: CGFloat = 2.2
            let rawOffset = EditorGeometry.offset(
                zoomingFrom: zoom,
                to: targetZoom,
                anchor: anchor,
                areaCentre: areaCentre,
                offset: offset
            )
            let clamped = EditorGeometry.clamped(
                rawOffset,
                picture: fitted.size,
                zoom: targetZoom,
                areaCentre: areaCentre,
                visible: visible
            )
            withAnimation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.08)) {
                zoom = targetZoom
                offset = clamped
            }
        }
    }

    private func hitTestFullPoint(_ areaPoint: CGPoint, hits item: MaskItem) -> Bool {
        guard pointsPerPixel > 0 else { return false }
        let fullPoint = fullImagePoint(for: areaPoint)
        let pad = 14 * max(model.previewScale.width, model.previewScale.height) / max(pointsPerPixel * zoom, 1)
        return item.bounds.insetBy(dx: -pad, dy: -pad).contains(fullPoint)
    }

    private func fullImagePoint(for areaPoint: CGPoint) -> CGPoint {
        let inPicture = EditorGeometry.picturePoint(
            of: areaPoint,
            fitted: fitted,
            zoom: zoom,
            offset: offset,
            areaCentre: areaCentre
        )
        let scaleX = model.previewScale.width / pointsPerPixel
        let scaleY = model.previewScale.height / pointsPerPixel
        return CGPoint(x: inPicture.x * scaleX, y: inPicture.y * scaleY)
    }

    private func fittedRect(for fullBounds: CGRect) -> CGRect {
        CGRect(
            x: fullBounds.minX / model.previewScale.width * pointsPerPixel,
            y: fullBounds.minY / model.previewScale.height * pointsPerPixel,
            width: fullBounds.width / model.previewScale.width * pointsPerPixel,
            height: fullBounds.height / model.previewScale.height * pointsPerPixel
        )
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if pinch == nil {
                    pinch = PinchState(zoom: zoom, offset: offset)
                    cancelHold()
                    draft = nil
                    manualDrag = nil
                }
                guard let start = pinch else { return }
                let newZoom = EditorGeometry.clampedZoom(start.zoom * value.magnification)
                let from = point(value.startAnchor)
                let newOffset = EditorGeometry.offset(
                    zoomingFrom: start.zoom,
                    to: newZoom,
                    anchor: from,
                    areaCentre: areaCentre,
                    offset: start.offset
                )
                zoom = newZoom
                offset = EditorGeometry.clamped(
                    newOffset,
                    picture: fitted.size,
                    zoom: newZoom,
                    areaCentre: areaCentre,
                    visible: visible
                )
            }
            .onEnded { _ in pinch = nil }
    }

    private func point(_ unit: UnitPoint) -> CGPoint {
        CGPoint(x: unit.x * area.width, y: unit.y * area.height)
    }

    // MARK: - Hold to compare original

    private func beginHold() {
        holdTask?.cancel()
        holdTask = Task { @MainActor in
            try? await Task.sleep(for: EditorGeometry.holdDelay)
            guard !Task.isCancelled else { return }
            isHolding = true
            model.showsOriginal = true
            holdFeedbackCount += 1
        }
    }

    private func cancelHold() {
        holdTask?.cancel()
        holdTask = nil
        endHold()
    }

    private func endHold() {
        holdTask?.cancel()
        holdTask = nil
        guard isHolding else { return }
        isHolding = false
        model.showsOriginal = false
    }

    // MARK: - Manual box

    private func close(_ box: CGRect) {
        let inPicture = EditorGeometry.pictureRect(
            of: box,
            fitted: fitted,
            zoom: zoom,
            offset: offset,
            areaCentre: areaCentre
        )
        let perPoint = CGPoint(
            x: model.previewScale.width / pointsPerPixel,
            y: model.previewScale.height / pointsPerPixel
        )
        let rect = CGRect(
            x: inPicture.minX * perPoint.x,
            y: inPicture.minY * perPoint.y,
            width: inPicture.width * perPoint.x,
            height: inPicture.height * perPoint.y
        )
        model.addManualBox(rect)
        boxFeedbackCount += 1
    }

    // MARK: - Locate

    private func locate(_ id: Int) {
        model.locateRequest = nil
        guard let item = model.items.first(where: { $0.id == id }) else { return }
        let rect = fittedRect(for: item.bounds)
        let framing = EditorGeometry.locate(item: rect, fitted: fitted, areaCentre: areaCentre, visible: visible)
        withAnimation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0)) {
            zoom = framing.zoom
            offset = framing.offset
        }
        lightRing(rect)
    }

    private func lightRing(_ rect: CGRect) {
        ringTask?.cancel()
        ring = rect
        ringLit = true
        ringTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.6)) { ringLit = false }
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 600))
            guard !Task.isCancelled else { return }
            ring = nil
        }
    }

    private func resetZoom() {
        guard zoom != 1 || offset != .zero else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            zoom = 1
            offset = .zero
        }
    }

    // MARK: - Liquid Glass Capsules

    private struct CapsulesKey: Equatable {
        var isFinding: Bool
        var showsOriginal: Bool
        var hint: Bool
    }

    private var capsulesKey: CapsulesKey {
        CapsulesKey(
            isFinding: model.recognition == .running,
            showsOriginal: model.showsOriginal,
            hint: hintShown && !model.showsOriginal
        )
    }

    private func capsules(pictureTop: CGFloat) -> some View {
        GlassEffectContainer(spacing: 8) {
            ZStack {
                if model.recognition == .running {
                    PictureCapsule(text: "4.2.1", spins: true)
                        .glassEffectID("statusCapsule", in: capsuleNamespace)
                        .glassEffectTransition(.matchedGeometry)
                        .transition(.opacity)
                }
                if hintShown, !model.showsOriginal {
                    PictureCapsule(text: "4.8.4")
                        .glassEffectID("statusCapsule", in: capsuleNamespace)
                        .glassEffectTransition(.matchedGeometry)
                        .transition(.opacity)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.top, pictureTop + 10)
                }
                if model.showsOriginal {
                    PictureCapsule(text: "4.8.6", weight: .semibold)
                        .glassEffectID("statusCapsule", in: capsuleNamespace)
                        .glassEffectTransition(.matchedGeometry)
                        .transition(.opacity)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.top, pictureTop + 10)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func showHint() {
        guard !hintShown else { return }
        HoldHint.markSeen()
        hintShown = true
        hintTask?.cancel()
        hintTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            hintShown = false
        }
    }

    // MARK: - Helpers

    private func rectInPoints(_ rect: CGRect, scale: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX * scale,
            y: rect.minY * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
    }

    private func scaled(_ rect: CGRect) -> CGRect {
        rectInPoints(rect, scale: zoom)
    }

    private func cancelEverything() {
        holdTask?.cancel()
        ringTask?.cancel()
        hintTask?.cancel()
        if isHolding { model.showsOriginal = false }
        isHolding = false
    }
}

private struct CoverPatchView: View {
    let patch: CoverPatch
    let pointsPerPixel: CGFloat

    var body: some View {
        Image(decorative: patch.image, scale: 1)
            .resizable()
            .interpolation(.high)
            .frame(width: patch.frame.width * pointsPerPixel, height: patch.frame.height * pointsPerPixel)
            .position(x: patch.frame.midX * pointsPerPixel, y: patch.frame.midY * pointsPerPixel)
    }
}
