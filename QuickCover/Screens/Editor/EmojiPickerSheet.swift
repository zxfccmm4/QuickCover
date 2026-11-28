import SwiftUI

/// Dark-studio Liquid Glass full Unicode 16.0 Emoji Picker (1,900+ emojis across Featured + all
/// 9 official Apple/Unicode categories) with instant Chinese & English search, recently used
/// stickers, smooth matched-geometry category tabs, and direct system Emoji keyboard input.
struct EmojiPickerSheet: View {
    @Environment(EditorModel.self) private var model
    @Namespace private var tabNamespace

    @State private var query = ""
    @State private var selectedCategoryID = EmojiPreset.categories.first?.id ?? "featured"
    @State private var selectionFeedbackCount = 0

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    private var sheetCardFill: Color {
        Color(.secondarySystemGroupedBackground).opacity(0.86)
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool {
        !trimmedQuery.isEmpty
    }

    private var searchResults: [EmojiEntry] {
        EmojiPreset.search(trimmedQuery)
    }

    private var activeCategory: EmojiCategory? {
        EmojiPreset.categories.first { $0.id == selectedCategoryID } ?? EmojiPreset.categories.first
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                searchAndInputBar
                    .padding(.horizontal, Metrics.pageInset)
                    .padding(.top, 8)

                if !isSearching {
                    categoryTabStrip
                }

                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Color.clear
                                .frame(height: 0)
                                .id("emojiTop")

                            if isSearching {
                                searchResultsSection
                            } else {
                                if !model.preferences.recentEmojis.isEmpty && selectedCategoryID == "featured" {
                                    recentSection
                                }

                                if let category = activeCategory {
                                    categoryGridSection(category)
                                }
                            }
                        }
                        .padding(.horizontal, Metrics.pageInset)
                        .padding(.bottom, 24)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .scrollBounceBehavior(.basedOnSize)
                    .scrollEdgeEffectStyle(.soft, for: .all)
                    .onChange(of: selectedCategoryID) { _, _ in
                        withAnimation(.snappy(duration: 0.22)) {
                            scrollProxy.scrollTo("emojiTop", anchor: .top)
                        }
                    }
                }
            }
            .navigationTitle("emoji.pickerTitle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        model.emojiPickerShown = false
                    }
                    .tint(.primary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Text(verbatim: "\(EmojiPreset.all.count)")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                        .accessibilityHidden(true)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selectionFeedbackCount)
        .presentationDetents([.fraction(0.72), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.thickMaterial)
        .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.72)))
    }

    // MARK: - Unified Search & Direct Emoji Input Bar

    private var searchAndInputBar: some View {
        let shape = ConcentricRectangle(corners: .concentric(minimum: 18), isUniform: true)
        return HStack(spacing: 10) {
            Text(model.preferences.emoji)
                .font(.system(size: 26))
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.white.opacity(0.10)))
                .overlay(Circle().strokeBorder(Theme.accentOnBlack.opacity(0.45), lineWidth: 1))

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                TextField("emoji.searchPlaceholder", text: $query)
                    .font(.body)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { applyCustomInputIfEmoji() }
                    .onChange(of: query) { _, newValue in
                        if EmojiPreset.isDirectEmojiInput(newValue) {
                            let symbol = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            selectEmoji(symbol)
                            query = ""
                        }
                    }
            }

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(shape.fill(sheetCardFill))
        .overlay(shape.stroke(Color.white.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: - 10-Category Horizontal Tab Bar

    private var categoryTabStrip: some View {
        ScrollViewReader { tabProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(EmojiPreset.categories) { category in
                        let isSelected = category.id == selectedCategoryID
                        Button {
                            withAnimation(.snappy(duration: 0.24)) {
                                selectedCategoryID = category.id
                            }
                            selectionFeedbackCount += 1
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: category.systemImage)
                                    .font(.caption.weight(.semibold))
                                Text(LocalizedStringKey(category.shortTitleKey))
                                    .font(.caption.weight(isSelected ? .semibold : .medium))
                            }
                            .foregroundStyle(isSelected ? Theme.onAccent : .primary.opacity(0.86))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background {
                                if isSelected {
                                    Capsule()
                                        .fill(Theme.accentOnBlack)
                                        .matchedGeometryEffect(id: "emojiCategoryTab", in: tabNamespace)
                                } else {
                                    Capsule()
                                        .fill(Color.white.opacity(0.09))
                                }
                            }
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        Color.white.opacity(isSelected ? 0.20 : 0.07),
                                        lineWidth: 0.5
                                    )
                            )
                        }
                        .buttonStyle(PressStyle(scale: 0.95))
                        .id(category.id)
                        .accessibilityLabel(LocalizedStringKey(category.titleKey))
                        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                    }
                }
                .padding(.horizontal, Metrics.pageInset)
                .padding(.vertical, 2)
            }
            .onChange(of: selectedCategoryID) { _, id in
                withAnimation(.snappy(duration: 0.24)) {
                    tabProxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    // MARK: - Recents Strip

    private var recentSection: some View {
        let shape = ConcentricRectangle(corners: .concentric(minimum: 18), isUniform: true)
        return VStack(alignment: .leading, spacing: 8) {
            Text("emoji.recent")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(model.preferences.recentEmojis, id: \.self) { symbol in
                        emojiCell(symbol)
                            .frame(width: 46, height: 46)
                    }
                }
                .padding(10)
            }
            .background(shape.fill(sheetCardFill))
            .overlay(shape.stroke(Color.white.opacity(0.08), lineWidth: 0.5))
        }
    }

    // MARK: - Active Category Grid

    private func categoryGridSection(_ category: EmojiCategory) -> some View {
        let shape = ConcentricRectangle(corners: .concentric(minimum: 20), isUniform: true)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Label(LocalizedStringKey(category.titleKey), systemImage: category.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(verbatim: "\(category.entries.count)")
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.accentOnBlack)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1.5)
                    .background(Theme.accentOnBlack.opacity(0.16), in: Capsule())
            }
            .padding(.leading, 4)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(category.entries) { entry in
                    emojiCell(entry.symbol)
                        .frame(height: 46)
                }
            }
            .padding(10)
            .background(shape.fill(sheetCardFill))
            .overlay(shape.stroke(Color.white.opacity(0.08), lineWidth: 0.5))
        }
    }

    // MARK: - Search Results Grid

    private var searchResultsSection: some View {
        let results = searchResults
        let shape = ConcentricRectangle(corners: .concentric(minimum: 20), isUniform: true)

        return VStack(alignment: .leading, spacing: 10) {
            if results.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("emoji.noResults")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("emoji.apply") {
                        selectEmoji(trimmedQuery)
                        query = ""
                    }
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .tint(Theme.accentOnBlack)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .padding(.horizontal, 16)
                .background(shape.fill(sheetCardFill))
                .overlay(shape.stroke(Color.white.opacity(0.08), lineWidth: 0.5))
            } else {
                Text(verbatim: L10n.emojiSearchCount(results.count))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(results) { entry in
                        emojiCell(entry.symbol)
                            .frame(height: 46)
                    }
                }
                .padding(10)
                .background(shape.fill(sheetCardFill))
                .overlay(shape.stroke(Color.white.opacity(0.08), lineWidth: 0.5))
            }
        }
    }

    // MARK: - Emoji Cell & Actions

    private func emojiCell(_ symbol: String) -> some View {
        let isSelected = model.preferences.emoji == symbol
        return Button {
            selectEmoji(symbol)
        } label: {
            Text(symbol)
                .font(.system(size: 27))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? Theme.accentOnBlack.opacity(0.22) : Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isSelected ? Theme.accentOnBlack : Color.clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(PressStyle(scale: 0.9))
        .accessibilityLabel(symbol)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func applyCustomInputIfEmoji() {
        guard !trimmedQuery.isEmpty else { return }
        if EmojiPreset.isDirectEmojiInput(trimmedQuery) {
            selectEmoji(trimmedQuery)
            query = ""
        } else if let first = searchResults.first {
            selectEmoji(first.symbol)
        }
    }

    private func selectEmoji(_ symbol: String) {
        if model.preferences.style != .emoji {
            model.setStyle(.emoji)
        }
        model.setEmoji(symbol)
        selectionFeedbackCount += 1
    }
}
