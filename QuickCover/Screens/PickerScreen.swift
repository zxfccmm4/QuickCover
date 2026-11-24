import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// 选图页（design.md §7.1，copy.md §3.1）：没有完整取用权限时的根页，「換一張」也会把它推到编辑页上面。
/// 大标题 3.1.1，说明 3.1.2，一张四行的卡片，顺序固定（選螢幕快照 3.1.9、選照片 3.1.3、選檔案 3.1.4、
/// 貼上圖片 3.1.5）；剪贴板里没有图时最后一行变灰，卡片下面出 3.1.6。选到的东西交给 `ShellModel.open(_:)`；
/// 打不开时弹系统的 3.1.7 / 3.1.8。放得下时页面不滚动；到辅助功能档放不下了才滚。
struct PickerScreen: View {
    @Environment(ShellModel.self) private var shell
    @Environment(\.scenePhase) private var scenePhase

    @State private var showsFileImporter = false
    @State private var showsBadFileAlert = false
    @State private var hasClipboardImage = false
    @State private var isOpening = false

    var body: some View {
        // 规格说页面不滚动（design.md §7.1.1）：放得下时它确实不滚（`.basedOnSize`，连回弹都没有）；
        // 字大到放不下（辅助功能档、小屏）时才滚，不然最后两行点不到。
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                Text("3.1.2")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryLabel)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                card
                if !hasClipboardImage {
                    Text("3.1.6")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryLabel)
                        .padding(.horizontal, 32)
                        .padding(.top, 10)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.page.ignoresSafeArea())
        .navigationTitle("3.1.1")
        .navigationBarTitleDisplayMode(.large)
        .fileImporter(isPresented: $showsFileImporter, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                open { await Task.detached(priority: .userInitiated) { Intake.picture(at: url) }.value }
            }
        }
        .alert("3.1.7", isPresented: $showsBadFileAlert) {
            Button("3.1.8") {}
        }
        .task { refreshClipboard() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshClipboard() }
        }
    }

    /// 四行一张卡（design.md §7.1.1）：第一行的图标块是 `#0B7A7A`（`Theme.accentButton`）加白，其余是填充色底加主题色图标。
    private var card: some View {
        VStack(spacing: 0) {
            LibraryRow(systemImage: "camera.viewfinder", title: "3.1.9", ground: Theme.accentButton, tint: .white,
                        screenshotsOnly: true) { picked($0) }
            separator
            LibraryRow(systemImage: "photo", title: "3.1.3", screenshotsOnly: false) { picked($0) }
            separator
            PickerRow(systemImage: "folder", title: "3.1.4") { showsFileImporter = true }
            separator
            PickerRow(systemImage: "clipboard", title: "3.1.5", isEnabled: hasClipboardImage) {
                open { Intake.pictureFromPasteboard() }
            }
        }
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.card))
        .padding(.horizontal, 16)
    }

    private var separator: some View {
        Rectangle()
            .fill(Theme.separator)
            .frame(height: 0.5)
            .padding(.leading, 16)
            .accessibilityHidden(true)
    }

    /// 进这一页、回到前台时看一眼剪贴板。
    private func refreshClipboard() {
        hasClipboardImage = PasteboardImage.isPresent
    }

    /// 系统选图面板选到的那张。
    private func picked(_ item: PhotosPickerItem) {
        open { await Intake.picture(from: item) }
    }

    /// 试着把选到的东西当图打开：打得开就进编辑页，打不开就弹 3.1.7。选图的面板收起来之前不弹，
    /// 不然系统的面板会把它吞掉。
    private func open(_ candidate: @escaping @MainActor () async -> PictureSource?) {
        guard !isOpening else { return }
        isOpening = true
        Task { @MainActor in
            defer { isOpening = false }
            if let picture = await candidate() {
                shell.open(picture)
            } else {
                try? await Task.sleep(for: .seconds(0.6))
                showsBadFileAlert = true
            }
        }
    }
}

/// 选图页里走系统照片面板的那两行。面板挂在各自的行上：两行共用一个面板时，第二行拉不起来。
private struct LibraryRow: View {
    let systemImage: String
    let title: LocalizedStringKey
    var ground: Color = Theme.fill
    var tint: Color = Theme.accent
    /// 只列截图（design.md §7.1.1 第 1 行），还是列全部（第 2 行）。
    let screenshotsOnly: Bool
    let onPick: (PhotosPickerItem) -> Void

    @State private var item: PhotosPickerItem?
    @State private var isShown = false

    var body: some View {
        PickerRow(systemImage: systemImage, title: title, ground: ground, tint: tint) { isShown = true }
            .photosPicker(isPresented: $isShown, selection: $item, matching: screenshotsOnly ? .screenshots : nil)
            .onChange(of: item) { _, picked in
                guard let picked else { return }
                item = nil
                onPick(picked)
            }
    }
}
