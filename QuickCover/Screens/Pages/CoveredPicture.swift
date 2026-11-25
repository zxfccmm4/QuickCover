import SwiftUI

/// 导出页上的那张图（design.md §7.5）：按导出的样子画出来，也就是 `MaskRenderer` 盖上开着的遮盖。
/// 开着的遮盖变了、换样式了，就重画一次。大小由页面先按原图比例定好，画完不会跳。
struct CoveredPicture: View {
    let editor: EditorModel
    let size: CGSize
    @State private var image: CGImage?

    var body: some View {
        ZStack {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 22, y: 6)
        .task(id: key) { await render() }
    }

    /// 重画的依据：哪一张、哪些遮盖开着、什么样式。
    private var key: RenderKey {
        RenderKey(editor: ObjectIdentifier(editor), items: editor.enabledItems.map(\.id), style: editor.preferences.style)
    }

    @MainActor
    private func render() async {
        let preview = editor.preview
        // 遮盖的坐标是整尺寸的像素，预览图比它小 `previewScale` 倍。
        let toPreview = CGSize(width: 1 / editor.previewScale.width, height: 1 / editor.previewScale.height)
        let findings = editor.enabledItems.flatMap(\.findings).map { $0.scaled(by: toPreview) }
        let style = editor.preferences.style
        // 按像素算的数（格子的下限）也跟着缩小，小框在页面上不会比文件里切得粗。
        let cut = MaskRenderer.onShrunkPicture(shrink: editor.previewScale)
        let rendered = await Task.detached(priority: .userInitiated) {
            MaskRenderer.flatten(preview, findings: findings, style: style,
                                 blurGrain: cut.blurGrain, floor: cut.floor)
        }.value
        if !Task.isCancelled { image = rendered }
    }
}

private struct RenderKey: Equatable {
    let editor: ObjectIdentifier
    let items: [Int]
    let style: MaskStyle
}
