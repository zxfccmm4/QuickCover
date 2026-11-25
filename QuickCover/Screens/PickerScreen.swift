import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Native Apple iOS 26/27 Import Hub inspired by DAMA, Picsew, and Apple Shortcuts:
/// features an optional recent-screenshots carousel, 2-column concentric bento hero cards for
/// Screenshots & Photo Library, grouped secondary sources (VisionKit Document Scanner, Files,
/// Clipboard), and a quiet on-device privacy assurance footer.
struct PickerScreen: View {
    @Environment(ShellModel.self) private var shell
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var typeSize

    @State private var showsFileImporter = false
    @State private var showsScanner = false
    @State private var openError: PickerOpenError?
    @State private var hasClipboardImage = false
    @State private var recentScreenshots: [RecentScreenshot] = []
    @State private var isOpening = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !recentScreenshots.isEmpty {
                    recentScreenshotsSection
                }

                heroBentoSection

                secondarySourcesSection

                privacyFooter
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(Theme.page.ignoresSafeArea())
        .scrollBounceBehavior(.basedOnSize)
        .scrollEdgeEffectStyle(.soft, for: .all)
        .navigationTitle("3.1.1")
        .navigationSubtitle("3.1.2")
        .navigationBarTitleDisplayMode(.large)
        .overlay {
            if isOpening {
                ProgressView()
                    .controlSize(.regular)
                    .padding(20)
                    .glassEffect(.regular, in: .circle)
            }
        }
        .fileImporter(
            isPresented: $showsFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                open {
                    await Task.detached(priority: .userInitiated) { Intake.picture(at: url) }.value
                }
            }
        }
        .fullScreenCover(isPresented: $showsScanner) {
            DocumentScannerView { scannedImage in
                showsScanner = false
                open {
                    await Task.detached(priority: .userInitiated) { Intake.picture(from: scannedImage) }.value
                }
            } onCancel: {
                showsScanner = false
            }
            .ignoresSafeArea()
        }
        .imagePasteDestination { payloads in
            guard let data = payloads.first else { return }
            open { try? PictureSource(data: data) }
        }
        .localizedErrorAlert(error: $openError) {
            Button("3.1.8", role: .cancel) {}
        }
        .task { await refreshSources() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await refreshSources() }
            }
        }
    }

    // MARK: - Recent Screenshots Carousel

    private var recentScreenshotsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("picker.recentScreenshots")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.secondaryLabel)
                .textCase(.uppercase)
                .padding(.horizontal, Metrics.pageInset + 4)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(recentScreenshots) { shot in
                        let shape = ConcentricRectangle(corners: .concentric(minimum: 14), isUniform: true)
                        Button {
                            open { await Intake.picture(localIdentifier: shot.id) }
                        } label: {
                            Image(decorative: shot.thumbnail, scale: 1)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 88, height: 124)
                                .clipShape(shape)
                                .overlay(
                                    shape.stroke(
                                        colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.08),
                                        lineWidth: 0.5
                                    )
                                )
                                .shadow(
                                    color: .black.opacity(colorScheme == .dark ? 0.35 : 0.10),
                                    radius: 8,
                                    y: 3
                                )
                        }
                        .buttonStyle(PressStyle(scale: 0.96))
                        .accessibilityLabel("3.1.9")
                    }
                }
                .padding(.horizontal, Metrics.pageInset)
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Concentric Bento Hero Cards

    private var heroBentoSection: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))

        return layout {
            LibraryHeroCard(
                systemImage: "camera.viewfinder",
                title: "3.1.9",
                subtitle: "picker.screenshotsSub",
                isPrimary: true,
                screenshotsOnly: true
            ) { picked($0) }

            LibraryHeroCard(
                systemImage: "photo.on.rectangle.angled",
                title: "3.1.3",
                subtitle: "picker.librarySub",
                isPrimary: false,
                screenshotsOnly: false
            ) { picked($0) }
        }
        .padding(.horizontal, Metrics.pageInset)
    }

    // MARK: - Grouped Secondary Sources Card

    private var secondarySourcesSection: some View {
        let shape = ConcentricRectangle(corners: .concentric(minimum: 20), isUniform: true)
        return VStack(alignment: .leading, spacing: 8) {
            Text("picker.sources")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.secondaryLabel)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                if DocumentScannerView.isSupported {
                    PickerRow(systemImage: "doc.viewfinder", title: "picker.scanDocument") {
                        showsScanner = true
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)

                    Divider().padding(.leading, 58)
                }

                PickerRow(systemImage: "folder", title: "3.1.4") {
                    showsFileImporter = true
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 9)

                Divider().padding(.leading, 58)

                PickerRow(
                    systemImage: "clipboard",
                    title: "3.1.5",
                    footnote: hasClipboardImage ? "picker.clipboardReady" : nil,
                    footnoteTint: Theme.accent,
                    isEnabled: hasClipboardImage
                ) {
                    open { Intake.pictureFromPasteboard() }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
            }
            .background(shape.fill(Theme.card))
            .overlay(
                shape.stroke(
                    colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04),
                    lineWidth: 0.5
                )
            )

            if !hasClipboardImage {
                Text("3.1.6")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryLabel)
                    .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, Metrics.pageInset)
    }

    // MARK: - On-Device Privacy Trust Badge

    private var privacyFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.shield.fill")
                .font(.caption.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            Text("picker.privacyBadge")
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.secondaryLabel)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Capsule().fill(Theme.fill))
    }

    // MARK: - Actions

    private func refreshSources() async {
        hasClipboardImage = PasteboardImage.isPresent
        recentScreenshots = await Intake.recentScreenshots(limit: 10)
    }

    private func picked(_ item: PhotosPickerItem) {
        open { await Intake.picture(from: item) }
    }

    private func open(_ candidate: @escaping @MainActor () async -> PictureSource?) {
        guard !isOpening else { return }
        isOpening = true
        Task { @MainActor in
            defer { isOpening = false }
            if let picture = await candidate() {
                shell.open(picture)
            } else {
                try? await Task.sleep(for: .milliseconds(500))
                openError = .cannotOpen
            }
        }
    }
}

/// Typed localized error for iOS 27 `alert(error:actions:)` presentation.
private enum PickerOpenError: LocalizedError {
    case cannotOpen

    var errorDescription: String? {
        L10n.text("3.1.7")
    }
}

/// Concentric bento hero card backed by an isolated `PhotosPicker` presentation.
private struct LibraryHeroCard: View {
    let systemImage: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let isPrimary: Bool
    let screenshotsOnly: Bool
    let onPick: (PhotosPickerItem) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var item: PhotosPickerItem?
    @State private var isShown = false

    var body: some View {
        let shape = ConcentricRectangle(corners: .concentric(minimum: 22), isUniform: true)
        Button {
            isShown = true
        } label: {
            ZStack(alignment: .topTrailing) {
                if isPrimary {
                    Image(systemName: systemImage)
                        .font(.system(size: 74, weight: .regular))
                        .foregroundStyle(.white.opacity(0.10))
                        .offset(x: 16, y: -12)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(isPrimary ? Color.white.opacity(0.20) : Theme.accent.opacity(0.13))
                            .frame(width: 40, height: 40)
                        Image(systemName: systemImage)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isPrimary ? .white : Theme.accent)
                    }
                    .accessibilityHidden(true)

                    Spacer(minLength: 10)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(isPrimary ? .white : Theme.body)
                            .lineLimit(2)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(isPrimary ? Color.white.opacity(0.82) : Theme.secondaryLabel)
                            .lineLimit(2)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
            }
            .background {
                if isPrimary {
                    shape.fill(
                        LinearGradient(
                            colors: [Color(hex: 0x0E8B8C), Color(hex: 0x086066)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                } else {
                    shape.fill(Theme.card)
                }
            }
            .clipShape(shape)
            .overlay(
                shape.stroke(
                    isPrimary
                        ? Color.white.opacity(0.18)
                        : (colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.05)),
                    lineWidth: 0.5
                )
            )
            .shadow(
                color: isPrimary
                    ? Color(hex: 0x086066).opacity(colorScheme == .dark ? 0.35 : 0.22)
                    : .black.opacity(colorScheme == .dark ? 0.25 : 0.05),
                radius: isPrimary ? 14 : 8,
                y: isPrimary ? 6 : 3
            )
        }
        .buttonStyle(PressStyle(scale: 0.97))
        .photosPicker(
            isPresented: $isShown,
            selection: $item,
            matching: screenshotsOnly ? .screenshots : nil
        )
        .onChange(of: item) { _, picked in
            guard let picked else { return }
            item = nil
            onPick(picked)
        }
    }
}

#Preview("Picker Light") {
    NavigationStack {
        PickerScreen()
    }
    .environment(ShellModel())
    .tint(Theme.accent)
    .preferredColorScheme(.light)
}

#Preview("Picker Dark") {
    NavigationStack {
        PickerScreen()
    }
    .environment(ShellModel())
    .tint(Theme.accent)
    .preferredColorScheme(.dark)
}
