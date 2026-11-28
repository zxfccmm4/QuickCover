import SwiftUI

/// Adaptive Liquid Glass inspector sheet for configuring diagonal anti-theft watermarks and
/// Picsew/Leica-style bottom studio signature captions. Works identically from both `EditorScreen`
/// (dark studio) and `ExportScreen` (adaptive light/dark export preview).
struct WatermarkSheet: View {
    @Environment(EditorModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectionFeedbackCount = 0

    private static let presetKeys = [
        "wm.preset.business",
        "wm.preset.identity",
        "wm.preset.showcase",
        "wm.preset.rental",
        "wm.preset.once",
    ]

    private var accentColor: Color {
        colorScheme == .dark ? Theme.accentOnBlack : Theme.accent
    }

    private var sheetCardFill: Color {
        colorScheme == .dark
            ? Color(.secondarySystemGroupedBackground).opacity(0.86)
            : Color(.secondarySystemGroupedBackground)
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { model.watermark.isEnabled },
            set: { enabled in
                model.watermark.isEnabled = enabled
                if enabled && model.watermark.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    model.watermark.text = L10n.text(
                        model.watermark.placement == .bottomBadge ? "wm.preset.showcase" : "wm.preset.business"
                    )
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

    private var placementBinding: Binding<WatermarkOptions.Placement> {
        Binding(
            get: { model.watermark.placement },
            set: { newPlacement in
                model.watermark.placement = newPlacement
                if !model.watermark.isEnabled {
                    model.watermark.isEnabled = true
                    if model.watermark.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        model.watermark.text = L10n.text(
                            newPlacement == .bottomBadge ? "wm.preset.showcase" : "wm.preset.business"
                        )
                    }
                }
                selectionFeedbackCount += 1
            }
        )
    }

    private var showsDeviceModelBinding: Binding<Bool> {
        Binding(
            get: { model.watermark.showsDeviceModel },
            set: { newValue in
                model.watermark.showsDeviceModel = newValue
                selectionFeedbackCount += 1
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
                                ground: model.watermark.isEnabled ? accentColor.opacity(0.18) : Theme.fill,
                                tint: model.watermark.isEnabled ? accentColor : .secondary
                            )
                            Text("wm.enable")
                                .font(.body)
                        }
                    }
                    .tint(nil)
                    .listRowBackground(sheetCardFill)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("wm.placement")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Picker("wm.placement", selection: placementBinding) {
                            ForEach(WatermarkOptions.Placement.allCases) { placement in
                                Text(LocalizedStringKey(placement.titleKey)).tag(placement)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 2)
                    .listRowBackground(sheetCardFill)

                    if model.watermark.placement == .bottomBadge && model.deviceFrame.isActive {
                        Toggle(isOn: showsDeviceModelBinding) {
                            HStack(spacing: 12) {
                                IconTile(
                                    systemImage: model.deviceFrame.category.systemImage,
                                    ground: accentColor.opacity(0.16),
                                    tint: accentColor
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("wm.showDeviceModel")
                                    if let name = model.deviceFrame.model?.displayName {
                                        Text(verbatim: name)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .tint(nil)
                        .listRowBackground(sheetCardFill)
                    }
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
                                                    .fill(isSelected ? Theme.accentButton : Theme.fill)
                                            )
                                            .overlay(
                                                Capsule()
                                                    .stroke(Theme.cardBorder(for: colorScheme), lineWidth: 0.5)
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
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 12) {
                            IconTile(
                                systemImage: "circle.lefthalf.filled",
                                ground: accentColor.opacity(0.16),
                                tint: accentColor
                            )
                            Text("wm.opacity")
                            Spacer()
                            Text("\(Int((model.watermark.opacity * 100).rounded()))%")
                                .font(.footnote.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                        }
                        Slider(value: opacityBinding, in: 0.10...0.60, step: 0.01)
                            .tint(accentColor)
                    }
                    .padding(.vertical, 2)
                    .listRowBackground(sheetCardFill)

                    if model.watermark.placement != .bottomBadge {
                        HStack(spacing: 12) {
                            IconTile(
                                systemImage: "square.grid.3x3.fill",
                                ground: Color.indigo.opacity(colorScheme == .dark ? 0.22 : 0.12),
                                tint: .indigo
                            )
                            Text("wm.density")
                            Spacer(minLength: 12)
                            Picker("wm.density", selection: densityBinding) {
                                ForEach(WatermarkOptions.Density.allCases) { density in
                                    Text(LocalizedStringKey(density.titleKey)).tag(density)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 196)
                        }
                        .listRowBackground(sheetCardFill)
                    }

                    HStack(spacing: 12) {
                        IconTile(
                            systemImage: "paintpalette.fill",
                            ground: Color.orange.opacity(colorScheme == .dark ? 0.20 : 0.12),
                            tint: .orange
                        )
                        Text("wm.color")
                        Spacer()
                        HStack(spacing: 10) {
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
                                                    .strokeBorder(Color.primary.opacity(0.24), lineWidth: 0.75)
                                            )
                                        if isSelected {
                                            Circle()
                                                .strokeBorder(accentColor, lineWidth: 2)
                                                .frame(width: 32, height: 32)
                                        }
                                    }
                                    .frame(width: 34, height: 34)
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
                        dismiss()
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
