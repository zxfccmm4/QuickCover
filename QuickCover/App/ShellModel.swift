import Observation
import Photos
import SwiftUI

/// Where the editor's `NavigationStack` pushes to (design.md §5).
enum Route: Hashable, Sendable {
    /// The picker, pushed by「換一張」; the editor stays under it.
    case picker
    /// The export page.
    case export
}

/// Which page is the root (design.md §5): the primer while photos haven't been allowed yet, the
/// picker without full access, the editor with it.
enum RootPage: Equatable, Sendable {
    case primer
    case picker
    case editor
}

/// The app's one path (design.md §5): which page is the root, what the navigation stack holds, the
/// editor and its picture, and the sheet of Review Each Item. `RootView` owns it and puts it in
/// the environment; screens reach it with `@Environment(ShellModel.self)`.
@MainActor
@Observable
final class ShellModel {

    /// Nil until the photo access has been read; the screen is black for that moment.
    private(set) var page: RootPage?
    /// The pages on the navigation stack (design.md §5). Bound to the stack's path, which is
    /// why anyone may write it; a later screen pushes here.
    var path: [Route] = []
    /// The picture being worked on; nil until one is opened. Each new picture is a new model, so
    /// the editor starts from design.md §7.3.1 every time.
    private(set) var editor: EditorModel?

    @ObservationIgnored private let authorization: () -> PHAuthorizationStatus
    @ObservationIgnored private let requestAccess: () async -> PhotosAccess
    @ObservationIgnored private let latestScreenshot: () async -> PictureSource?

    init(authorization: @escaping () -> PHAuthorizationStatus = { PHPhotoLibrary.authorizationStatus(for: .readWrite) },
         requestAccess: @escaping () async -> PhotosAccess = { await Intake.photosAccess() },
         latestScreenshot: @escaping () async -> PictureSource? = { await Intake.latestScreenshot() }) {
        self.authorization = authorization
        self.requestAccess = requestAccess
        self.latestScreenshot = latestScreenshot
    }

    // MARK: Where the app opens

    /// At launch (design.md §5, copy.md §3.2). Reads the photo access without asking: the primer
    /// comes first and the system prompt only after「允許取用照片」. With full access the app opens
    /// straight on the latest screenshot; with limited access, without it, or when the latest
    /// screenshot can't be read, on the picker.
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

    /// 「允許取用照片」(3.2.3): the system prompt. All the photos allowed opens the latest screenshot;
    /// anything else goes to the picker, and nothing is asked again afterwards (copy.md §3.2).
    func allowAccess() async {
        if await requestAccess() == .full {
            await openLatestScreenshot()
        } else {
            showPicker()
        }
    }

    /// 「先選一張圖」(3.2.4), and where everything but full access lands.
    func showPicker() {
        path = []
        page = .picker
    }

    // MARK: Getting around from the editor

    /// 「換一張」(3.1.8): the picker is pushed and the editor stays under it (design.md §5).
    func showPickerFromEditor() {
        leaveEditor()
        path.append(.picker)
    }

    /// 「匯出」(4.9.1): the export page is pushed, nothing asks first (design.md §5).
    func showExport() {
        leaveEditor()
        path.append(.export)
    }

    /// 「逐項檢查」(4.4.1): the sheet comes up; the drawing tool goes off first (design.md §7.3.7).
    func showReview() {
        editor?.drawToolOn = false
        editor?.reviewShown = true
    }

    /// The sheet closes (swiped away or by tapping the picture):「看原圖」goes off with it
    /// (design.md §7.4.1).
    func hideReview() {
        editor?.reviewShown = false
        editor?.showsOriginal = false
    }

    /// A picture was picked, chosen or pasted: the editor starts on it from the beginning
    /// (design.md §7.1.1, §7.3.1).
    func open(_ picture: PictureSource) {
        let model = EditorModel(picture: picture)
        editor = model
        path = []
        page = .editor
        model.startRecognition()
    }

    /// The app went to the background:「看原圖」, the drawing tool and Review Each Item go off
    /// (copy.md 7.3, design.md §7.3.7).
    func wentToBackground() {
        leaveEditor()
    }

    /// Leaving the editor the way design.md §7.3.7 lists: everything that was only on for the
    /// moment goes off.
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
