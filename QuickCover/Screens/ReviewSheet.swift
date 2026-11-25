import SwiftUI

/// Native iOS 26/27 Liquid Glass Inspector Sheet for reviewing, batch-toggling by category,
/// deleting manual boxes, and switching masking styles.
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
                                .foregroundStyle(Theme.secondaryLabel)

                            if !availableBatchGroups.isEmpty {
                                batchToggleStrip
                                    .padding(.top, 2)
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
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
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
                }
            }
        }
        .sensoryFeedback(.selection, trigger: batchFeedbackCount)
        .presentationDetents([.fraction(0.62), .large])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.62)))
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { top in
            SheetGeometry.shared.top = top
        }
        .task {
            AccessibilityNotification.Announcement(L10n.text("4.4.1")).post()
        }
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
                                        .fill(isCovered ? Color.white.opacity(0.22) : Theme.fillTwo)
                                )
                        }
                        .foregroundStyle(isCovered ? .white : Theme.body)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(isCovered ? Theme.accentButton : Theme.fill)
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
