import SwiftUI

/// Live preview of the flattened export output (including all 6 mask styles, colors, granularity,
/// and anti-theft diagonal watermark) framed in an iOS 26 concentric rounded container.
/// Supports press-and-hold to compare directly against the untouched original before saving.
struct CoveredPicture: View {
    let editor: EditorModel
    let size: CGSize
    var onRendered: ((CGImage) -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @State private var image: CGImage?
    @State private var showsOriginal = false
    @State private var holdFeedbackCount = 0

    var body: some View {
        let shape = ConcentricRectangle(corners: .concentric(minimum: 16), isUniform: true)
        ZStack(alignment: .top) {
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
        .task(id: key) { await render() }
    }

    private var key: RenderKey {
        RenderKey(
            editor: ObjectIdentifier(editor),
            items: editor.enabledItems.map(\.id),
            appearance: editor.maskAppearance
        )
    }

    @MainActor
    private func render() async {
        let preview = editor.preview
        let toPreview = CGSize(width: 1 / editor.previewScale.width, height: 1 / editor.previewScale.height)
        let findings = editor.enabledItems.flatMap(\.findings).map { $0.scaled(by: toPreview) }
        let appearance = editor.maskAppearance
        let cut = MaskRenderer.onShrunkPicture(shrink: editor.previewScale)
        let rendered = await Task.detached(priority: .userInitiated) {
            MaskRenderer.flatten(
                preview,
                findings: findings,
                appearance: appearance,
                blurGrain: cut.blurGrain,
                floor: cut.floor
            )
        }.value
        if !Task.isCancelled {
            image = rendered
            onRendered?(rendered)
        }
    }
}

private struct RenderKey: Equatable {
    let editor: ObjectIdentifier
    let items: [Int]
    let appearance: MaskAppearance
}
