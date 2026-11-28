import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Apple-native three-tier "What's New" sheet:
/// 1. Centered header (App Icon + bold title + monospaced version pill)
/// 2. Scrollable, max-440pt centered feature list with borderless hierarchical SF Symbols
/// 3. Fixed bottom action dock (frosted ultraThinMaterial on mobile; hairline-divided bar on desktop)
struct WhatsNewSheet: View {
    let presentation: WhatsNewPresentation
    let onContinue: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private static let entranceSpring = Animation.spring(response: 0.45, dampingFraction: 0.86)
    private static let maxContentWidth: CGFloat = 440

    private var features: [WhatsNewFeature] {
        presentation.release.features(for: .current)
    }

    private var isRevealed: Bool {
        appeared || reduceMotion
    }

    var body: some View {
        #if os(macOS)
        desktopBody
        #else
        mobileBody
        #endif
    }

    // MARK: - Mobile Layout (iOS / iPadOS)

    #if !os(macOS)
    private var mobileBody: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    headerSection
                        .padding(.top, presentation.mode.showsCloseButton ? 8 : 36)

                    featureListSection
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Color(.systemBackground).ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                mobileFooter
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if presentation.mode.showsCloseButton {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            onContinue()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.semibold))
                        }
                        .accessibilityLabel("whatsnew.close")
                        .keyboardShortcut(.cancelAction)
                    }
                }
            }
            .toolbar(presentation.mode.showsCloseButton ? .visible : .hidden, for: .navigationBar)
        }
        .tint(Theme.accent)
        .task {
            await triggerEntranceIfNeeded()
        }
    }

    private var mobileFooter: some View {
        VStack(spacing: 12) {
            releaseNotesLink
                .frame(maxWidth: .infinity)

            Button(action: onContinue) {
                Text("whatsnew.continue")
                    .font(.body.weight(.semibold))
                    .lineLimit(nil)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .buttonSizing(.flexible)
            .controlSize(.large)
            .tint(Theme.accentButton)
            .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: Self.maxContentWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.08))
                .frame(height: 0.5)
        }
    }
    #endif

    // MARK: - Desktop Layout (macOS)

    #if os(macOS)
    private var desktopBody: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    headerSection
                        .padding(.top, 32)

                    featureListSection
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }

            Rectangle()
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.10))
                .frame(height: 1)

            HStack(spacing: 16) {
                releaseNotesLink

                Spacer(minLength: 12)

                Button("whatsnew.continue", action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(Theme.accentButton)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 480, height: 580)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay {
            Button(action: onContinue) { EmptyView() }
                .keyboardShortcut(.cancelAction)
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
        .task {
            await triggerEntranceIfNeeded()
        }
    }
    #endif

    // MARK: - Shared Header & Feature List

    private var headerSection: some View {
        VStack(spacing: 14) {
            WhatsNewAppIcon()
                .padding(.bottom, 2)

            Text("whatsnew.title")
                .font(titleFont)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(verbatim: L10n.whatsNewVersion(presentation.displayVersion))
                .font(.footnote.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    Theme.accent.opacity(colorScheme == .dark ? 0.18 : 0.12),
                    in: Capsule()
                )
        }
        .frame(maxWidth: Self.maxContentWidth)
        .opacity(isRevealed ? 1 : 0)
        .offset(y: isRevealed ? 0 : 7)
        .animation(reduceMotion ? nil : Self.entranceSpring, value: appeared)
    }

    private var featureListSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                WhatsNewFeatureRow(feature: feature)
                    .opacity(isRevealed ? 1 : 0)
                    .offset(y: isRevealed ? 0 : 11)
                    .animation(
                        reduceMotion
                            ? nil
                            : Self.entranceSpring.delay(Double(index + 1) * 0.05),
                        value: appeared
                    )
            }
        }
        .frame(maxWidth: Self.maxContentWidth, alignment: .leading)
    }

    private var releaseNotesLink: some View {
        Link(destination: presentation.release.releaseNotesURL) {
            HStack(spacing: 4) {
                Text("whatsnew.releaseNotes")
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Theme.accent)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
    }

    private var titleFont: Font {
        #if os(macOS)
        .system(size: 26, weight: .bold)
        #else
        .largeTitle.bold()
        #endif
    }

    private func triggerEntranceIfNeeded() async {
        guard !appeared else { return }
        if reduceMotion {
            appeared = true
            return
        }
        // Let the sheet commit its initial layout frame before starting the staggered spring reveal.
        try? await Task.sleep(for: .milliseconds(30))
        guard !Task.isCancelled else { return }
        appeared = true
    }
}

// MARK: - App Icon

private struct WhatsNewAppIcon: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        #if os(macOS)
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable()
            .scaledToFit()
            .frame(width: 56, height: 56)
            .accessibilityHidden(true)
        #else
        let size: CGFloat = 64
        let cornerRadius = size * 0.2237
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        Image("IconArtwork")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(
                    Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.08),
                    lineWidth: 0.5
                )
            }
            .shadow(
                color: Theme.accent.opacity(colorScheme == .dark ? 0.28 : 0.20),
                radius: 12,
                y: 5
            )
            .accessibilityHidden(true)
        #endif
    }
}

// MARK: - Feature Row

private struct WhatsNewFeatureRow: View {
    let feature: WhatsNewFeature

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: feature.systemImage)
                .font(.system(size: 26, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(feature.accent.color)
                .frame(width: 32, height: 32, alignment: .center)
                .padding(.top, 1)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(feature.titleKey))
                    .font(rowTitleFont)
                    .foregroundStyle(.primary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                Text(LocalizedStringKey(feature.descriptionKey))
                    .font(rowDescriptionFont)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2.5)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var rowTitleFont: Font {
        #if os(macOS)
        .system(size: 14, weight: .semibold)
        #else
        .headline
        #endif
    }

    private var rowDescriptionFont: Font {
        #if os(macOS)
        .system(size: 12.5)
        #else
        .subheadline
        #endif
    }
}

#Preview("Auto Light") {
    WhatsNewSheet(
        presentation: WhatsNewPresentation(
            release: WhatsNewCatalog.releases[0],
            displayVersion: "1.1 (6)",
            mode: .automatic
        ),
        onContinue: {}
    )
    .preferredColorScheme(.light)
}

#Preview("Manual Dark") {
    WhatsNewSheet(
        presentation: WhatsNewPresentation(
            release: WhatsNewCatalog.releases[0],
            displayVersion: "1.1 (6)",
            mode: .manual
        ),
        onContinue: {}
    )
    .preferredColorScheme(.dark)
}
