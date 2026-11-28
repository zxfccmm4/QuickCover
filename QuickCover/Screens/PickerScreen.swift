import Photos
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Native Apple Photos (iOS 26/27) inspired Library screen:
/// displays your real photo library edge-to-edge immediately on launch in a tight 3-column grid,
/// supports multi-selecting screenshots or importing Screen Recordings to stitch long screenshots,
/// floats a translucent Liquid Glass pill over the scrolling grid, and transitions into the dark
/// photo studio the moment you confirm your image.
struct PickerScreen: View {
    @Environment(ShellModel.self) private var shell
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Namespace private var filterNamespace

    @State private var store = PhotoLibraryStore()
    @State private var showsPhotosPicker = false
    @State private var pickedPhotoItem: PhotosPickerItem?
    @State private var showsFileImporter = false
    @State private var showsScanner = false
    @State private var openError: PickerOpenError?
    @State private var hasClipboardImage = false
    @State private var openingAssetID: String?
    @State private var isOpeningExternal = false
    @State private var selectionFeedbackCount = 0

    private var gridColumns: [GridItem] {
        let count = sizeClass == .regular ? 5 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 2), count: count)
    }

    private var activeCountText: String {
        guard store.canBrowseGrid else {
            return L10n.text("3.1.2")
        }
        switch store.filter {
        case .all:
            return L10n.libraryPhotoCount(store.totalPhotoCount)
        case .screenshots:
            return L10n.libraryScreenshotCount(store.screenshotCount)
        }
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            if store.canBrowseGrid {
                if store.items.isEmpty && store.hasLoadedOnce {
                    emptyFilterView
                } else {
                    photoGridView
                }
            } else {
                permissionFallbackView
            }

            if isOpeningExternal {
                AppleIntelligenceOrb(size: 28)
                    .padding(18)
                    .glassEffect(.regular, in: .circle)
            }
        }
        .navigationTitle("library.title")
        .navigationSubtitle(activeCountText)
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .top, spacing: 0) {
            if store.canBrowseGrid {
                topFilterHeaderBar
            }
        }
        .photosPicker(
            isPresented: $showsPhotosPicker,
            selection: $pickedPhotoItem,
            matching: .images
        )
        .onChange(of: pickedPhotoItem) { _, picked in
            guard let picked else { return }
            pickedPhotoItem = nil
            openExternal { await Intake.picture(from: picked) }
        }
        .fileImporter(
            isPresented: $showsFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                openExternal {
                    await Task.detached(priority: .userInitiated) { Intake.picture(at: url) }.value
                }
            }
        }
        .fullScreenCover(isPresented: $showsScanner) {
            DocumentScannerView { scannedImage in
                showsScanner = false
                openExternal {
                    await Task.detached(priority: .userInitiated) { Intake.picture(from: scannedImage) }.value
                }
            } onCancel: {
                showsScanner = false
            }
            .ignoresSafeArea()
        }
        .imagePasteDestination { payloads in
            guard let data = payloads.first else { return }
            openExternal { try? PictureSource(data: data) }
        }
        .localizedErrorAlert(error: $openError) {
            Button("3.1.8", role: .cancel) {}
        }
        .sensoryFeedback(.selection, trigger: selectionFeedbackCount)
        .task {
            hasClipboardImage = PasteboardImage.isPresent
            store.startObservingAndLoad()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                hasClipboardImage = PasteboardImage.isPresent
                store.refreshAuthorizationAndLoad()
            }
        }
    }

    // MARK: - Edge-to-Edge Apple Photos Grid

    private var photoGridView: some View {
        ScrollView {
            VStack(spacing: 0) {
                if store.authorization == .limited {
                    limitedAccessStrip
                        .padding(.horizontal, Metrics.pageInset)
                        .padding(.top, 4)
                        .padding(.bottom, 10)
                }

                LazyVGrid(columns: gridColumns, spacing: 2) {
                    ForEach(store.items) { item in
                        LibraryPhotoCell(
                            item: item,
                            store: store,
                            showsScreenshotGlyph: store.filter == .all && item.isScreenshot,
                            isOpening: openingAssetID == item.id
                        ) {
                            openLibraryAsset(item.id)
                        }
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollEdgeEffectStyle(.soft, for: .all)
    }

    private var limitedAccessStrip: some View {
        HStack(spacing: 10) {
            Image(systemName: "photo.stack.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)

            Text("library.limitedBanner")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 6)

            Button("library.selectMore") {
                presentLimitedLibraryPicker()
            }
            .font(.footnote.weight(.semibold))
            .tint(Theme.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Theme.card, in: Capsule())
        .overlay(Capsule().stroke(Theme.cardBorder(for: colorScheme), lineWidth: 0.5))
    }

    // MARK: - Native Top Filter Pill & Selection Action Dock

    private var topFilterHeaderBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 3) {
                ForEach(PhotoLibraryFilter.allCases) { option in
                    let isSelected = store.filter == option
                    Button {
                        guard store.filter != option else { return }
                        withAnimation(.snappy(duration: 0.24)) {
                            store.filter = option
                        }
                        selectionFeedbackCount += 1
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: option.systemImage)
                                .font(.caption.weight(.semibold))
                            Text(LocalizedStringKey(option.titleKey))
                                .font(.subheadline.weight(isSelected ? .semibold : .medium))
                        }
                        .foregroundStyle(isSelected ? .white : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .frame(minHeight: 34)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(Theme.accentButton)
                                    .matchedGeometryEffect(id: "libraryFilterPill", in: filterNamespace)
                            } else {
                                Capsule()
                                    .fill(Color.clear)
                            }
                        }
                        .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .contentShape(.capsule)
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
            .padding(4)
            .glassEffect(.regular.interactive(), in: .capsule)
            .contentShape(.capsule)

            Spacer(minLength: 4)

            if hasClipboardImage {
                Button {
                    openExternal { Intake.pictureFromPasteboard() }
                } label: {
                    Image(systemName: "clipboard.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 40, height: 40)
                        .contentShape(.circle)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(PressStyle(scale: 0.94))
                .contentShape(.circle)
                .accessibilityLabel("3.1.5")
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .padding(.horizontal, Metrics.pageInset)
        .padding(.vertical, 6)
        .animation(.snappy(duration: 0.24), value: hasClipboardImage)
    }

    // MARK: - Minimal Empty & Permission States

    private var emptyFilterView: some View {
        ContentUnavailableView {
            Label(
                store.filter == .screenshots ? "library.emptyScreenshots.title" : "library.emptyAll.title",
                systemImage: store.filter == .screenshots ? "camera.viewfinder" : "photo.on.rectangle.angled"
            )
        } description: {
            Text(store.filter == .screenshots ? "library.emptyScreenshots.body" : "library.emptyAll.body")
        } actions: {
            if store.filter == .screenshots && store.totalPhotoCount > 0 {
                Button("library.showAllPhotos") {
                    withAnimation(.snappy(duration: 0.24)) {
                        store.filter = .all
                    }
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .tint(Theme.accentButton)
            } else {
                Button("library.importPhotos") {
                    showsPhotosPicker = true
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .tint(Theme.accentButton)
            }
        }
        .padding(.bottom, 64)
    }

    private var permissionFallbackView: some View {
        ContentUnavailableView {
            Label("library.noAccess.title", systemImage: "photo.stack")
        } description: {
            Text("library.noAccess.body")
        } actions: {
            VStack(spacing: 10) {
                Button {
                    showsPhotosPicker = true
                } label: {
                    Label("library.importPhotos", systemImage: "photo.on.rectangle.angled")
                        .font(.buttonText)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(Theme.accentButton)

                Button {
                    shell.openStitchTab(mode: .screenRecording)
                } label: {
                    Label("longshot.menuVideo", systemImage: "record.circle")
                        .font(.subheadline.weight(.medium))
                }
                .tint(Theme.accent)

                if store.authorization == .denied || store.authorization == .restricted {
                    Button("library.openSettings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .tint(Theme.accent)
                } else {
                    Button("3.2.3") {
                        Task { await store.requestAccess() }
                    }
                    .font(.subheadline.weight(.medium))
                    .tint(Theme.accent)
                }
            }
        }
    }

    // MARK: - Actions

    private func openLibraryAsset(_ id: String) {
        guard openingAssetID == nil, !isOpeningExternal else { return }
        openingAssetID = id
        selectionFeedbackCount += 1
        Task { @MainActor in
            defer { openingAssetID = nil }
            let picture: PictureSource? = if let asset = store.asset(for: id) {
                await Intake.picture(asset: asset)
            } else {
                await Intake.picture(localIdentifier: id)
            }
            if let picture {
                shell.open(picture)
            } else {
                openError = .cannotOpen
            }
        }
    }

    private func openExternal(_ candidate: @escaping @MainActor () async -> PictureSource?) {
        guard !isOpeningExternal, openingAssetID == nil else { return }
        isOpeningExternal = true
        Task { @MainActor in
            defer { isOpeningExternal = false }
            if let picture = await candidate() {
                shell.open(picture)
            } else {
                try? await Task.sleep(for: .milliseconds(350))
                openError = .cannotOpen
            }
        }
    }

    private func presentLimitedLibraryPicker() {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              let root = scene.keyWindow?.rootViewController else {
            return
        }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: top)
    }
}

// MARK: - Edge-to-Edge Square Photo Tile

private struct LibraryPhotoCell: View {
    let item: LibraryAssetItem
    let store: PhotoLibraryStore
    let showsScreenshotGlyph: Bool
    let isOpening: Bool
    let onTap: () -> Void

    @Environment(\.displayScale) private var displayScale
    @State private var thumbnail: UIImage?
    @State private var requestID: PHImageRequestID = PHInvalidImageRequestID

    var body: some View {
        Button(action: onTap) {
            Color(.secondarySystemFill)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                    }
                }
                .clipped()
                .overlay(alignment: .bottomTrailing) {
                    if showsScreenshotGlyph && !isOpening {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(5)
                            .background(Color.black.opacity(0.45), in: Circle())
                            .padding(5)
                            .accessibilityHidden(true)
                    }
                }
                .overlay {
                    if isOpening {
                        Color.black.opacity(0.32)
                        ProgressView()
                            .tint(.white)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(PressStyle(scale: 0.97))
        .onAppear {
            guard thumbnail == nil else { return }
            let px = 140 * max(displayScale, 2)
            requestID = store.requestThumbnail(
                for: item.id,
                pixelSize: CGSize(width: px, height: px)
            ) { image in
                if let image {
                    thumbnail = image
                }
            }
        }
        .onDisappear {
            store.cancelThumbnailRequest(requestID)
            requestID = PHInvalidImageRequestID
        }
        .accessibilityLabel(item.isScreenshot ? "3.1.9" : "3.1.3")
    }
}

/// Transparent UIKit view that claims touches strictly inside the bottom home-indicator safe-area
/// band so low thumb taps beneath the floating filter pill never bleed through to the photo grid.
struct BottomSafeAreaTouchShield: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isUserInteractionEnabled = true
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

/// Typed localized error for iOS 27 `alert(error:actions:)` presentation.
private enum PickerOpenError: LocalizedError {
    case cannotOpen

    var errorDescription: String? {
        L10n.text("3.1.7")
    }
}

#Preview("Library Light") {
    NavigationStack {
        PickerScreen()
    }
    .environment(ShellModel())
    .tint(Theme.accent)
    .preferredColorScheme(.light)
}

#Preview("Library Dark") {
    NavigationStack {
        PickerScreen()
    }
    .environment(ShellModel())
    .tint(Theme.accent)
    .preferredColorScheme(.dark)
}
