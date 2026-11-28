import SwiftUI

/// First-party Apple Welcome screen for initial Photo Library onboarding.
/// Follows Apple's OnboardingKit rhythm: ambient top radial wash, continuous-corner App Icon,
/// bold display heading, tinted squircle SF Symbol feature rows, quiet limited-access card, and
/// `.safeAreaBar` Liquid Glass CTAs.
struct PrimerScreen: View {
    @Environment(ShellModel.self) private var shell
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appeared = false

    private var buttonsScroll: Bool { typeSize.isAccessibilitySize }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZStack {
                    // Subtle Apple-style ambient halo behind the app icon
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Theme.accent.opacity(colorScheme == .dark ? 0.24 : 0.14),
                                    Color.purple.opacity(colorScheme == .dark ? 0.10 : 0.05),
                                    .clear,
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 96
                            )
                        )
                        .frame(width: 192, height: 192)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)

                    IconArtwork(size: 96)
                }
                .padding(.top, 12)
                .padding(.bottom, 10)
                .scaleEffect(appeared || reduceMotion ? 1 : 0.92)
                .opacity(appeared || reduceMotion ? 1 : 0)

                Text("3.2.1")
                    .font(.title.bold())
                    .foregroundStyle(Theme.body)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 10)

                Text("3.2.2")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2.5)
                    .frame(maxWidth: 320)
                    .padding(.bottom, 30)

                VStack(alignment: .leading, spacing: 20) {
                    FeatureHighlightRow(
                        systemImage: "sparkles",
                        tint: .purple,
                        usesIntelligenceTint: true,
                        title: "primer.feat1.title",
                        description: "primer.feat1.body"
                    )
                    FeatureHighlightRow(
                        systemImage: "swatchpalette.fill",
                        tint: Theme.accent,
                        title: "primer.feat2.title",
                        description: "primer.feat2.body"
                    )
                    FeatureHighlightRow(
                        systemImage: "lock.shield.fill",
                        tint: .green,
                        title: "primer.feat3.title",
                        description: "primer.feat3.body"
                    )
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 26)
                .offset(y: appeared || reduceMotion ? 0 : 12)
                .opacity(appeared || reduceMotion ? 1 : 0)

                limitedAccessNote

                if buttonsScroll {
                    actionStack
                        .padding(.top, 24)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollEdgeEffectStyle(.soft, for: .all)
        .background(Theme.page.ignoresSafeArea())
        .safeAreaBar(edge: .bottom, spacing: 0) {
            if !buttonsScroll {
                actionStack
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .padding(.bottom, 16)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    AboutScreen()
                } label: {
                    Label("about.title", systemImage: "info.circle")
                }
                .accessibilityLabel("about.title")
            }
        }
        .onAppear {
            guard !appeared else { return }
            withAnimation(reduceMotion ? nil : .spring(duration: 0.55, bounce: 0.25)) {
                appeared = true
            }
        }
    }

    private var limitedAccessNote: some View {
        let shape = ConcentricRectangle(corners: .concentric(minimum: 16), isUniform: true)
        return HStack(alignment: .top, spacing: 11) {
            Image(systemName: "photo.stack.fill")
                .font(.subheadline.weight(.medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.accent)
                .frame(width: 26, height: 26)
                .background(
                    Theme.accent.opacity(colorScheme == .dark ? 0.16 : 0.10),
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
                .accessibilityHidden(true)
            Text("3.2.6")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryLabel)
                .lineSpacing(1.5)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(shape.fill(Theme.card))
        .overlay(shape.stroke(Theme.cardBorder(for: colorScheme), lineWidth: 0.5))
    }

    private var actionStack: some View {
        GlassEffectContainer(spacing: 8) {
            VStack(spacing: 6) {
                PrimaryButton(title: "3.2.3") {
                    Task { await shell.allowAccess() }
                }
                PlainTextButton(title: "3.2.4") {
                    shell.showPicker()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct FeatureHighlightRow: View {
    let systemImage: String
    let tint: Color
    var usesIntelligenceTint = false
    let title: LocalizedStringKey
    let description: LocalizedStringKey

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(
                    usesIntelligenceTint
                        ? AnyShapeStyle(AppleIntelligencePalette.linearGradient)
                        : AnyShapeStyle(tint)
                )
                .frame(width: 40, height: 40)
                .background(
                    tint.opacity(colorScheme == .dark ? 0.18 : 0.12),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
                .padding(.top, 1)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.body)
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryLabel)
                    .lineSpacing(1.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview("Primer Light") {
    NavigationStack {
        PrimerScreen()
    }
    .environment(ShellModel())
    .tint(Theme.accent)
    .preferredColorScheme(.light)
}

#Preview("Primer Dark") {
    NavigationStack {
        PrimerScreen()
    }
    .environment(ShellModel())
    .tint(Theme.accent)
    .preferredColorScheme(.dark)
}
