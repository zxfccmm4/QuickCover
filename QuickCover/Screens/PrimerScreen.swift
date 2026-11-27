import SwiftUI

/// First-party Apple Welcome screen for initial Photo Library onboarding.
/// Follows Apple's OnboardingKit rhythm: continuous-corner App Icon, bold display heading,
/// unboxed hierarchical SF Symbol highlights, quiet limited-access explanation, and `.safeAreaBar`
/// Liquid Glass CTAs.
struct PrimerScreen: View {
    @Environment(ShellModel.self) private var shell
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var typeSize

    private var buttonsScroll: Bool { typeSize.isAccessibilitySize }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                IconArtwork(size: 96)
                    .padding(.top, 28)
                    .padding(.bottom, 22)

                Text("3.2.1")
                    .font(.title.bold())
                    .foregroundStyle(Theme.body)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 10)

                Text("3.2.2")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .frame(maxWidth: 320)
                    .padding(.bottom, 32)

                VStack(alignment: .leading, spacing: 22) {
                    FeatureHighlightRow(
                        systemImage: "sparkles",
                        title: "primer.feat1.title",
                        description: "primer.feat1.body",
                        usesIntelligenceTint: true
                    )
                    FeatureHighlightRow(
                        systemImage: "swatchpalette",
                        title: "primer.feat2.title",
                        description: "primer.feat2.body"
                    )
                    FeatureHighlightRow(
                        systemImage: "lock.shield.fill",
                        title: "primer.feat3.title",
                        description: "primer.feat3.body"
                    )
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 28)

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
    }

    private var limitedAccessNote: some View {
        let shape = ConcentricRectangle(corners: .concentric(minimum: 16), isUniform: true)
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "photo.stack")
                .font(.subheadline.weight(.medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.accent)
                .padding(.top, 1)
                .accessibilityHidden(true)
            Text("3.2.6")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryLabel)
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
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    var usesIntelligenceTint = false

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 25, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(
                    usesIntelligenceTint
                        ? AnyShapeStyle(AppleIntelligencePalette.linearGradient)
                        : AnyShapeStyle(Theme.accent)
                )
                .frame(width: 34, height: 34, alignment: .center)
                .padding(.top, 1)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.body)
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryLabel)
                    .lineSpacing(1.5)
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
