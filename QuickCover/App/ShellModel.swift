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

/// Top-level app coordinator owned by `RootView` and shared via SwiftUI `@Environment`.
/// Follows Apple Photos' gallery-first rhythm: launching opens directly onto the full-bleed photo
/// library grid; selecting any photo pushes smoothly into the dark editing studio with tools.
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
        case .authorized, .limited, .denied, .restricted:
            showPicker()
        @unknown default:
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

    func wentToBackground() {
        leaveEditor()
    }

    private func leaveEditor() {
        editor?.resetTransientState()
    }
}
