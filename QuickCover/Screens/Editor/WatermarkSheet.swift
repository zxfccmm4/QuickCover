import SwiftUI

/// Translucent Liquid Glass half-sheet for configuring diagonal anti-theft watermarks
/// (ideal for ID cards, licenses, contracts, and verification screenshots).
/// Allows live canvas preview directly above the sheet while editing text, opacity, density, and tint.
struct WatermarkSheet: View {
    @Environment(EditorModel.self) private var model
    @State private var selectionFeedbackCount = 0

    private static let presetKeys = [
        "wm.preset.business",
        "wm.preset.identity",
        "wm.preset.rental",
        "wm.preset.once",
    ]

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { model.watermark.isEnabled },
            set: { enabled in
                model.watermark.isEnabled = enabled
                if enabled && model.watermark.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    model.watermark.text = L10n.text("wm.preset.business")
                }
                selectionFeedbackCount += 1
            }
        )
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { model.watermark.text },
            set: { newValue in
                model.watermark.text = newValue
                if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !model.watermark.isEnabled {
                    model.watermark.isEnabled = true
                }
            }
        )
    }

    private var opacityBinding: Binding<Double> {
        Binding(
            get: { model.watermark.opacity },
            set: { model.watermark.opacity = $0 }
        )
    }

    private var densityBinding: Binding<WatermarkOptions.Density> {
        Binding(
            get: { model.watermark.density },
            set: {
                model.watermark.density = $0
                selectionFeedbackCount += 1
            }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: enabledBinding) {
                        Label("wm.enable", systemImage: "checkerboard.shield")
                    }
                    .tint(Theme.accent)
                }

                Section("wm.textSection") {
                    HStack(spacing: 8) {
                        TextField("wm.placeholder", text: textBinding, axis: .vertical)
                            .lineLimit(1...2)
                            .submitLabel(.done)

                        if !model.watermark.text.isEmpty {
                            Button {
                                model.watermark.text = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Theme.tertiary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Clear")
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("wm.presets")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.secondaryLabel)
                            .padding(.horizontal, 16)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Self.presetKeys, id: \.self) { key in
                                    let resolved = L10n.text(key)
                                    let isSelected = model.watermark.text == resolved && model.watermark.isEnabled
                                    Button {
                                        model.watermark.text = resolved
                                        model.watermark.isEnabled = true
                                        selectionFeedbackCount += 1
                                    } label: {
                                        Text(LocalizedStringKey(key))
                                            .font(.footnote.weight(isSelected ? .semibold : .regular))
                                            .foregroundStyle(isSelected ? .white : Theme.body)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(
                                                Capsule()
                                                    .fill(isSelected ? Theme.accentButton : Theme.fill)
                                            )
                                    }
                                    .buttonStyle(PressStyle(scale: 0.96))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 2)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0))
                }

                Section("wm.appearance") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("wm.opacity")
                            Spacer()
                            Text("\(Int((model.watermark.opacity * 100).rounded()))%")
                                .font(.footnote.monospacedDigit())
                                .foregroundStyle(Theme.secondaryLabel)
                        }
                        Slider(value: opacityBinding, in: 0.10...0.55, step: 0.01)
                            .tint(Theme.accent)
                    }
                    .padding(.vertical, 1)

                    HStack {
                        Text("wm.density")
                        Spacer(minLength: 16)
                        Picker("wm.density", selection: densityBinding) {
                            ForEach(WatermarkOptions.Density.allCases) { density in
                                Text(LocalizedStringKey(density.titleKey)).tag(density)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 210)
                    }

                    HStack {
                        Text("wm.color")
                        Spacer()
                        HStack(spacing: 12) {
                            ForEach(WatermarkOptions.Tint.allCases) { tint in
                                let isSelected = model.watermark.tint == tint
                                Button {
                                    model.watermark.tint = tint
                                    selectionFeedbackCount += 1
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(swatchColor(for: tint))
                                            .frame(width: 24, height: 24)
                                            .overlay(
                                                Circle()
                                                    .stroke(Theme.separator, lineWidth: 0.75)
                                            )
                                        if isSelected {
                                            Circle()
                                                .stroke(Theme.accent, lineWidth: 2.5)
                                                .frame(width: 31, height: 31)
                                        }
                                    }
                                    .frame(width: 32, height: 32)
                                }
                                .buttonStyle(PressStyle(scale: 0.92))
                                .accessibilityLabel(LocalizedStringKey(tint.titleKey))
                                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .scrollContentBackground(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .scrollEdgeEffectStyle(.soft, for: .all)
            .navigationTitle("wm.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        model.watermarkShown = false
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selectionFeedbackCount)
        .presentationDetents([.fraction(0.68), .large])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.68)))
    }

    private func swatchColor(for tint: WatermarkOptions.Tint) -> Color {
        switch tint {
        case .white: Color.white
        case .slate: Color(red: 0.22, green: 0.22, blue: 0.25)
        case .red: Color(red: 0.85, green: 0.16, blue: 0.16)
        }
    }
}
