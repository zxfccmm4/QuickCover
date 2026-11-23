import SwiftUI

/// 引导页（design.md §7.2，copy.md §3.2）：还没允许取用照片时的第一页。图标作品（§10.2），居中的粗标题
/// 3.2.1，正文 3.2.2，小字 3.2.6；钉在下面的是主按钮 3.2.3「允許取用照片」(`ShellModel.allowAccess()`)
/// 和纯文字按钮 3.2.4「先選一張圖」(`ShellModel.showPicker()`)。导航栏是空的。
struct PrimerScreen: View {
    @Environment(ShellModel.self) private var shell

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    icon
                        .padding(.bottom, 26)
                    Text("3.2.1")
                        .font(.title2.bold())
                        .foregroundStyle(Theme.body)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 10)
                    Text("3.2.2")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryLabel)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 12)
                    Text("3.2.6")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryLabel)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .padding(.top, 28)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            VStack(spacing: 2) {
                PrimaryButton(title: "3.2.3") { Task { await shell.allowAccess() } }
                PlainTextButton(title: "3.2.4") { shell.showPicker() }
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .background(Theme.page.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 那张画（design.md §10.2）：就是 App 图标，132，自己裁 29.5 的圆角，沿边 1 pt 白 14%，不投影。
    private var icon: some View {
        let shape = RoundedRectangle(cornerRadius: 29.5, style: .continuous)
        return Image("IconArtwork")
            .resizable()
            .frame(width: 132, height: 132)
            .clipShape(shape)
            .overlay(shape.strokeBorder(.white.opacity(0.14), lineWidth: 1))
            .accessibilityHidden(true)
    }
}
