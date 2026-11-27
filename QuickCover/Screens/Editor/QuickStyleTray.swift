import SwiftUI

/// Floating iOS 26/27 Liquid Glass quick style dock with matched-geometry morphing sub-bars:
/// - 6 live-texture style tiles (`马赛克`, `斜条`, `魔术消除`, `纯色`, `模糊`, `表情`)
/// - 12 curated Apple colors + native rainbow `ColorPicker` for Solid, Mosaic, and Stripes
/// - Granularity pills (`细腻 / 标准 / 粗粒`) for Mosaic, Stripes, and Blur
/// - Quick favorite/recent emojis + `更多` button opening the 48+ categorized `EmojiPickerSheet`
/// - One-tap Apple Intelligence Magic Erase action pill when `.conceal` is active
struct QuickStyleTray: View {
    @Environment(EditorModel.self) private var model
    @Namespace private var trayNamespace

    private var style: MaskStyle { model.preferences.style }

    private var feedbackTrigger: String {
        let p = model.preferences
        return "\(p.style.rawValue).\(p.solidColor.rawValue).\(p.customSolidColor?.red ?? -1).\(p.mosaicTint.hashValue).\(p.emoji).\(p.strength.rawValue)"
    }

    private var customSolidBinding: Binding<Color> {
        Binding(
            get: { Color(cgColor: model.maskAppearance.resolvedSolidCGColor) },
            set: { newColor in
                if let rgb = CustomColorRGB(cgColor: UIColor(newColor).cgColor) {
                    model.setCustomSolidColor(rgb)
                }
            }
        )
    }

    private var customMosaicTintBinding: Binding<Color> {
        Binding(
            get: {
                if let c = model.preferences.mosaicTint.resolvedColor {
                    return Color(cgColor: c.cgColor)
                }
                return Theme.accentOnBlack
            },
            set: { newColor in
                if let rgb = CustomColorRGB(cgColor: UIColor(newColor).cgColor) {
                    model.setMosaicTint(.color(.custom(rgb)))
                }
            }
        )
    }

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            VStack(spacing: 8) {
                contextualControls
                    .glassEffectID("traySubControl", in: trayNamespace)
                    .glassEffectTransition(.matchedGeometry)

                styleStrip
                    .glassEffectID("trayPrimaryStrip", in: trayNamespace)
            }
        }
        .animation(.snappy(duration: 0.26), value: style)
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
    }

    // MARK: - Contextual Sub-Controls

    @ViewBuilder
    private var contextualControls: some View {
        switch style {
        case .mosaic, .stripes:
            VStack(spacing: 8) {
                strengthBar
                mosaicColorBar
            }
            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))

        case .solid:
            solidColorBar
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))

        case .emoji:
            emojiBar
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))

        case .conceal:
            magicEraseBar
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))

        case .blur:
            strengthBar
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
        }
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
                    appearance: model.maskAppearance,
                    size: CGSize(width: 34, height: 22),
                    cornerRadius: 6
                )
                .shadow(color: .black.opacity(0.28), radius: 2, y: 1)

                Text(LocalizedStringKey(option.titleKey))
                    .font(.caption2.weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Theme.accentOnBlack : .white.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)
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
                    .stroke(
                        isSelected
                            ? (option == .conceal
                                ? AnyShapeStyle(AppleIntelligencePalette.linearGradient)
                                : AnyShapeStyle(Theme.accentOnBlack.opacity(0.60)))
                            : AnyShapeStyle(Color.clear),
                        lineWidth: 1.2
                    )
            )
        }
        .buttonStyle(PressStyle(scale: 0.94))
        .accessibilityLabel(LocalizedStringKey(option.titleKey))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Rich Mosaic / Stripes Color Bar (Auto Original + 12 Presets + Pinned Custom ColorPicker)

    private var mosaicColorBar: some View {
        let isCustomSelected: Bool = {
            if case .color(.custom) = model.preferences.mosaicTint { return true }
            return false
        }()

        return HStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    // Original auto-sampled image mosaic button
                    let isOriginal = model.preferences.mosaicTint == .original
                    Button {
                        model.setMosaicTint(.original)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(
                                    AngularGradient(
                                        colors: [
                                            Color(white: 0.85), Color(white: 0.40), Theme.accentOnBlack,
                                            Color(white: 0.65), Color(white: 0.85),
                                        ],
                                        center: .center
                                    )
                                )
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Image(systemName: "checkerboard.rectangle")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                        .shadow(radius: 1)
                                )
                            if isOriginal {
                                Circle()
                                    .strokeBorder(Theme.accentOnBlack, lineWidth: 2)
                                    .frame(width: 32, height: 32)
                            }
                        }
                        .frame(width: 34, height: 34)
                    }
                    .buttonStyle(PressStyle(scale: 0.9))
                    .accessibilityLabel("mosaic.colorOriginal")
                    .accessibilityAddTraits(isOriginal ? [.isSelected] : [])

                    ForEach(SolidColorPreset.allCases) { preset in
                        let isSelected = model.preferences.mosaicTint == .color(.preset(preset))
                        colorDot(preset: preset, isSelected: isSelected) {
                            model.setMosaicTint(.color(.preset(preset)))
                        }
                    }
                }
                .padding(.leading, 10)
                .padding(.trailing, 6)
                .padding(.vertical, 5)
            }

            Divider()
                .frame(height: 20)
                .overlay(Color.white.opacity(0.16))

            customColorWheel(selection: customMosaicTintBinding, isSelected: isCustomSelected)
                .padding(.leading, 2)
                .padding(.trailing, 8)
                .padding(.vertical, 5)
        }
        .glassEffect(.regular, in: .capsule)
        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 0.5))
    }

    // MARK: - Rich Solid Color Bar (12 Presets + Pinned Custom ColorPicker)

    private var solidColorBar: some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(SolidColorPreset.allCases) { preset in
                        let isSelected = model.preferences.customSolidColor == nil && model.preferences.solidColor == preset
                        colorDot(preset: preset, isSelected: isSelected) {
                            model.setSolidColor(preset)
                        }
                    }
                }
                .padding(.leading, 10)
                .padding(.trailing, 6)
                .padding(.vertical, 5)
            }

            Divider()
                .frame(height: 20)
                .overlay(Color.white.opacity(0.16))

            customColorWheel(
                selection: customSolidBinding,
                isSelected: model.preferences.customSolidColor != nil
            )
            .padding(.leading, 2)
            .padding(.trailing, 8)
            .padding(.vertical, 5)
        }
        .glassEffect(.regular, in: .capsule)
        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 0.5))
    }

    private func colorDot(preset: SolidColorPreset, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(cgColor: preset.cgColor))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(preset == .black ? 0.35 : 0.18), lineWidth: 1)
                    )
                if isSelected {
                    Circle()
                        .strokeBorder(Theme.accentOnBlack, lineWidth: 2)
                        .frame(width: 32, height: 32)
                }
            }
            .frame(width: 34, height: 34)
        }
        .buttonStyle(PressStyle(scale: 0.9))
        .accessibilityLabel(LocalizedStringKey(preset.titleKey))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func customColorWheel(selection: Binding<Color>, isSelected: Bool) -> some View {
        ZStack {
            ColorPicker("", selection: selection, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 26, height: 26)
            if isSelected {
                Circle()
                    .strokeBorder(Theme.accentOnBlack, lineWidth: 2)
                    .frame(width: 33, height: 33)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: 34, height: 34)
        .accessibilityLabel("color.custom")
    }

    // MARK: - Expanded Emoji Quick Strip + More Button

    private var emojiBar: some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(model.quickBarEmojis, id: \.self) { symbol in
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
                                        .strokeBorder(isSelected ? Theme.accentOnBlack.opacity(0.85) : Color.clear, lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(PressStyle(scale: 0.9))
                        .accessibilityLabel(symbol)
                        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                    }
                }
                .padding(.leading, 8)
                .padding(.trailing, 4)
                .padding(.vertical, 5)
            }

            Divider()
                .frame(height: 22)
                .overlay(Color.white.opacity(0.16))

            Button {
                model.emojiPickerShown = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                    Text("emoji.more")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Theme.accentOnBlack)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.white.opacity(0.10)))
            }
            .buttonStyle(PressStyle(scale: 0.94))
            .padding(.trailing, 7)
            .accessibilityLabel("emoji.pickerTitle")
        }
        .glassEffect(.regular, in: .capsule)
        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 0.5))
    }

    // MARK: - Apple Intelligence Magic Erase Contextual Bar

    private var magicEraseBar: some View {
        Button {
            Task { await model.runAppleIntelligenceScan(applyMagicErase: true) }
        } label: {
            HStack(spacing: 7) {
                if model.isRunningIntelligence {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppleIntelligencePalette.linearGradient)
                }
                Text("ai.magicScanAction")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(.regular.interactive(), in: .capsule)
            .overlay(
                Capsule()
                    .stroke(AppleIntelligencePalette.linearGradient.opacity(0.55), lineWidth: 1)
            )
        }
        .buttonStyle(PressStyle(scale: 0.95))
        .disabled(model.isRunningIntelligence)
    }

    // MARK: - Granularity Bar

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
                        .padding(.vertical, 6)
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
