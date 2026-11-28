import SwiftUI

/// Compact iOS 26/27 Liquid Glass quick style dock modeled after Apple Photos Edit & Markup:
/// keeps the canvas generous by never stacking more than two slim glass strips:
/// - Contextual single-line strip (compact granularity menu + 12 colors + pinned ColorPicker for
///   Mosaic/Stripes; 12 colors + ColorPicker for Solid; quick emojis + More for Emoji; one-tap
///   Apple Intelligence Magic Erase pill for Magic Erase; granularity capsule for Blur)
/// - Slim 6-style live-swatch strip with matched-geometry selection gliding
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
        GlassEffectContainer(spacing: 6) {
            VStack(spacing: 6) {
                contextualControls
                    .glassEffectID("traySubControl", in: trayNamespace)
                    .glassEffectTransition(.matchedGeometry)

                styleStrip
                    .glassEffectID("trayPrimaryStrip", in: trayNamespace)
            }
        }
        .animation(.snappy(duration: 0.24), value: style)
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
    }

    // MARK: - Contextual Single-Line Strip

    @ViewBuilder
    private var contextualControls: some View {
        switch style {
        case .mosaic, .stripes:
            mosaicUnifiedBar
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

    // MARK: - Slim 6-Style Live Swatch Strip

    private var styleStrip: some View {
        let shape = ConcentricRectangle(corners: .concentric(minimum: 20), isUniform: true)
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 2) {
                ForEach(MaskStyle.allCases) { option in
                    styleTile(for: option)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    ForEach(MaskStyle.allCases) { option in
                        styleTile(for: option)
                    }
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 4)
            }
        }
        .glassEffect(.regular, in: shape)
        .overlay(
            shape.stroke(Color.white.opacity(0.09), lineWidth: 0.5)
        )
    }

    private func styleTile(for option: MaskStyle) -> some View {
        let isSelected = option == style
        return Button {
            model.setStyle(option)
        } label: {
            VStack(spacing: 4) {
                StyleSwatch(
                    style: option,
                    appearance: model.maskAppearance,
                    size: CGSize(width: 30, height: 19),
                    cornerRadius: 5.5
                )
                .shadow(color: .black.opacity(0.24), radius: 1.5, y: 1)

                Text(LocalizedStringKey(option.titleKey))
                    .font(.system(size: 10.5, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Theme.accentOnBlack : .white.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)
            }
            .frame(minWidth: 50, minHeight: 42)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 2)
            .padding(.vertical, 3)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.14))
                        .matchedGeometryEffect(id: "styleTileSelection", in: trayNamespace)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? (option == .conceal
                                ? AnyShapeStyle(AppleIntelligencePalette.linearGradient)
                                : AnyShapeStyle(Theme.accentOnBlack.opacity(0.55)))
                            : AnyShapeStyle(Color.clear),
                        lineWidth: 1.1
                    )
            )
        }
        .buttonStyle(PressStyle(scale: 0.94))
        .accessibilityLabel(LocalizedStringKey(option.titleKey))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Unified Mosaic / Stripes Bar (Compact Granularity + Auto + 12 Colors + Pinned ColorPicker)

    private var mosaicUnifiedBar: some View {
        let isCustomSelected: Bool = {
            if case .color(.custom) = model.preferences.mosaicTint { return true }
            return false
        }()

        return HStack(spacing: 4) {
            Menu {
                ForEach(MaskStrength.allCases) { level in
                    Button {
                        model.setStrength(level)
                    } label: {
                        if model.preferences.strength == level {
                            Label(LocalizedStringKey(level.titleKey), systemImage: "checkmark")
                        } else {
                            Text(LocalizedStringKey(level.titleKey))
                        }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 10, weight: .semibold))
                    Text(LocalizedStringKey(model.preferences.strength.titleKey))
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Theme.accentOnBlack)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.10)))
            } primaryAction: {
                cycleStrength()
            }
            .padding(.leading, 6)

            Divider()
                .frame(height: 18)
                .overlay(Color.white.opacity(0.16))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
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
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Image(systemName: "checkerboard.rectangle")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .shadow(radius: 1)
                                )
                            if isOriginal {
                                Circle()
                                    .strokeBorder(Theme.accentOnBlack, lineWidth: 1.8)
                                    .frame(width: 30, height: 30)
                            }
                        }
                        .frame(width: 32, height: 32)
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
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }

            Divider()
                .frame(height: 18)
                .overlay(Color.white.opacity(0.16))

            customColorWheel(selection: customMosaicTintBinding, isSelected: isCustomSelected)
                .padding(.leading, 1)
                .padding(.trailing, 7)
                .padding(.vertical, 4)
        }
        .glassEffect(.regular, in: .capsule)
        .overlay(Capsule().stroke(Color.white.opacity(0.09), lineWidth: 0.5))
    }

    private func cycleStrength() {
        let all = MaskStrength.allCases
        guard let idx = all.firstIndex(of: model.preferences.strength) else { return }
        model.setStrength(all[(idx + 1) % all.count])
    }

    // MARK: - Rich Solid Color Bar (12 Presets + Pinned Custom ColorPicker)

    private var solidColorBar: some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(SolidColorPreset.allCases) { preset in
                        let isSelected = model.preferences.customSolidColor == nil && model.preferences.solidColor == preset
                        colorDot(preset: preset, isSelected: isSelected) {
                            model.setSolidColor(preset)
                        }
                    }
                }
                .padding(.leading, 8)
                .padding(.trailing, 4)
                .padding(.vertical, 4)
            }

            Divider()
                .frame(height: 18)
                .overlay(Color.white.opacity(0.16))

            customColorWheel(
                selection: customSolidBinding,
                isSelected: model.preferences.customSolidColor != nil
            )
            .padding(.leading, 1)
            .padding(.trailing, 7)
            .padding(.vertical, 4)
        }
        .glassEffect(.regular, in: .capsule)
        .overlay(Capsule().stroke(Color.white.opacity(0.09), lineWidth: 0.5))
    }

    private func colorDot(preset: SolidColorPreset, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(cgColor: preset.cgColor))
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(preset == .black ? 0.35 : 0.18), lineWidth: 1)
                    )
                if isSelected {
                    Circle()
                        .strokeBorder(Theme.accentOnBlack, lineWidth: 1.8)
                        .frame(width: 30, height: 30)
                }
            }
            .frame(width: 32, height: 32)
        }
        .buttonStyle(PressStyle(scale: 0.9))
        .accessibilityLabel(LocalizedStringKey(preset.titleKey))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func customColorWheel(selection: Binding<Color>, isSelected: Bool) -> some View {
        ZStack {
            ColorPicker("", selection: selection, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 24, height: 24)
            if isSelected {
                Circle()
                    .strokeBorder(Theme.accentOnBlack, lineWidth: 1.8)
                    .frame(width: 31, height: 31)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: 32, height: 32)
        .accessibilityLabel("color.custom")
    }

    // MARK: - Expanded Emoji Quick Strip + More Button

    private var emojiBar: some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(model.quickBarEmojis, id: \.self) { symbol in
                        let isSelected = model.preferences.emoji == symbol
                        Button {
                            model.setEmoji(symbol)
                        } label: {
                            Text(symbol)
                                .font(.system(size: 20))
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(isSelected ? Color.white.opacity(0.16) : Color.clear)
                                )
                                .overlay(
                                    Circle()
                                        .strokeBorder(isSelected ? Theme.accentOnBlack.opacity(0.85) : Color.clear, lineWidth: 1.4)
                                )
                        }
                        .buttonStyle(PressStyle(scale: 0.9))
                        .accessibilityLabel(symbol)
                        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                    }
                }
                .padding(.leading, 7)
                .padding(.trailing, 4)
                .padding(.vertical, 4)
            }

            Divider()
                .frame(height: 20)
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
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.10)))
            }
            .buttonStyle(PressStyle(scale: 0.94))
            .padding(.trailing, 6)
            .accessibilityLabel("emoji.pickerTitle")
        }
        .glassEffect(.regular, in: .capsule)
        .overlay(Capsule().stroke(Color.white.opacity(0.09), lineWidth: 0.5))
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

    // MARK: - Blur Granularity Bar

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
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(Theme.accentOnBlack)
                                    .matchedGeometryEffect(id: "strengthSelection", in: trayNamespace)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(3)
        .glassEffect(.regular, in: .capsule)
        .overlay(Capsule().stroke(Color.white.opacity(0.09), lineWidth: 0.5))
        .animation(.snappy(duration: 0.24), value: model.preferences.strength)
    }
}
