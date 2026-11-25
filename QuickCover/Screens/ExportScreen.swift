import SwiftUI
import UniformTypeIdentifiers

/// Native Apple Export & Share screen using adaptive Light/Dark grouped styling, concentric preview
/// with hold-to-compare, glanceable privacy-status summary pills, export format & metadata controls,
/// iOS 26 `.safeAreaBar(edge: .bottom)`, native SwiftUI `ShareLink`, and iOS 27 `.copyable`.
struct ExportScreen: View {
    @Environment(ShellModel.self) private var shell
    @Environment(EditorModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize

    @State private var toastText: String?
    @State private var toastShown = false
    @State private var toastTask: Task<Void, Never>?
    @State private var saveFailed = false
    @State private var isSaving = false
    @State private var renderedPreview: CGImage?

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

    private var sharePreviewImage: Image {
        Image(decorative: renderedPreview ?? model.preview, scale: 1)
    }

    private var resolvedFormatBadge: String {
        let target = model.preferences.exportFormat.utType(original: model.picture.fileType)
        if target == .png { return "PNG" }
        if target == .heic { return "HEIC" }
        if target == .jpeg { return "JPEG" }
        return target.preferredFilenameExtension?.uppercased() ?? "IMAGE"
    }

    var body: some View {
        let buttonsScroll = typeSize.isAccessibilitySize
        let facts = facts

        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    page(facts)
                    if buttonsScroll {
                        buttons
                            .padding(.top, 16)
                    }
                }
                .padding(.bottom, 20)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollEdgeEffectStyle(.soft, for: .all)
            .safeAreaBar(edge: .bottom, spacing: 0) {
                if !buttonsScroll {
                    buttons
                        .padding(.top, 6)
                }
            }

            if let toastText {
                Toast(
                    text: LocalizedStringKey(toastText),
                    isShown: toastShown,
                    fadeIn: ExportToastTiming.fadeIn,
                    fadeOut: ExportToastTiming.fadeOut
                )
                .accessibilityHidden(true)
                .padding(.top, 12)
            }
        }
        .background(Theme.page.ignoresSafeArea())
        .navigationTitle("6.1.1")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: successFeedbackCount)
        .sensoryFeedback(.error, trigger: errorFeedbackCount)
        .sensoryFeedback(.selection, trigger: selectionFeedbackCount)
        .onChange(of: saveFailed) { _, failed in
            if failed { AccessibilityNotification.Announcement(L10n.text("6.4.2")).post() }
        }
    }

    @ViewBuilder
    private func page(_ facts: ExportFacts) -> some View {
        CoveredPicture(
            editor: model,
            size: facts.pictureSize(aspect: Self.aspect(of: model.preview))
        ) { rendered in
            renderedPreview = rendered
        }
        .copyableTransferable([shareItem])
        .padding(.top, 14)

        VStack(spacing: 7) {
            privacySummaryStrip

            Text("6.1.2")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryLabel)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .padding(.top, 12)
        .padding(.bottom, 16)

        VStack(spacing: 0) {
            ExportToggleRow(title: "6.2.1", footnote: facts.footnote, isOn: stripMetadata)

            Divider()
                .padding(.leading, 16)

            exportFormatRow
        }
        .background(
            ConcentricRectangle(corners: .concentric(minimum: 18), isUniform: true)
                .fill(Theme.card)
        )
        .padding(.horizontal, Metrics.pageInset)

        if facts.showsCoveredLine {
            coveredLine
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.top, 10)
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
            .padding(.horizontal, Metrics.pageInset)
            .padding(.top, 12)
        }
    }

    private var privacySummaryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Text("\(Int(model.size.width)) × \(Int(model.size.height)) · \(resolvedFormatBadge)")
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(Theme.secondaryLabel)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.fill))

                if !model.enabledItems.isEmpty {
                    Label(L10n.coveredCount(model.enabledItems.count), systemImage: "checkmark.shield.fill")
                        .font(.caption.weight(.medium).monospacedDigit())
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Theme.accent.opacity(0.12)))
                }

                if model.preferences.stripMetadata {
                    Label("export.metadataStripped", systemImage: "location.slash.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Theme.accent.opacity(0.12)))
                }

                if model.watermark.isActive {
                    Label("wm.title", systemImage: "checkerboard.shield")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Theme.accent.opacity(0.12)))
                        .accessibilityLabel("export.watermarkActive")
                }
            }
            .padding(.horizontal, Metrics.pageInset)
            .frame(minWidth: 0, maxWidth: .infinity)
        }
    }

    private var exportFormatRow: some View {
        HStack(spacing: 12) {
            Text("export.format")
                .font(.body)
                .foregroundStyle(Theme.body)

            Spacer(minLength: 8)

            Picker("export.format", selection: exportFormat) {
                ForEach(ExportFormat.allCases) { format in
                    Text(LocalizedStringKey(format.titleKey)).tag(format)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(Theme.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: Metrics.rowMinHeight)
    }

    private func switchToSolid() {
        selectionFeedbackCount += 1
        withAnimation(.snappy(duration: 0.25)) {
            model.setStyle(.solid)
        }
    }

    private var coveredLine: some View {
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
    }

    private var buttons: some View {
        GlassEffectContainer(spacing: 10) {
            VStack(spacing: 12) {
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

                VStack(spacing: 10) {
                    PrimaryButton(
                        title: "6.1.3",
                        systemImage: "square.and.arrow.down",
                        isBusy: isSaving
                    ) {
                        save()
                    }

                    HStack(spacing: 10) {
                        ShareLink(
                            item: shareItem,
                            preview: SharePreview(L10n.text("6.1.1"), image: sharePreviewImage)
                        ) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                    .fontWeight(.semibold)
                                Text("6.1.4")
                                    .font(.buttonText)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .minimumScaleFactor(0.85)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.capsule)
                        .buttonSizing(.flexible)
                        .controlSize(.large)

                        SecondaryButton(title: "6.1.5", systemImage: "doc.on.doc") {
                            copy()
                        }
                    }
                }
            }
            .padding(.horizontal, Metrics.pageInset)
            .padding(.bottom, 16)
        }
        .animation(.snappy(duration: 0.25), value: saveFailed)
    }

    // MARK: - Actions

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

    private func copy() {
        Task { @MainActor in
            if let data = try? await model.exportData() {
                let targetType = model.preferences.exportFormat.utType(original: model.picture.fileType)
                ExportActions.copy(data, fileType: targetType)
                successFeedbackCount += 1
                showToast("6.4.4")
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
