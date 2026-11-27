import Observation
import Photos
import SwiftUI

/// Destinations pushed onto the root `NavigationStack`.
enum Route: Hashable, Sendable {
    /// Picker pushed from the editor via「換一張」.
    case picker
    /// Export & share preview page.
    case export
}

/// Root screen before any push: onboarding primer, picker without full photo access, or editor.
enum RootPage: Equatable, Sendable {
    case primer
    case picker
    case editor
}

/// Top-level app coordinator owned by `RootView` and shared via SwiftUI `@Environment`.
@MainActor
@Observable
final class ShellModel {

    /// Nil until the photo authorization status is read on launch.
    private(set) var page: RootPage?
    /// NavigationStack path.
    var path: [Route] = []
    /// Style explicitly chosen by the user for the currently opened image (nil until changed).
    private(set) var stylePickedThisTime: MaskStyle?
    /// Active editor session; recreated fresh for each opened picture.
    private(set) var editor: EditorModel?

    @ObservationIgnored private let authorization: () -> PHAuthorizationStatus
    @ObservationIgnored private let requestAccess: () async -> PhotosAccess
    @ObservationIgnored private let latestScreenshot: () async -> PictureSource?

    init(
        authorization: @escaping () -> PHAuthorizationStatus = { PHPhotoLibrary.authorizationStatus(for: .readWrite) },
        requestAccess: @escaping () async -> PhotosAccess = { await Intake.photosAccess() },
        latestScreenshot: @escaping () async -> PictureSource? = { await Intake.latestScreenshot() }
    ) {
        self.authorization = authorization
        self.requestAccess = requestAccess
        self.latestScreenshot = latestScreenshot
    }

    // MARK: - Launch

    func start() async {
        guard page == nil else { return }
        switch authorization() {
        case .notDetermined:
            page = .primer
        case .authorized:
            await openLatestScreenshot()
        case .limited, .denied, .restricted:
            showPicker()
        @unknown default:
            showPicker()
        }
    }

    func allowAccess() async {
        if await requestAccess() == .full {
            await openLatestScreenshot()
        } else {
            showPicker()
        }
    }

    func showPicker() {
        path = []
        page = .picker
    }

    // MARK: - Navigation from Editor

    func showPickerFromEditor() {
        leaveEditor()
        path.append(.picker)
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
        editor?.onStyleChanged = nil
        let model = EditorModel(picture: picture)
        stylePickedThisTime = nil
        model.onStyleChanged = { [weak self, weak model] style in
            guard let self, let model, self.editor === model else { return }
            self.stylePickedThisTime = style
        }
        editor = model
        path = []
        page = .editor
        model.startRecognition()
    }

    func wentToBackground() {
        leaveEditor()
    }

    private func leaveEditor() {
        editor?.resetTransientState()
    }

    private func openLatestScreenshot() async {
        if let screenshot = await latestScreenshot() {
            open(screenshot)
        } else {
            showPicker()
        }
    }
}
