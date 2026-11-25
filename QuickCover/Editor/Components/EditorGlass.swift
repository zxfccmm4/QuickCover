import SwiftUI

/// Standalone floating glass controls for editor previews and tests.
/// Uses a single `GlassEffectContainer` without nesting glass inside glass.
struct EditorTopButtons: View {
    @Environment(EditorModel.self) private var model
    @Environment(ShellModel.self) private var shell

    var hidesTitlesWhenTheyDoNotFit = false

    @State private var titledWidth: CGFloat = 0
    @State private var untitledWidth: CGFloat = 0
    @State private var availableWidth: CGFloat = 0

    private var isReady: Bool { model.recognition != .running }
    private var titleHidden: Bool {
        hidesTitlesWhenTheyDoNotFit &&
            !Self.titlesFit(titled: titledWidth, untitled: untitledWidth, available: availableWidth)
    }

    private nonisolated static let titleShrinkFloor: CGFloat = 0.9

    nonisolated static func titlesFit(titled: CGFloat, untitled: CGFloat, available: CGFloat) -> Bool {
        guard titled > 0, untitled > 0, available > 0 else { return true }
        return untitled + titleShrinkFloor * (titled - untitled) <= available
    }

    var body: some View {
        HStack {
            GlassLabelButton(
                systemImage: "photo.on.rectangle",
                title: "3.1.8",
                isEnabled: isReady,
                titleHidden: titleHidden
            ) {
                shell.showPickerFromEditor()
            }
            Spacer()
            GlassLabelButton(
                systemImage: "list.bullet",
                title: "4.4.1",
                isEnabled: isReady,
                titleHidden: titleHidden
            ) {
                shell.showReview()
            }
        }
        .background {
            if hidesTitlesWhenTheyDoNotFit {
                GeometryReader { proxy in
                    let available = proxy.size.width
                    pair(titles: ("3.1.8", "4.4.1"))
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { titledWidth = $0 }
                        .background {
                            pair(titles: ("", ""))
                                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { untitledWidth = $0 }
                        }
                        .onGeometryChange(for: CGFloat.self) { _ in available } action: { availableWidth = $0 }
                        .allowsHitTesting(false)
                        .hidden()
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(.horizontal, Metrics.pageInset)
    }

    private func pair(titles: (LocalizedStringKey, LocalizedStringKey)) -> some View {
        HStack(spacing: 8) {
            GlassLabelButton(systemImage: "photo.on.rectangle", title: titles.0) {}
            GlassLabelButton(systemImage: "list.bullet", title: titles.1) {}
        }
        .fixedSize()
    }
}

/// Floating Liquid Glass action strip separating editing tools from the prominent Export pill
/// inside a single `GlassEffectContainer` (avoiding glass-on-glass nesting).
struct EditorGlassBar: View {
    @Environment(EditorModel.self) private var model
    @Environment(ShellModel.self) private var shell

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    toolButton(systemImage: "arrow.uturn.backward", label: "4.8.1", isEnabled: model.canUndo) {
                        model.undo()
                    }
                    toolButton(systemImage: "arrow.uturn.forward", label: "4.8.2", isEnabled: model.canRedo) {
                        model.redo()
                    }
                    toolButton(
                        systemImage: "rectangle.dashed",
                        label: "4.8.3",
                        isSelected: model.drawToolOn
                    ) {
                        model.drawToolOn.toggle()
                    }
                }
                .padding(.horizontal, 4)
                .frame(height: 52)
                .glassEffect(.regular.interactive(), in: .capsule)

                Spacer(minLength: 0)

                ExportButton { shell.showExport() }
                    .frame(height: 52)
            }
        }
    }

    private func toolButton(
        systemImage: String,
        label: LocalizedStringKey,
        isSelected: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.glassIcon)
                .foregroundStyle(isSelected ? Theme.onAccent : Color.white)
                .frame(width: 44, height: 44)
                .background {
                    if isSelected {
                        Circle().fill(Theme.accentOnBlack)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : Theme.disabledOpacity)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
