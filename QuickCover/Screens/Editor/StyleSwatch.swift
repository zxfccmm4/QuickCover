import SwiftUI

/// Tactile miniature visual preview tile for each `MaskStyle`, live-reflecting colored mosaic,
/// colored diagonal stripes, Apple Intelligence magic erase, custom solid colors, and chosen emoji.
struct StyleSwatch: View {
    let style: MaskStyle
    var solidColorOption: MaskColorOption = .preset(.black)
    var mosaicTint: MosaicTint = .original
    var emoji: String = EmojiPreset.default
    var size: CGSize = CGSize(width: 30, height: 22)
    var cornerRadius: CGFloat = 6

    init(
        style: MaskStyle,
        appearance: MaskAppearance,
        size: CGSize = CGSize(width: 30, height: 22),
        cornerRadius: CGFloat = 6
    ) {
        self.style = style
        self.solidColorOption = appearance.resolvedSolidOption
        self.mosaicTint = appearance.mosaicTint
        self.emoji = appearance.emoji
        self.size = size
        self.cornerRadius = cornerRadius
    }

    init(
        style: MaskStyle,
        solidColor: SolidColorPreset = .black,
        mosaicTint: MosaicTint = .original,
        emoji: String = EmojiPreset.default,
        size: CGSize = CGSize(width: 30, height: 22),
        cornerRadius: CGFloat = 6
    ) {
        self.style = style
        self.solidColorOption = .preset(solidColor)
        self.mosaicTint = mosaicTint
        self.emoji = emoji
        self.size = size
        self.cornerRadius = cornerRadius
    }

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
                let palette: [Color] = mosaicCellColors
                for r in 0..<rows {
                    for c in 0..<cols {
                        let rect = CGRect(x: CGFloat(c) * cw, y: CGFloat(r) * ch, width: cw + 0.5, height: ch + 0.5)
                        context.fill(Path(rect), with: .color(palette[r * cols + c]))
                    }
                }
            }

        case .stripes:
            Canvas { context, sz in
                let barColor = mosaicTint.resolvedColor.map { Color(cgColor: $0.cgColor) } ?? .black
                context.fill(Path(CGRect(origin: .zero, size: sz)), with: .color(barColor))
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
                    context.fill(p, with: .color(Color(white: 0.86)))
                    d += period
                }
            }

        case .conceal:
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.90, green: 0.95, blue: 0.98),
                        Color(red: 0.89, green: 0.87, blue: 0.98),
                        Color(red: 0.98, green: 0.90, blue: 0.94),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "sparkles")
                    .font(.system(size: min(size.height * 0.56, 13), weight: .semibold))
                    .foregroundStyle(AppleIntelligencePalette.linearGradient)
            }

        case .solid:
            ZStack {
                Color(cgColor: solidColorOption.cgColor)
                LinearGradient(
                    colors: [Color.white.opacity(0.16), .clear],
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

    private var mosaicCellColors: [Color] {
        guard let tint = mosaicTint.resolvedColor else {
            return [
                Color(white: 0.86), Color(white: 0.44), Color(red: 0.36, green: 0.72, blue: 0.71),
                Color(white: 0.32), Color(white: 0.78), Color(white: 0.54),
            ]
        }
        let c = tint.rgba
        let factors: [Double] = [1.18, 0.78, 1.0, 0.68, 1.12, 0.88]
        return factors.map { f in
            let r = f <= 1 ? Double(c.r) * f : Double(c.r) + (1 - Double(c.r)) * (f - 1)
            let g = f <= 1 ? Double(c.g) * f : Double(c.g) + (1 - Double(c.g)) * (f - 1)
            let b = f <= 1 ? Double(c.b) * f : Double(c.b) + (1 - Double(c.b)) * (f - 1)
            return Color(red: min(max(r, 0), 1), green: min(max(g, 0), 1), blue: min(max(b, 0), 1))
        }
    }
}
