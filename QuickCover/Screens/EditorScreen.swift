import SwiftUI

/// Full-bleed dark photo-editing studio inspired by Apple Photos, Photomator, and iOS 26/27 Markup.
/// Features a live top-center Liquid Glass coverage / zoom HUD pill, grouped trailing watermark &
/// review controls, live-texture `QuickStyleTray`, and scoped dark-studio chrome.
struct EditorScreen: View {
    @Environment(EditorModel.self) private var model
    @Environment(ShellModel.self) private var shell
    @Environment(\.systemColorScheme) private var systemColorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var glassNamespace

    @State private var calloutHeight: CGFloat = 0
    @State private var styleTrayHeight: CGFloat = 0
    @State private var calloutDismissed = false
    @State private var drawHintHidden = false
    @State private var announcedCallout: EditorCallout.Kind?
    @State private var canvasZoom: CGFloat = 1
    @State private var zoomResetTrigger = 0

    private var isFinding: Bool { model.recognition == .running }
    private var enabledCount: Int { model.enabledItems.count }

    private var callout: EditorCallout.Kind? {
        guard !calloutDismissed else { return nil }
        return switch model.recognition {
        case .running: nil
        case .done: model.found.isEmpty ? .nothing : nil
        case .failed: .failed
        }
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

    var body: some View {
        GeometryReader { proxy in
            let bottomOverlayHeight: CGFloat = if callout != nil {
                calloutHeight + EditorLayout.pictureOverCallout
            } else if model.styleTrayShown {
                styleTrayHeight + 12
            } else {
                0
            }
            let reviewHeight = max(SheetGeometry.shared.top - proxy.safeAreaInsets.top, 0)

            ZStack {
                EditorPicture(
                    area: CGSize(
                        width: proxy.size.width,
                        height: max(proxy.size.height - bottomOverlayHeight, 0)
                    ),
                    reviewVisibleHeight: reviewHeight,
                    isBlurred: isFinding,
                    zoomResetTrigger: zoomResetTrigger,
                    onZoomChanged: { canvasZoom = $0 },
                    onTapOutsideReview: { shell.hideReview() }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: bottomOverlayHeight)

                GlassEffectContainer(spacing: 12) {
                    VStack {
                        Spacer()
                        if let callout {
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
                        } else if model.styleTrayShown {
                            QuickStyleTray()
                                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { styleTrayHeight = $0 }
                                .padding(.horizontal, Metrics.pageInset)
                                .padding(.bottom, EditorLayout.calloutOverBar)
                                .glassEffectID("styleTray", in: glassNamespace)
                                .glassEffectTransition(.materialize)
                                .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .bottom)))
                        } else if model.drawToolOn, !drawHintHidden {
                            PictureCapsule(text: "4.8.5")
                                .padding(.bottom, EditorLayout.drawCapsuleOverBar)
                                .glassEffectID("drawHint", in: glassNamespace)
                                .glassEffectTransition(.matchedGeometry)
                                .transition(.opacity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background { ambientBackdrop(for: proxy.size) }
            .animation(.easeInOut(duration: 0.2), value: model.drawToolOn && !drawHintHidden)
            .animation(.snappy(duration: 0.28), value: callout)
            .animation(.snappy(duration: 0.26), value: model.styleTrayShown)
        }
        .environment(\.colorScheme, .dark)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar, .bottomBar)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .toolbarBackgroundVisibility(.hidden, for: .bottomBar)
        .keepsBottomToolbarExpanded()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    shell.showPickerFromEditor()
                } label: {
                    Label("3.1.8", systemImage: "photo.on.rectangle")
                }
                .disabled(isFinding)
                .accessibilityLabel("3.1.8")
            }

            ToolbarItem(placement: .principal) {
                studioStatusPill
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.drawToolOn = false
                    model.styleTrayShown = false
                    model.watermarkShown = true
                } label: {
                    Image(systemName: "checkerboard.shield")
                        .fontWeight(model.watermark.isActive ? .semibold : .regular)
                        .foregroundStyle(model.watermark.isActive ? Theme.accentOnBlack : .primary)
                }
                .disabled(isFinding)
                .accessibilityLabel("editor.watermarkButton")
                .accessibilityAddTraits(model.watermark.isActive ? [.isSelected] : [])
            }

            ToolbarItem(placement: AppleToolbarPlacement.pinnedTrailing) {
                Button {
                    shell.showReview()
                } label: {
                    Label("4.4.1", systemImage: "list.bullet")
                }
                .disabled(isFinding)
                .accessibilityLabel("4.4.1")
            }

            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    model.undo()
                } label: {
                    Label("4.8.1", systemImage: "arrow.uturn.backward")
                }
                .disabled(!model.canUndo || isFinding)
                .accessibilityLabel("4.8.1")

                Button {
                    model.redo()
                } label: {
                    Label("4.8.2", systemImage: "arrow.uturn.forward")
                }
                .disabled(!model.canRedo || isFinding)
                .accessibilityLabel("4.8.2")

                Button {
                    if !model.drawToolOn {
                        model.styleTrayShown = false
                    }
                    model.drawToolOn.toggle()
                } label: {
                    Image(systemName: "rectangle.dashed")
                        .fontWeight(model.drawToolOn ? .bold : .regular)
                        .foregroundStyle(model.drawToolOn ? Theme.accentOnBlack : .primary)
                }
                .disabled(isFinding)
                .accessibilityLabel("4.8.3")
                .accessibilityAddTraits(model.drawToolOn ? [.isSelected] : [])

                Button {
                    if !model.styleTrayShown {
                        model.drawToolOn = false
                    }
                    model.styleTrayShown.toggle()
                } label: {
                    Image(systemName: "swatchpalette")
                        .fontWeight(model.styleTrayShown ? .semibold : .regular)
                        .foregroundStyle(model.styleTrayShown ? Theme.accentOnBlack : .primary)
                }
                .disabled(isFinding)
                .accessibilityLabel("editor.styleButton")
                .accessibilityAddTraits(model.styleTrayShown ? [.isSelected] : [])
            }

            ToolbarSpacer(.flexible, placement: .bottomBar)

            ToolbarItem(placement: .bottomBar) {
                Button {
                    shell.showExport()
                } label: {
                    Text("4.9.1")
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
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
                .preferredColorScheme(systemColorScheme)
        }
        .sheet(isPresented: watermarkShown) {
            WatermarkSheet()
                .environment(model)
                .preferredColorScheme(systemColorScheme)
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
                .padding(.vertical, 6)
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
                        .foregroundStyle(enabledCount > 0 ? Theme.accentOnBlack : .secondary)
                    Text(L10n.coveredCount(enabledCount))
                        .font(.footnote.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(enabledCount > 0 ? 0.95 : 0.65))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
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
                    .blur(radius: 70)
                    .opacity(0.18)
                    .backgroundExtensionEffect()
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Actions

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
