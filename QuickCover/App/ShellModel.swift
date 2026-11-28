import Observation
import Photos
import SwiftUI

/// Destinations pushed onto the root `NavigationStack`.
enum Route: Hashable, Sendable {
    /// Photo Library gallery pushed from a standalone editor.
    case picker
    /// Dark-studio photo editor pushed when selecting a photo from the Library grid.
    case editor
    /// Export & share preview page.
    case export
}

/// Root screen before any push: onboarding primer, Apple Photos-style Library grid, or standalone editor.
enum RootPage: Equatable, Sendable {
    case primer
    case picker
    case editor
}

/// Top-level native iOS 26 `TabView` sections when unlocked past the onboarding primer.
enum AppTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case library
    case stitch
    case about

    var id: String { rawValue }
}

/// One-shot handoff payload carrying assets from Library multi-select (or Screen Recording action)
/// straight into the dedicated Long Screenshot tab.
struct PendingStitchRequest: Identifiable {
    let id = UUID()
    let mode: LongScreenshotStudioView.Mode
    let assets: [PHAsset]
    let assetIDs: [String]
}

/// Top-level app coordinator owned by `RootView` and shared via SwiftUI `@Environment`.
/// Follows Apple Photos' gallery-first rhythm: launching opens directly onto the full-bleed photo
/// library grid with a native 3-tab shell (`Library`, `Stitch`, `About`).
@MainActor
@Observable
final class ShellModel {

    /// Nil until the photo authorization status is read on launch.
    private(set) var page: RootPage?
    /// Active top-level tab in the native `TabView` shell.
    var selectedTab: AppTab = .library
    /// NavigationStack path for the active tab.
    var path: [Route] = []
    /// Queued long-screenshot request sent from Library selection into Tab 2 (`Stitch`).
    var pendingStitchRequest: PendingStitchRequest?
    /// Style explicitly chosen by the user for the currently opened image (nil until changed).
    private(set) var stylePickedThisTime: MaskStyle?
    /// Active editor session; recreated fresh for each opened picture.
    private(set) var editor: EditorModel?
    /// Active What's New sheet presentation (auto on version upgrade or manual replay from About).
    var whatsNewPresentation: WhatsNewPresentation?

    @ObservationIgnored let whatsNewStore: WhatsNewStore
    @ObservationIgnored private let authorization: () -> PHAuthorizationStatus
    @ObservationIgnored private let requestAccess: () async -> PhotosAccess
    @ObservationIgnored private let latestScreenshot: () async -> PictureSource?
    @ObservationIgnored private let whatsNewPostPrimerDelay: Duration
    @ObservationIgnored private let whatsNewLaunchDelay: Duration
    @ObservationIgnored private var cameFromPrimer = false
    @ObservationIgnored private var hasAttemptedAutoWhatsNew = false
    @ObservationIgnored private var pendingWhatsNewTask: Task<Void, Never>?

    init(
        authorization: @escaping () -> PHAuthorizationStatus = { PHPhotoLibrary.authorizationStatus(for: .readWrite) },
        requestAccess: @escaping () async -> PhotosAccess = { await Intake.photosAccess() },
        latestScreenshot: @escaping () async -> PictureSource? = { await Intake.latestScreenshot() },
        whatsNewStore: WhatsNewStore = WhatsNewStore(),
        whatsNewPostPrimerDelay: Duration = .milliseconds(420),
        whatsNewLaunchDelay: Duration = .milliseconds(180)
    ) {
        self.authorization = authorization
        self.requestAccess = requestAccess
        self.latestScreenshot = latestScreenshot
        self.whatsNewStore = whatsNewStore
        self.whatsNewPostPrimerDelay = whatsNewPostPrimerDelay
        self.whatsNewLaunchDelay = whatsNewLaunchDelay
    }

    // MARK: - Launch

    func start() async {
        guard page == nil else { return }
        switch authorization() {
        case .notDetermined:
            cameFromPrimer = true
            page = .primer
        case .authorized, .limited, .denied, .restricted:
            cameFromPrimer = false
            showPicker()
        @unknown default:
            cameFromPrimer = false
            showPicker()
        }
    }

    func allowAccess() async {
        _ = await requestAccess()
        showPicker()
    }

    func showPicker() {
        leaveEditor()
        path = []
        page = .picker
        scheduleAutoWhatsNewIfNeeded(afterPrimer: cameFromPrimer)
    }

    // MARK: - Navigation

    func showPickerFromEditor() {
        leaveEditor()
        if page == .picker {
            path = []
        } else {
            path.append(.picker)
        }
    }

    func showExport() {
        leaveEditor()
        path.append(.export)
    }

    func showReview() {
        editor?.drawToolOn = false
        editor?.styleTrayShown = false
        editor?.watermarkShown = false
        editor?.emojiPickerShown = false
        editor?.selectedManualID = nil
        editor?.reviewShown = true
    }

    func hideReview() {
        editor?.reviewShown = false
        editor?.showsOriginal = false
    }

    func open(_ picture: PictureSource) {
        pendingWhatsNewTask?.cancel()
        editor?.onStyleChanged = nil
        let model = EditorModel(picture: picture)
        stylePickedThisTime = nil
        model.onStyleChanged = { [weak self, weak model] style in
            guard let self, let model, self.editor === model else { return }
            self.stylePickedThisTime = style
        }
        editor = model

        if page == .picker || page == .primer {
            page = .picker
            path = [.editor]
        } else {
            path = []
            page = .editor
        }
        model.startRecognition()
    }

    /// Opens a stitched long screenshot straight onto `ExportScreen` for immediate device framing,
    /// watermarking, and sharing while keeping `EditorScreen` one back-swipe away if redaction is desired.
    func openForExport(_ picture: PictureSource) {
        pendingWhatsNewTask?.cancel()
        editor?.onStyleChanged = nil
        let model = EditorModel(picture: picture)
        stylePickedThisTime = nil
        model.onStyleChanged = { [weak self, weak model] style in
            guard let self, let model, self.editor === model else { return }
            self.stylePickedThisTime = style
        }
        editor = model
        model.markReadyWithoutRecognition()

        if page == .picker || page == .primer {
            page = .picker
            path = [.editor, .export]
        } else {
            page = .editor
            path = [.export]
        }
    }

    // MARK: - What's New

    /// Manually opens What's New (e.g. from About or macOS app menu), displaying a close button on mobile.
    func presentWhatsNewManually() {
        pendingWhatsNewTask?.cancel()
        hasAttemptedAutoWhatsNew = true
        whatsNewPresentation = whatsNewStore.makePresentation(mode: .manual)
    }

    /// Handles incoming URLs, supporting debug query parameters (e.g. `?forceWhatsNew=1`) to force preview.
    func handleOpenURL(_ url: URL) {
        guard whatsNewStore.isForcePreviewURL(url) else { return }
        presentWhatsNewManually()
    }

    /// Records the current version as seen on this device and dismisses the sheet.
    func dismissWhatsNew() {
        pendingWhatsNewTask?.cancel()
        whatsNewStore.markCurrentVersionSeen()
        whatsNewPresentation = nil
    }

    private func scheduleAutoWhatsNewIfNeeded(afterPrimer: Bool) {
        guard !hasAttemptedAutoWhatsNew,
              page == .picker,
              path.isEmpty,
              whatsNewPresentation == nil,
              whatsNewStore.shouldAutoPresent else {
            return
        }

        pendingWhatsNewTask?.cancel()
        let delay = afterPrimer ? whatsNewPostPrimerDelay : whatsNewLaunchDelay
        pendingWhatsNewTask = Task { @MainActor [weak self] in
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            guard let self,
                  !Task.isCancelled,
                  !self.hasAttemptedAutoWhatsNew,
                  self.page == .picker,
                  self.path.isEmpty,
                  self.whatsNewPresentation == nil,
                  self.whatsNewStore.shouldAutoPresent else {
                return
            }
            self.hasAttemptedAutoWhatsNew = true
            self.cameFromPrimer = false
            self.whatsNewPresentation = self.whatsNewStore.makePresentation(mode: .automatic)
        }
    }

    /// Switches directly to the dedicated Long Screenshot studio tab with optional preselected assets or mode.
    func openStitchTab(
        mode: LongScreenshotStudioView.Mode = .multiImage,
        assets: [PHAsset] = [],
        assetIDs: [String] = []
    ) {
        if !assets.isEmpty || !assetIDs.isEmpty || mode == .screenRecording {
            pendingStitchRequest = PendingStitchRequest(mode: mode, assets: assets, assetIDs: assetIDs)
        }
        selectedTab = .stitch
    }

    func wentToBackground() {
        leaveEditor()
    }

    private func leaveEditor() {
        editor?.resetTransientState()
    }
}
