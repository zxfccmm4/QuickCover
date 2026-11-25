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
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else if style == .emoji {
                emojiBar
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else if style.supportsStrength {
                strengthBar
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            styleStrip
        }
        .animation(.snappy(duration: 0.24), value: style)
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
    }

    // MARK: - 6-Style Live Swatch Strip

    private var styleStrip: some View {
        let shape = ConcentricRectangle(corners: .concentric(minimum: 22), isUniform: true)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(MaskStyle.allCases) { option in
                    let isSelected = option == style
                    Button {
                        model.setStyle(option)
                    } label: {
                        VStack(spacing: 5) {
                            StyleSwatch(
                                style: option,
                                solidColor: model.preferences.solidColor,
                                emoji: model.preferences.emoji,
                                size: CGSize(width: 32, height: 22),
                                cornerRadius: 6
                            )
                            .shadow(color: .black.opacity(0.28), radius: 2, y: 1)

                            Text(LocalizedStringKey(option.titleKey))
                                .font(.caption2.weight(isSelected ? .semibold : .medium))
                                .foregroundStyle(isSelected ? Theme.accentOnBlack : .white.opacity(0.86))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(minWidth: 50, minHeight: 48)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(isSelected ? Theme.accentOnBlack.opacity(0.20) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(isSelected ? Theme.accentOnBlack.opacity(0.60) : Color.clear, lineWidth: 1.2)
                        )
                    }
                    .buttonStyle(PressStyle(scale: 0.94))
                    .accessibilityLabel(LocalizedStringKey(option.titleKey))
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
        }
        .glassEffect(.regular, in: shape)
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
                                .stroke(Theme.accentOnBlack, lineWidth: 2.5)
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
                                .fill(isSelected ? Theme.accentOnBlack.opacity(0.24) : Color.clear)
                        )
                        .overlay(
                            Circle()
                                .stroke(isSelected ? Theme.accentOnBlack : Color.clear, lineWidth: 1.5)
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
    }

    private var strengthBar: some View {
        HStack(spacing: 4) {
            ForEach(MaskStrength.allCases) { level in
                let isSelected = model.preferences.strength == level
                Button {
                    model.setStrength(level)
                } label: {
                    Text(LocalizedStringKey(level.titleKey))
                        .font(.caption.weight(isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? Theme.onAccent : .white.opacity(0.86))
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
    }
}
