import SwiftUI

/// Floating Liquid Glass status capsule over the editor canvas.
/// Uses native `ProgressView` when spinning and expands vertically for large Dynamic Type sizes.
struct PictureCapsule: View {
    let text: LocalizedStringKey
    var weight: Font.Weight = .medium
    var spins = false
    var usesIntelligenceAccent = false

    var body: some View {
        HStack(spacing: 8) {
            if spins {
                AppleIntelligenceOrb(size: 18)
            } else if usesIntelligenceAccent {
                Image(systemName: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppleIntelligencePalette.linearGradient)
                    .accessibilityHidden(true)
            }
            Group {
                if spins {
                    AppleIntelligenceShimmerText(text: text, font: .subheadline.weight(weight))
                } else {
                    Text(text)
                        .font(.subheadline.weight(weight))
                        .foregroundStyle(.white)
                }
            }
            .multilineTextAlignment(.center)
            .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minHeight: 36)
        .glassEffect(.regular, in: .capsule)
        .overlay {
            if usesIntelligenceAccent || spins {
                Capsule()
                    .stroke(AppleIntelligencePalette.linearGradient.opacity(0.65), lineWidth: 1)
            }
        }
    }
}

/// High-contrast concentric locate ring around an item selected from ReviewSheet.
struct LocateRing: View {
    let rect: CGRect

    private let corner: CGFloat = 4

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner + 11, style: .continuous)
                .inset(by: -11)
                .strokeBorder(Color.black.opacity(0.16), lineWidth: 5)
            RoundedRectangle(cornerRadius: corner + 6, style: .continuous)
                .inset(by: -6)
                .strokeBorder(Color.black.opacity(0.85), lineWidth: 1)
            RoundedRectangle(cornerRadius: corner + 4, style: .continuous)
                .inset(by: -4)
                .strokeBorder(Theme.accentOnBlack, lineWidth: 2)
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Subtle dashed outline around an auto-detected suggestion that the user explicitly uncovered,
/// providing a clean tap-to-re-cover affordance (inspired by Black Highlighter & DAMA).
struct UncoveredSuggestionOutline: View {
    let rect: CGRect

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.black.opacity(0.45), lineWidth: 2)
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(Theme.accentOnBlack.opacity(0.85), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Theme.accentOnBlack.opacity(0.06))
                )
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Interactive iridescent rubber-band overlay while dragging a manual cover or magic-erase box.
struct DrawBoxOverlay: View {
    let rect: CGRect
    var isMagicErase = false
    var pixelSize: CGSize? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .inset(by: -1.5)
                .strokeBorder(Color.black.opacity(0.75), lineWidth: 1.5)

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(
                    isMagicErase
                        ? AnyShapeStyle(AppleIntelligencePalette.linearGradient.opacity(0.22))
                        : AnyShapeStyle(Theme.accentOnBlack.opacity(0.16))
                )
                .strokeBorder(
                    isMagicErase
                        ? AnyShapeStyle(AppleIntelligencePalette.linearGradient)
                        : AnyShapeStyle(Theme.accentOnBlack),
                    lineWidth: 2
                )
                .shadow(
                    color: (isMagicErase ? AppleIntelligencePalette.colors[3] : Theme.accentOnBlack).opacity(0.55),
                    radius: 8
                )
        }
        .frame(width: rect.width, height: rect.height)
        .overlay(alignment: .top) {
            if let pixelSize, pixelSize.width >= 10, pixelSize.height >= 10 {
                Text(verbatim: "\(Int(pixelSize.width)) × \(Int(pixelSize.height))")
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .glassEffect(.regular, in: .capsule)
                    .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 0.5))
                    .offset(y: rect.minY > 34 ? -28 : rect.height + 8)
            }
        }
        .position(x: rect.midX, y: rect.midY)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Apple Markup-inspired selection outline with four crisp corner handles around a tapped
/// hand-drawn box so users immediately recognize it can be dragged or deleted.
struct SelectedManualBoxFrame: View {
    let rect: CGRect

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .inset(by: -2.5)
                .strokeBorder(Color.black.opacity(0.75), lineWidth: 2)
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .inset(by: -1.5)
                .strokeBorder(Theme.accentOnBlack, style: StrokeStyle(lineWidth: 1.8, dash: [5, 3]))

            cornerHandle.position(x: 0, y: 0)
            cornerHandle.position(x: rect.width, y: 0)
            cornerHandle.position(x: 0, y: rect.height)
            cornerHandle.position(x: rect.width, y: rect.height)
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var cornerHandle: some View {
        Circle()
            .fill(.white)
            .frame(width: 9, height: 9)
            .overlay(
                Circle()
                    .stroke(Theme.accentButton, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
    }
}

/// Real-time watermark preview layer matching `MaskRenderer` & `DeviceFrameRenderer` at 60fps.
struct WatermarkLiveOverlay: View {
    let options: WatermarkOptions

    var body: some View {
        Canvas { context, size in
            context.withCGContext { cg in
                cg.saveGState()
                cg.translateBy(x: 0, y: size.height)
                cg.scaleBy(x: 1, y: -1)
                if options.placement == .bottomBadge {
                    DeviceFrameRenderer.drawBottomBadge(
                        in: cg,
                        canvasSize: size,
                        bandHeight: max(36, min(size.width, size.height) * 0.11),
                        watermark: options,
                        modelName: nil,
                        onDarkBackground: false,
                        usePillBacking: true
                    )
                } else {
                    MaskRenderer.drawWatermark(in: cg, size: size, options: options)
                }
                cg.restoreGState()
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
