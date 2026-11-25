import SwiftUI

/// Dark-studio Liquid Glass inspector sheet for configuring diagonal anti-theft watermarks
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

    private var sheetCardFill: Color {
        Color(.secondarySystemGroupedBackground).opacity(0.86)
    }

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
                        HStack(spacing: 12) {
                            IconTile(
                                systemImage: "checkerboard.shield",
                                ground: model.watermark.isEnabled ? Theme.accentOnBlack.opacity(0.18) : Color.white.opacity(0.10),
                                tint: model.watermark.isEnabled ? Theme.accentOnBlack : .secondary
                            )
                            Text("wm.enable")
                                .font(.body)
                        }
                    }
                    .tint(nil)
                    .listRowBackground(sheetCardFill)
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
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Clear")
                        }
                    }
                    .listRowBackground(sheetCardFill)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("wm.presets")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
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
                                            .foregroundStyle(isSelected ? .white : .primary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(
                                                Capsule()
                                                    .fill(isSelected ? Theme.accentButton : Color.white.opacity(0.10))
                                            )
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color.white.opacity(isSelected ? 0.20 : 0.08), lineWidth: 0.5)
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
                    .listRowBackground(sheetCardFill)
                }

                Section("wm.appearance") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("wm.opacity")
                            Spacer()
                            Text("\(Int((model.watermark.opacity * 100).rounded()))%")
                                .font(.footnote.weight(.medium).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: opacityBinding, in: 0.10...0.55, step: 0.01)
                            .tint(Theme.accentOnBlack)
                    }
                    .padding(.vertical, 2)
                    .listRowBackground(sheetCardFill)

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
                    .listRowBackground(sheetCardFill)

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
                                                    .stroke(Color.white.opacity(0.28), lineWidth: 0.75)
                                            )
                                        if isSelected {
                                            Circle()
                                                .stroke(Theme.accentOnBlack, lineWidth: 2.2)
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
                    .listRowBackground(sheetCardFill)
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
                    .tint(.primary)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selectionFeedbackCount)
        .presentationDetents([.fraction(0.68), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.thickMaterial)
        .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.68)))
    }

    private func swatchColor(for tint: WatermarkOptions.Tint) -> Color {
        switch tint {
        case .white: Color.white
        case .slate: Color(red: 0.28, green: 0.28, blue: 0.32)
        case .red: Color(red: 0.88, green: 0.20, blue: 0.20)
        }
    }
}
