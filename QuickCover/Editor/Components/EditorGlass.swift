import SwiftUI

/// The two glass buttons at the top of the editor (design.md §6):「換一張」(3.1.8) on the left,
/// 「逐項檢查」(4.4.1) on the right, 16 from the edges, 6 under the top safe area. While the picture
/// is being looked at they are at 42% and can't be tapped (§7.3.1). Put them inside the same
/// `GlassEffectContainer` as `EditorGlassBar`.
struct EditorTopButtons: View {
    @Environment(EditorModel.self) private var model
    @Environment(ShellModel.self) private var shell

    /// Measures whether the two titled capsules fit side by side and, where they don't, shows only
    /// the symbols, the way accessibility text sizes do (§9.5): in English they stop fitting one step
    /// above the default size on a 402 pt screen (「Choose Anot…」), in Chinese they fit up to XXXL.
    /// Off by default: the titles stay up to the accessibility sizes whatever the width.
    var hidesTitlesWhenTheyDoNotFit = false

    @State private var titledWidth: CGFloat = 0
    @State private var untitledWidth: CGFloat = 0
    @State private var availableWidth: CGFloat = 0

    private var isReady: Bool { model.recognition != .running }
    private var titleHidden: Bool {
        hidesTitlesWhenTheyDoNotFit &&
            !Self.titlesFit(titled: titledWidth, untitled: untitledWidth, available: availableWidth)
    }

    /// How far the two titles may shrink before they go instead: `GlassLabelButton` lets a title
    /// shrink to 85% before it truncates, and a title that needs that is already too small to read.
    private static let titleShrinkFloor: CGFloat = 0.9

    /// Whether the two titled capsules fit side by side in `available` points (they are 8 apart):
    /// `titled` is both at their natural width, `untitled` the same capsules with empty titles, so
    /// `titled - untitled` is the text. Not measured yet (`0`) counts as fitting.
    static func titlesFit(titled: CGFloat, untitled: CGFloat, available: CGFloat) -> Bool {
        guard titled > 0, untitled > 0, available > 0 else { return true }
        return untitled + titleShrinkFloor * (titled - untitled) <= available
    }

    var body: some View {
        HStack {
            GlassLabelButton(systemImage: "photo.on.rectangle", title: "3.1.8", isEnabled: isReady,
                             titleHidden: titleHidden) {
                shell.showPickerFromEditor()
            }
            Spacer()
            GlassLabelButton(systemImage: "list.bullet", title: "4.4.1", isEnabled: isReady,
                             titleHidden: titleHidden) {
                shell.showReview()
            }
        }
        .background {
            if hidesTitlesWhenTheyDoNotFit {
                // The two capsules at their natural width, never seen or read.
                GeometryReader { proxy in
                    pair(titles: ("3.1.8", "4.4.1"))
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { titledWidth = $0 }
                        .background {
                            pair(titles: ("", ""))
                                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { untitledWidth = $0 }
                        }
                        .onGeometryChange(for: CGFloat.self) { _ in proxy.size.width } action: { availableWidth = $0 }
                        .allowsHitTesting(false)
                        .hidden()
                        .accessibilityHidden(true)
                }
            }
        }
        // Inside the padding, so that the measurement sees the row's own width.
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

/// The glass bar at the bottom of the editor (design.md §6): 還原 (4.8.1), 重做 (4.8.2), 手動框選
/// (4.8.3), a stretch of space, then 匯出 (4.9.1). 16 from each side of the screen, 52 high, 6
/// inside at the ends and between the icon buttons, 8 above the bottom safe area. Put it inside
/// the same `GlassEffectContainer` as `EditorTopButtons`.
struct EditorGlassBar: View {
    @Environment(EditorModel.self) private var model
    @Environment(ShellModel.self) private var shell

    var body: some View {
        HStack(spacing: 6) {
            GlassIconButton(systemImage: "arrow.uturn.backward", label: "4.8.1", isEnabled: model.canUndo) {
                model.undo()
            }
            GlassIconButton(systemImage: "arrow.uturn.forward", label: "4.8.2", isEnabled: model.canRedo) {
                model.redo()
            }
            GlassIconButton(systemImage: "rectangle.dashed", label: "4.8.3", isSelected: model.drawToolOn) {
                model.drawToolOn.toggle()
            }
            Spacer(minLength: 0)
            ExportButton { shell.showExport() }
        }
        .padding(.horizontal, 6)
        .frame(height: 52)
        .glassEffect(.regular, in: .capsule)
    }
}
