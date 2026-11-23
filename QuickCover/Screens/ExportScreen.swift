import SwiftUI

/// 导出页（design.md §7.5，copy.md §6.1–§6.4）：「匯出」推过来，系统导航栏，标题 6.1.1、「‹ 編輯」。
/// 页面从上到下能滚：导出样子的图（`CoveredPicture`）、6.1.2、位置信息开关那一行（6.2.1，`EditorModel.setStripMetadata`）、
/// 6.2.4（模糊时没有）。上次留下的模糊时，卡片下面是 6.3.1 加小按钮 6.3.2「改用純色」，图最高 285。
/// 钉在底部的是主按钮 6.1.3 和并排的次按钮 6.1.4、6.1.5，上面一层 20 的渐变；存失败时按钮上面出 6.4.2 加 6.4.3；
/// 存好、拷贝好，导航栏下面出 toast（6.4.1 / 6.4.4），人还在这一页。
struct ExportScreen: View {
    @Environment(ShellModel.self) private var shell
    @Environment(EditorModel.self) private var model

    @State private var toastText: String?
    @State private var toastShown = false
    @State private var toastTask: Task<Void, Never>?
    @State private var saveFailed = false
    @State private var isSaving = false
    @State private var shareFile: ShareFile?

    private var facts: ExportFacts {
        ExportFacts(style: model.preferences.style,
                    stripMetadata: model.preferences.stripMetadata,
                    blurPickedThisTime: shell.stylePickedThisTime == .blur)
    }

    private var stripMetadata: Binding<Bool> {
        Binding(get: { model.preferences.stripMetadata }, set: { model.setStripMetadata($0) })
    }

    var body: some View {
        let facts = facts
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    CoveredPicture(editor: model,
                                   size: facts.pictureSize(aspect: Self.aspect(of: model.preview)))
                        .padding(.top, 12)
                    Text("6.1.2")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryLabel)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 10)
                        .padding(.bottom, 22)
                    ExportToggleRow(title: "6.2.1", footnote: facts.footnote, isOn: stripMetadata)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.card))
                        .padding(.horizontal, 16)
                    if facts.showsCoveredLine {
                        coveredLine
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 32)
                            .padding(.top, 10)
                    }
                    if facts.showsBlurNotice {
                        NoticeBar(systemImage: "exclamationmark.triangle", tint: Theme.blurNoticeIcon,
                                  ground: Theme.blurNotice, text: "6.3.1") {
                            SmallButton(title: "6.3.2") { model.setStyle(.solid) }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                    }
                }
                .padding(.bottom, 16)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
            if let toastText {
                // toast 本身不进读屏的顺序（design.md §9.4），念的那一句在 `showToast` 里发。
                Toast(text: LocalizedStringKey(toastText), isShown: toastShown)
                    .accessibilityHidden(true)
                    .padding(.top, 11)
            }
        }
        .background(Theme.page.ignoresSafeArea())
        .navigationTitle("6.1.1")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareFile) { ShareSheet(file: $0) }
        .onChange(of: saveFailed) { _, failed in
            if failed { AccessibilityNotification.Announcement(L10n.text("6.4.2")).post() }
        }
    }

    /// 6.2.4 那一行（design.md §7.5.1 第 4 条）：前面一个 15 pt 的 `checkmark`。
    private var coveredLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            Text("6.2.4")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryLabel)
        }
    }

    /// 钉在底部的按钮区（design.md §7.5.1 第 5 条）：上面 20 的渐变，再是左右 16、上 12、下 12 加离底部安全区 8。
    /// 存失败时主按钮上面 12 先出提醒条（§7.5.3）。
    private var bottomBar: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, Theme.page], startPoint: .top, endPoint: .bottom)
                .frame(height: 20)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            VStack(spacing: 12) {
                if saveFailed {
                    NoticeBar(systemImage: "exclamationmark.circle", tint: Theme.errorIcon,
                              ground: Theme.fillTwo, text: "6.4.2") {
                        TextButton(title: "6.4.3") { save() }
                    }
                }
                VStack(spacing: 10) {
                    PrimaryButton(title: "6.1.3") { save() }
                    HStack(spacing: 10) {
                        SecondaryButton(title: "6.1.4") { share() }
                        SecondaryButton(title: "6.1.5") { copy() }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(Theme.page.ignoresSafeArea(edges: .bottom))
    }

    // MARK: - Doing it

    /// 6.1.3「儲存到照片」：导出，存进图库。没存成就换成 6.4.2；存成了提醒收起，出 toast。存的时候不接第二下。
    private func save() {
        guard !isSaving else { return }
        isSaving = true
        Task { @MainActor in
            defer { isSaving = false }
            do {
                let data = try await model.exportData()
                try await ExportActions.saveToPhotos(data)
                saveFailed = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                showToast("6.4.1")
            } catch {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                saveFailed = true
            }
        }
    }

    /// 6.1.4「分享」：导出，交给系统的分享面板。
    private func share() {
        Task { @MainActor in
            if let data = try? await model.exportData() { shareFile = ShareFile(data: data) }
        }
    }

    /// 6.1.5「拷貝」：导出，原样放到剪贴板，出 toast。
    private func copy() {
        Task { @MainActor in
            if let data = try? await model.exportData() {
                ExportActions.copy(data, fileType: model.picture.fileType)
                showToast("6.4.4")
            }
        }
    }

    /// toast（design.md §7.5.4）：淡入、停 1.6 秒、淡出，淡完从页面上拿掉；读屏同时念一遍（§9.4）。
    private func showToast(_ text: String) {
        toastTask?.cancel()
        toastText = text
        toastShown = true
        AccessibilityNotification.Announcement(L10n.text(text)).post()
        toastTask = Task { @MainActor in
            try? await Task.sleep(for: ExportToastTiming.shows)
            guard !Task.isCancelled else { return }
            toastShown = false
            try? await Task.sleep(for: ExportToastTiming.clears)
            guard !Task.isCancelled else { return }
            toastText = nil
        }
    }

    private static func aspect(of image: CGImage) -> CGFloat {
        guard image.height > 0 else { return 1 }
        return CGFloat(image.width) / CGFloat(image.height)
    }
}
