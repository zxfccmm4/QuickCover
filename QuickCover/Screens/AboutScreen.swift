import SwiftUI
import UIKit

/// Apple-native About screen modeled after Tamio's AboutView:
/// - Interactive continuous-corner App Icon header with spring wiggle and one-tap version copy
/// - Overview & 6 Core Capabilities pushing to rich detail pages with native zoom transitions
/// - Connect links with optically normalized brand icons (X, Telegram, Mail, GitHub)
/// - Special Thanks & Apple framework acknowledgements
/// - Privacy Policy & Open Source Notice + interactive Made-With-Love footer
struct AboutScreen: View {
    @ScaledMetric private var iconColumnWidth: CGFloat = 28
    @State private var loveCount = 0
    @Namespace private var zoomNamespace

    var body: some View {
        Form {
            Section {
                AboutHeaderView()
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("about.overview.primary")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("about.overview.secondary")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 2)
            } header: {
                Text("about.section.overview")
            }

            Section("about.section.capabilities") {
                ForEach(QuickCoverCapability.all) { capability in
                    NavigationLink {
                        AboutCapabilityDetailView(capability: capability, namespace: zoomNamespace)
                    } label: {
                        capabilityRow(capability)
                            .matchedTransitionSource(id: capability.id, in: zoomNamespace)
                    }
                }
            }

            Section("about.section.connect") {
                ForEach(AboutLinkItem.social) { link in
                    AboutLinkRow(link: link)
                }
            }

            Section("about.section.thanks") {
                ForEach(AboutLinkItem.acknowledgements) { link in
                    AboutLinkRow(link: link)
                }
            }

            Section {
                NavigationLink {
                    QuickCoverPrivacyPolicyView()
                } label: {
                    legalRow(
                        systemImage: "hand.raised.fill",
                        tint: .blue,
                        titleKey: "about.legal.privacy"
                    )
                }

                NavigationLink {
                    QuickCoverNoticeView()
                } label: {
                    legalRow(
                        systemImage: "doc.text.fill",
                        tint: .indigo,
                        titleKey: "about.legal.license"
                    )
                }
            } header: {
                Text("about.section.legal")
            } footer: {
                Text("about.legal.footer")
            }

            Section {
                madeByButton
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
        }
        .navigationTitle("about.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func capabilityRow(_ capability: QuickCoverCapability) -> some View {
        HStack(spacing: 12) {
            Image(systemName: capability.systemImage)
                .font(.title3.weight(.medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(
                    capability.usesIntelligenceGradient
                        ? AnyShapeStyle(AppleIntelligencePalette.linearGradient)
                        : AnyShapeStyle(capability.tint)
                )
                .frame(width: min(iconColumnWidth, 38), height: min(iconColumnWidth, 38))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(capability.titleKey))
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(LocalizedStringKey(capability.subtitleKey))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
        }
        .padding(.vertical, 1)
    }

    private func legalRow(systemImage: String, tint: Color, titleKey: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3.weight(.medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: min(iconColumnWidth, 38), height: min(iconColumnWidth, 38))
                .accessibilityHidden(true)

            Text(titleKey)
                .font(.body)
                .foregroundStyle(.primary)
                .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
        }
        .padding(.vertical, 1)
    }

    private var madeByButton: some View {
        Button {
            loveCount += 1
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                    .symbolEffect(.bounce, value: loveCount)
                Text("about.madeWithLove")
                    .foregroundStyle(.tertiary)
            }
            .font(.footnote)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: loveCount)
    }
}

// MARK: - Header View

private struct AboutHeaderView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric private var logoSize: CGFloat = 84

    @State private var iconTapCount = 0
    @State private var iconWiggling = false
    @State private var copyTrigger = 0
    @State private var copiedVersion = false

    private var shortVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var versionString: String {
        L10n.aboutVersion(shortVersion, build: buildNumber)
    }

    var body: some View {
        let clampedLogoSize = min(logoSize, 112)

        VStack(spacing: 6) {
            Button {
                iconTapCount += 1
                guard !reduceMotion else { return }
                withAnimation(.spring(duration: 0.22, bounce: 0.5)) {
                    iconWiggling = true
                }
            } label: {
                IconArtwork(size: clampedLogoSize)
                    .rotationEffect(.degrees(iconWiggling && !reduceMotion ? 8 : 0))
                    .scaleEffect(iconWiggling && !reduceMotion ? 1.04 : 1.0)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 6)
            .accessibilityHidden(true)
            .sensoryFeedback(.impact(flexibility: .soft), trigger: iconTapCount)
            .task(id: iconTapCount) {
                guard iconTapCount > 0, !reduceMotion else { return }
                try? await Task.sleep(for: .milliseconds(220))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(duration: 0.45, bounce: 0.55)) {
                    iconWiggling = false
                }
            }

            Text("about.appName")
                .font(.title2.bold())
                .foregroundStyle(.primary)

            Text("about.tagline")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                copyVersion()
            } label: {
                HStack(spacing: 4) {
                    Text(verbatim: versionString)
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.tertiary)

                    Image(systemName: copiedVersion ? "checkmark.circle.fill" : "doc.on.doc")
                        .font(.caption2)
                        .foregroundStyle(copiedVersion ? AnyShapeStyle(.green) : AnyShapeStyle(.quaternary))
                        .contentTransition(.symbolEffect(.replace))
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(versionString), \(L10n.text("6.1.5"))")
            .sensoryFeedback(.success, trigger: copyTrigger)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .task(id: copyTrigger) {
            guard copyTrigger > 0 else { return }
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
                copiedVersion = false
            }
        }
    }

    private func copyVersion() {
        UIPasteboard.general.string = "QuickCover \(shortVersion) (\(buildNumber))"
        copyTrigger += 1
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
            copiedVersion = true
        }
    }
}

// MARK: - Feature Icon Badge

private struct AboutFeatureBadge: View {
    let systemName: String
    let tint: Color
    var usesIntelligenceGradient = false
    var size: CGFloat = 56

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.46, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(
                usesIntelligenceGradient
                    ? AnyShapeStyle(AppleIntelligencePalette.linearGradient)
                    : AnyShapeStyle(tint)
            )
            .frame(width: size, height: size)
            .background(
                tint.opacity(0.13),
                in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            )
    }
}

// MARK: - Capabilities Model & Detail View

private struct QuickCoverCapability: Identifiable, Hashable {
    let id: String
    let titleKey: String
    let subtitleKey: String
    let detailKey: String
    let highlightKeys: [String]
    let systemImage: String
    let tint: Color
    var usesIntelligenceGradient = false
    let docsURL: URL?

    static let all: [QuickCoverCapability] = [
        QuickCoverCapability(
            id: "apple-intelligence",
            titleKey: "about.cap.ai.title",
            subtitleKey: "about.cap.ai.sub",
            detailKey: "about.cap.ai.detail",
            highlightKeys: ["about.cap.ai.h1", "about.cap.ai.h2"],
            systemImage: "sparkles",
            tint: .purple,
            usesIntelligenceGradient: true,
            docsURL: URL(string: "https://github.com/zxfccmm4/QuickCover")
        ),
        QuickCoverCapability(
            id: "vision-detection",
            titleKey: "about.cap.vision.title",
            subtitleKey: "about.cap.vision.sub",
            detailKey: "about.cap.vision.detail",
            highlightKeys: ["about.cap.vision.h1", "about.cap.vision.h2"],
            systemImage: "viewfinder",
            tint: .blue,
            docsURL: URL(string: "https://github.com/zxfccmm4/QuickCover")
        ),
        QuickCoverCapability(
            id: "magic-erase",
            titleKey: "about.cap.magic.title",
            subtitleKey: "about.cap.magic.sub",
            detailKey: "about.cap.magic.detail",
            highlightKeys: ["about.cap.magic.h1", "about.cap.magic.h2"],
            systemImage: "wand.and.stars",
            tint: .indigo,
            docsURL: URL(string: "https://github.com/zxfccmm4/QuickCover")
        ),
        QuickCoverCapability(
            id: "styles-colors-emoji",
            titleKey: "about.cap.styles.title",
            subtitleKey: "about.cap.styles.sub",
            detailKey: "about.cap.styles.detail",
            highlightKeys: ["about.cap.styles.h1", "about.cap.styles.h2"],
            systemImage: "swatchpalette.fill",
            tint: .teal,
            docsURL: URL(string: "https://github.com/zxfccmm4/QuickCover/releases")
        ),
        QuickCoverCapability(
            id: "watermark-scanner",
            titleKey: "about.cap.tools.title",
            subtitleKey: "about.cap.tools.sub",
            detailKey: "about.cap.tools.detail",
            highlightKeys: ["about.cap.tools.h1", "about.cap.tools.h2"],
            systemImage: "checkerboard.shield",
            tint: .orange,
            docsURL: URL(string: "https://github.com/zxfccmm4/QuickCover")
        ),
        QuickCoverCapability(
            id: "offline-privacy",
            titleKey: "about.cap.privacy.title",
            subtitleKey: "about.cap.privacy.sub",
            detailKey: "about.cap.privacy.detail",
            highlightKeys: ["about.cap.privacy.h1", "about.cap.privacy.h2"],
            systemImage: "lock.shield.fill",
            tint: .green,
            docsURL: URL(string: "https://github.com/zxfccmm4/QuickCover")
        ),
    ]
}

private struct AboutCapabilityDetailView: View {
    let capability: QuickCoverCapability
    let namespace: Namespace.ID
    @ScaledMetric private var emblemSize: CGFloat = 56

    var body: some View {
        let clamped = min(emblemSize, 72)

        Form {
            Section {
                VStack(spacing: 8) {
                    AboutFeatureBadge(
                        systemName: capability.systemImage,
                        tint: capability.tint,
                        usesIntelligenceGradient: capability.usesIntelligenceGradient,
                        size: clamped
                    )
                    .padding(.bottom, 4)
                    .accessibilityHidden(true)

                    Text(LocalizedStringKey(capability.titleKey))
                        .font(.title2.bold())
                        .foregroundStyle(.primary)

                    Text(LocalizedStringKey(capability.subtitleKey))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))

            Section("about.section.overview") {
                Text(LocalizedStringKey(capability.detailKey))
                    .font(.body)
                    .lineSpacing(3)
            }

            Section("about.section.highlights") {
                ForEach(capability.highlightKeys, id: \.self) { key in
                    Label {
                        Text(LocalizedStringKey(key))
                            .font(.body)
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(capability.tint)
                    }
                }
            }

            if let docsURL = capability.docsURL {
                Section("about.section.resources") {
                    AboutLinkRow(
                        link: AboutLinkItem(
                            id: "learn-\(capability.id)",
                            title: Text("about.learnMore"),
                            subtitle: docsURL.host().map { Text(verbatim: $0) },
                            icon: .symbol("safari.fill", tint: .blue),
                            url: docsURL
                        )
                    )
                }
            }
        }
        .navigationTransition(.zoom(sourceID: capability.id, in: namespace))
        .navigationTitle(LocalizedStringKey(capability.titleKey))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Link Item & Row

private struct AboutLinkItem: Identifiable {
    enum Icon {
        case asset(String)
        case github
        case symbol(String, tint: Color)
    }

    let id: String
    let title: Text
    var subtitle: Text? = nil
    let icon: Icon
    let url: URL?

    static var social: [AboutLinkItem] {
        [
            AboutLinkItem(
                id: "x",
                title: Text("about.social.x"),
                subtitle: Text(verbatim: "@st7evechou"),
                icon: .asset("symbol.twitter.icon"),
                url: URL(string: "https://twitter.com/st7evechou")
            ),
            AboutLinkItem(
                id: "telegram",
                title: Text("about.social.telegram"),
                subtitle: Text(verbatim: "@st7evee"),
                icon: .asset("Telegramicon"),
                url: URL(string: "https://t.me/st7evee")
            ),
            AboutLinkItem(
                id: "feedback",
                title: Text("about.social.feedback"),
                subtitle: Text("about.social.feedbackSub"),
                icon: .asset("Mail"),
                url: URL(string: "mailto:zxfccmm@gmail.com?subject=Feedback%20for%20QuickCover")
            ),
            AboutLinkItem(
                id: "github",
                title: Text("about.social.github"),
                subtitle: Text(verbatim: "zxfccmm4/QuickCover"),
                icon: .github,
                url: URL(string: "https://github.com/zxfccmm4/QuickCover")
            ),
        ]
    }

    static var acknowledgements: [AboutLinkItem] {
        [
            AboutLinkItem(
                id: "contributors",
                title: Text("about.thanks.contributors"),
                subtitle: Text(verbatim: "@zxfccmm4"),
                icon: .symbol("person.2.fill", tint: .blue),
                url: URL(string: "https://github.com/zxfccmm4/QuickCover/graphs/contributors")
            ),
            AboutLinkItem(
                id: "vision",
                title: Text(verbatim: "Apple Vision & VisionKit"),
                subtitle: Text("about.thanks.visionSub"),
                icon: .symbol("eye.fill", tint: .teal),
                url: URL(string: "https://developer.apple.com/documentation/vision")
            ),
            AboutLinkItem(
                id: "foundationmodels",
                title: Text(verbatim: "Apple FoundationModels"),
                subtitle: Text("about.thanks.aiSub"),
                icon: .symbol("sparkles", tint: .purple),
                url: URL(string: "https://developer.apple.com/documentation/foundationmodels")
            ),
            AboutLinkItem(
                id: "swiftui",
                title: Text(verbatim: "SwiftUI & Liquid Glass"),
                subtitle: Text("about.thanks.swiftuiSub"),
                icon: .symbol("swift", tint: .orange),
                url: URL(string: "https://developer.apple.com/xcode/swiftui/")
            ),
            AboutLinkItem(
                id: "airbuild",
                title: Text(verbatim: "AirBuild"),
                subtitle: Text("about.thanks.airbuildSub"),
                icon: .symbol("hammer.fill", tint: .indigo),
                url: URL(string: "https://air.build/?utm_source=made-with-airbuild&utm_medium=ios-app")
            ),
        ]
    }
}

private struct AboutLinkRow: View {
    let link: AboutLinkItem

    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric private var iconColumnWidth: CGFloat = 28

    var body: some View {
        if let url = link.url {
            Link(destination: url) {
                HStack(spacing: 12) {
                    icon
                        .frame(width: min(iconColumnWidth, 38), height: min(iconColumnWidth, 38))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        link.title
                            .font(.body)
                            .foregroundStyle(.primary)

                        if let subtitle = link.subtitle {
                            subtitle
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }

                    Spacer(minLength: 8)

                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 1)
                .contentShape(.rect)
            }
            .accessibilityAddTraits(.isLink)
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch link.icon {
        case .asset(let name):
            normalizedAssetIcon(name)
        case .github:
            Image(colorScheme == .dark ? "github-mark-white" : "github-mark")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
        case .symbol(let name, let tint):
            Image(systemName: name)
                .font(.title3.weight(.medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
        }
    }

    @ViewBuilder
    private func normalizedAssetIcon(_ name: String) -> some View {
        if name == "symbol.twitter.icon" {
            let badgeSize: CGFloat = 26
            let cornerRadius = badgeSize * 0.2237
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(white: 0.12))
                Image(name)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .foregroundStyle(.white)
            }
            .frame(width: badgeSize, height: badgeSize)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.primary.opacity(0.12), lineWidth: 0.5)
            }
        } else if name == "Mail" {
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: 28.5, height: 28.5)
        } else {
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
        }
    }
}

// MARK: - Privacy Policy View

private struct QuickCoverPrivacyPolicyView: View {
    private struct CommitmentItem: Identifiable {
        let id: Int
        let icon: String
        let tint: Color
        let textKey: LocalizedStringKey
    }

    private static let commitments: [CommitmentItem] = [
        .init(id: 1, icon: "iphone", tint: .teal, textKey: "about.privacy.p1"),
        .init(id: 2, icon: "sparkles", tint: .purple, textKey: "about.privacy.p2"),
        .init(id: 3, icon: "photo.badge.checkmark", tint: .blue, textKey: "about.privacy.p3"),
        .init(id: 4, icon: "location.slash.fill", tint: .orange, textKey: "about.privacy.p4"),
        .init(id: 5, icon: "hand.raised.fill", tint: .green, textKey: "about.privacy.p5"),
    ]

    var body: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    AboutFeatureBadge(systemName: "hand.raised.fill", tint: .blue, size: 56)
                        .accessibilityHidden(true)

                    Text("about.legal.privacy")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))

            Section {
                ForEach(Self.commitments) { item in
                    HStack(alignment: .top, spacing: 12) {
                        AboutFeatureBadge(systemName: item.icon, tint: item.tint, size: 28)
                            .padding(.top, 2)
                            .accessibilityHidden(true)

                        Text(item.textKey)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("about.legal.privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Open Source & Notice View

private struct QuickCoverNoticeView: View {
    var body: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    AboutFeatureBadge(systemName: "doc.text.fill", tint: .indigo, size: 56)
                        .accessibilityHidden(true)

                    Text("about.legal.license")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 4, trailing: 16))

            Section("about.license.section.deps") {
                Text("about.license.depsBody")
                    .font(.body)
                    .lineSpacing(3)
            }

            Section("about.license.section.sdk") {
                Text("about.license.sdkBody")
                    .font(.body)
                    .lineSpacing(3)
            }

            Section("about.section.resources") {
                AboutLinkRow(
                    link: AboutLinkItem(
                        id: "repo",
                        title: Text("about.social.github"),
                        subtitle: Text(verbatim: "github.com/zxfccmm4/QuickCover"),
                        icon: .github,
                        url: URL(string: "https://github.com/zxfccmm4/QuickCover")
                    )
                )
                AboutLinkRow(
                    link: AboutLinkItem(
                        id: "releases",
                        title: Text("about.license.releases"),
                        subtitle: Text("about.license.releasesSub"),
                        icon: .symbol("shippingbox.fill", tint: .teal),
                        url: URL(string: "https://github.com/zxfccmm4/QuickCover/releases")
                    )
                )
            }
        }
        .navigationTitle("about.legal.license")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("About Light") {
    NavigationStack {
        AboutScreen()
    }
    .tint(Theme.accent)
    .preferredColorScheme(.light)
}

#Preview("About Dark") {
    NavigationStack {
        AboutScreen()
    }
    .tint(Theme.accent)
    .preferredColorScheme(.dark)
}
