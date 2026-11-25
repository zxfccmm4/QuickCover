import SwiftUI

/// First-party Apple Welcome screen for initial Photo Library onboarding.
/// Combines the adaptive App Icon, 3-item privacy & capability highlights, concentric limited-access
/// note, and iOS 26 `.safeAreaBar` Liquid Glass CTAs.
struct PrimerScreen: View {
    @Environment(ShellModel.self) private var shell
    @Environment(\.dynamicTypeSize) private var typeSize

    private var buttonsScroll: Bool { typeSize.isAccessibilitySize }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                IconArtwork()
                    .padding(.top, 16)
                    .padding(.bottom, 22)

                Text("3.2.1")
                    .font(.title.bold())
                    .foregroundStyle(Theme.body)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)

                Text("3.2.2")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.bottom, 26)

                VStack(alignment: .leading, spacing: 18) {
                    FeatureHighlightRow(
                        systemImage: "sparkles",
                        title: "primer.feat1.title",
                        description: "primer.feat1.body"
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
                .padding(.horizontal, 4)
                .padding(.bottom, 24)

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
                    .padding(.top, 8)
                    .padding(.bottom, 16)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var limitedAccessNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "photo.stack")
                .font(.subheadline.weight(.semibold))
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
        .background(
            ConcentricRectangle(corners: .concentric(minimum: 16), isUniform: true)
                .fill(Theme.card)
        )
    }

    private var actionStack: some View {
        GlassEffectContainer(spacing: 8) {
            VStack(spacing: 8) {
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

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.accent)
                .frame(width: 40, height: 40)
                .background(
                    ConcentricRectangle(corners: .concentric(minimum: 12), isUniform: true)
                        .fill(Theme.accent.opacity(0.12))
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.body)
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryLabel)
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
