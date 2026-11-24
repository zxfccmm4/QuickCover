import SwiftUI

/// 导出页的位置开关那一行（design.md §7.5）。和编辑页的 `ToggleRow` 一个做法，只是行首没有图标块
/// (§10.3 的图上就没有)，所以单独写在这里，不动共用的那个。
struct ExportToggleRow: View {
    let title: LocalizedStringKey
    let footnote: LocalizedStringKey
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 不限行数：辅助功能档（AX）下 6.2.2 要四五行，限三行会把句子截掉；页面本来就能滚。
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(Theme.body)
                Text(footnote)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryLabel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(nil)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        .onTapGesture { isOn.toggle() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(Text(title)), \(Text(footnote))"))
        .accessibilityAddTraits([.isButton, .isToggle])
        .accessibilityAction(.default) { isOn.toggle() }
    }
}
