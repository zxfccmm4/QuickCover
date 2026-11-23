import Foundation
import ImageIO
import Photos
import Testing

@testable import QuickCover

/// Where the app opens and how it gets around (design.md §5), without PhotoKit: the shell is given
/// the answers PhotoKit would give.
@MainActor
struct ShellModelTests {

    private func picture() throws -> PictureSource {
        try PictureSource(data: Sample.jpeg(Sample.text("13812345678", at: CGPoint(x: 20, y: 20))))
    }

    private func shell(status: PHAuthorizationStatus = .notDetermined,
                       granted: PhotosAccess = .full,
                       screenshot: PictureSource? = nil) -> ShellModel {
        ShellModel(authorization: { status }, requestAccess: { granted }, latestScreenshot: { screenshot })
    }

    @Test
    @MainActor
    func theFirstLaunchShowsThePrimerAndAsksNothing() async {
        let shell = shell()
        #expect(shell.page == nil, "black while the access is read")
        await shell.start()
        #expect(shell.page == .primer)
        #expect(shell.editor == nil)
        #expect(shell.path.isEmpty)
    }

    @Test
    @MainActor
    func fullAccessOpensStraightOnTheLatestScreenshot() async throws {
        let shell = shell(status: .authorized, screenshot: try picture())
        await shell.start()
        #expect(shell.page == .editor)
        #expect(shell.editor != nil)
        #expect(shell.path.isEmpty)
        #expect(shell.editor?.recognition == .running, "the picture is being looked at from the start")
        shell.editor?.cancelRecognition()
    }

    @Test
    @MainActor
    func fullAccessWithNoScreenshotToShowOpensOnThePicker() async {
        let shell = shell(status: .authorized, screenshot: nil)
        await shell.start()
        #expect(shell.page == .picker)
        #expect(shell.editor == nil)
    }

    @Test(arguments: [PHAuthorizationStatus.limited, .denied, .restricted])
    @MainActor
    func anythingShortOfFullAccessOpensOnThePicker(status: PHAuthorizationStatus) async throws {
        let shell = shell(status: status, screenshot: try picture())
        await shell.start()
        #expect(shell.page == .picker, "\(status)")
        #expect(shell.editor == nil, "the latest screenshot isn't even looked for")
    }

    @Test
    @MainActor
    func startHappensOnce() async throws {
        let shell = shell(status: .authorized, screenshot: try picture())
        await shell.start()
        #expect(shell.page == .editor)
        let editor = shell.editor
        await shell.start()
        #expect(shell.page == .editor)
        #expect(shell.editor === editor, "a second start doesn't reopen the picture")
        editor?.cancelRecognition()
    }

    @Test
    @MainActor
    func allowingEveryPhotoOpensTheLatestScreenshot() async throws {
        let shell = shell(granted: .full, screenshot: try picture())
        await shell.start()
        #expect(shell.page == .primer)
        await shell.allowAccess()
        #expect(shell.page == .editor)
        #expect(shell.path.isEmpty, "the primer is replaced, not covered")
        shell.editor?.cancelRecognition()
    }

    @Test(arguments: [PhotosAccess.limited, .denied])
    @MainActor
    func allowingSomePhotosOrNoneGoesToThePicker(granted: PhotosAccess) async throws {
        let shell = shell(granted: granted, screenshot: try picture())
        await shell.start()
        await shell.allowAccess()
        #expect(shell.page == .picker, "\(granted)")
        #expect(shell.editor == nil)
    }

    @Test
    @MainActor
    func thePlainTextButtonShowsThePicker() async {
        let shell = shell()
        await shell.start()
        shell.showPicker()
        #expect(shell.page == .picker)
        #expect(shell.path.isEmpty)
    }

    @Test
    @MainActor
    func chooseAnotherPushesThePickerOverTheEditor() async throws {
        let shell = shell()
        await shell.start()
        shell.open(try picture())
        shell.showPickerFromEditor()
        #expect(shell.page == .editor, "the editor stays under it")
        #expect(shell.path == [.picker])
        shell.editor?.cancelRecognition()
    }

    @Test
    @MainActor
    func exportIsPushedWithoutAsking() throws {
        let shell = shell()
        shell.open(try picture())
        shell.showExport()
        #expect(shell.path == [.export])
        #expect(shell.page == .editor)
        shell.editor?.cancelRecognition()
    }

    @Test
    @MainActor
    func reviewEachItemShowsAndHides() throws {
        let shell = shell()
        shell.open(try picture())
        let editor = shell.editor
        editor?.drawToolOn = true
        editor?.showsOriginal = true
        shell.showReview()
        #expect(editor?.reviewShown == true)
        #expect(editor?.drawToolOn == false, "opening Review Each Item leaves the drawing tool")
        #expect(editor?.showsOriginal == true, "holding to see the original is the same state (copy.md 7.3)")

        shell.hideReview()
        #expect(editor?.reviewShown == false)
        #expect(editor?.showsOriginal == false, "closing it also switches「看原圖」off (design.md §7.4.1)")
        #expect(shell.path.isEmpty, "it is a sheet, not a push")
        editor?.cancelRecognition()
    }

    @Test
    @MainActor
    func aNewPictureStartsTheEditorOver() throws {
        let shell = shell()
        shell.open(try picture())
        let first = shell.editor
        first?.showsOriginal = true
        first?.drawToolOn = true
        shell.showPickerFromEditor()

        shell.open(try picture())
        #expect(shell.editor !== first, "each picture gets its own editor")
        #expect(shell.page == .editor)
        #expect(shell.path.isEmpty, "anything pushed goes away")
        #expect(shell.editor?.showsOriginal == false)
        #expect(shell.editor?.drawToolOn == false)
        #expect(shell.editor?.items.isEmpty == true)
        #expect(shell.editor?.recognition == .running)
        shell.editor?.cancelRecognition()
        first?.cancelRecognition()
    }

    @Test
    @MainActor
    func leavingTheEditorOrTheAppTurnsOffWhatWasOnlyOnForTheMoment() throws {
        let shell = shell()
        shell.open(try picture())
        let editor = shell.editor
        editor?.showsOriginal = true
        editor?.drawToolOn = true

        shell.showExport()
        #expect(editor?.showsOriginal == false)
        #expect(editor?.drawToolOn == false, "going to the export page leaves the drawing tool (design.md §7.3.7)")

        editor?.showsOriginal = true
        shell.wentToBackground()
        #expect(editor?.showsOriginal == false, "going to the background switches「看原圖」off (copy.md 7.3)")
        editor?.cancelRecognition()
    }

    @Test
    @MainActor
    func theRoutesAreWhatTheNavigationStackPushes() {
        #expect(Route.picker != Route.export)
        #expect([Route.picker, Route.export].count == 2)
    }
}
