import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

/// Handoff payload launching Stage 2 (`LongScreenshotCanvasEditorView`) from either Stage 1 Hub
/// or Library multi-selection.
struct LongScreenshotSession: Identifiable, Sendable {
    let id = UUID()
    let initialMode: LongScreenshotStudioView.Mode
    var initialDirection: LongScreenshotStitcher.Direction = .vertical
    var initialImages: [CGImage] = []
    var initialVideoURL: URL? = nil
    var initialVideoAsset: SendableAVAsset? = nil
    var deleteVideoAfter: Bool = false
    var initialVideoPrecision: LongScreenshotStitcher.VideoPrecision = .standard
}

/// Stage 2: Native Apple Photos-inspired dark editing studio for stitched long screenshots.
/// - Clean native iOS 26 `.toolbar` adapting automatically between Preview mode and Focused Tool mode.
/// - Full-stage `AppleIntelligenceLoadingView` during smart overlap analysis and video frame extraction.
/// - Readable-width vertical canvas with direct on-image seam dragging + live zoomed loupe, plus
///   direct 4-edge cropping and compact frame filmstrip reordering.
struct LongScreenshotCanvasEditorView: View {
    enum StudioTool: String, CaseIterable, Identifiable {
        case seam
        case crop
        case frames

        var id: String { rawValue }

        var titleKey: String {
            switch self {
            case .seam: "longshot.studio.toolSeam"
            case .crop: "longshot.studio.toolCrop"
            case .frames: "longshot.studio.toolFrames"
            }
        }

        var systemImage: String {
            switch self {
            case .seam: "scissors"
            case .crop: "crop"
            case .frames: "rectangle.stack"
            }
        }
    }

    enum SeamDragMode: String, CaseIterable, Identifiable {
        case cut
        case gap

        var id: String { rawValue }

        var titleKey: String {
            switch self {
            case .cut: "longshot.seamDragCut"
            case .gap: "longshot.seamDragGap"
            }
        }
    }

    struct StudioFrame: Identifiable {
        let id = UUID()
        let image: CGImage
        let thumb: UIImage
    }

    private struct DividerColorOption: Identifiable {
        let id: String
        let rgb: CustomColorRGB
        let labelKey: String

        static let presets: [DividerColorOption] = [
            DividerColorOption(id: "mist", rgb: CustomColorRGB(red: 0.96, green: 0.96, blue: 0.97), labelKey: "longshot.color.mist"),
            DividerColorOption(id: "white", rgb: CustomColorRGB(red: 1.0, green: 1.0, blue: 1.0), labelKey: "longshot.color.white"),
            DividerColorOption(id: "slate", rgb: CustomColorRGB(red: 0.17, green: 0.17, blue: 0.18), labelKey: "longshot.color.slate"),
            DividerColorOption(id: "black", rgb: CustomColorRGB(red: 0.0, green: 0.0, blue: 0.0), labelKey: "longshot.color.black"),
        ]
    }

    let session: LongScreenshotSession
    let onBack: () -> Void
    let onComplete: (PictureSource) -> Void
    var onCompleteForExport: ((PictureSource) -> Void)? = nil

    @State private var frames: [StudioFrame] = []
    @State private var direction: LongScreenshotStitcher.Direction = .vertical
    @State private var smartOverlap = true
    @State private var spacing: LongScreenshotStitcher.Spacing = .none
    @State private var videoPrecision: LongScreenshotStitcher.VideoPrecision = .standard

    @State private var verticalLayout: LongScreenshotStitcher.VerticalLayout?
    @State private var seams: [LongScreenshotStitcher.SeamAdjustment] = []
    @State private var selectedSeamIndex: Int = 0
    @State private var uncroppedResult: LongScreenshotStitcher.Result?
    @State private var stitchedResult: LongScreenshotStitcher.Result?
    @State private var videoBaseResult: LongScreenshotStitcher.Result?

    @State private var cropInsets: LongScreenshotStitcher.CropInsets = .zero
    @State private var dividerColor: CustomColorRGB = LongScreenshotStitcher.defaultDividerColor

    @State private var activeTool: StudioTool? = nil
    @State private var isOverviewZoom = false
    @State private var seamDragMode: SeamDragMode = .cut
    @State private var draggingSeamIndex: Int?
    @State private var dragStartSeam: LongScreenshotStitcher.SeamAdjustment?
    @State private var dragDeltaPx: Int = 0
    @State private var seamLoupeImage: CGImage?

    @State private var isStitching = true
    @State private var progress: Double = 0
    @State private var errorMessage: String?
    @State private var rerenderTask: Task<Void, Never>?

    @State private var showsPhotosPicker = false
    @State private var pickedPhotoItems: [PhotosPickerItem] = []

    @State private var successCount = 0
    @State private var selectionCount = 0
    @State private var impactCount = 0

    private var canAdjustSeams: Bool {
        direction == .vertical && verticalLayout != nil && !seams.isEmpty
    }

    private var availableTools: [StudioTool] {
        if session.initialMode == .screenRecording {
            var tools: [StudioTool] = []
            if canAdjustSeams { tools.append(.seam) }
            tools.append(.crop)
            if frames.count >= 2 { tools.append(.frames) }
            return tools
        }
        return canAdjustSeams ? [.seam, .crop, .frames] : [.crop, .frames]
    }

    private var hasAnyEdits: Bool {
        if !cropInsets.isZero { return true }
        if dividerColor != LongScreenshotStitcher.defaultDividerColor { return true }
        if let layout = verticalLayout, layout.seams != seams { return true }
        return false
    }

    private var canResetActiveTool: Bool {
        switch activeTool {
        case .seam:
            if let layout = verticalLayout, layout.seams != seams { return true }
            return dividerColor != LongScreenshotStitcher.defaultDividerColor
        case .crop:
            return !cropInsets.isZero
        case .frames, .none:
            return false
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.09, blue: 0.11),
                    Color(red: 0.04, green: 0.04, blue: 0.05),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            studioCanvasArea
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            studioToolbarContent
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomStudioDock
        }
        .photosPicker(
            isPresented: $showsPhotosPicker,
            selection: $pickedPhotoItems,
            maxSelectionCount: 12,
            matching: .images
        )
        .onChange(of: pickedPhotoItems) { _, items in
            guard !items.isEmpty else { return }
            let captured = items
            pickedPhotoItems = []
            Task { await appendPickedItems(captured) }
        }
        .onChange(of: direction) { _, newValue in
            if newValue == .horizontal && activeTool == .seam {
                activeTool = .frames
            }
            selectionCount += 1
            Task { await restitchFrames() }
        }
        .onChange(of: smartOverlap) { _, _ in
            selectionCount += 1
            Task { await restitchFrames() }
        }
        .onChange(of: spacing) { _, _ in
            selectionCount += 1
            Task { await restitchFrames() }
        }
        .onChange(of: selectedSeamIndex) { _, _ in
            selectionCount += 1
            refreshSeamLoupe()
        }
        .onChange(of: activeTool) { _, tool in
            selectionCount += 1
            if tool == .seam {
                refreshSeamLoupe()
            }
        }
        .task(id: session.id) {
            await bootstrapSession()
        }
        .sensoryFeedback(.success, trigger: successCount)
        .sensoryFeedback(.selection, trigger: selectionCount)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: impactCount)
    }

    // MARK: - Native Adaptive iOS 26 Toolbar

    @ToolbarContentBuilder
    private var studioToolbarContent: some ToolbarContent {
        if let activeTool {
            ToolbarItem(placement: .topBarLeading) {
                if canResetActiveTool {
                    Button("longshot.studio.resetTool") {
                        resetActiveTool(activeTool)
                    }
                    .foregroundStyle(.orange)
                }
            }

            ToolbarItem(placement: .principal) {
                Text(LocalizedStringKey(activeTool.titleKey))
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("longshot.studio.done") {
                    withAnimation(.snappy(duration: 0.24)) {
                        self.activeTool = nil
                    }
                    selectionCount += 1
                }
                .fontWeight(.semibold)
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .tint(Theme.accentButton)
            }
        } else {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    rerenderTask?.cancel()
                    selectionCount += 1
                    onBack()
                } label: {
                    Label("longshot.studio.back", systemImage: "chevron.left")
                }
                .tint(.white)
            }

            ToolbarItem(placement: .principal) {
                if let stitchedResult, !isStitching {
                    VStack(spacing: 1) {
                        Text(verbatim: "\(stitchedResult.image.width) × \(stitchedResult.image.height)")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())

                        if stitchedResult.stitchedOverlapCount > 0 {
                            Text(verbatim: L10n.longshotOverlapCount(stitchedResult.stitchedOverlapCount))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(Theme.accentOnBlack)
                        } else if canAdjustSeams {
                            Text("longshot.studio.tapSeamHint")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                if stitchedResult != nil && !isStitching {
                    if direction == .vertical {
                        Button {
                            withAnimation(.snappy(duration: 0.26)) {
                                isOverviewZoom.toggle()
                            }
                            selectionCount += 1
                        } label: {
                            Label(
                                isOverviewZoom ? "longshot.studio.readable" : "longshot.studio.overview",
                                systemImage: isOverviewZoom ? "arrow.up.left.and.arrow.down.right" : "rectangle.arrowtriangle.2.outward"
                            )
                        }
                        .tint(isOverviewZoom ? Theme.accentOnBlack : .white)
                    }

                    if session.initialMode == .multiImage || hasAnyEdits {
                        Menu {
                            if session.initialMode == .multiImage {
                                Button {
                                    showsPhotosPicker = true
                                } label: {
                                    Label("longshot.addScreenshots", systemImage: "plus")
                                }
                            }

                            if hasAnyEdits {
                                Button(role: .destructive) {
                                    resetAllEdits()
                                } label: {
                                    Label("longshot.resetEdits", systemImage: "arrow.counterclockwise")
                                }
                            }
                        } label: {
                            Label("longshot.addScreenshots", systemImage: "ellipsis")
                        }
                        .tint(.white)
                    }
                }
            }
        }
    }

    // MARK: - Full-Screen Direct-Manipulation Canvas

    private var studioCanvasArea: some View {
        GeometryReader { geo in
            if isStitching {
                AppleIntelligenceLoadingView(
                    title: "longshot.processing",
                    progress: progress > 0 ? progress : nil,
                    showsEdgeGlow: true
                )
            } else if let errorMessage {
                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(verbatim: errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.88))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button("longshot.studio.back") { onBack() }
                        .buttonStyle(.glassProminent)
                        .buttonBorderShape(.capsule)
                        .tint(Theme.accentButton)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let stitchedResult {
                let uncropped = uncroppedResult?.image ?? videoBaseResult?.image ?? stitchedResult.image

                if activeTool == .crop {
                    let aspect = CGFloat(max(uncropped.width, 1)) / CGFloat(max(uncropped.height, 1))
                    Image(decorative: uncropped, scale: 1)
                        .resizable()
                        .scaledToFit()
                        .overlay {
                            GeometryReader { imgGeo in
                                StudioCropOverlay(
                                    size: imgGeo.size,
                                    imageWidth: uncropped.width,
                                    imageHeight: uncropped.height,
                                    crop: $cropInsets,
                                    onEdgeSnap: { impactCount += 1 },
                                    onCommit: {
                                        selectionCount += 1
                                        scheduleLiveRerender()
                                    }
                                )
                            }
                        }
                        .aspectRatio(aspect, contentMode: .fit)
                        .frame(maxWidth: max(120, geo.size.width - 28), maxHeight: max(120, geo.size.height - 16))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: .black.opacity(0.55), radius: 20, y: 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if direction == .horizontal {
                    let img = stitchedResult.image
                    let aspect = CGFloat(max(img.width, 1)) / CGFloat(max(img.height, 1))
                    let targetH = max(140, min(geo.size.height - 24, 520))
                    ScrollView(.horizontal, showsIndicators: true) {
                        Image(decorative: img, scale: 1)
                            .resizable()
                            .frame(width: targetH * aspect, height: targetH)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: .black.opacity(0.5), radius: 18, y: 6)
                            .padding(.horizontal, 18)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    let canvasImage = (activeTool == .seam) ? uncropped : stitchedResult.image
                    let aspect = CGFloat(max(canvasImage.width, 1)) / CGFloat(max(canvasImage.height, 1))

                    if isOverviewZoom && activeTool != .seam {
                        Image(decorative: canvasImage, scale: 1)
                            .resizable()
                            .scaledToFit()
                            .aspectRatio(aspect, contentMode: .fit)
                            .frame(maxWidth: max(120, geo.size.width - 28), maxHeight: max(120, geo.size.height - 16))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: .black.opacity(0.55), radius: 18, y: 6)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        let readableW = min(max(240, geo.size.width - 32), 480)
                        let readableH = max(120, readableW / max(aspect, 0.008))
                        let seamFractions = (activeTool == .seam && verticalLayout != nil)
                            ? computeSeamFractions(layout: verticalLayout!, seams: seams, totalHeight: canvasImage.height)
                            : []

                        ScrollViewReader { proxy in
                            ScrollView(.vertical, showsIndicators: true) {
                                ZStack(alignment: .top) {
                                    TiledLongImageView(
                                        image: canvasImage,
                                        displayWidth: readableW,
                                        displayHeight: readableH
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.white.opacity(0.14), lineWidth: 0.75)
                                    )
                                    .shadow(color: .black.opacity(0.55), radius: 20, y: 8)

                                    if activeTool == .seam, let layout = verticalLayout {
                                        StudioSeamOverlay(
                                            canvasSize: CGSize(width: readableW, height: readableH),
                                            seamFractions: seamFractions,
                                            seams: seams,
                                            selectedIndex: selectedSeamIndex,
                                            draggingIndex: draggingSeamIndex,
                                            dragDeltaPx: dragDeltaPx,
                                            onTapSeam: { idx in
                                                selectedSeamIndex = idx
                                            },
                                            onDragChanged: { idx, translationY in
                                                handleDirectSeamDrag(
                                                    at: idx,
                                                    translationY: translationY,
                                                    viewHeight: readableH,
                                                    uncroppedHeight: canvasImage.height,
                                                    layout: layout
                                                )
                                            },
                                            onDragEnded: {
                                                draggingSeamIndex = nil
                                                dragStartSeam = nil
                                                dragDeltaPx = 0
                                                selectionCount += 1
                                                scheduleLiveRerender()
                                            }
                                        )
                                    }
                                }
                                .frame(width: readableW, height: readableH)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                            }
                            .onChange(of: selectedSeamIndex) { _, newIdx in
                                if activeTool == .seam {
                                    withAnimation(.snappy(duration: 0.32)) {
                                        proxy.scrollTo("seam-anchor-\(newIdx)", anchor: .center)
                                    }
                                }
                            }
                            .onChange(of: activeTool) { _, newTool in
                                if newTool == .seam {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                        withAnimation(.snappy(duration: 0.3)) {
                                            proxy.scrollTo("seam-anchor-\(selectedSeamIndex)", anchor: .center)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Unified Apple Photos-Style Bottom Studio Dock

    @ViewBuilder
    private var bottomStudioDock: some View {
        if !isStitching, let stitchedResult {
            VStack(spacing: 10) {
                if let activeTool {
                    activeToolDrawer(for: activeTool)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    // Clean two-row studio footer: icon-over-label tools + balanced export/redact CTAs
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            ForEach(availableTools) { tool in
                                Button {
                                    withAnimation(.snappy(duration: 0.24)) {
                                        activeTool = tool
                                    }
                                    selectionCount += 1
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: tool.systemImage)
                                            .font(.body.weight(.medium))
                                            .frame(height: 20)
                                        Text(LocalizedStringKey(tool.titleKey))
                                            .font(.caption2.weight(.medium))
                                    }
                                    .foregroundStyle(.white.opacity(0.92))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .contentShape(.rect)
                                }
                                .buttonStyle(PressStyle(scale: 0.95))
                            }
                        }

                        GlassEffectContainer(spacing: 10) {
                            HStack(spacing: 10) {
                                if let onCompleteForExport {
                                    SecondaryButton(
                                        title: "longshot.studio.frameShort",
                                        systemImage: "iphone.and.arrow.forward.inward"
                                    ) {
                                        openOutput(stitchedResult, handler: onCompleteForExport)
                                    }
                                }
                                PrimaryButton(
                                    title: "longshot.enterEditor",
                                    systemImage: "wand.and.stars"
                                ) {
                                    openOutput(stitchedResult, handler: onComplete)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy(duration: 0.24), value: activeTool)
        }
    }

    @ViewBuilder
    private func activeToolDrawer(for tool: StudioTool) -> some View {
        switch tool {
        case .seam:
            seamDrawer
        case .crop:
            cropDrawer
        case .frames:
            framesDrawer
        }
    }

    @ViewBuilder
    private var seamDrawer: some View {
        if let layout = verticalLayout,
           seams.indices.contains(selectedSeamIndex),
           layout.orderedImages.indices.contains(selectedSeamIndex),
           layout.orderedImages.indices.contains(selectedSeamIndex + 1) {
            let prevImg = layout.orderedImages[selectedSeamIndex]
            let currImg = layout.orderedImages[selectedSeamIndex + 1]
            let seam = seams[selectedSeamIndex]

            let minPrevCutY = (selectedSeamIndex == 0)
                ? 16
                : min(prevImg.height, seams[selectedSeamIndex - 1].currStartY + 16)
            let maxPrevTrim = max(0, prevImg.height - minPrevCutY)
            let prevTrim = max(0, min(maxPrevTrim, prevImg.height - seam.prevCutY))

            let maxCurrStart = (selectedSeamIndex == seams.count - 1)
                ? max(0, currImg.height - 16)
                : max(0, min(currImg.height - 16, seams[selectedSeamIndex + 1].prevCutY - 16))
            let currTrim = max(0, min(maxCurrStart, seam.currStartY))

            VStack(spacing: 10) {
                if draggingSeamIndex != nil, let loupe = seamLoupeImage {
                    ZStack {
                        Image(decorative: loupe, scale: 1)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 112)
                        Rectangle()
                            .fill(Theme.accentOnBlack)
                            .frame(height: 1.5)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Theme.accentOnBlack, lineWidth: 1.5)
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }

                HStack(spacing: 8) {
                    if seams.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(seams.indices, id: \.self) { idx in
                                    let isSel = idx == selectedSeamIndex
                                    let matched = seams[idx].isAutoMatched
                                    Button {
                                        selectedSeamIndex = idx
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: matched ? "checkmark.circle.fill" : "scissors")
                                                .font(.system(size: 10, weight: .bold))
                                            Text(L10n.longshotSeamTitle(idx + 1))
                                                .font(.caption.weight(.semibold))
                                        }
                                        .foregroundStyle(isSel ? .white : (matched ? Theme.accentOnBlack : .orange))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(
                                            Capsule().fill(
                                                isSel
                                                    ? Theme.accentButton
                                                    : Color.white.opacity(0.12)
                                            )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    } else {
                        Text(L10n.longshotSeamTitle(1))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.accentOnBlack)
                        Spacer()
                    }

                    Picker("", selection: $seamDragMode) {
                        ForEach(SeamDragMode.allCases) { m in
                            Text(LocalizedStringKey(m.titleKey)).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 142)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        Button("longshot.seamTrimChrome") {
                            applySuggestedChromeTrim(at: selectedSeamIndex)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Theme.accentButton))

                        Button("longshot.seamReset") {
                            resetSeamToAuto(at: selectedSeamIndex)
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(0.14)))

                        if seams.count > 1 {
                            Button("longshot.seamApplyGapAll") {
                                applyCurrentGapToAll()
                            }
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.white.opacity(0.14)))
                        }

                        if seam.gap > 0 {
                            ForEach(DividerColorOption.presets) { preset in
                                let active = dividerColor == preset.rgb
                                Button {
                                    dividerColor = preset.rgb
                                    selectionCount += 1
                                    refreshSeamLoupe()
                                    scheduleLiveRerender()
                                } label: {
                                    Circle()
                                        .fill(Color(red: preset.rgb.red, green: preset.rgb.green, blue: preset.rgb.blue))
                                        .frame(width: 22, height: 22)
                                        .overlay(
                                            Circle().stroke(
                                                active ? Theme.accentOnBlack : Color.white.opacity(0.35),
                                                lineWidth: active ? 2.5 : 1
                                            )
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(LocalizedStringKey(preset.labelKey))
                            }
                        }
                    }
                }

                HStack(spacing: 8) {
                    StudioMicroStepper(titleKey: "longshot.seamPrevShort", value: prevTrim, step: 12) { delta in
                        let next = max(0, min(maxPrevTrim, prevTrim + delta))
                        updateSeam(at: selectedSeamIndex) { $0.prevCutY = prevImg.height - next }
                    }
                    StudioMicroStepper(titleKey: "longshot.seamCurrShort", value: currTrim, step: 12) { delta in
                        let next = max(0, min(maxCurrStart, currTrim + delta))
                        updateSeam(at: selectedSeamIndex) { $0.currStartY = next }
                    }
                    StudioMicroStepper(titleKey: "longshot.seamGapShort", value: seam.gap, step: 8) { delta in
                        let next = max(0, min(120, seam.gap + delta))
                        updateSeam(at: selectedSeamIndex) { $0.gap = next }
                    }
                }
            }
            .padding(14)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private var cropDrawer: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.snappy(duration: 0.22)) {
                            cropInsets.left = cropInsets.left > 0.03 ? 0 : 0.04
                            cropInsets.right = cropInsets.right > 0.03 ? 0 : 0.04
                        }
                        selectionCount += 1
                        scheduleLiveRerender()
                    } label: {
                        let active = cropInsets.left > 0.01 && cropInsets.right > 0.01
                        Text("longshot.studio.cropSymLR")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(active ? Theme.accentButton : Color.white.opacity(0.14)))
                    }
                    .buttonStyle(PressStyle(scale: 0.95))

                    Button {
                        withAnimation(.snappy(duration: 0.22)) {
                            cropInsets.top = cropInsets.top > 0.04 ? 0 : 0.055
                        }
                        selectionCount += 1
                        scheduleLiveRerender()
                    } label: {
                        let active = cropInsets.top > 0.01
                        Text("longshot.studio.cropTopBar")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(active ? Theme.accentButton : Color.white.opacity(0.14)))
                    }
                    .buttonStyle(PressStyle(scale: 0.95))

                    Button {
                        withAnimation(.snappy(duration: 0.22)) {
                            cropInsets.bottom = cropInsets.bottom > 0.03 ? 0 : 0.045
                        }
                        selectionCount += 1
                        scheduleLiveRerender()
                    } label: {
                        let active = cropInsets.bottom > 0.01
                        Text("longshot.studio.cropBottomBar")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(active ? Theme.accentButton : Color.white.opacity(0.14)))
                    }
                    .buttonStyle(PressStyle(scale: 0.95))
                }
            }

            HStack {
                Label("longshot.cropHintOnImage", systemImage: "hand.draw")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
                Text(
                    verbatim: "L \(Int((cropInsets.left * 100).rounded()))% · R \(Int((cropInsets.right * 100).rounded()))% · T \(Int((cropInsets.top * 100).rounded()))% · B \(Int((cropInsets.bottom * 100).rounded()))%"
                )
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.9))
                .contentTransition(.numericText())
            }
        }
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var framesDrawer: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(frames.enumerated()), id: \.element.id) { index, frame in
                        VStack(spacing: 4) {
                            ZStack(alignment: .topLeading) {
                                Image(uiImage: frame.thumb)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 52, height: 74)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                                    )

                                Text(verbatim: "\(index + 1)")
                                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                                    .foregroundStyle(.white)
                                    .frame(width: 17, height: 17)
                                    .background(Theme.accentButton, in: Circle())
                                    .padding(3)
                            }
                            .overlay(alignment: .topTrailing) {
                                if frames.count > 2 {
                                    Button {
                                        removeFrame(at: index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(.white, Color.black.opacity(0.72))
                                            .padding(2)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            HStack(spacing: 4) {
                                Button {
                                    moveFrame(from: index, by: -1)
                                } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(index > 0 ? .white : .white.opacity(0.25))
                                        .frame(width: 22, height: 16)
                                        .background(Color.white.opacity(0.12), in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .disabled(index == 0)

                                Button {
                                    moveFrame(from: index, by: 1)
                                } label: {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(index < frames.count - 1 ? .white : .white.opacity(0.25))
                                        .frame(width: 22, height: 16)
                                        .background(Color.white.opacity(0.12), in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .disabled(index == frames.count - 1)
                            }
                        }
                    }

                    VStack(spacing: 4) {
                        Button {
                            showsPhotosPicker = true
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: "plus")
                                    .font(.subheadline.weight(.semibold))
                                Text("longshot.addShort")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(Theme.accentOnBlack)
                            .frame(width: 48, height: 74)
                            .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(PressStyle(scale: 0.95))

                        Color.clear.frame(height: 16)
                    }
                }
            }

            HStack(spacing: 8) {
                Picker("", selection: $direction) {
                    ForEach(LongScreenshotStitcher.Direction.allCases) { dir in
                        Text(LocalizedStringKey(dir.titleKey)).tag(dir)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 132)

                if direction == .vertical {
                    Button {
                        withAnimation(.snappy(duration: 0.22)) {
                            smartOverlap.toggle()
                        }
                    } label: {
                        Label("longshot.smartOverlap", systemImage: "sparkles")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(smartOverlap ? Theme.accentButton : Color.white.opacity(0.14)))
                    }
                    .buttonStyle(PressStyle(scale: 0.95))
                }

                Spacer(minLength: 4)

                if direction == .horizontal || !smartOverlap {
                    Picker("", selection: $spacing) {
                        ForEach(LongScreenshotStitcher.Spacing.allCases) { sp in
                            Text(LocalizedStringKey(sp.titleKey)).tag(sp)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 132)
                }
            }
        }
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - Actions & Stitch Execution

    private func resetActiveTool(_ tool: StudioTool) {
        withAnimation(.snappy(duration: 0.22)) {
            switch tool {
            case .seam:
                if let layout = verticalLayout {
                    seams = layout.seams
                }
                dividerColor = LongScreenshotStitcher.defaultDividerColor
                refreshSeamLoupe()
            case .crop:
                cropInsets = .zero
            case .frames:
                break
            }
        }
        impactCount += 1
        scheduleLiveRerender()
    }

    private func resetAllEdits() {
        cropInsets = .zero
        dividerColor = LongScreenshotStitcher.defaultDividerColor
        if let layout = verticalLayout {
            seams = layout.seams
        }
        impactCount += 1
        refreshSeamLoupe()
        scheduleLiveRerender()
    }

    private func bootstrapSession() async {
        direction = session.initialDirection
        videoPrecision = session.initialVideoPrecision
        errorMessage = nil

        if session.initialMode == .screenRecording {
            let resolvedAsset = session.initialVideoAsset ?? session.initialVideoURL.map { SendableAVAsset(asset: AVURLAsset(url: $0)) }
            guard let videoAsset = resolvedAsset else {
                isStitching = false
                errorMessage = LongScreenshotStitcher.Failure.videoHasNoFrames.localizedDescription
                return
            }
            isStitching = true
            defer {
                if session.deleteVideoAfter, let videoURL = session.initialVideoURL {
                    try? FileManager.default.removeItem(at: videoURL)
                }
                isStitching = false
            }
            let prec = videoPrecision
            let div = dividerColor
            do {
                let (layout, rendered) = try await Task.detached(priority: .userInitiated) {
                    let computed = try await LongScreenshotStitcher.stitchVideoLayout(
                        asset: videoAsset.asset,
                        options: .init(videoPrecision: prec)
                    ) { p in
                        Task { @MainActor in
                            progress = p
                        }
                    }
                    let base = try LongScreenshotStitcher.renderVertical(
                        layout: computed,
                        seams: computed.seams,
                        crop: .zero,
                        dividerColor: div
                    )
                    return (computed, base)
                }.value

                frames = layout.orderedImages.map { StudioFrame(image: $0, thumb: UIImage(cgImage: $0)) }
                verticalLayout = layout
                seams = layout.seams
                selectedSeamIndex = max(0, min(layout.seams.count - 1, 0))
                videoBaseResult = rendered
                uncroppedResult = rendered
                stitchedResult = rendered
                refreshSeamLoupe()
                successCount += 1
            } catch {
                errorMessage = error.localizedDescription
            }
            return
        }

        frames = session.initialImages.map { StudioFrame(image: $0, thumb: UIImage(cgImage: $0)) }
        if frames.count >= 2 {
            await restitchFrames()
        } else {
            isStitching = false
            errorMessage = LongScreenshotStitcher.Failure.needTwoImagesDescription
        }
    }

    private func appendPickedItems(_ items: [PhotosPickerItem]) async {
        isStitching = true
        errorMessage = nil
        var next = frames
        for item in items {
            if let source = await Intake.picture(from: item), let cg = try? source.uprightImage() {
                next.append(StudioFrame(image: cg, thumb: UIImage(cgImage: cg)))
            }
        }
        frames = next
        await restitchFrames()
    }

    private func moveFrame(from index: Int, by delta: Int) {
        let dest = index + delta
        guard frames.indices.contains(index), frames.indices.contains(dest) else { return }
        withAnimation(.snappy(duration: 0.2)) {
            frames.swapAt(index, dest)
        }
        selectionCount += 1
        Task { await restitchFrames() }
    }

    private func removeFrame(at index: Int) {
        guard frames.count > 2, frames.indices.contains(index) else { return }
        frames.remove(at: index)
        selectionCount += 1
        Task { await restitchFrames() }
    }

    private func restitchFrames() async {
        rerenderTask?.cancel()
        guard frames.count >= 2 else {
            isStitching = false
            return
        }
        isStitching = true
        errorMessage = nil
        let rawImages = frames.map(\.image)
        let opts = LongScreenshotStitcher.Options(
            direction: direction,
            smartOverlap: smartOverlap,
            allowReverseOrder: session.initialMode != .screenRecording,
            spacing: spacing,
            preferVideoTolerances: session.initialMode == .screenRecording
        )
        let crop = cropInsets
        let div = dividerColor
        do {
            if direction == .vertical {
                let (layout, uncropped, rendered) = try await Task.detached(priority: .userInitiated) {
                    let computed = try LongScreenshotStitcher.computeVerticalLayout(images: rawImages, options: opts)
                    let base = try LongScreenshotStitcher.renderVertical(
                        layout: computed,
                        seams: computed.seams,
                        crop: .zero,
                        dividerColor: div,
                        maxHeight: opts.maxHeight
                    )
                    let final = crop.isZero
                        ? base
                        : LongScreenshotStitcher.Result(
                            image: LongScreenshotStitcher.applyCrop(base.image, crop: crop),
                            frameCount: base.frameCount,
                            stitchedOverlapCount: base.stitchedOverlapCount
                        )
                    return (computed, base, final)
                }.value
                verticalLayout = layout
                if opts.smartOverlap && opts.allowReverseOrder {
                    frames = layout.orderedImages.map { StudioFrame(image: $0, thumb: UIImage(cgImage: $0)) }
                }
                seams = layout.seams
                selectedSeamIndex = max(0, min(layout.seams.count - 1, selectedSeamIndex))
                uncroppedResult = uncropped
                stitchedResult = rendered
                refreshSeamLoupe()
            } else {
                let (uncropped, rendered) = try await Task.detached(priority: .userInitiated) {
                    let base = try LongScreenshotStitcher.stitch(
                        images: rawImages,
                        options: opts,
                        crop: .zero,
                        dividerColor: div
                    )
                    let final = crop.isZero
                        ? base
                        : LongScreenshotStitcher.Result(
                            image: LongScreenshotStitcher.applyCrop(base.image, crop: crop),
                            frameCount: base.frameCount,
                            stitchedOverlapCount: base.stitchedOverlapCount
                        )
                    return (base, final)
                }.value
                verticalLayout = nil
                seams = []
                seamLoupeImage = nil
                uncroppedResult = uncropped
                stitchedResult = rendered
            }
            successCount += 1
        } catch {
            errorMessage = error.localizedDescription
        }
        isStitching = false
    }

    private func computeSeamFractions(
        layout: LongScreenshotStitcher.VerticalLayout,
        seams: [LongScreenshotStitcher.SeamAdjustment],
        totalHeight: Int
    ) -> [CGFloat] {
        guard totalHeight > 0, seams.count == max(0, layout.orderedImages.count - 1) else {
            return []
        }
        var out: [CGFloat] = []
        out.reserveCapacity(seams.count)
        var cursor = 0
        for i in 0..<seams.count {
            let img = layout.orderedImages[i]
            let rawTop = (i == 0) ? 0 : max(0, min(img.height - 1, seams[i - 1].currStartY))
            let rawBottom = max(1, min(img.height, seams[i].prevCutY))
            let safeTop = min(rawTop, max(0, rawBottom - 1))
            let sliceH = max(1, rawBottom - safeTop)
            let gap = max(0, min(160, seams[i].gap))
            let seamCenter = CGFloat(cursor + sliceH) + CGFloat(gap) * 0.5
            out.append(min(0.98, max(0.02, seamCenter / CGFloat(totalHeight))))
            cursor += sliceH + gap
        }
        return out
    }

    private func handleDirectSeamDrag(
        at index: Int,
        translationY: CGFloat,
        viewHeight: CGFloat,
        uncroppedHeight: Int,
        layout: LongScreenshotStitcher.VerticalLayout
    ) {
        guard seams.indices.contains(index),
              layout.orderedImages.indices.contains(index),
              layout.orderedImages.indices.contains(index + 1) else {
            return
        }
        if draggingSeamIndex != index {
            selectedSeamIndex = index
            draggingSeamIndex = index
            dragStartSeam = seams[index]
        }
        guard let baseSeam = dragStartSeam else { return }
        let pxPerPt = max(1.0, CGFloat(uncroppedHeight) / max(viewHeight, 120))
        let deltaPx = Int((translationY * pxPerPt).rounded())
        dragDeltaPx = deltaPx

        switch seamDragMode {
        case .cut:
            let prevImg = layout.orderedImages[index]
            let minPrevCutY = (index == 0)
                ? 16
                : min(prevImg.height, seams[index - 1].currStartY + 16)
            seams[index].prevCutY = max(minPrevCutY, min(prevImg.height, baseSeam.prevCutY + deltaPx))
        case .gap:
            seams[index].gap = max(0, min(120, baseSeam.gap + deltaPx))
        }
        refreshSeamLoupe()
    }

    private func updateSeam(at index: Int, mutate: (inout LongScreenshotStitcher.SeamAdjustment) -> Void) {
        guard seams.indices.contains(index) else { return }
        mutate(&seams[index])
        selectionCount += 1
        refreshSeamLoupe()
        scheduleLiveRerender()
    }

    private func applySuggestedChromeTrim(at index: Int) {
        guard let layout = verticalLayout,
              seams.indices.contains(index),
              layout.orderedImages.indices.contains(index),
              layout.orderedImages.indices.contains(index + 1) else {
            return
        }
        let suggested = LongScreenshotStitcher.suggestedChromeTrim(
            previous: layout.orderedImages[index],
            current: layout.orderedImages[index + 1]
        )
        updateSeam(at: index) { seam in
            let minCut = (index == 0) ? 16 : min(layout.orderedImages[index].height, seams[index - 1].currStartY + 16)
            seam.prevCutY = max(minCut, suggested.prevCutY)
            let maxStart = (index == seams.count - 1)
                ? max(0, layout.orderedImages[index + 1].height - 16)
                : max(0, min(layout.orderedImages[index + 1].height - 16, seams[index + 1].prevCutY - 16))
            seam.currStartY = min(maxStart, suggested.currStartY)
        }
        impactCount += 1
    }

    private func applyCurrentGapToAll() {
        guard seams.indices.contains(selectedSeamIndex) else { return }
        let targetGap = seams[selectedSeamIndex].gap
        for idx in seams.indices {
            seams[idx].gap = targetGap
        }
        selectionCount += 1
        refreshSeamLoupe()
        scheduleLiveRerender()
    }

    private func resetSeamToAuto(at index: Int) {
        guard let layout = verticalLayout,
              layout.seams.indices.contains(index),
              seams.indices.contains(index) else {
            return
        }
        seams[index] = layout.seams[index]
        selectionCount += 1
        refreshSeamLoupe()
        scheduleLiveRerender()
    }

    private func refreshSeamLoupe() {
        guard let layout = verticalLayout,
              seams.indices.contains(selectedSeamIndex),
              layout.orderedImages.indices.contains(selectedSeamIndex),
              layout.orderedImages.indices.contains(selectedSeamIndex + 1) else {
            seamLoupeImage = nil
            return
        }
        seamLoupeImage = LongScreenshotStitcher.renderSeamPreview(
            previous: layout.orderedImages[selectedSeamIndex],
            current: layout.orderedImages[selectedSeamIndex + 1],
            seam: seams[selectedSeamIndex],
            bandPixels: 160,
            dividerColor: dividerColor
        )
    }

    private func scheduleLiveRerender() {
        rerenderTask?.cancel()
        if direction == .vertical, let layout = verticalLayout {
            let activeSeams = seams
            let crop = cropInsets
            let div = dividerColor
            rerenderTask = Task {
                try? await Task.sleep(for: .milliseconds(25))
                guard !Task.isCancelled else { return }
                if let pair = try? await Task.detached(priority: .userInitiated, operation: {
                    let base = try LongScreenshotStitcher.renderVertical(
                        layout: layout,
                        seams: activeSeams,
                        crop: .zero,
                        dividerColor: div
                    )
                    let final = crop.isZero
                        ? base
                        : LongScreenshotStitcher.Result(
                            image: LongScreenshotStitcher.applyCrop(base.image, crop: crop),
                            frameCount: base.frameCount,
                            stitchedOverlapCount: base.stitchedOverlapCount
                        )
                    return (base, final)
                }).value, !Task.isCancelled {
                    uncroppedResult = pair.0
                    stitchedResult = pair.1
                }
            }
            return
        }

        if let base = videoBaseResult {
            let crop = cropInsets
            rerenderTask = Task {
                try? await Task.sleep(for: .milliseconds(25))
                guard !Task.isCancelled else { return }
                let cropped = await Task.detached(priority: .userInitiated) {
                    LongScreenshotStitcher.applyCrop(base.image, crop: crop)
                }.value
                guard !Task.isCancelled else { return }
                stitchedResult = LongScreenshotStitcher.Result(
                    image: cropped,
                    frameCount: base.frameCount,
                    stitchedOverlapCount: base.stitchedOverlapCount
                )
            }
        }
    }

    private func openOutput(_ result: LongScreenshotStitcher.Result, handler: (PictureSource) -> Void) {
        rerenderTask?.cancel()
        do {
            let finalImage: CGImage
            if direction == .vertical, let layout = verticalLayout {
                finalImage = try LongScreenshotStitcher.renderVertical(
                    layout: layout,
                    seams: seams,
                    crop: cropInsets,
                    dividerColor: dividerColor
                ).image
            } else if session.initialMode == .screenRecording, let base = videoBaseResult {
                finalImage = LongScreenshotStitcher.applyCrop(base.image, crop: cropInsets)
            } else {
                finalImage = result.image
            }
            let picture = try LongScreenshotStitcher.makePictureSource(from: finalImage)
            handler(picture)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension LongScreenshotStitcher.Failure {
    static var needTwoImagesDescription: String {
        LongScreenshotStitcher.Failure.notEnoughImages.localizedDescription
    }
}

// MARK: - Native Dark Studio 4-Edge Crop Overlay

private struct StudioCropOverlay: View {
    enum EdgeKind { case left, right, top, bottom }

    let size: CGSize
    let imageWidth: Int
    let imageHeight: Int
    @Binding var crop: LongScreenshotStitcher.CropInsets
    let onEdgeSnap: () -> Void
    let onCommit: () -> Void

    @State private var activeEdge: EdgeKind?
    @State private var dragStart: LongScreenshotStitcher.CropInsets?

    var body: some View {
        let w = max(size.width, 1)
        let h = max(size.height, 1)
        let lX = CGFloat(crop.left) * w
        let rX = CGFloat(1.0 - crop.right) * w
        let tY = CGFloat(crop.top) * h
        let bY = CGFloat(1.0 - crop.bottom) * h
        let cropW = max(24, rX - lX)
        let cropH = max(24, bY - tY)

        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.60)
                .frame(width: w, height: tY)
            Color.black.opacity(0.60)
                .frame(width: w, height: max(0, h - bY))
                .offset(y: bY)
            Color.black.opacity(0.60)
                .frame(width: lX, height: cropH)
                .offset(y: tY)
            Color.black.opacity(0.60)
                .frame(width: max(0, w - rX), height: cropH)
                .offset(x: rX, y: tY)

            ZStack {
                Rectangle()
                    .stroke(.white, lineWidth: 1.5)

                if activeEdge != nil {
                    Path { p in
                        p.move(to: CGPoint(x: cropW / 3, y: 0))
                        p.addLine(to: CGPoint(x: cropW / 3, y: cropH))
                        p.move(to: CGPoint(x: cropW * 2 / 3, y: 0))
                        p.addLine(to: CGPoint(x: cropW * 2 / 3, y: cropH))
                        p.move(to: CGPoint(x: 0, y: cropH / 3))
                        p.addLine(to: CGPoint(x: cropW, y: cropH / 3))
                        p.move(to: CGPoint(x: 0, y: cropH * 2 / 3))
                        p.addLine(to: CGPoint(x: cropW, y: cropH * 2 / 3))
                    }
                    .stroke(Color.white.opacity(0.45), lineWidth: 0.75)
                }
            }
            .frame(width: cropW, height: cropH)
            .offset(x: lX, y: tY)

            if activeEdge != nil {
                let outW = Int((Double(imageWidth) * (1.0 - crop.left - crop.right)).rounded())
                let outH = Int((Double(imageHeight) * (1.0 - crop.top - crop.bottom)).rounded())
                Text(verbatim: "\(outW) × \(outH)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.accentButton, in: Capsule())
                    .position(x: lX + cropW / 2, y: max(20, tY + 22))
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }

            edgeHandle(horizontal: false, active: activeEdge == .left)
                .position(x: lX, y: tY + cropH / 2)
                .highPriorityGesture(edgeDrag(.left, w: w, h: h))

            edgeHandle(horizontal: false, active: activeEdge == .right)
                .position(x: rX, y: tY + cropH / 2)
                .highPriorityGesture(edgeDrag(.right, w: w, h: h))

            edgeHandle(horizontal: true, active: activeEdge == .top)
                .position(x: lX + cropW / 2, y: tY)
                .highPriorityGesture(edgeDrag(.top, w: w, h: h))

            edgeHandle(horizontal: true, active: activeEdge == .bottom)
                .position(x: lX + cropW / 2, y: bY)
                .highPriorityGesture(edgeDrag(.bottom, w: w, h: h))
        }
        .animation(.easeOut(duration: 0.14), value: activeEdge != nil)
    }

    private func edgeHandle(horizontal: Bool, active: Bool) -> some View {
        Capsule()
            .fill(active ? Theme.accentOnBlack : .white)
            .frame(width: horizontal ? 42 : 6, height: horizontal ? 6 : 42)
            .shadow(color: .black.opacity(0.55), radius: 4, y: 1)
            .frame(width: 46, height: 46)
            .contentShape(.rect)
    }

    private func edgeDrag(_ edge: EdgeKind, w: CGFloat, h: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if activeEdge != edge {
                    activeEdge = edge
                    dragStart = crop
                }
                guard let base = dragStart else { return }
                let wasNonZero = edgeValue(edge, in: crop) > 0.005
                switch edge {
                case .left:
                    crop.left = max(0, min(min(0.35, 0.85 - base.right), base.left + Double(value.translation.width / w)))
                case .right:
                    crop.right = max(0, min(min(0.35, 0.85 - base.left), base.right - Double(value.translation.width / w)))
                case .top:
                    crop.top = max(0, min(min(0.25, 0.85 - base.bottom), base.top + Double(value.translation.height / h)))
                case .bottom:
                    crop.bottom = max(0, min(min(0.25, 0.85 - base.top), base.bottom - Double(value.translation.height / h)))
                }
                if wasNonZero && edgeValue(edge, in: crop) <= 0.004 {
                    onEdgeSnap()
                }
            }
            .onEnded { _ in
                activeEdge = nil
                dragStart = nil
                onCommit()
            }
    }

    private func edgeValue(_ edge: EdgeKind, in insets: LongScreenshotStitcher.CropInsets) -> Double {
        switch edge {
        case .left: insets.left
        case .right: insets.right
        case .top: insets.top
        case .bottom: insets.bottom
        }
    }
}

// MARK: - Readable-Width Scrollable Seam Drag Overlay

private struct StudioSeamOverlay: View {
    let canvasSize: CGSize
    let seamFractions: [CGFloat]
    let seams: [LongScreenshotStitcher.SeamAdjustment]
    let selectedIndex: Int
    let draggingIndex: Int?
    let dragDeltaPx: Int
    let onTapSeam: (Int) -> Void
    let onDragChanged: (Int, CGFloat) -> Void
    let onDragEnded: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(seamFractions.enumerated()), id: \.offset) { index, frac in
                if seams.indices.contains(index) {
                    let y = max(24, min(canvasSize.height - 24, frac * canvasSize.height))
                    let isSelected = index == selectedIndex
                    let isDragging = index == draggingIndex
                    let seam = seams[index]

                    ZStack {
                        Rectangle()
                            .fill(isSelected || isDragging ? Theme.accentOnBlack : (seam.isAutoMatched ? Theme.accentOnBlack.opacity(0.6) : Color.orange))
                            .frame(height: isDragging ? 3 : 1.75)

                        HStack(spacing: 5) {
                            Image(systemName: seam.isAutoMatched ? "checkmark.circle.fill" : "scissors")
                                .font(.caption2.weight(.bold))
                            Text(L10n.longshotSeamTitle(index + 1))
                                .font(.caption.weight(.bold))
                            if isDragging && dragDeltaPx != 0 {
                                Text(verbatim: dragDeltaPx > 0 ? "+\(dragDeltaPx)px" : "\(dragDeltaPx)px")
                                    .font(.caption2.weight(.bold).monospacedDigit())
                            } else if seam.gap > 0 {
                                Text(verbatim: "+\(seam.gap)px")
                                    .font(.caption2.weight(.semibold).monospacedDigit())
                            }
                            Image(systemName: "arrow.up.and.down")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(
                                (isSelected || isDragging || seam.isAutoMatched)
                                    ? Theme.accentButton
                                    : Color.orange
                            )
                        )
                        .shadow(color: .black.opacity(0.45), radius: 8, y: 2)
                        .scaleEffect(isDragging ? 1.07 : 1.0)
                    }
                    .frame(width: canvasSize.width, height: 48)
                    .contentShape(.rect)
                    .id("seam-anchor-\(index)")
                    .position(x: canvasSize.width / 2, y: y)
                    .onTapGesture {
                        onTapSeam(index)
                    }
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 2)
                            .onChanged { value in
                                onDragChanged(index, value.translation.height)
                            }
                            .onEnded { _ in
                                onDragEnded()
                            }
                    )
                }
            }
        }
    }
}

private struct StudioMicroStepper: View {
    let titleKey: String
    let value: Int
    let step: Int
    let onDelta: (Int) -> Void

    var body: some View {
        HStack(spacing: 5) {
            Button {
                onDelta(-step)
            } label: {
                Image(systemName: "minus")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.14), in: Circle())
            }
            .buttonStyle(.plain)

            VStack(spacing: 1) {
                Text(LocalizedStringKey(titleKey))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
                Text(verbatim: "\(value)")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            .frame(minWidth: 34)

            Button {
                onDelta(step)
            } label: {
                Image(systemName: "plus")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.14), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Renders ultra-tall stitched images as <= 2048px vertical Metal texture slices so real iPhone GPUs
/// never truncate or blank out long screenshots past hardware texture size limits.
private struct TiledLongImageView: View {
    let image: CGImage
    let displayWidth: CGFloat
    let displayHeight: CGFloat

    private static let tilePx = 2048

    private var slices: [(image: CGImage, height: CGFloat)] {
        let totalH = image.height
        guard totalH > Self.tilePx, image.width > 0 else {
            return [(image, displayHeight)]
        }
        var result: [(CGImage, CGFloat)] = []
        var y = 0
        while y < totalH {
            let sliceH = min(Self.tilePx, totalH - y)
            if let cropped = image.cropping(to: CGRect(x: 0, y: y, width: image.width, height: sliceH)) {
                let hPt = displayHeight * (CGFloat(sliceH) / CGFloat(totalH))
                result.append((cropped, hPt))
            }
            y += sliceH
        }
        return result.isEmpty ? [(image, displayHeight)] : result
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(slices.enumerated()), id: \.offset) { _, slice in
                Image(decorative: slice.image, scale: 1)
                    .resizable()
                    .frame(width: displayWidth, height: slice.height)
            }
        }
        .frame(width: displayWidth, height: displayHeight)
    }
}
