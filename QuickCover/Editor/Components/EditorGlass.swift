import SwiftUI

/// The two glass buttons at the top of the editor (design.md §6):「換一張」(3.1.8) on the left,
/// 「逐項檢查」(4.4.1) on the right, 16 from the edges, 6 under the top safe area. While the picture
/// is being looked at they are at 42% and can't be tapped (§7.3.1). Put them inside the same
/// `GlassEffectContainer` as `EditorGlassBar`.
struct EditorTopButtons: View {
    @Environment(EditorModel.self) private var model
    @Environment(ShellModel.self) private var shell

    private var isReady: Bool { model.recognition != .running }

    var body: some View {
        HStack {
            GlassLabelButton(systemImage: "photo.on.rectangle", title: "3.1.8", isEnabled: isReady) {
                shell.showPickerFromEditor()
            }
            Spacer()
            GlassLabelButton(systemImage: "list.bullet", title: "4.4.1", isEnabled: isReady) {
                shell.showReview()
            }
        }
        .padding(.horizontal, Metrics.pageInset)
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
