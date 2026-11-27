import SwiftUI

/// Full-bleed dark photo-editing studio inspired by Apple Photos, Apple Intelligence Clean Up,
/// and iOS 26/27 Screenshot Markup.
/// Uses unified monochrome Liquid Glass toolbar controls (highlighting brand teal for active tools,
/// Apple Intelligence iridescence for smart privacy scanning, and prominent Export CTA), a centered
/// live coverage/zoom HUD pill, gallery-framed canvas, and harmonized dark-studio inspector sheets.
struct EditorScreen: View {
    @Environment(EditorModel.self) private var model
    @Environment(ShellModel.self) private var shell
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var glassNamespace

    @State private var calloutHeight: CGFloat = 0
    @State private var styleTrayHeight: CGFloat = 0
    @State private var calloutDismissed = false
    @State private var drawHintHidden = false
    @State private var announcedCallout: EditorCallout.Kind?
    @State private var canvasZoom: CGFloat = 1
    @State private var zoomResetTrigger = 0
    @State private var aiToastMessage: String?
    @State private var aiToastTask: Task<Void, Never>?

    private var isFinding: Bool { model.recognition == .running }
    private var enabledCount: Int { model.enabledItems.count }
    private var isSheetOpen: Bool { model.reviewShown || model.watermarkShown || model.emojiPickerShown }

    private var callout: EditorCallout.Kind? {
        guard !calloutDismissed, !isSheetOpen else { return nil }
        return switch model.recognition {
        case .running: nil
        case .done: model.found.isEmpty ? .nothing : nil
        case .failed: .failed
        }
    }

    private var showsStyleTray: Bool {
        model.styleTrayShown && !isSheetOpen
    }

    private var showsDrawHint: Bool {
        model.drawToolOn && !drawHintHidden && !isSheetOpen && !showsStyleTray && callout == nil
    }

    private var manualBoxCount: Int { model.items.filter { $0.origin == .manual }.count }

    private var reviewShown: Binding<Bool> {
        Binding(
            get: { model.reviewShown },
            set: { shown in if !shown { shell.hideReview() } }
        )
    }

    private var watermarkShown: Binding<Bool> {
        Binding(
            get: { model.watermarkShown },
            set: { model.watermarkShown = $0 }
        )
    }

    private var emojiPickerShown: Binding<Bool> {
        Binding(
            get: { model.emojiPickerShown },
            set: { model.emojiPickerShown = $0 }
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let horizontalMat: CGFloat = 10
            let bottomOverlayHeight: CGFloat = if showsStyleTray {
                styleTrayHeight + 12
            } else if callout != nil {
                calloutHeight + EditorLayout.pictureOverCallout
            } else {
                0
            }
            let reviewHeight = max(SheetGeometry.shared.top - proxy.safeAreaInsets.top, 0)

            ZStack(alignment: .bottom) {
                EditorPicture(
                    area: CGSize(
                        width: max(proxy.size.width - horizontalMat * 2, 0),
                        height: max(proxy.size.height - bottomOverlayHeight, 0)
                    ),
                    reviewVisibleHeight: reviewHeight,
                    isBlurred: isFinding,
                    zoomResetTrigger: zoomResetTrigger,
                    onZoomChanged: { canvasZoom = $0 },
                    onTapOutsideReview: { shell.hideReview() }
                )
                .padding(.horizontal, horizontalMat)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: bottomOverlayHeight)

                if let aiToastMessage, !isSheetOpen {
                    VStack {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppleIntelligencePalette.linearGradient)
                            Text(verbatim: aiToastMessage)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .glassEffect(.regular, in: .capsule)
                        .overlay(
                            Capsule()
                                .stroke(AppleIntelligencePalette.linearGradient.opacity(0.55), lineWidth: 0.8)
                        )
                        .padding(.top, 8)
                        Spacer()
                    }
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if showsStyleTray || callout != nil || showsDrawHint {
                    GlassEffectContainer(spacing: 12) {
                        Group {
                            if showsStyleTray {
                                QuickStyleTray()
                                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { styleTrayHeight = $0 }
                                    .padding(.horizontal, Metrics.pageInset)
                                    .padding(.bottom, EditorLayout.calloutOverBar)
                                    .glassEffectID("styleTray", in: glassNamespace)
                                    .glassEffectTransition(.materialize)
                                    .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .bottom)))
                            } else if let callout {
                                EditorCallout(
                                    kind: callout,
                                    draw: startDrawing,
                                    retry: retryRecognition
                                )
                                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { calloutHeight = $0 }
                                .padding(.horizontal, Metrics.pageInset)
                                .padding(.bottom, EditorLayout.calloutOverBar)
                                .glassEffectID("callout", in: glassNamespace)
                                .glassEffectTransition(.materialize)
                                .transition(reduceMotion ? .identity : .opacity.combined(with: .scale(scale: 0.96)))
                            } else if showsDrawHint {
                                PictureCapsule(text: "4.8.5")
                                    .padding(.bottom, EditorLayout.drawCapsuleOverBar)
                                    .glassEffectID("drawHint", in: glassNamespace)
                                    .glassEffectTransition(.matchedGeometry)
                                    .transition(.opacity)
                            }
                        }
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background { ambientBackdrop(for: proxy.size) }
            .animation(.easeInOut(duration: 0.2), value: showsDrawHint)
            .animation(.snappy(duration: 0.28), value: callout)
            .animation(.snappy(duration: 0.26), value: showsStyleTray)
            .animation(.snappy(duration: 0.24), value: aiToastMessage)
        }
        .environment(\.colorScheme, .dark)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar, .bottomBar)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .toolbarBackgroundVisibility(.hidden, for: .bottomBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    shell.showPickerFromEditor()
                } label: {
                    Label("3.1.8", systemImage: "photo.on.rectangle")
                }
                .tint(.primary)
                .disabled(isFinding)
                .accessibilityLabel("3.1.8")
            }

            ToolbarItem(placement: .principal) {
                studioStatusPill
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    model.drawToolOn = false
                    model.styleTrayShown = false
                    model.watermarkShown = true
                } label: {
                    Label("editor.watermarkButton", systemImage: "checkerboard.shield")
                        .symbolVariant(model.watermark.isActive ? .fill : .none)
                }
                .tint(model.watermark.isActive ? Theme.accentOnBlack : .primary)
                .disabled(isFinding)
                .accessibilityLabel("editor.watermarkButton")
                .accessibilityAddTraits(model.watermark.isActive ? [.isSelected] : [])

                Button {
                    shell.showReview()
                } label: {
                    Label("4.4.1", systemImage: "list.bullet")
                }
                .tint(model.reviewShown ? Theme.accentOnBlack : .primary)
                .disabled(isFinding)
                .accessibilityLabel("4.4.1")
            }

            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    model.undo()
                } label: {
                    Label("4.8.1", systemImage: "arrow.uturn.backward")
                }
                .tint(.primary)
                .disabled(!model.canUndo || isFinding)
                .accessibilityLabel("4.8.1")

                Button {
                    model.redo()
                } label: {
                    Label("4.8.2", systemImage: "arrow.uturn.forward")
                }
                .tint(.primary)
                .disabled(!model.canRedo || isFinding)
                .accessibilityLabel("4.8.2")

                Button {
                    if !model.drawToolOn {
                        model.styleTrayShown = false
                    }
                    model.drawToolOn.toggle()
                } label: {
                    Label("4.8.3", systemImage: "rectangle.dashed")
                }
                .tint(model.drawToolOn ? Theme.accentOnBlack : .primary)
                .disabled(isFinding)
                .accessibilityLabel("4.8.3")
                .accessibilityAddTraits(model.drawToolOn ? [.isSelected] : [])

                Button {
                    if !model.styleTrayShown {
                        model.drawToolOn = false
                    }
                    model.styleTrayShown.toggle()
                } label: {
                    Label("editor.styleButton", systemImage: "swatchpalette")
                        .symbolVariant(model.styleTrayShown ? .fill : .none)
                }
                .tint(model.styleTrayShown ? Theme.accentOnBlack : .primary)
                .disabled(isFinding)
                .accessibilityLabel("editor.styleButton")
                .accessibilityAddTraits(model.styleTrayShown ? [.isSelected] : [])
            }

            ToolbarItem(placement: .bottomBar) {
                Menu {
                    Button {
                        triggerSmartScan(applyMagicErase: false)
                    } label: {
                        Label("ai.menuScan", systemImage: "sparkles")
                    }

                    Button {
                        triggerSmartScan(applyMagicErase: true)
                    } label: {
                        Label("ai.menuMagicErase", systemImage: "wand.and.stars")
                    }

                    Divider()

                    Toggle(
                        "ai.autoToggle",
                        isOn: Binding(
                            get: { model.preferences.autoAppleIntelligence },
                            set: { model.setAutoAppleIntelligence($0) }
                        )
                    )
                } label: {
                    Image(systemName: "sparkles")
                        .fontWeight(.semibold)
                        .foregroundStyle(AppleIntelligencePalette.linearGradient)
                        .symbolEffect(.pulse, isActive: model.isRunningIntelligence)
                } primaryAction: {
                    triggerSmartScan(applyMagicErase: false)
                }
                .disabled(isFinding || model.isRunningIntelligence)
                .accessibilityLabel("ai.buttonLabel")
            }

            ToolbarSpacer(.flexible, placement: .bottomBar)

            ToolbarItem(placement: .bottomBar) {
                Button {
                    shell.showExport()
                } label: {
                    Text("4.9.1")
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.accentButton)
                .disabled(isFinding)
                .accessibilityLabel("4.9.1")
            }
        }
        .sheet(isPresented: reviewShown) {
            ReviewSheet()
                .environment(shell)
                .environment(model)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: watermarkShown) {
            WatermarkSheet()
                .environment(model)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: emojiPickerShown) {
            EmojiPickerSheet()
                .environment(model)
                .preferredColorScheme(.dark)
        }
        .task(id: isFinding) {
            if isFinding { announce("4.2.1") }
        }
        .task(id: callout) {
            guard let callout else { return }
            if announcedCallout != callout {
                announcedCallout = callout
                announce(callout == .nothing ? "5.1.1" : "5.2.1")
            }
        }
        .onChange(of: model.drawToolOn) { _, on in
            if on { drawHintHidden = false }
        }
        .onChange(of: manualBoxCount) { _, count in
            if model.drawToolOn, count > 0 { drawHintHidden = true }
        }
        .onDisappear {
            aiToastTask?.cancel()
        }
    }

    // MARK: - Top-Center Live Studio HUD Pill

    @ViewBuilder
    private var studioStatusPill: some View {
        if isFinding {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityHidden(true)
        } else if canvasZoom > 1.05 {
            Button {
                zoomResetTrigger += 1
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.caption2.weight(.semibold))
                    Text("\(String(format: "%.1f", canvasZoom))×")
                        .font(.footnote.weight(.semibold).monospacedDigit())
                }
                .foregroundStyle(Theme.accentOnBlack)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .glassEffect(.regular.interactive(), in: .capsule)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("editor.resetZoom")
            .transition(.opacity.combined(with: .scale(scale: 0.92)))
        } else {
            Button {
                shell.showReview()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: enabledCount > 0 ? "checkmark.shield.fill" : "shield")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(enabledCount > 0 ? Theme.accentOnBlack : .white.opacity(0.5))
                    Text(L10n.coveredCount(enabledCount))
                        .font(.footnote.weight(.medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(enabledCount > 0 ? 0.95 : 0.72))
                }
                .padding(.horizontal, 12)
                .frame(height: 32)
                .glassEffect(.regular.interactive(), in: .capsule)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.coveredCount(enabledCount))
            .transition(.opacity)
        }
    }

    /// Subtle dark ambient wash constrained strictly to container bounds so `scaledToFill()` never
    /// widens the editor layout.
    private func ambientBackdrop(for size: CGSize) -> some View {
        ZStack {
            Theme.studioCanvas
            if !reduceMotion {
                Image(decorative: model.preview, scale: 1)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .blur(radius: 72)
                    .opacity(0.14)
                    .backgroundExtensionEffect()
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Actions

    private func triggerSmartScan(applyMagicErase: Bool) {
        Task { @MainActor in
            let added = await model.runAppleIntelligenceScan(applyMagicErase: applyMagicErase)
            let message: String = if added > 0 {
                L10n.intelligenceAdded(added)
            } else if applyMagicErase {
                L10n.text("ai.magicEraseApplied")
            } else {
                L10n.text("ai.resultNone")
            }
            showAIToast(message)
        }
    }

    private func showAIToast(_ message: String) {
        aiToastTask?.cancel()
        aiToastMessage = message
        aiToastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled else { return }
            aiToastMessage = nil
        }
    }

    private func startDrawing() {
        calloutDismissed = true
        model.styleTrayShown = false
        model.drawToolOn = true
    }

    private func retryRecognition() {
        calloutDismissed = false
        announcedCallout = nil
        model.retryRecognition()
    }

    private func announce(_ key: String) {
        AccessibilityNotification.Announcement(L10n.text(key)).post()
    }
}

/// Shared editor spacing & layout constants.
enum EditorLayout {
    static let topInset: CGFloat = 62
    static let bottomInset: CGFloat = 72
    static let topButtonsInset: CGFloat = 6
    static let barInset: CGFloat = 8
    static let barHeight: CGFloat = 52
    static let calloutOverBar: CGFloat = 12
    static let pictureOverCallout: CGFloat = 14
    static let drawCapsuleOverBar: CGFloat = 10
    static let sheetTop: CGFloat = 300
    static let sheetInset: CGFloat = 20
    static let calloutIdle = Duration.seconds(5)
}

/// Tracks the live top edge of ReviewSheet so "Locate" frames items above the sheet cleanly.
@Observable @MainActor
final class SheetGeometry {
    static let shared = SheetGeometry()

    var top: CGFloat = EditorLayout.sheetTop
    var extra: CGFloat = 0

    nonisolated static func addition(sheetTop: CGFloat, extraBefore: CGFloat, top: CGFloat) -> CGFloat {
        max(0, sheetTop + extraBefore - top)
    }
}
