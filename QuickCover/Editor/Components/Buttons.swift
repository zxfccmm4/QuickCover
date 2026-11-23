import SwiftUI

/// design.md §6: a control gets smaller while it's pressed (glass goes to 0.94 in 0.12 s, the
/// primary button to 0.8 opacity). The buttons of this folder use it; a screen can put it on its
/// own with `.buttonStyle(PressStyle(scale: 0.94))`.
struct PressStyle: ButtonStyle {
    var scale: CGFloat = 1
    var opacity: CGFloat = 1

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? opacity : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// The primary button (design.md §6): the whole width, 50 high, corner 14, `#7B2FE0`, white 17
/// semibold on one line, 0.8 opacity while pressed.
struct PrimaryButton: View {
    let title: LocalizedStringKey
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.buttonText)
                .foregroundStyle(Theme.body)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.accentButton))
        }
        .buttonStyle(PressStyle(opacity: 0.8))
        .disabled(!isEnabled)
    }
}

/// The secondary button (design.md §6): the primary button's size, the second fill as its ground,
/// the text in the body colour. Two stand side by side with 10 between them.
struct SecondaryButton: View {
    let title: LocalizedStringKey
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.buttonText)
                .foregroundStyle(Theme.body)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.fillTwo))
        }
        .buttonStyle(PressStyle(opacity: 0.8))
        .disabled(!isEnabled)
    }
}

/// The plain text button (design.md §6): 44 high, the text in the accent colour, 17 regular, no
/// ground: the primer's「先選一張圖」, the callout's「手動框選」.
struct PlainTextButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .foregroundStyle(Theme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 8)
                .frame(minHeight: Metrics.minimumTarget)
        }
        .buttonStyle(PressStyle(opacity: 0.8))
    }
}

/// The small button (design.md §6): 36 high, corner 10, the second fill as its ground, the text in
/// the accent colour, 15 semibold, 14 inside:「改用純色」. The place that answers a tap is 44 high
/// (§9.5) without the row growing.
struct SmallButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.smallButtonText)
                .foregroundStyle(Theme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.fillTwo))
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(opacity: 0.8))
        .padding(.vertical, -4)
    }
}

/// The text button (design.md §6): 36 high, no ground, the text in the accent colour, 15 semibold,
/// 8 inside:「再試一次」. Like the small button, tapped over 44.
struct TextButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.smallButtonText)
                .foregroundStyle(Theme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 8)
                .frame(height: 36)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(opacity: 0.8))
        .padding(.vertical, -4)
    }
}
