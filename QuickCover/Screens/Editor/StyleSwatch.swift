import SwiftUI

/// Tactile miniature visual preview tile for each `MaskStyle`, echoing DAMA / Mosaic+ / Apple
/// Markup's direct-manipulation swatches so users recognize every masking effect at a glance.
struct StyleSwatch: View {
    let style: MaskStyle
    var solidColor: SolidColorPreset = .black
    var emoji: String = EmojiPreset.default
    var size: CGSize = CGSize(width: 30, height: 22)
    var cornerRadius: CGFloat = 6

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        swatchContent
            .frame(width: size.width, height: size.height)
            .clipShape(shape)
            .overlay(
                shape.stroke(Color.white.opacity(0.24), lineWidth: 0.75)
            )
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var swatchContent: some View {
        switch style {
        case .mosaic:
            Canvas { context, sz in
                let cols = 3
                let rows = 2
                let cw = sz.width / CGFloat(cols)
                let ch = sz.height / CGFloat(rows)
                let palette: [Color] = [
                    Color(white: 0.86), Color(white: 0.44), Color(red: 0.36, green: 0.72, blue: 0.71),
                    Color(white: 0.32), Color(white: 0.78), Color(white: 0.54),
                ]
                for r in 0..<rows {
                    for c in 0..<cols {
                        let rect = CGRect(x: CGFloat(c) * cw, y: CGFloat(r) * ch, width: cw + 0.5, height: ch + 0.5)
                        context.fill(Path(rect), with: .color(palette[r * cols + c]))
                    }
                }
            }

        case .stripes:
            Canvas { context, sz in
                context.fill(Path(CGRect(origin: .zero, size: sz)), with: .color(.black))
                let period: CGFloat = max(4.5, sz.height * 0.28)
                let stripeW = period * 0.48
                var d = -sz.height
                while d < sz.width + sz.height {
                    var p = Path()
                    p.move(to: CGPoint(x: d, y: 0))
                    p.addLine(to: CGPoint(x: d + stripeW, y: 0))
                    p.addLine(to: CGPoint(x: d + stripeW + sz.height, y: sz.height))
                    p.addLine(to: CGPoint(x: d + sz.height, y: sz.height))
                    p.closeSubpath()
                    context.fill(p, with: .color(Color(white: 0.82)))
                    d += period
                }
            }

        case .conceal:
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.94, green: 0.96, blue: 0.98), Color(red: 0.82, green: 0.88, blue: 0.91)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "sparkles")
                    .font(.system(size: min(size.height * 0.55, 12), weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }

        case .solid:
            ZStack {
                Color(cgColor: solidColor.cgColor)
                LinearGradient(
                    colors: [Color.white.opacity(solidColor == .white ? 0 : 0.16), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

        case .blur:
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.22, green: 0.34, blue: 0.38),
                        Color(red: 0.58, green: 0.78, blue: 0.77),
                        Color(red: 0.86, green: 0.90, blue: 0.93),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: size.height * 0.75, height: size.height * 0.75)
                    .offset(x: -size.width * 0.18, y: -size.height * 0.1)
                    .blur(radius: 3)
                Circle()
                    .fill(Color(red: 0.08, green: 0.48, blue: 0.48).opacity(0.55))
                    .frame(width: size.height * 0.7, height: size.height * 0.7)
                    .offset(x: size.width * 0.2, y: size.height * 0.14)
                    .blur(radius: 3)
            }

        case .emoji:
            ZStack {
                Color(red: 0.95, green: 0.95, blue: 0.97)
                Text(emoji.isEmpty ? EmojiPreset.default : emoji)
                    .font(.system(size: min(size.height * 0.78, 16)))
            }
        }
    }
}
