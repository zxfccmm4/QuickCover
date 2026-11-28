import SwiftUI
import UniformTypeIdentifiers

/// Unified Apple Creative Export Studio:
/// - **Top Live Preview Stage**: Soft gallery backdrop keeping `CoveredPicture` unobstructed with
///   hold-to-compare, fluid aspect/backdrop/frame morphing, and a floating glass telemetry strip.
/// - **5-Tab Studio Dock**: Inline zero-push access to `画幅` (with platform icons & category filters),
///   `背景` (works with OR without device frame: 18-swatch palette + Hue + ColorPicker, custom gradient
///   mixer, or custom gallery photo), `外壳` (29 2026 Apple models), `版式` (templates, rounded corners,
///   shadow & scale), and `导出` (watermark, format, EXIF stripping).
/// - **Bottom Liquid Glass Action Bar**: Persistent Save / Share / Copy controls.
struct ExportScreen: View {
    enum StudioTab: String, CaseIterable, Identifiable {
        case ratio
        case backdrop
        case frame
        case layout
        case export

        var id: String { rawValue }

        var titleKey: String {
            switch self {
            case .ratio: "export.tab.aspect"
            case .backdrop: "export.tab.backdrop"
            case .frame: "export.tab.frame"
            case .layout: "export.tab.layout"
            case .export: "export.tab.export"
            }
        }

        var systemImage: String {
            switch self {
            case .ratio: "aspectratio"
            case .backdrop: "paintpalette"
            case .frame: "iphone.and.arrow.forward.inward"
            case .layout: "square.grid.2x2"
            case .export: "slider.horizontal.3"
            }
        }
    }

    @Environment(ShellModel.self) private var shell
    @Environment(EditorModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var tabNamespace

    private struct SharePayload: Identifiable {
        let id = UUID()
        let url: URL
    }

    @State private var studioTab: StudioTab = .ratio
    @State private var aspectCategory: ExportAspectCategory = .all
    @State private var toastText: String?
    @State private var toastShown = false
    @State private var toastTask: Task<Void, Never>?
    @State private var saveFailed = false
    @State private var isSaving = false
    @State private var isSharing = false
    @State private var sharePayload: SharePayload?
    @State private var renderedPreview: CGImage?
    @State private var showsWatermarkSheet = false

    @State private var successFeedbackCount = 0
    @State private var errorFeedbackCount = 0
    @State private var selectionFeedbackCount = 0

    private var facts: ExportFacts {
        ExportFacts(
            style: model.preferences.style,
            stripMetadata: model.preferences.stripMetadata,
            blurPickedThisTime: shell.stylePickedThisTime == .blur,
            coversText: model.coversText
        )
    }

    private var stripMetadata: Binding<Bool> {
        Binding(get: { model.preferences.stripMetadata }, set: { model.setStripMetadata($0) })
    }

    private var exportFormat: Binding<ExportFormat> {
        Binding(get: { model.preferences.exportFormat }, set: {
            model.setExportFormat($0)
            selectionFeedbackCount += 1
        })
    }

    private var shareItem: CoveredImageExport {
        CoveredImageExport(
            picture: model.picture,
            findings: model.enabledItems.flatMap(\.findings),
            options: model.exportOptions
        )
    }

    private var resolvedFormatBadge: String {
        if model.deviceFrame.needsPNG {
            return "PNG"
        }
        let target = model.preferences.exportFormat.utType(original: model.picture.fileType)
        if target == .png { return "PNG" }
        if target == .heic { return "HEIC" }
        if target == .jpeg { return "JPEG" }
        return target.preferredFilenameExtension?.uppercased() ?? "IMAGE"
    }

    private var previewAspect: CGFloat {
        Self.aspect(of: renderedPreview ?? model.preview)
    }

    private var outputDimensionText: String {
        if let rendered = renderedPreview, (model.deviceFrame.isStudioCanvasActive || model.exportAspectRatio != .original) {
            return "\(rendered.width) × \(rendered.height) · \(resolvedFormatBadge)"
        }
        let scale = model.deviceFrame.outputScale
        let w = Int((model.size.width * scale).rounded())
        let h = Int((model.size.height * scale).rounded())
        return "\(w) × \(h) · \(resolvedFormatBadge)"
    }

    private var usesNativeDeviceStudioAspect: Bool {
        model.deviceFrame.isStudioCanvasActive && model.deviceFrame.showsBackground && model.deviceFrame.canvasAspect == .auto
    }

    private var hasStudioEdits: Bool {
        model.exportAspectRatio != .original || model.deviceFrame != .none || model.watermark.isEnabled
    }

    private var visibleAspectPresets: [ExportAspectRatio] {
        ExportAspectRatio.presets(in: aspectCategory)
    }

    var body: some View {
        let facts = facts

        GeometryReader { geo in
            let stageHeight = max(210, min(335, geo.size.height * 0.43))

            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    // 1. Pinned Live Gallery Preview Stage
                    pinnedPreviewStage(
                        width: geo.size.width,
                        height: stageHeight
                    )

                    // 2. Unified 5-Tab Studio Control Dock
                    VStack(spacing: 0) {
                        studioTabStrip
                            .padding(.horizontal, Metrics.pageInset)
                            .padding(.top, 10)
                            .padding(.bottom, 8)

                        ScrollView {
                            VStack(spacing: 12) {
                                switch studioTab {
                                case .ratio:
                                    ratioInspectorContent
                                case .backdrop:
                                    StudioBackdropPanel {
                                        selectionFeedbackCount += 1
                                    }
                                case .frame:
                                    StudioDeviceFramePanel(
                                        onSelectionFeedback: { selectionFeedbackCount += 1 },
                                        onJumpToBackdrop: {
                                            withAnimation(.snappy(duration: 0.22)) {
                                                studioTab = .backdrop
                                            }
                                        }
                                    )
                                case .layout:
                                    StudioLayoutPanel {
                                        selectionFeedbackCount += 1
                                    }
                                case .export:
                                    exportSettingsInspectorContent(facts: facts)
                                }
                            }
                            .padding(.horizontal, Metrics.pageInset)
                            .padding(.top, 2)
                            .padding(.bottom, 22)
                        }
                        .scrollBounceBehavior(.basedOnSize)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.page)
                }

                if let toastText {
                    Toast(
                        text: LocalizedStringKey(toastText),
                        isShown: toastShown,
                        fadeIn: ExportToastTiming.fadeIn,
                        fadeOut: ExportToastTiming.fadeOut
                    )
                    .accessibilityHidden(true)
                    .padding(.top, 10)
                }
            }
        }
        .background(Theme.page.ignoresSafeArea())
        .navigationTitle("6.1.1")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if hasStudioEdits {
                    Button {
                        withAnimation(.snappy(duration: 0.24)) {
                            model.exportAspectRatio = .original
                            model.deviceFrame = .none
                            model.watermark.isEnabled = false
                        }
                        selectionFeedbackCount += 1
                    } label: {
                        Label("export.resetEdits", systemImage: "arrow.counterclockwise")
                    }
                    .tint(Theme.secondaryLabel)
                }

                NavigationLink {
                    AboutScreen()
                } label: {
                    Label("about.title", systemImage: "info.circle")
                }
                .accessibilityLabel("about.title")
            }
        }
        .safeAreaBar(edge: .bottom, spacing: 0) {
            bottomActionBar
        }
        .sheet(isPresented: $showsWatermarkSheet) {
            WatermarkSheet()
                .environment(model)
        }
        .sheet(item: $sharePayload) { payload in
            ShareActivitySheet(fileURL: payload.url) {
                sharePayload = nil
            }
        }
        .sensoryFeedback(.success, trigger: successFeedbackCount)
        .sensoryFeedback(.error, trigger: errorFeedbackCount)
        .sensoryFeedback(.selection, trigger: selectionFeedbackCount)
        .onChange(of: saveFailed) { _, failed in
            if failed { AccessibilityNotification.Announcement(L10n.text("6.4.2")).post() }
        }
    }

    // MARK: - Top Pinned Live Preview Stage

    private func pinnedPreviewStage(width: CGFloat, height: CGFloat) -> some View {
        let maxImgH = max(130, height - 54)
        let targetSize = PictureFit.size(
            aspect: previewAspect,
            maxWidth: max(44, width - 38),
            maxHeight: maxImgH
        )

        return ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [
                    Color(colorScheme == .dark ? .secondarySystemBackground : .systemGroupedBackground),
                    Theme.page.opacity(0.95),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            CoveredPicture(
                editor: model,
                size: CGSize(
                    width: max(44, min(targetSize.width, width - 36)),
                    height: max(120, min(targetSize.height, maxImgH))
                )
            ) { rendered in
                renderedPreview = rendered
            }
            .copyableTransferable([shareItem])
            .padding(.top, 8)
            .padding(.bottom, 34)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            privacySummaryStrip
                .padding(.bottom, 6)
        }
        .frame(height: height)
    }

    // MARK: - Unified 5-Tab Studio Bar

    private var studioTabStrip: some View {
        HStack(spacing: 4) {
            ForEach(StudioTab.allCases) { tab in
                let active = studioTab == tab
                let hasDot = tabHasActiveIndicator(tab)
                Button {
                    withAnimation(.snappy(duration: 0.24)) {
                        studioTab = tab
                    }
                    selectionFeedbackCount += 1
                } label: {
                    VStack(spacing: 3) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: tab.systemImage)
                                .font(.system(size: 16, weight: active ? .semibold : .medium))
                                .frame(height: 19)
                            if hasDot {
                                Circle()
                                    .fill(active ? .white : Theme.accent)
                                    .frame(width: 5, height: 5)
                                    .offset(x: 6, y: -2)
                            }
                        }
                        Text(LocalizedStringKey(tab.titleKey))
                            .font(.system(size: 11, weight: active ? .semibold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .foregroundStyle(active ? .white : Theme.secondaryLabel)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background {
                        if active {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(Theme.accentButton)
                                .matchedGeometryEffect(id: "exportStudioTabPill", in: tabNamespace)
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(PressStyle(scale: 0.96))
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Theme.fill.opacity(0.65))
        )
    }

    private func tabHasActiveIndicator(_ tab: StudioTab) -> Bool {
        switch tab {
        case .ratio:
            model.exportAspectRatio != .original
        case .backdrop:
            model.deviceFrame.isStudioCanvasActive && model.deviceFrame.showsBackground
        case .frame:
            model.deviceFrame.isActive
        case .layout:
            model.deviceFrame.isStudioCanvasActive && (model.deviceFrame.template != .centered || model.deviceFrame.outputScale < 0.99)
        case .export:
            model.watermark.isActive
        }
    }

    // MARK: - Studio Tab 1: Categorized Aspect Ratios + Platform Brand Badges

    private var ratioInspectorContent: some View {
        let cardShape = ConcentricRectangle(corners: .concentric(minimum: 18), isUniform: true)
        return VStack(spacing: 12) {
            // Category filter pills (全部 / 社媒平台 / App Store / 通用比例)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ExportAspectCategory.allCases) { cat in
                        let selected = aspectCategory == cat
                        Button {
                            withAnimation(.snappy(duration: 0.22)) {
                                aspectCategory = cat
                            }
                            selectionFeedbackCount += 1
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: cat.systemImage)
                                    .font(.caption.weight(.semibold))
                                Text(LocalizedStringKey(cat.titleKey))
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(selected ? .white : Theme.body)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(selected ? Theme.accentButton : Theme.fill))
                        }
                        .buttonStyle(PressStyle(scale: 0.95))
                    }
                }
                .padding(.vertical, 2)
            }

            // Visual Cards with Custom Brand Icons + Proportion Tags
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(visibleAspectPresets) { preset in
                        let selected = model.exportAspectRatio == preset
                        Button {
                            withAnimation(.snappy(duration: 0.24)) {
                                model.exportAspectRatio = preset
                            }
                            selectionFeedbackCount += 1
                        } label: {
                            AspectRatioVisualCard(preset: preset, isSelected: selected)
                        }
                        .buttonStyle(PressStyle(scale: 0.95))
                    }
                }
                .padding(.vertical, 2)
            }

            // Fit/Fill + Backdrop Swatches when non-original aspect ratio selected without studio canvas override
            if model.exportAspectRatio != .original && !usesNativeDeviceStudioAspect {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Picker("", selection: Binding<ExportAspectFitMode>(
                            get: { model.exportAspectFit },
                            set: { newFit in
                                withAnimation(.snappy(duration: 0.22)) {
                                    model.exportAspectFit = newFit
                                }
                                selectionFeedbackCount += 1
                            }
                        )) {
                            ForEach(ExportAspectFitMode.allCases) { fitMode in
                                Text(LocalizedStringKey(fitMode.titleKey)).tag(fitMode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: 175)

                        Spacer(minLength: 4)

                        if model.exportAspectFit == .fit && !model.deviceFrame.needsPNG {
                            HStack(spacing: 7) {
                                ForEach(ExportAspectBackdrop.allCases) { bg in
                                    let active = model.exportAspectBackdrop == bg
                                    Button {
                                        withAnimation(.snappy(duration: 0.2)) {
                                            model.exportAspectBackdrop = bg
                                        }
                                        selectionFeedbackCount += 1
                                    } label: {
                                        aspectBackdropDot(for: bg, active: active)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(LocalizedStringKey(bg.titleKey))
                                }
                            }
                        }
                    }

                    if model.exportAspectFit == .fit && !model.deviceFrame.isStudioCanvasActive {
                        Divider()
                        Button {
                            withAnimation(.snappy(duration: 0.22)) {
                                model.deviceFrame.enableFramelessBackdrop = true
                                model.deviceFrame.showsBackground = true
                                studioTab = .backdrop
                            }
                            selectionFeedbackCount += 1
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "paintpalette.fill")
                                    .font(.caption.weight(.semibold))
                                Text("export.customizeBackdrop")
                                    .font(.caption.weight(.semibold))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.semibold))
                            }
                            .foregroundStyle(Theme.accent)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
                .background(cardShape.fill(Theme.card))
                .overlay(cardShape.stroke(Theme.cardBorder(for: colorScheme), lineWidth: 0.5))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Text("6.1.2")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryLabel)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
        .animation(.snappy(duration: 0.24), value: model.exportAspectRatio)
        .animation(.snappy(duration: 0.22), value: model.exportAspectFit)
        .animation(.snappy(duration: 0.22), value: aspectCategory)
    }

    @ViewBuilder
    private func aspectBackdropDot(for bg: ExportAspectBackdrop, active: Bool) -> some View {
        let base = Circle()
            .frame(width: 24, height: 24)
            .overlay(
                Circle().stroke(
                    active ? Theme.accent : Theme.cardBorder(for: colorScheme),
                    lineWidth: active ? 2.5 : 1
                )
            )
        switch bg {
        case .adaptiveBlur:
            Circle()
                .fill(AppleIntelligencePalette.linearGradient)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle().stroke(
                        active ? Theme.accent : Theme.cardBorder(for: colorScheme),
                        lineWidth: active ? 2.5 : 1
                    )
                )
        case .light:
            base.foregroundStyle(Color(red: 0.94, green: 0.94, blue: 0.96))
        case .dark:
            base.foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.14))
        case .white:
            base.foregroundStyle(.white)
        }
    }

    // MARK: - Studio Tab 5: Watermark, Export Format & Privacy Controls

    private func exportSettingsInspectorContent(facts: ExportFacts) -> some View {
        let cardShape = ConcentricRectangle(corners: .concentric(minimum: 18), isUniform: true)
        return VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    showsWatermarkSheet = true
                } label: {
                    HStack(spacing: 12) {
                        IconTile(
                            systemImage: "checkerboard.shield",
                            ground: (model.watermark.isActive ? Theme.accent : Color.teal)
                                .opacity(colorScheme == .dark ? 0.22 : 0.12),
                            tint: model.watermark.isActive ? Theme.accent : .teal
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text("export.watermarkRow")
                                .font(.body)
                                .foregroundStyle(Theme.body)
                            if model.watermark.isActive {
                                Text(LocalizedStringKey(model.watermark.placement.titleKey))
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(Theme.accent)
                                    .lineLimit(1)
                            } else {
                                Text("export.watermarkCardSub")
                                    .font(.footnote)
                                    .foregroundStyle(Theme.secondaryLabel)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 4)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)

                if !model.watermark.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Toggle("", isOn: Binding(
                        get: { model.watermark.isEnabled },
                        set: { newVal in
                            model.watermark.isEnabled = newVal
                            selectionFeedbackCount += 1
                        }
                    ))
                    .labelsHidden()
                    .tint(Theme.accent)
                }

                Button {
                    showsWatermarkSheet = true
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(cardShape.fill(Theme.card))
            .overlay(cardShape.stroke(Theme.cardBorder(for: colorScheme), lineWidth: 0.5))

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    IconTile(
                        systemImage: "doc.badge.gearshape",
                        ground: Color.blue.opacity(colorScheme == .dark ? 0.22 : 0.12),
                        tint: .blue
                    )

                    Text("export.format")
                        .font(.body)
                        .foregroundStyle(Theme.body)

                    Spacer(minLength: 8)

                    Picker("export.format", selection: exportFormat) {
                        ForEach(ExportFormat.allCases) { format in
                            Text(LocalizedStringKey(format.titleKey)).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 190)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(minHeight: Metrics.rowMinHeight)

                Divider().padding(.leading, 56)

                ExportToggleRow(title: "6.2.1", footnote: facts.footnote, isOn: stripMetadata)
            }
            .background(cardShape.fill(Theme.card))
            .overlay(cardShape.stroke(Theme.cardBorder(for: colorScheme), lineWidth: 0.5))

            if facts.showsCoveredLine {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.footnote.weight(.semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Theme.accent)
                        .accessibilityHidden(true)
                    Text("6.2.4")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryLabel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
            }

            if let noticeKey = facts.noticeKey {
                NoticeBar(
                    systemImage: "exclamationmark.triangle.fill",
                    tint: Theme.blurNoticeIcon,
                    ground: Theme.blurNotice,
                    text: noticeKey,
                    stacksWhenTooWide: true
                ) {
                    SmallButton(title: "6.3.2") { switchToSolid() }
                }
            }
        }
    }

    // MARK: - Floating Telemetry Pill

    private var privacySummaryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Text(verbatim: outputDimensionText)
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.body)
                    .contentTransition(.numericText())
                    .fixedSize()
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())

                if model.exportAspectRatio != .original {
                    Text(LocalizedStringKey(model.exportAspectRatio.titleKey))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .fixedSize()
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                if let deviceModel = model.deviceFrame.model {
                    Label(deviceModel.displayName, systemImage: deviceModel.systemImage)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .fixedSize()
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                } else if model.deviceFrame.enableFramelessBackdrop && model.deviceFrame.showsBackground {
                    Label(LocalizedStringKey(model.deviceFrame.backdropKind.titleKey), systemImage: "paintpalette")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .fixedSize()
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                if !model.enabledItems.isEmpty {
                    Label(L10n.coveredCount(model.enabledItems.count), systemImage: "checkmark.shield.fill")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.accent)
                        .fixedSize()
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .padding(.horizontal, Metrics.pageInset)
        }
    }

    // MARK: - Compact Single-Row Bottom Action Bar

    private var bottomActionBar: some View {
        GlassEffectContainer(spacing: 10) {
            VStack(spacing: 10) {
                if saveFailed {
                    NoticeBar(
                        systemImage: "exclamationmark.circle.fill",
                        tint: Theme.errorIcon,
                        ground: Theme.fillTwo,
                        text: "6.4.2"
                    ) {
                        TextButton(title: "6.4.3") { save() }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                HStack(spacing: 10) {
                    PrimaryButton(
                        title: "6.1.3",
                        systemImage: "square.and.arrow.down",
                        isBusy: isSaving
                    ) {
                        save()
                    }

                    Button {
                        share()
                    } label: {
                        Group {
                            if isSharing {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.body.weight(.semibold))
                            }
                        }
                        .frame(width: 50, height: 50)
                        .contentShape(.circle)
                        .glassEffect(.regular.interactive(), in: .circle)
                    }
                    .buttonStyle(PressStyle(scale: 0.94))
                    .disabled(isSharing || isSaving)
                    .accessibilityLabel("6.1.4")
                }
            }
            .padding(.horizontal, Metrics.pageInset)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .animation(.snappy(duration: 0.25), value: saveFailed)
    }

    // MARK: - Actions

    private func switchToSolid() {
        selectionFeedbackCount += 1
        withAnimation(.snappy(duration: 0.25)) {
            model.setStyle(.solid)
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        Task { @MainActor in
            defer { isSaving = false }
            do {
                let data = try await model.exportData()
                try await ExportActions.saveToPhotos(data)
                saveFailed = false
                successFeedbackCount += 1
                showToast("6.4.1")
            } catch {
                errorFeedbackCount += 1
                saveFailed = true
            }
        }
    }

    private func share() {
        guard !isSharing else { return }
        isSharing = true
        Task { @MainActor in
            defer { isSharing = false }
            do {
                let data = try await model.exportData()
                let targetType: UTType = model.deviceFrame.needsPNG
                    ? .png
                    : model.preferences.exportFormat.utType(original: model.picture.fileType)
                let url = try ExportActions.makeShareFileURL(data: data, fileType: targetType)
                sharePayload = SharePayload(url: url)
                selectionFeedbackCount += 1
            } catch {
                errorFeedbackCount += 1
            }
        }
    }

    private func showToast(_ text: String) {
        toastTask?.cancel()
        toastText = text
        toastShown = true
        AccessibilityNotification.Announcement(L10n.text(text)).post()
        toastTask = Task { @MainActor in
            try? await Task.sleep(for: ExportToastTiming.shows)
            guard !Task.isCancelled else { return }
            toastShown = false
            try? await Task.sleep(for: ExportToastTiming.clears)
            guard !Task.isCancelled else { return }
            toastText = nil
        }
    }

    private static func aspect(of image: CGImage) -> CGFloat {
        guard image.height > 0 else { return 1 }
        return CGFloat(image.width) / CGFloat(image.height)
    }
}

private struct AspectRatioVisualCard: View {
    let preset: ExportAspectRatio
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 7) {
            PlatformAspectBadgeView(preset: preset, size: 32)

            VStack(spacing: 1) {
                Text(LocalizedStringKey(preset.titleKey))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : Theme.body)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                if let badge = preset.ratioBadge {
                    Text(verbatim: badge)
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(isSelected ? .white.opacity(0.90) : Theme.secondaryLabel)
                } else {
                    Text(verbatim: "Auto")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(isSelected ? .white.opacity(0.90) : Theme.secondaryLabel)
                }
            }
        }
        .frame(width: 88, height: 82)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(isSelected ? Theme.accentButton : Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(
                    isSelected ? Theme.accentButton : Theme.cardBorder(for: colorScheme),
                    lineWidth: isSelected ? 1 : 0.5
                )
        )
    }
}
