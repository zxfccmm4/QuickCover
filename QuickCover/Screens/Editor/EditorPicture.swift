import SwiftUI
import UIKit

/// The picture and everything on it (design.md §7.3): fitted in the area it is given, the covers
/// the export will press in, the capsules, and the gestures (two fingers zoom 1…4 and move, a
/// held finger shows the original, the drawing tool draws a box). Single taps do nothing.
struct EditorPicture: View {
    /// The area the picture may fill, in points.
    let area: CGSize
    /// How much of the area stays visible when Review Each Item is up: from its top down to the
    /// sheet's edge.「Locate」(§7.4.3) frames an item in that part.
    var reviewVisibleHeight: CGFloat = 0
    /// While the picture is being looked at it is blurred, 14 pt, and what is on it is not (§7.3.1).
    var isBlurred = false

    @Environment(EditorModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var zoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var patches: [CoverPatch] = []
    /// Whether the covers have had their entrance (§7.3.2, §8): they come once, all together.
    @State private var coversAppeared = false
    @State private var drag: DragState?
    @State private var pinch: PinchState?
    @State private var isHolding = false
    @State private var holdTask: Task<Void, Never>?
    @State private var draft: Draft?
    @State private var ring: CGRect?
    @State private var ringLit = false
    @State private var ringTask: Task<Void, Never>?
    @State private var hintShown = false
    @State private var hintTask: Task<Void, Never>?

    private struct DragState {
        var startOffset: CGSize
        var moved = false
        var magnified = false
    }

    private struct PinchState {
        var zoom: CGFloat
        var offset: CGSize
    }

    private struct Draft {
        var start: CGPoint
        var end: CGPoint
    }

    // MARK: - Where things are

    private var previewSize: CGSize {
        CGSize(width: model.preview.width, height: model.preview.height)
    }

    private var fitted: CGRect { EditorGeometry.fitted(size: previewSize, in: area) }
    private var areaCentre: CGPoint { CGPoint(x: area.width / 2, y: area.height / 2) }
    /// Points per preview pixel at zoom 1.
    private var pointsPerPixel: CGFloat {
        previewSize.width > 0 ? fitted.width / previewSize.width : 1
    }

    /// The part of the area that has to stay covered by the picture: all of it, or what is above
    /// the sheet while Review Each Item is up.
    private var visible: CGRect {
        let height = model.reviewShown && reviewVisibleHeight > 0 ? reviewVisibleHeight : area.height
        return CGRect(x: 0, y: 0, width: area.width, height: height)
    }

    private var coverKey: CoverKey { CoverKey(items: model.items, style: model.preferences.style) }

    // MARK: - Body

    var body: some View {
        let fitted = fitted
        let shown = CGSize(width: fitted.width * zoom, height: fitted.height * zoom)
        let picture = ZStack {
            Image(decorative: model.preview, scale: 1)
                .resizable()
                .frame(width: shown.width, height: shown.height)
            covers(pointsPerPixel: pointsPerPixel * zoom)
                .frame(width: shown.width, height: shown.height)
            if let ring {
                LocateRing(rect: rectInPoints(ring, scale: pointsPerPixel * zoom))
                    .opacity(ringLit ? 1 : 0)
            }
            if let draft, let box = EditorGeometry.drawnBox(from: draft.start, to: draft.end) {
                DrawBoxOverlay(rect: EditorGeometry.pictureRect(of: box, fitted: fitted, zoom: zoom, offset: offset, areaCentre: areaCentre))
            }
        }
        .frame(width: shown.width, height: shown.height)
        .position(x: fitted.midX + offset.width, y: fitted.midY + offset.height)
        .blur(radius: isBlurred ? 14 : 0)
        .animation(.easeInOut(duration: 0.25), value: isBlurred)

        ZStack {
            picture
            capsules(pictureTop: max(fitted.midY + offset.height - shown.height / 2, 0))
        }
        .frame(width: area.width, height: area.height)
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .simultaneousGesture(magnifyGesture)
        .animation(.easeInOut(duration: 0.2), value: capsulesKey)
        .task(id: coverKey) { await renderCovers() }
        .onChange(of: model.locateRequest) { _, id in if let id { locate(id) } }
        .onChange(of: model.reviewShown) { _, shown in if !shown { resetZoom() } }
        .onChange(of: model.recognition) { _, state in
            if state == .done, !model.found.isEmpty, HoldHint.isDue() { showHint() }
        }
        .onDisappear { cancelEverything() }
    }

    // MARK: - Covers

    /// The boxes that are on, each the picture's own pixels with its cover pressed in by
    /// `MaskRenderer`: what the export will give (§7.3.2). They fade in and out in 0.2 s; the
    /// first time they come they grow from 0.6, all at once (§8). A change of style cross-fades.
    private func covers(pointsPerPixel: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(patches) { patch in
                CoverPatchView(patch: patch, pointsPerPixel: pointsPerPixel)
                    .id("\(patch.id).\(model.preferences.style.rawValue)")
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
        // Drawn once at 0.6 and transparent, then let go: the spring of §8, 0.26 s, bounce 0.2.
        try? await Task.sleep(for: .milliseconds(32))
        guard !Task.isCancelled else { return }
        withAnimation(.spring(duration: 0.26, bounce: 0.2)) { coversAppeared = true }
    }

    // MARK: - Gestures

    /// One finger: a touch that stays down 0.35 s without moving shows the original until it lifts
    /// (§7.3.6); a touch that moves pans the picture, or draws a box with the drawing tool
    /// (§7.3.7). While the original is shown nothing pans.
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in dragChanged(value) }
            .onEnded { _ in dragEnded() }
    }

    private func dragChanged(_ value: DragGesture.Value) {
        if drag == nil {
            drag = DragState(startOffset: offset)
            if pinch == nil { beginHold() }
        }
        guard var state = drag else { return }
        if isHolding { return }
        let distance = hypot(value.translation.width, value.translation.height)
        if distance > EditorGeometry.holdSlop, !state.moved {
            state.moved = true
            cancelHold()
        }
        if pinch != nil {
            // Two fingers: the pinch moves the picture too (§7.3.7), and no box is being drawn.
            state.magnified = true
            drag = state
            return
        }
        drag = state
        if model.drawToolOn {
            if state.magnified { draft = nil } else { draft = Draft(start: value.startLocation, end: value.location) }
            return
        }
        guard state.moved else { return }
        offset = EditorGeometry.clamped(CGSize(width: state.startOffset.width + value.translation.width,
                                               height: state.startOffset.height + value.translation.height),
                                        picture: fitted.size, zoom: zoom, areaCentre: areaCentre, visible: visible)
    }

    private func dragEnded() {
        let state = drag
        drag = nil
        endHold()
        if model.drawToolOn, let draft, state?.magnified == false,
           let box = EditorGeometry.drawnBox(from: draft.start, to: draft.end) {
            close(box)
        }
        draft = nil
    }

    /// Two fingers zoom 1…4 about where they are (§7.3.2); with the drawing tool on, two fingers
    /// still zoom rather than draw (§7.3.7).
    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if pinch == nil {
                    pinch = PinchState(zoom: zoom, offset: offset)
                    cancelHold()
                    draft = nil
                }
                guard let start = pinch else { return }
                let newZoom = EditorGeometry.clampedZoom(start.zoom * value.magnification)
                // Zoom about where the fingers began (the gesture gives no current point).
                // Its anchor is in units of the view (0…1); the view is the area.
                let from = point(value.startAnchor)
                let newOffset = EditorGeometry.offset(zoomingFrom: start.zoom, to: newZoom, anchor: from,
                                                      areaCentre: areaCentre, offset: start.offset)
                zoom = newZoom
                offset = EditorGeometry.clamped(newOffset, picture: fitted.size, zoom: newZoom, areaCentre: areaCentre, visible: visible)
            }
            .onEnded { _ in pinch = nil }
    }

    /// A point of the gesture, in units of this view (0…1), in the area's points.
    private func point(_ unit: UnitPoint) -> CGPoint {
        CGPoint(x: unit.x * area.width, y: unit.y * area.height)
    }

    // MARK: - Hold to see the original

    private func beginHold() {
        holdTask?.cancel()
        holdTask = Task { @MainActor in
            try? await Task.sleep(for: EditorGeometry.holdDelay)
            guard !Task.isCancelled else { return }
            isHolding = true
            model.showsOriginal = true
            Haptics.hold()
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

    // MARK: - Drawing a box

    /// `box` is in the area's points; the model keeps full-size pixels.
    private func close(_ box: CGRect) {
        let inPicture = EditorGeometry.pictureRect(of: box, fitted: fitted, zoom: zoom, offset: offset, areaCentre: areaCentre)
        let perPoint = CGPoint(x: model.previewScale.width / pointsPerPixel, y: model.previewScale.height / pointsPerPixel)
        let rect = CGRect(x: inPicture.minX * perPoint.x, y: inPicture.minY * perPoint.y,
                          width: inPicture.width * perPoint.x, height: inPicture.height * perPoint.y)
        model.addManualBox(rect)
        Haptics.boxClosed()
    }

    // MARK: - Locate

    ///「Locate」(§7.4.3): the item to the middle of what is visible above the sheet, as large as
    /// it may be (1…3×), with the edge lit for 0.7 s then fading for 0.6 s.
    private func locate(_ id: Int) {
        model.locateRequest = nil
        guard let item = model.items.first(where: { $0.id == id }) else { return }
        let bounds = item.bounds
        let rect = CGRect(x: bounds.minX / model.previewScale.width * pointsPerPixel,
                          y: bounds.minY / model.previewScale.height * pointsPerPixel,
                          width: bounds.width / model.previewScale.width * pointsPerPixel,
                          height: bounds.height / model.previewScale.height * pointsPerPixel)
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

    // MARK: - Capsules

    private struct CapsulesKey: Equatable {
        var isFinding: Bool
        var showsOriginal: Bool
        var hint: Bool
    }

    private var capsulesKey: CapsulesKey {
        CapsulesKey(isFinding: model.recognition == .running, showsOriginal: model.showsOriginal,
                    hint: hintShown && !model.showsOriginal)
    }

    /// 4.2.1 in the middle while the picture is being looked at; 4.8.4 the first time, and 4.8.6
    /// while the original is shown, 8 under the picture's top edge. They fade in and out (§8) and
    /// are not read by VoiceOver (§9.1).
    private func capsules(pictureTop: CGFloat) -> some View {
        ZStack {
            if model.recognition == .running {
                PictureCapsule(text: "4.2.1", spins: true)
                    .transition(.opacity)
            }
            if hintShown, !model.showsOriginal {
                PictureCapsule(text: "4.8.4")
                    .transition(.opacity)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, pictureTop + 8)
            }
            if model.showsOriginal {
                PictureCapsule(text: "4.8.6", weight: .semibold)
                    .transition(.opacity)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, pictureTop + 8)
            }        }
        .accessibilityHidden(true)
    }

    /// 4.8.4 stays 5 s the first time a covered picture is seen, then never again (§7.3.3).
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
        CGRect(x: rect.minX * scale, y: rect.minY * scale, width: rect.width * scale, height: rect.height * scale)
    }

    private func cancelEverything() {
        holdTask?.cancel()
        ringTask?.cancel()
        hintTask?.cancel()
        if isHolding { model.showsOriginal = false }
        isHolding = false
    }
}

/// One cover on the picture: its pixels at its place. `pointsPerPixel` is the scale of the moment.
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

/// The two touches the editor makes (design.md §8): a light one when the hold shows the original
/// and when a drawn box closes, and a selection one when the style changes. Switches, glass
/// buttons and the segmented control have the system's own.
@MainActor
enum Haptics {
    static func hold() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func boxClosed() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func styleChanged() { UISelectionFeedbackGenerator().selectionChanged() }
}
