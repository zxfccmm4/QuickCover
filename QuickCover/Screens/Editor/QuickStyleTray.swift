import SwiftUI

/// Floating Liquid Glass quick style dock positioned above the editor's bottom toolbar.
/// Renders miniature live-texture `StyleSwatch` previews across all 6 mask styles plus
/// contextual controls for solid fill palette, emoji stickers, and mosaic/stripes/blur granularity.
struct QuickStyleTray: View {
    @Environment(EditorModel.self) private var model

    private var style: MaskStyle { model.preferences.style }

    private var feedbackTrigger: String {
        "\(style.rawValue).\(model.preferences.solidColor.rawValue).\(model.preferences.emoji).\(model.preferences.strength.rawValue)"
    }

    var body: some View {
        VStack(spacing: 10) {
            if style == .solid {
                solidPaletteBar
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
            } else if style == .emoji {
                emojiBar
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
            } else if style.supportsStrength {
                strengthBar
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
            }

            styleStrip
        }
        .animation(.snappy(duration: 0.24), value: style)
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
    }

    // MARK: - 6-Style Live Swatch Strip

    private var styleStrip: some View {
        let shape = ConcentricRectangle(corners: .concentric(minimum: 22), isUniform: true)
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) {
                ForEach(MaskStyle.allCases) { option in
                    styleTile(for: option)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(MaskStyle.allCases) { option in
                        styleTile(for: option)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
            }
        }
        .glassEffect(.regular, in: shape)
        .overlay(
            shape.stroke(Color.white.opacity(0.10), lineWidth: 0.5)
        )
    }

    private func styleTile(for option: MaskStyle) -> some View {
        let isSelected = option == style
        return Button {
            model.setStyle(option)
        } label: {
            VStack(spacing: 5) {
                StyleSwatch(
                    style: option,
                    solidColor: model.preferences.solidColor,
                    emoji: model.preferences.emoji,
                    size: CGSize(width: 34, height: 22),
                    cornerRadius: 6
                )
                .shadow(color: .black.opacity(0.28), radius: 2, y: 1)

                Text(LocalizedStringKey(option.titleKey))
                    .font(.caption2.weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Theme.accentOnBlack : .white.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(minWidth: 52, minHeight: 50)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 3)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.14) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(isSelected ? Theme.accentOnBlack.opacity(0.55) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PressStyle(scale: 0.94))
        .accessibilityLabel(LocalizedStringKey(option.titleKey))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Contextual Sub-Controls

    private var solidPaletteBar: some View {
        HStack(spacing: 12) {
            ForEach(SolidColorPreset.allCases) { preset in
                let isSelected = model.preferences.solidColor == preset
                Button {
                    model.setSolidColor(preset)
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(cgColor: preset.cgColor))
                            .frame(width: 26, height: 26)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(preset == .black ? 0.35 : 0.18), lineWidth: 1)
                            )
                        if isSelected {
                            Circle()
                                .stroke(Theme.accentOnBlack, lineWidth: 2)
                                .frame(width: 33, height: 33)
                        }
                    }
                    .frame(width: 34, height: 34)
                }
                .buttonStyle(PressStyle(scale: 0.9))
                .accessibilityLabel(LocalizedStringKey(preset.titleKey))
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 0.5))
    }

    private var emojiBar: some View {
        HStack(spacing: 8) {
            ForEach(EmojiPreset.all, id: \.self) { symbol in
                let isSelected = model.preferences.emoji == symbol
                Button {
                    model.setEmoji(symbol)
                } label: {
                    Text(symbol)
                        .font(.system(size: 21))
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(isSelected ? Color.white.opacity(0.16) : Color.clear)
                        )
                        .overlay(
                            Circle()
                                .stroke(isSelected ? Theme.accentOnBlack.opacity(0.75) : Color.clear, lineWidth: 1.25)
                        )
                }
                .buttonStyle(PressStyle(scale: 0.9))
                .accessibilityLabel(symbol)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 0.5))
    }

    private var strengthBar: some View {
        HStack(spacing: 3) {
            ForEach(MaskStrength.allCases) { level in
                let isSelected = model.preferences.strength == level
                Button {
                    model.setStrength(level)
                } label: {
                    Text(LocalizedStringKey(level.titleKey))
                        .font(.caption.weight(isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? Theme.onAccent : .white.opacity(0.84))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(isSelected ? Theme.accentOnBlack : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(4)
        .glassEffect(.regular, in: .capsule)
        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 0.5))
    }
}
