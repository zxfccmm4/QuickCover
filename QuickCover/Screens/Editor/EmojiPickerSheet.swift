import SwiftUI

/// Dark-studio Liquid Glass sheet providing 48 categorized emojis across 4 collections, recently
/// used stickers, and a custom Emoji keyboard input so users can pick any Unicode emoji.
struct EmojiPickerSheet: View {
    @Environment(EditorModel.self) private var model
    @State private var customInput = ""
    @State private var selectionFeedbackCount = 0

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    private var sheetCardFill: Color {
        Color(.secondarySystemGroupedBackground).opacity(0.86)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    customEmojiCard

                    if !model.preferences.recentEmojis.isEmpty {
                        recentSection
                    }

                    ForEach(EmojiPreset.categories) { category in
                        categorySection(category)
                    }
                }
                .padding(.horizontal, Metrics.pageInset)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollEdgeEffectStyle(.soft, for: .all)
            .navigationTitle("emoji.pickerTitle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        model.emojiPickerShown = false
                    }
                    .tint(.primary)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selectionFeedbackCount)
        .presentationDetents([.fraction(0.66), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.thickMaterial)
        .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.66)))
    }

    // MARK: - Custom Emoji Input

    private var customEmojiCard: some View {
        let shape = ConcentricRectangle(corners: .concentric(minimum: 18), isUniform: true)
        return HStack(spacing: 10) {
            Text(model.preferences.emoji)
                .font(.system(size: 26))
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.white.opacity(0.10)))

            TextField("emoji.customPlaceholder", text: $customInput)
                .font(.body)
                .submitLabel(.done)
                .onSubmit { applyCustomEmoji() }
                .onChange(of: customInput) { _, newValue in
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let first = trimmed.first else { return }
                    let candidate = String(first)
                    if candidate.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation || $0.properties.isEmoji }) {
                        selectEmoji(candidate)
                        customInput = ""
                    }
                }

            if !customInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button("emoji.apply") {
                    applyCustomEmoji()
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.glassProminent)
                .tint(Theme.accentButton)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(shape.fill(sheetCardFill))
        .overlay(shape.stroke(Color.white.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: - Recents

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("emoji.recent")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(model.preferences.recentEmojis, id: \.self) { symbol in
                        emojiCell(symbol)
                            .frame(width: 48, height: 48)
                    }
                }
            }
        }
    }

    // MARK: - Category Grid

    private func categorySection(_ category: EmojiCategory) -> some View {
        let shape = ConcentricRectangle(corners: .concentric(minimum: 20), isUniform: true)
        return VStack(alignment: .leading, spacing: 8) {
            Label(LocalizedStringKey(category.titleKey), systemImage: category.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(category.emojis, id: \.self) { symbol in
                    emojiCell(symbol)
                        .frame(height: 46)
                }
            }
            .padding(10)
            .background(shape.fill(sheetCardFill))
            .overlay(shape.stroke(Color.white.opacity(0.08), lineWidth: 0.5))
        }
    }

    private func emojiCell(_ symbol: String) -> some View {
        let isSelected = model.preferences.emoji == symbol
        return Button {
            selectEmoji(symbol)
        } label: {
            Text(symbol)
                .font(.system(size: 26))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? Theme.accentOnBlack.opacity(0.22) : Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSelected ? Theme.accentOnBlack : Color.clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(PressStyle(scale: 0.9))
        .accessibilityLabel(symbol)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func applyCustomEmoji() {
        let trimmed = customInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        selectEmoji(trimmed)
        customInput = ""
    }

    private func selectEmoji(_ symbol: String) {
        if model.preferences.style != .emoji {
            model.setStyle(.emoji)
        }
        model.setEmoji(symbol)
        selectionFeedbackCount += 1
    }
}
