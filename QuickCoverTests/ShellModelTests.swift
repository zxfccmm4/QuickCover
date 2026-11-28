import Foundation
import ImageIO
import Photos
import Testing

@testable import QuickCover

/// Where the app opens and how it navigates in the Apple Photos gallery-first architecture,
/// without hitting PhotoKit directly.
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
        #expect(shell.page == nil, "waiting while photo authorization is read")
        await shell.start()
        #expect(shell.page == .primer)
        #expect(shell.editor == nil)
        #expect(shell.path.isEmpty)
    }

    @Test(arguments: [PHAuthorizationStatus.authorized, .limited, .denied, .restricted])
    @MainActor
    func determinedAccessOpensDirectlyOnThePhotoLibrary(status: PHAuthorizationStatus) async throws {
        let shell = shell(status: status, screenshot: try picture())
        await shell.start()
        #expect(shell.page == .picker, "\(status) launches onto the Apple Photos library grid")
        #expect(shell.editor == nil)
        #expect(shell.path.isEmpty)
    }

    @Test
    @MainActor
    func startHappensOnce() async throws {
        let shell = shell(status: .authorized, screenshot: try picture())
        await shell.start()
        #expect(shell.page == .picker)
        shell.open(try picture())
        let editor = shell.editor
        await shell.start()
        #expect(shell.editor === editor, "a second start does not reset the active session")
        editor?.cancelRecognition()
    }

    @Test(arguments: [PhotosAccess.full, .limited, .denied])
    @MainActor
    func completingPrimerOpensThePhotoLibrary(granted: PhotosAccess) async throws {
        let shell = shell(granted: granted, screenshot: try picture())
        await shell.start()
        #expect(shell.page == .primer)
        await shell.allowAccess()
        #expect(shell.page == .picker, "\(granted)")
        #expect(shell.path.isEmpty)
        #expect(shell.editor == nil)
    }

    @Test
    @MainActor
    func tappingAPhotoFromTheLibraryPushesTheEditorAndCanReturnBack() async throws {
        let shell = shell(status: .authorized)
        await shell.start()
        #expect(shell.page == .picker)

        shell.open(try picture())
        #expect(shell.page == .picker, "library stays at root underneath the pushed editor")
        #expect(shell.path == [.editor])
        #expect(shell.editor != nil)
        #expect(shell.editor?.recognition == .running)

        shell.showPickerFromEditor()
        #expect(shell.page == .picker)
        #expect(shell.path.isEmpty, "returning pops straight back to the photo library grid")
        shell.editor?.cancelRecognition()
    }

    /// 这次自己选的样式（design.md §7.5.2）：换了样式记下来；只拨位置开关不算；换一张图从头算。
    @Test
    @MainActor
    func theStylePickedForAPictureIsRemembered() async throws {
        UserDefaults.standard.removeObject(forKey: EditorModel.Preferences.styleKey)
        defer { UserDefaults.standard.removeObject(forKey: EditorModel.Preferences.styleKey) }
        let shell = shell()
        shell.open(try picture())
        let editor = try #require(shell.editor)
        defer { editor.cancelRecognition() }
        #expect(shell.stylePickedThisTime == nil, "刚打开，还没有自己选过")

        editor.setStyle(.blur)
        try await Task.sleep(for: .milliseconds(100))
        #expect(shell.stylePickedThisTime == .blur)

        editor.setStripMetadata(!editor.preferences.stripMetadata)
        try await Task.sleep(for: .milliseconds(100))
        #expect(shell.stylePickedThisTime == .blur, "偏好设置变了但样式没变，不算选过")
        editor.setStripMetadata(!editor.preferences.stripMetadata)

        editor.setStyle(.solid)
        try await Task.sleep(for: .milliseconds(100))
        #expect(shell.stylePickedThisTime == .solid, "以最后一次为准")

        shell.open(try picture())
        #expect(shell.stylePickedThisTime == nil, "新的一张从头算")
        editor.setStyle(.blur)
        try await Task.sleep(for: .milliseconds(100))
        #expect(shell.stylePickedThisTime == nil, "旧编辑页再变，不算到新的一张上")
        shell.editor?.setStyle(.default)
        shell.editor?.cancelRecognition()
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
    func exportIsPushedOverTheEditor() async throws {
        let shell = shell(status: .authorized)
        await shell.start()
        shell.open(try picture())
        shell.showExport()
        #expect(shell.path == [.editor, .export])
        #expect(shell.page == .picker)
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
    func aNewPictureStartsTheEditorOver() async throws {
        let shell = shell(status: .authorized)
        await shell.start()
        shell.open(try picture())
        let first = shell.editor
        first?.showsOriginal = true
        first?.drawToolOn = true
        shell.showPickerFromEditor()

        shell.open(try picture())
        #expect(shell.editor !== first, "each picture gets its own editor")
        #expect(shell.page == .picker)
        #expect(shell.path == [.editor])
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
        #expect(Route.picker != Route.editor)
        #expect(Route.editor != Route.export)
        #expect([Route.picker, Route.editor, Route.export].count == 3)
    }

    @Test
    @MainActor
    func stitchTabSwitchAndPendingRequestHandoff() async throws {
        let shell = shell(status: .authorized)
        await shell.start()
        #expect(shell.selectedTab == .library)
        #expect(shell.pendingStitchRequest == nil)

        shell.openStitchTab(mode: .multiImage, assets: [], assetIDs: ["a1", "a2"])
        #expect(shell.selectedTab == .stitch)
        #expect(shell.pendingStitchRequest?.assetIDs == ["a1", "a2"])
        #expect(shell.pendingStitchRequest?.mode == .multiImage)

        shell.openForExport(try picture())
        #expect(shell.path == [.editor, .export])
        shell.editor?.cancelRecognition()
    }
}
