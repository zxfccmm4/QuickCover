import SwiftUI

/// Native iOS 26/27 dark-studio Liquid Glass Inspector Sheet for reviewing detected items,
/// batch-toggling by category, deleting manual boxes, and switching masking styles.
struct ReviewSheet: View {
    @Environment(EditorModel.self) private var model
    @Environment(ShellModel.self) private var shell
    @State private var batchFeedbackCount = 0

    private var suggestions: [MaskItem] { ReviewSheetSections.suggestions(in: model.items) }
    private var textLines: [MaskItem] { ReviewSheetSections.textLines(in: model.items) }

    private var availableBatchGroups: [(group: MaskItem.Group, count: Int, titleKey: LocalizedStringKey, systemImage: String)] {
        let candidates: [(MaskItem.Group, LocalizedStringKey, String)] = [
            (.face, "review.batchFaces", "person.crop.rectangle"),
            (.text, "review.batchText", "text.quote"),
            (.code, "review.batchCodes", "qrcode"),
        ]
        return candidates.compactMap { group, titleKey, symbol in
            let count = model.suggestionItems(in: group).count
            return count > 0 ? (group, count, titleKey, symbol) : nil
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !model.found.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            SummaryText(found: model.found)
                            Text("4.4.2")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            if !availableBatchGroups.isEmpty {
                                batchToggleStrip
                                    .padding(.top, 4)
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                    }
                }

                Section {
                    ToggleRow(
                        systemImage: "eye",
                        title: Text("7.3"),
                        isOn: originalBinding,
                        stateKeys: nil,
                        hint: nil
                    )
                    .listRowBackground(sheetCardFill)

                    if !textLines.isEmpty {
                        intelligenceRow
                            .listRowBackground(sheetCardFill)
                    }
                }

                if !suggestions.isEmpty {
                    Section {
                        ForEach(suggestions) { item in
                            ChecklistRow(
                                item: item,
                                number: model.ordinal(of: item),
                                isOn: binding(item)
                            ) {
                                locate(item)
                            }
                            .listRowBackground(sheetCardFill)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if item.origin == .manual {
                                    Button(role: .destructive) {
                                        model.remove(item.id)
                                    } label: {
                                        Label("review.delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }

                if !textLines.isEmpty {
                    Section {
                        CoverAllTextRow(isOn: model.coversAllText) {
                            model.setAllText($0)
                        }
                        .listRowBackground(sheetCardFill)
                    } footer: {
                        if model.hasUncoveredTextLines {
                            UncoveredTextReminder(draw: startDrawing)
                                .padding(.top, 4)
                        }
                    }

                    Section {
                        ForEach(Array(textLines.enumerated()), id: \.element.id) { index, item in
                            ChecklistRow(
                                item: item,
                                number: numbered(textLines, at: index),
                                isOn: binding(item)
                            ) {
                                locate(item)
                            }
                            .listRowBackground(sheetCardFill)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .scrollContentBackground(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .scrollEdgeEffectStyle(.soft, for: .all)
            .contentMargins(.bottom, 16, for: .scrollContent)
            .safeAreaBar(edge: .bottom, spacing: 0) {
                StylePicker()
            }
            .navigationTitle("4.4.1")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        shell.hideReview()
                    }
                    .tint(.primary)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: batchFeedbackCount)
        .presentationDetents([.fraction(0.62), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.thickMaterial)
        .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.62)))
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { top in
            SheetGeometry.shared.top = top
        }
        .task {
            AccessibilityNotification.Announcement(L10n.text("4.4.1")).post()
        }
    }

    private var sheetCardFill: Color {
        Color(.secondarySystemGroupedBackground).opacity(0.86)
    }

    private var intelligenceRow: some View {
        HStack(spacing: 12) {
            ZStack {
                ConcentricRectangle(corners: .concentric(minimum: 8), isUniform: true)
                    .fill(AppleIntelligencePalette.linearGradient.opacity(0.18))
                    .frame(width: 30, height: 30)
                Image(systemName: "sparkles")
                    .font(.tileIcon)
                    .foregroundStyle(AppleIntelligencePalette.linearGradient)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("ai.reviewTitle")
                    .font(.body)
                    .foregroundStyle(Theme.body)
                Text("ai.reviewHint")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                Task { await model.runAppleIntelligenceScan() }
                batchFeedbackCount += 1
            } label: {
                if model.isRunningIntelligence {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("ai.scanNow")
                        .font(.footnote.weight(.semibold))
                }
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
            .tint(Theme.accentOnBlack)
            .disabled(model.isRunningIntelligence)
        }
        .padding(.vertical, 3)
    }

    private var batchToggleStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableBatchGroups, id: \.group) { entry in
                    let isCovered = model.isGroupCovered(entry.group)
                    Button {
                        model.setGroupCovered(entry.group, !isCovered)
                        batchFeedbackCount += 1
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: isCovered ? "checkmark.circle.fill" : entry.systemImage)
                                .font(.caption.weight(.semibold))
                            Text(entry.titleKey)
                                .font(.footnote.weight(.semibold))
                            Text("\(entry.count)")
                                .font(.caption2.weight(.bold).monospacedDigit())
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule()
                                        .fill(isCovered ? Color.white.opacity(0.22) : Color.white.opacity(0.12))
                                )
                        }
                        .foregroundStyle(isCovered ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(isCovered ? Theme.accentButton : Color.white.opacity(0.10))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(isCovered ? 0.18 : 0.08), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(PressStyle(scale: 0.95))
                    .accessibilityAddTraits(isCovered ? [.isSelected] : [])
                }
            }
        }
    }

    private func numbered(_ list: [MaskItem], at index: Int) -> Int? {
        list.count > 1 ? index + 1 : nil
    }

    private func binding(_ item: MaskItem) -> Binding<Bool> {
        Binding(get: { item.isOn }, set: { model.setOn(item.id, $0) })
    }

    private var originalBinding: Binding<Bool> {
        Binding(get: { model.showsOriginal }, set: { model.showsOriginal = $0 })
    }

    private func locate(_ item: MaskItem) {
        model.requestLocate(item.id)
    }

    private func startDrawing() {
        shell.hideReview()
        model.drawToolOn = true
    }
}
