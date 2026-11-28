import SwiftUI

/// Bottom-pinned masking style selector rendered inside ReviewSheet's `.safeAreaBar(edge: .bottom)`.
/// Uses miniature live-texture `StyleSwatch` capsules across all 6 `MaskStyle` options (or a native
/// `Menu` picker at Accessibility Dynamic Type sizes) with declarative `.sensoryFeedback`.
struct StylePicker: View {
    @Environment(EditorModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    @Namespace private var pillNamespace
    @State private var blurNoticeShown = false

    private var styleBinding: Binding<MaskStyle> {
        Binding(get: { model.preferences.style }, set: { pick($0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if typeSize.isAccessibilitySize {
                accessibilityMenuPicker
                    .padding(.horizontal, Metrics.pageInset)
            } else {
                Text("4.7.1")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.horizontal, Metrics.pageInset + 4)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MaskStyle.allCases) { option in
                            let isSelected = model.preferences.style == option
                            Button {
                                pick(option)
                            } label: {
                                HStack(spacing: 6) {
                                    StyleSwatch(
                                        style: option,
                                        appearance: model.maskAppearance,
                                        size: CGSize(width: 22, height: 16),
                                        cornerRadius: 4.5
                                    )
                                    Text(LocalizedStringKey(option.titleKey))
                                        .font(.subheadline.weight(isSelected ? .semibold : .medium))
                                }
                                .foregroundStyle(isSelected ? .white : .primary)
                                .padding(.leading, 8)
                                .padding(.trailing, 13)
                                .padding(.vertical, 8)
                                .background {
                                    if isSelected {
                                        Capsule()
                                            .fill(option == .conceal ? Color.white.opacity(0.18) : Theme.accentButton)
                                            .matchedGeometryEffect(id: "reviewStylePill", in: pillNamespace)
                                    } else {
                                        Capsule()
                                            .fill(Color.white.opacity(0.09))
                                    }
                                }
                                .overlay(
                                    Capsule()
                                        .strokeBorder(
                                            isSelected
                                                ? (option == .conceal
                                                    ? AnyShapeStyle(AppleIntelligencePalette.linearGradient)
                                                    : AnyShapeStyle(Color.white.opacity(0.24)))
                                                : AnyShapeStyle(Color.white.opacity(0.08)),
                                            lineWidth: isSelected && option == .conceal ? 1.2 : 0.5
                                        )
                                )
                            }
                            .buttonStyle(PressStyle(scale: 0.96))
                            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                        }
                    }
                    .padding(.horizontal, Metrics.pageInset)
                    .animation(.snappy(duration: 0.24), value: model.preferences.style)
                }
            }

            if blurNoticeShown {
                BlurNotice()
                    .padding(.horizontal, Metrics.pageInset)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 12)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5)
        }
        .sensoryFeedback(.selection, trigger: model.preferences.style)
    }

    private var accessibilityMenuPicker: some View {
        Menu {
            Picker("4.7.1", selection: styleBinding) {
                ForEach(MaskStyle.allCases) { option in
                    Label(LocalizedStringKey(option.titleKey), systemImage: option.systemImage)
                        .tag(option)
                }
            }
        } label: {
            HStack {
                Text("4.7.1")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(LocalizedStringKey(model.preferences.style.titleKey))
                    .foregroundStyle(.primary)
                    .fontWeight(.semibold)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .font(.body)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .accessibilityLabel(Text("\(Text("4.7.1")), \(Text(LocalizedStringKey(model.preferences.style.titleKey)))"))
    }

    private func pick(_ style: MaskStyle) {
        guard style != model.preferences.style else { return }
        model.setStyle(style)
        withAnimation(.snappy(duration: 0.22)) {
            blurNoticeShown = style == .blur
        }
    }
}

private struct BlurNotice: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.footnote)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.blurNoticeIcon)
                .accessibilityHidden(true)
                .padding(.top, 1)
            Text("4.7.5")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }
}
