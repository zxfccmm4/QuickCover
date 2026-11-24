import SwiftUI

/// The editor (design.md §7.3): black, no navigation bar. The picture fitted between the top
/// buttons and the glass bar, the callout at the bottom when nothing was found or the look failed,
/// and the sheet of Review Each Item over the lower part of the screen.
struct EditorScreen: View {
    @Environment(EditorModel.self) private var model
    @Environment(ShellModel.self) private var shell
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var calloutHeight: CGFloat = 0
    /// Set by the card's「手動框選」(§7.3.4) or by the 5 s of §8; a new picture starts over.
    @State private var calloutDismissed = false
    @State private var calloutTask: Task<Void, Never>?
    @State private var drawHintHidden = false
    @State private var announcedCallout: EditorCallout.Kind?

    private var isFinding: Bool { model.recognition == .running }

    private var callout: EditorCallout.Kind? {
        guard !calloutDismissed else { return nil }
        return switch model.recognition {
        case .running: nil
        case .done: model.found.isEmpty ? .nothing : nil
        case .failed: .failed
        }
    }

    private var manualBoxCount: Int { model.items.filter { $0.origin == .manual }.count }

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let fullHeight = proxy.size.height - EditorLayout.topInset - EditorLayout.bottomInset
            // The card sits 12 over the glass bar and the picture area already ends 12 over it, so only
            // the card and the 14 under the picture come off the area.
            let calloutSpace = callout == nil ? 0 : calloutHeight + EditorLayout.pictureOverCallout
            ZStack(alignment: .top) {
                Theme.page.ignoresSafeArea()

                EditorPicture(area: CGSize(width: proxy.size.width, height: max(fullHeight - calloutSpace, 0)),
                              reviewVisibleHeight: SheetGeometry.shared.top - proxy.safeAreaInsets.top - EditorLayout.topInset,
                              isBlurred: isFinding)
                    .padding(.top, EditorLayout.topInset)
                    .padding(.bottom, EditorLayout.bottomInset)
                    // Pinned to the top: a centred frame would let the card cover the picture's bottom.
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: calloutSpace)

                GlassEffectContainer {
                    VStack(spacing: 0) {
                        EditorTopButtons()
                            .padding(.top, EditorLayout.topButtonsInset)
                        Spacer()
                        EditorGlassBar()
                            .padding(.horizontal, Metrics.pageInset)
                            .padding(.bottom, EditorLayout.barInset)
                    }
                }
                .disabled(isFinding)
                .opacity(isFinding ? Theme.disabledOpacity : 1)

                if let callout {
                    EditorCallout(kind: callout, draw: startDrawing, retry: model.retryRecognition)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { calloutHeight = $0 }
                        .padding(.horizontal, Metrics.pageInset)
                        .padding(.bottom, EditorLayout.barInset + EditorLayout.barHeight + EditorLayout.calloutOverBar)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .transition(reduceMotion ? .identity : .opacity)
                }

                if model.drawToolOn, !drawHintHidden {
                    PictureCapsule(text: "4.8.5")
                        .padding(.bottom, EditorLayout.barInset + EditorLayout.barHeight + EditorLayout.drawCapsuleOverBar)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .transition(.opacity)
                }

                if model.reviewShown {
                    ReviewScrim()
                        .onTapGesture { shell.hideReview() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(.easeInOut(duration: 0.2), value: model.drawToolOn && !drawHintHidden)
            .animation(.easeInOut(duration: 0.25), value: model.reviewShown)
            .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in touched() })
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: isFinding) { if isFinding { announce("4.2.1") } }
        .task(id: callout) {
            guard let callout else { return }
            if announcedCallout != callout {
                announcedCallout = callout
                announce(callout == .nothing ? "5.1.1" : "5.2.1")
            }
            scheduleCalloutDismissal()
        }
        .onChange(of: model.drawToolOn) { _, on in
            if on { drawHintHidden = false }
        }
        .onChange(of: manualBoxCount) { _, count in
            // The capsule 4.8.5 stays until the first box is drawn (§7.3.7).
            if model.drawToolOn, count > 0 { drawHintHidden = true }
        }
        .onDisappear { calloutTask?.cancel() }
    }

    // MARK: - Actions

    /// The card goes, the picture comes back and the drawing tool goes on (§7.3.4, §7.3.5).
    private func startDrawing() {
        calloutTask?.cancel()
        calloutDismissed = true
        model.drawToolOn = true
    }

    /// Any touch on the page keeps the failed callout up another 5 s (§8).
    private func touched() {
        guard callout == .failed else { return }
        scheduleCalloutDismissal()
    }

    private func scheduleCalloutDismissal() {
        calloutTask?.cancel()
        guard callout == .failed else { return }
        calloutTask = Task { @MainActor in
            try? await Task.sleep(for: EditorLayout.calloutIdle)
            guard !Task.isCancelled else { return }
            calloutDismissed = true
        }
    }

    private func announce(_ key: String) {
        AccessibilityNotification.Announcement(L10n.text(key)).post()
    }
}

/// The numbers of design.md §7.3 and §4. The picture area ends 62 under the top safe area (12 under
/// the top buttons, which are 6 down and 44 high) and 72 over the bottom safe area (12 over the
/// glass bar, 8 up and 52 high).
enum EditorLayout {
    static let topInset: CGFloat = 62
    static let bottomInset: CGFloat = 72
    static let topButtonsInset: CGFloat = 6
    static let barInset: CGFloat = 8
    static let barHeight: CGFloat = 52
    static let calloutOverBar: CGFloat = 12
    static let pictureOverCallout: CGFloat = 14
    static let drawCapsuleOverBar: CGFloat = 10
    /// §7.4.1: the sheet's edge is 300 under the top of the screen.
    static let sheetTop: CGFloat = 300
    /// §7.4.2–§7.4.3: the sheet's sides, where the summary, the description and the cards align.
    static let sheetInset: CGFloat = 32
    /// §8: the failed callout goes by itself after 5 s nobody touches the page.
    static let calloutIdle = Duration.seconds(5)
}

/// Where the sheet of Review Each Item is on the screen. §7.4.1 puts its edge 300 under the top,
/// but the system places a sheet of a given height a little higher on some versions, and the
/// sheet moves when it is pulled: the sheet measures its own top edge here, and the scrim and
/// the「locate」framing go by that. `extra` is what the system added on top of the requested
/// height (0 where it does not), taken off the next time the sheet comes up.
@Observable @MainActor
final class SheetGeometry {
    static let shared = SheetGeometry()

    /// The sheet's top edge on the screen, as last measured (the §7.4.1 value before any).
    var top: CGFloat = EditorLayout.sheetTop
    /// How much lower the sheet has to be asked for so that its edge comes to `EditorLayout.sheetTop`.
    var extra: CGFloat = 0
}

/// What is above the sheet of Review Each Item (§7.4.1): black at 32%, and a tap on it closes the
/// sheet. It covers the picture and the buttons, which are not to be reached while the sheet is up.
private struct ReviewScrim: View {
    var body: some View {
        GeometryReader { proxy in
            Color.black.opacity(0.32)
                .frame(height: SheetGeometry.shared.top)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .contentShape(Rectangle())
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
