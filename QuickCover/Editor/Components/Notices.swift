import SwiftUI

/// Adaptive inline advisory banner using iOS 26 concentric geometry and `ViewThatFits` layout so
/// short messages share a row with their action while longer warnings stack cleanly without clipping.
struct NoticeBar<Trailing: View>: View {
    let systemImage: String
    let tint: Color
    let ground: Color
    let text: LocalizedStringKey
    var stacksWhenTooWide = false
    @ViewBuilder let trailing: () -> Trailing
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        symbol
                        words
                    }
                    trailing()
                }
            } else if stacksWhenTooWide {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        symbol
                        words.fixedSize(horizontal: true, vertical: false)
                        Spacer(minLength: 0)
                        trailing()
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 10) {
                            symbol
                            words
                        }
                        HStack(spacing: 10) {
                            symbol.hidden()
                            trailing()
                        }
                    }
                }
            } else {
                HStack(spacing: 10) {
                    symbol
                    words
                    trailing()
                        .layoutPriority(1)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .background(
            ConcentricRectangle(corners: .concentric(minimum: 16), isUniform: true)
                .fill(ground)
        )
        .overlay(
            ConcentricRectangle(corners: .concentric(minimum: 16), isUniform: true)
                .stroke(tint.opacity(0.22), lineWidth: 0.5)
        )
    }

    private var symbol: some View {
        Image(systemName: systemImage)
            .font(.noticeIcon)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            .accessibilityHidden(true)
    }

    private var words: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Theme.body)
            .lineLimit(typeSize.isAccessibilitySize || stacksWhenTooWide ? nil : 3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Compact Apple-style Liquid Glass studio callout for empty or failed recognition states.
/// Deliberately proportioned so the photo canvas remains the hero above the card.
struct CalloutCard<Action: View>: View {
    let systemImage: String
    var tint: Color = Theme.accentOnBlack
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var readsTogether = false
    @ViewBuilder let action: () -> Action

    var body: some View {
        let shape = ConcentricRectangle(corners: .concentric(minimum: 26), isUniform: true)
        VStack(spacing: 14) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.16))
                        .frame(width: 44, height: 44)
                    Image(systemName: systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(tint)
                }
                .accessibilityHidden(true)

                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .lineSpacing(1.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 4)
            }
            .accessibilityElement(children: readsTogether ? .combine : .contain)

            action()
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: shape)
        .overlay(
            shape.stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
    }
}

/// Floating Liquid Glass confirmation toast ("Saved to Photos" / "Copied") with animated SF Symbol.
struct Toast: View {
    let text: LocalizedStringKey
    let isShown: Bool
    var fadeIn: Double = 0.25
    var fadeOut: Double = 0.3

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 19, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.saved)
                .symbolEffect(.bounce, value: isShown)
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.leading, 12)
        .padding(.trailing, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 40)
        .glassEffect(.regular, in: .capsule)
        .opacity(isShown ? 1 : 0)
        .scaleEffect(isShown ? 1 : 0.94)
        .offset(y: isShown ? 0 : -8)
        .animation(.snappy(duration: isShown ? fadeIn : fadeOut), value: isShown)
        .allowsHitTesting(false)
    }
}

/// Summary headline at the top of Review Each Item.
struct SummaryText: View {
    let found: FoundCounts

    var body: some View {
        Text(L10n.summary(found))
            .font(.title2.bold())
            .foregroundStyle(Theme.body)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(L10n.screenReaderSummary(found))
    }
}

/// Continuous-corner App Icon presentation for PrimerScreen, adapting smoothly to Light and Dark Mode.
struct IconArtwork: View {
    var size: CGFloat = 104
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let radius = size * (29.5 / 132.0)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        Image("IconArtwork")
            .resizable()
            .frame(width: size, height: size)
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(
                    colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.08),
                    lineWidth: 0.75
                )
            )
            .shadow(
                color: colorScheme == .dark ? .black.opacity(0.5) : .black.opacity(0.16),
                radius: size * 0.16,
                y: size * 0.08
            )
            .accessibilityHidden(true)
    }
}
