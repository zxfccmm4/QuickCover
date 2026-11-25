import SwiftUI

/// Interactive Liquid Glass circular icon button (44×44) for studio overlays.
struct GlassIconButton: View {
    let systemImage: String
    let label: LocalizedStringKey
    var isSelected = false
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.glassIcon)
                .foregroundStyle(isSelected ? Theme.onAccent : Color.white)
                .frame(width: 44, height: 44)
                .glassEffect(
                    isSelected
                        ? .regular.tint(Theme.accentOnBlack).interactive()
                        : .regular.interactive(),
                    in: .circle
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : Theme.disabledOpacity)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// Interactive Liquid Glass capsule button that gracefully collapses to a 44×44 circle when space
/// or Dynamic Type requires icon-only presentation.
struct GlassLabelButton: View {
    let systemImage: String
    let title: LocalizedStringKey
    var isEnabled = true
    var titleHidden = false
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    private var showsTitle: Bool { Self.showsTitle(at: typeSize, titleHidden: titleHidden) }

    nonisolated static func showsTitle(at typeSize: DynamicTypeSize, titleHidden: Bool = false) -> Bool {
        !titleHidden && !typeSize.isAccessibilitySize
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.glassIcon)
                if showsTitle {
                    Text(title)
                        .font(.buttonText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, showsTitle ? 14 : 0)
            .frame(width: showsTitle ? nil : 44, height: 44)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : Theme.disabledOpacity)
        .accessibilityLabel(Text(title))
    }
}

/// Prominent tinted Liquid Glass Export pill.
struct ExportButton: View {
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    private var showsTitle: Bool { !typeSize.isAccessibilitySize }

    var body: some View {
        Button(action: action) {
            Group {
                if showsTitle {
                    Text("4.9.1")
                        .font(.buttonText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.glassIcon)
                }
            }
            .padding(.horizontal, showsTitle ? 12 : 0)
            .frame(minWidth: showsTitle ? 76 : 44)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .tint(Theme.accentButton)
        .accessibilityLabel("4.9.1")
    }
}

/// Floating Liquid Glass status capsule over the editor canvas. Grows vertically with Dynamic Type.
struct GlassCapsule: View {
    let text: LocalizedStringKey
    var weight: Font.Weight = .medium

    var body: some View {
        Text(text)
            .font(.subheadline.weight(weight))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minHeight: 36)
            .glassEffect(.regular, in: .capsule)
    }
}
