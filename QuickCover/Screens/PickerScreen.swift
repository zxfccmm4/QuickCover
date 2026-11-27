import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Native Apple iOS 26/27 Import Hub inspired by Apple Files, Photos, and Shortcuts:
/// features an optional recent-screenshots shelf, two balanced concentric hero cards for
/// Screenshots & Photo Library, a grouped secondary sources card (VisionKit Document Scanner,
/// Files, Clipboard) with tactile row press highlights, and a quiet Apple Privacy footer.
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
            VStack(alignment: .leading, spacing: 22) {
                if !recentScreenshots.isEmpty {
                    recentScreenshotsSection
                }

                heroBentoSection

                secondarySourcesSection

                privacyFooter
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
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

    // MARK: - Recent Screenshots Shelf

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
                                    shape.stroke(Theme.cardBorder(for: colorScheme), lineWidth: 0.5)
                                )
                                .shadow(
                                    color: .black.opacity(colorScheme == .dark ? 0.35 : 0.08),
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

    // MARK: - Balanced Apple Bento Hero Cards

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

                    Divider().padding(.leading, 58)
                }

                PickerRow(systemImage: "folder", title: "3.1.4") {
                    showsFileImporter = true
                }

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
            }
            .background(Theme.card)
            .clipShape(shape)
            .overlay(
                shape.stroke(Theme.cardBorder(for: colorScheme), lineWidth: 0.5)
            )

            if !hasClipboardImage {
                Text("3.1.6")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryLabel)
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, Metrics.pageInset)
    }

    // MARK: - Quiet Apple Privacy Footer

    private var privacyFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.shield.fill")
                .font(.footnote.weight(.medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            Text("picker.privacyBadge")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryLabel)
        }
        .padding(.horizontal, Metrics.pageInset)
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

/// Balanced Apple HIG concentric card backed by an isolated `PhotosPicker` presentation.
/// Emphasizes Screenshots subtly via a solid brand-teal icon badge and gentle tinted wash while
/// maintaining visual equilibrium with Photo Library across Light and Dark Mode.
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
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    ZStack {
                        Circle()
                            .fill(isPrimary ? Theme.accentButton : Theme.accent.opacity(colorScheme == .dark ? 0.18 : 0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: systemImage)
                            .font(.system(size: 18, weight: .semibold))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(isPrimary ? .white : Theme.accent)
                    }
                    .accessibilityHidden(true)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isPrimary ? Theme.accent.opacity(0.7) : Theme.tertiary)
                        .padding(.top, 4)
                        .accessibilityHidden(true)
                }

                Spacer(minLength: 4)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Theme.body)
                        .lineLimit(2)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryLabel)
                        .lineLimit(2)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .background {
                ZStack {
                    shape.fill(Theme.card)
                    if isPrimary {
                        shape.fill(
                            LinearGradient(
                                colors: [
                                    Theme.accent.opacity(colorScheme == .dark ? 0.16 : 0.10),
                                    Theme.accent.opacity(colorScheme == .dark ? 0.05 : 0.02),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    }
                }
            }
            .clipShape(shape)
            .overlay(
                shape.stroke(
                    isPrimary
                        ? Theme.accent.opacity(colorScheme == .dark ? 0.30 : 0.20)
                        : Theme.cardBorder(for: colorScheme),
                    lineWidth: 0.5
                )
            )
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.22 : 0.04),
                radius: 8,
                y: 2
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
