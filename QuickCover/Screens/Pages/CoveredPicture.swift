import SwiftUI

/// Live preview of the flattened export output (including all 6 mask styles, colors, granularity,
/// anti-theft diagonal watermark, and optional Apple hardware device frame) inside an iOS 26
/// concentric rounded container. Supports press-and-hold to compare with the unmasked original.
struct CoveredPicture: View {
    let editor: EditorModel
    let size: CGSize
    var onRendered: ((CGImage) -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @State private var image: CGImage?
    @State private var showsOriginal = false
    @State private var holdFeedbackCount = 0

    private var showsTransparentCheckerboard: Bool {
        editor.deviceFrame.needsPNG && !showsOriginal
    }

    var body: some View {
        let shape = ConcentricRectangle(corners: .concentric(minimum: 16), isUniform: true)
        ZStack(alignment: .top) {
            if showsTransparentCheckerboard {
                TransparentCheckerboard()
                    .frame(width: size.width, height: size.height)
            }

            Image(decorative: (showsOriginal ? editor.preview : (image ?? editor.preview)), scale: 1)
                .resizable()
                .scaledToFit()
                .frame(width: size.width, height: size.height)

            if showsOriginal {
                Text("4.8.6")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !showsOriginal {
                Image(systemName: "eye")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.black.opacity(0.42), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.5))
                    .padding(8)
                    .accessibilityHidden(true)
                    .transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .overlay(
            shape.stroke(
                colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08),
                lineWidth: 0.5
            )
        )
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0.35 : 0.14),
            radius: 20,
            y: 8
        )
        .contentShape(.rect)
        .onLongPressGesture(minimumDuration: 0.18, maximumDistance: 24, perform: {}, onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.14)) {
                showsOriginal = pressing
            }
            if pressing {
                holdFeedbackCount += 1
            }
        })
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: holdFeedbackCount)
        .animation(.easeInOut(duration: 0.2), value: image != nil)
        .animation(.snappy(duration: 0.22), value: editor.deviceFrame)
        .animation(.snappy(duration: 0.24), value: editor.exportAspectRatio)
        .task(id: key) { await render() }
    }

    private var key: RenderKey {
        RenderKey(
            editor: ObjectIdentifier(editor),
            items: editor.enabledItems.map(\.id),
            appearance: editor.maskAppearance,
            deviceFrame: editor.deviceFrame,
            exportAspectRatio: editor.exportAspectRatio,
            exportAspectFit: editor.exportAspectFit,
            exportAspectBackdrop: editor.exportAspectBackdrop
        )
    }

    @MainActor
    private func render() async {
        let preview = editor.preview
        let toPreview = CGSize(width: 1 / editor.previewScale.width, height: 1 / editor.previewScale.height)
        let findings = editor.enabledItems.flatMap(\.findings).map { $0.scaled(by: toPreview) }
        let appearance = editor.maskAppearance
        let deviceFrame = editor.deviceFrame
        let exportAspectRatio = editor.exportAspectRatio
        let exportAspectFit = editor.exportAspectFit
        let exportAspectBackdrop = editor.exportAspectBackdrop
        let cut = MaskRenderer.onShrunkPicture(shrink: editor.previewScale)
        let rendered = await Task.detached(priority: .userInitiated) {
            MaskRenderer.flatten(
                preview,
                findings: findings,
                appearance: appearance,
                blurGrain: cut.blurGrain,
                floor: cut.floor,
                deviceFrame: deviceFrame,
                exportAspectRatio: exportAspectRatio,
                exportAspectFit: exportAspectFit,
                exportAspectBackdrop: exportAspectBackdrop
            )
        }.value
        if !Task.isCancelled {
            image = rendered
            onRendered?(rendered)
        }
    }
}

private struct TransparentCheckerboard: View {
    var body: some View {
        Canvas { ctx, size in
            let cell: CGFloat = 10
            let rows = Int(ceil(size.height / cell))
            let cols = Int(ceil(size.width / cell))
            let light = Color(white: 0.90)
            let dark = Color(white: 0.80)
            for r in 0..<rows {
                for c in 0..<cols {
                    let rect = CGRect(x: CGFloat(c) * cell, y: CGFloat(r) * cell, width: cell, height: cell)
                    ctx.fill(Path(rect), with: .color((r + c).isMultiple(of: 2) ? light : dark))
                }
            }
        }
    }
}

private struct RenderKey: Equatable {
    let editor: ObjectIdentifier
    let items: [Int]
    let appearance: MaskAppearance
    let deviceFrame: DeviceFrameOptions
    let exportAspectRatio: ExportAspectRatio
    let exportAspectFit: ExportAspectFitMode
    let exportAspectBackdrop: ExportAspectBackdrop
}
