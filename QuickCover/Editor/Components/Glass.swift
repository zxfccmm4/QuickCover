import SwiftUI

/// A 44×44 circle of glass with a 21 pt white symbol (design.md §6): 還原, 重做 and 手動框選 on the
/// editor's glass bar. What can't be done stays where it is at 42%. A selected tool is a solid
/// `#C77DFF` circle with a `#1A0033` symbol.
struct GlassIconButton: View {
    let systemImage: String
    /// The copy.md number that names the button.
    let label: LocalizedStringKey
    var isSelected = false
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.glassIcon)
                .foregroundStyle(isSelected ? Theme.onAccent : Theme.body)
                .frame(width: 44, height: 44)
                .background {
                    if isSelected {
                        Circle().fill(Theme.accent)
                    } else {
                        Circle().fill(.clear).glassEffect(.regular, in: .circle)
                    }
                }
        }
        .buttonStyle(PressStyle(scale: 0.94))
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : Theme.disabledOpacity)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// The two glass capsules at the top of the editor (design.md §6): 44 high, corner 23, a 21 pt
/// symbol and 17 semibold text in white 6 apart, 12 inside. From accessibility text sizes on only
/// the symbol stays; the name is still what VoiceOver reads (§9.5).
struct GlassLabelButton: View {
    let systemImage: String
    let title: LocalizedStringKey
    var isEnabled = true
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    private var showsTitle: Bool { !typeSize.isAccessibilitySize }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage).font(.glassIcon)
                if showsTitle {
                    Text(title).font(.buttonText).lineLimit(1).minimumScaleFactor(0.85)
                }
            }
            .foregroundStyle(Theme.body)
            .padding(.horizontal, showsTitle ? 12 : 11.5)
            .frame(height: 44)
            .glassEffect(.regular, in: .capsule)
        }
        .buttonStyle(PressStyle(scale: 0.94))
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : Theme.disabledOpacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
    }
}

/// 「匯出」on the glass bar (design.md §6): 44 high, corner 23, at least 100 wide, solid `#7B2FE0`
/// rather than glass, which would let the picture show through under white text. From accessibility
/// text sizes on only a symbol stays (§9.5); the spec names none for it, so this is
/// `square.and.arrow.up`.
struct ExportButton: View {
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    private var showsTitle: Bool { !typeSize.isAccessibilitySize }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if !showsTitle {
                    Image(systemName: "square.and.arrow.up").font(.glassIcon)
                }
                if showsTitle {
                    Text("4.9.1").font(.buttonText).lineLimit(1).minimumScaleFactor(0.85)
                }
            }
            .foregroundStyle(Theme.body)
            .padding(.horizontal, 20)
            .frame(minWidth: 100)
            .frame(height: 44)
            .background(Capsule().fill(Theme.accentButton))
        }
        .buttonStyle(PressStyle(scale: 0.94))
        .accessibilityLabel("4.9.1")
    }
}

/// A capsule of glass over the picture (design.md §4): 36 high, corner 18, 14 inside, white
/// `.subheadline`, centred. 4.8.4 and 4.8.5 are medium;「原圖」(4.8.6) is semibold.
struct GlassCapsule: View {
    let text: LocalizedStringKey
    var weight: Font.Weight = .medium

    var body: some View {
        Text(text)
            .font(.subheadline.weight(weight))
            .foregroundStyle(Theme.body)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .glassEffect(.regular, in: .capsule)
    }
}
