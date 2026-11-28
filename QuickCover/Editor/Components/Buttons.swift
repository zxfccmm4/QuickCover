import SwiftUI

/// Subtle press feedback for custom interactive surfaces that do not use a native system button style.
struct PressStyle: ButtonStyle {
    var scale: CGFloat = 1
    var opacity: CGFloat = 1

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? opacity : 1)
            .animation(.snappy(duration: 0.14), value: configuration.isPressed)
    }
}

/// Primary Apple iOS 26/27 CTA using native `.glassProminent` with flexible full-width sizing.
struct PrimaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String? = nil
    var isEnabled = true
    var isBusy = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isBusy {
                    AppleIntelligenceOrb(size: 18)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .fontWeight(.semibold)
                }
                Text(title)
                    .font(.buttonText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.vertical, 2)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .buttonSizing(.flexible)
        .controlSize(.large)
        .tint(Theme.accentButton)
        .disabled(!isEnabled || isBusy)
    }
}

/// Secondary Apple iOS 26/27 CTA using native interactive `.glass` with flexible sizing.
struct SecondaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String? = nil
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .fontWeight(.semibold)
                }
                Text(title)
                    .font(.buttonText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.vertical, 2)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .buttonSizing(.flexible)
        .controlSize(.large)
        .disabled(!isEnabled)
    }
}

/// Borderless accent action button (e.g. secondary onboarding link or callout action).
struct PlainTextButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)
                .frame(minHeight: Metrics.minimumTarget)
                .padding(.horizontal, 8)
        }
        .buttonStyle(.borderless)
        .tint(Theme.accent)
    }
}

/// Compact capsule action used inside advisory notices (e.g. "Switch to Solid Color").
struct SmallButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.smallButtonText)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .controlSize(.regular)
        .tint(Theme.accent)
    }
}

/// Inline borderless compact action used in error advisories and checklist reminders.
struct TextButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.smallButtonText)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 8)
                .frame(minHeight: 36)
        }
        .buttonStyle(.borderless)
        .tint(Theme.accent)
    }
}
