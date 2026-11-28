import Photos
import PhotosUI
import SwiftUI
import UIKit

/// Stage 1 of the dedicated Long Screenshot tab (`Tab("tab.stitch")`):
/// Immediately displays a live Apple Photos-style screenshot/photo grid and Screen Recording grid
/// with ordered tap selection (`1`, `2`, `3`), one-tap stitching into `LongScreenshotCanvasEditorView`
/// (Stage 2), and seamless handoff from Library multi-select.
struct LongScreenshotHubView: View {
    enum HubScope: String, CaseIterable, Identifiable {
        case screenshots
        case allPhotos
        case screenRecording

        var id: String { rawValue }

        var titleKey: String {
            switch self {
            case .screenshots: "longshot.hub.scopeShots"
            case .allPhotos: "longshot.hub.scopeAll"
            case .screenRecording: "longshot.hub.scopeVideo"
            }
        }
    }

    let onComplete: (PictureSource) -> Void
    var onCompleteForExport: ((PictureSource) -> Void)? = nil

    @Environment(ShellModel.self) private var shell
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Namespace private var scopeNamespace

    @State private var store = PhotoLibraryStore()
    @State private var scope: HubScope = .screenshots
    @State private var selectedIDs: [String] = []
    @State private var direction: LongScreenshotStitcher.Direction = .vertical
    @State private var videoPrecision: LongScreenshotStitcher.VideoPrecision = .standard

    @State private var recentVideos: [LibraryVideoItem] = []
    @State private var activeSession: LongScreenshotSession?
    @State private var isLoadingSession = false
    @State private var errorMessage: String?

    @State private var showsPhotosPicker = false
    @State private var pickedPhotoItems: [PhotosPickerItem] = []
    @State private var pickedVideoItem: PhotosPickerItem?

    @State private var selectionCount = 0

    private var photoColumns: [GridItem] {
        let count = sizeClass == .regular ? 5 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 2), count: count)
    }

    private var videoColumns: [GridItem] {
        let count = sizeClass == .regular ? 4 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
    }

    private var subtitleText: String {
        if !selectedIDs.isEmpty {
            return L10n.longshotSelectHint(selectedIDs.count)
        }
        if scope == .screenRecording {
            return L10n.text("longshot.hub.pickHintVideo")
        }
        return L10n.text("longshot.hub.pickHint")
    }

    var body: some View {
        Group {
            if let session = activeSession {
                LongScreenshotCanvasEditorView(
                    session: session,
                    onBack: {
                        withAnimation(.snappy(duration: 0.25)) {
                            activeSession = nil
                        }
                    },
                    onComplete: onComplete,
                    onCompleteForExport: onCompleteForExport
                )
                .id(session.id)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                hubContent
                    .transition(.opacity)
            }
        }
        .animation(.snappy(duration: 0.26), value: activeSession?.id)
        .onChange(of: shell.pendingStitchRequest?.id) { _, _ in
            Task { await consumePendingRequestIfNeeded() }
        }
        .task {
            if store.filter != .screenshots && !store.hasLoadedOnce {
                store.filter = .screenshots
            }
            store.startObservingAndLoad()
            if recentVideos.isEmpty {
                recentVideos = Intake.recentVideos(limit: 24)
            }
            await consumePendingRequestIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.refreshAuthorizationAndLoad()
                recentVideos = Intake.recentVideos(limit: 24)
            }
        }
        .onChange(of: scope) { _, newScope in
            selectionCount += 1
            if newScope == .screenshots && store.filter != .screenshots {
                store.filter = .screenshots
            } else if newScope == .allPhotos && store.filter != .all {
                store.filter = .all
            } else if newScope == .screenRecording && recentVideos.isEmpty {
                recentVideos = Intake.recentVideos(limit: 24)
            }
        }
        .photosPicker(
            isPresented: $showsPhotosPicker,
            selection: $pickedPhotoItems,
            maxSelectionCount: 12,
            matching: .images
        )
        .onChange(of: pickedPhotoItems) { _, items in
            guard !items.isEmpty else { return }
            let captured = items
            pickedPhotoItems = []
            Task { await launchFromPickedPhotos(captured) }
        }
        .onChange(of: pickedVideoItem) { _, item in
            guard let item else { return }
            pickedVideoItem = nil
            Task { await launchFromPickedVideo(item) }
        }
        .sensoryFeedback(.selection, trigger: selectionCount)
    }

    private var hubContent: some View {
        ZStack {
            Theme.page.ignoresSafeArea()

            if scope == .screenRecording {
                videoHubGrid
            } else if store.canBrowseGrid {
                if store.items.isEmpty && store.hasLoadedOnce {
                    emptyPhotoScopeView
                } else {
                    photoSelectionGrid
                }
            } else {
                noPhotoPermissionView
            }

            if isLoadingSession {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                VStack(spacing: 14) {
                    AppleIntelligenceOrb(size: 46)
                    AppleIntelligenceShimmerText(
                        text: "longshot.loadingFrames",
                        font: .subheadline.weight(.semibold)
                    )
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 22)
                .glassEffect(.regular, in: .rect(cornerRadius: 22))
            }
        }
        .navigationTitle("tab.stitch")
        .navigationSubtitle(subtitleText)
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .top, spacing: 0) {
            scopeHeaderBar
        }
        .safeAreaBar(edge: .bottom, spacing: 0) {
            if scope != .screenRecording && !selectedIDs.isEmpty {
                selectionActionBar
            }
        }
    }

    // MARK: - Top Scope Switcher

    private var scopeHeaderBar: some View {
        HStack {
            HStack(spacing: 3) {
                ForEach(HubScope.allCases) { option in
                    let selected = scope == option
                    Button {
                        guard scope != option else { return }
                        withAnimation(.snappy(duration: 0.24)) {
                            scope = option
                        }
                    } label: {
                        Text(LocalizedStringKey(option.titleKey))
                            .font(.subheadline.weight(selected ? .semibold : .medium))
                            .foregroundStyle(selected ? .white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background {
                                if selected {
                                    Capsule()
                                        .fill(Theme.accentButton)
                                        .matchedGeometryEffect(id: "stitchHubScope", in: scopeNamespace)
                                }
                            }
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .glassEffect(.regular.interactive(), in: .capsule)

            Spacer(minLength: 4)

            if let errorMessage {
                Text(verbatim: errorMessage)
                    .font(.caption2)
                    .foregroundStyle(Theme.errorIcon)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, Metrics.pageInset)
        .padding(.vertical, 6)
    }

    // MARK: - Photo Selection Grid

    private var photoSelectionGrid: some View {
        ScrollView {
            LazyVGrid(columns: photoColumns, spacing: 2) {
                ForEach(store.items) { item in
                    let order = selectedIDs.firstIndex(of: item.id).map { $0 + 1 }
                    HubPhotoCell(
                        item: item,
                        store: store,
                        selectionOrder: order
                    ) {
                        toggleSelection(item.id)
                    }
                }
            }
            .padding(.bottom, 28)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollEdgeEffectStyle(.soft, for: .all)
    }

    private var emptyPhotoScopeView: some View {
        ContentUnavailableView {
            Label(
                scope == .screenshots ? "library.emptyScreenshots" : "library.emptyAll",
                systemImage: scope == .screenshots ? "camera.viewfinder" : "photo.on.rectangle"
            )
        } description: {
            Text(scope == .screenshots ? "library.emptyScreenshotsSub" : "library.emptyAllSub")
        } actions: {
            if scope == .screenshots {
                Button("library.showAllPhotos") {
                    withAnimation(.snappy(duration: 0.24)) {
                        scope = .allPhotos
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accentButton)
            }
        }
    }

    private var noPhotoPermissionView: some View {
        ContentUnavailableView {
            Label("3.1.3", systemImage: "photo.stack")
        } description: {
            Text("longshot.emptyFramesHint")
        } actions: {
            Button("longshot.addScreenshots") {
                showsPhotosPicker = true
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accentButton)
        }
    }

    // MARK: - Screen Recording Grid

    private var videoHubGrid: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    PhotosPicker(selection: $pickedVideoItem, matching: .videos) {
                        Label("longshot.pickRecording", systemImage: "video.badge.plus")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.capsule)
                    .tint(Theme.accentButton)

                    Picker("", selection: $videoPrecision) {
                        ForEach(LongScreenshotStitcher.VideoPrecision.allCases) { prec in
                            Text(LocalizedStringKey(prec.titleKey)).tag(prec)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 132)
                }

                if recentVideos.isEmpty {
                    ContentUnavailableView {
                        Label("longshot.hub.noRecordings", systemImage: "record.circle")
                    } description: {
                        Text("longshot.videoGuideBody")
                    }
                    .padding(.top, 24)
                } else {
                    LazyVGrid(columns: videoColumns, spacing: 10) {
                        ForEach(recentVideos) { video in
                            HubVideoCard(video: video) {
                                Task { await launchFromLibraryVideo(video) }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Metrics.pageInset)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollEdgeEffectStyle(.soft, for: .all)
    }

    // MARK: - Floating Bottom Selection Action Bar

    private var selectionActionBar: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        selectedIDs = []
                    }
                    selectionCount += 1
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.primary)
                        .frame(width: 38, height: 38)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(PressStyle(scale: 0.92))
                .accessibilityLabel("longshot.clearAll")

                Picker("", selection: $direction) {
                    ForEach(LongScreenshotStitcher.Direction.allCases) { dir in
                        Text(LocalizedStringKey(dir.titleKey)).tag(dir)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 126)

                Button {
                    Task { await launchSelectedPhotos() }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.caption.weight(.semibold))
                        Text(verbatim: L10n.longshotStartStitch(selectedIDs.count))
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .tint(Theme.accentButton)
                .disabled(selectedIDs.count < 2 || isLoadingSession)
            }
            .padding(.horizontal, Metrics.pageInset)
            .padding(.vertical, 8)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Selection & Launch Actions

    private func toggleSelection(_ id: String) {
        withAnimation(.snappy(duration: 0.2)) {
            if let existing = selectedIDs.firstIndex(of: id) {
                selectedIDs.remove(at: existing)
            } else if selectedIDs.count < 12 {
                selectedIDs.append(id)
            }
        }
        selectionCount += 1
    }

    private func launchSelectedPhotos() async {
        guard selectedIDs.count >= 2 else { return }
        isLoadingSession = true
        errorMessage = nil
        let assets = selectedIDs.compactMap { store.asset(for: $0) }
        let images: [CGImage] = if assets.count == selectedIDs.count {
            await Intake.images(assets: assets)
        } else {
            await Intake.images(localIdentifiers: selectedIDs)
        }
        isLoadingSession = false
        guard images.count >= 2 else {
            errorMessage = LongScreenshotStitcher.Failure.notEnoughImages.localizedDescription
            return
        }
        activeSession = LongScreenshotSession(
            initialMode: .multiImage,
            initialDirection: direction,
            initialImages: images
        )
    }

    private func launchFromPickedPhotos(_ items: [PhotosPickerItem]) async {
        isLoadingSession = true
        errorMessage = nil
        var loaded: [CGImage] = []
        for item in items {
            if let source = await Intake.picture(from: item), let cg = try? source.uprightImage() {
                loaded.append(cg)
            }
        }
        isLoadingSession = false
        guard loaded.count >= 2 else {
            errorMessage = LongScreenshotStitcher.Failure.notEnoughImages.localizedDescription
            return
        }
        activeSession = LongScreenshotSession(
            initialMode: .multiImage,
            initialDirection: direction,
            initialImages: loaded
        )
    }

    private func launchFromLibraryVideo(_ item: LibraryVideoItem) async {
        isLoadingSession = true
        errorMessage = nil
        guard let asset = await Intake.videoAsset(localIdentifier: item.id) else {
            isLoadingSession = false
            errorMessage = LongScreenshotStitcher.Failure.videoHasNoFrames.localizedDescription
            return
        }
        isLoadingSession = false
        activeSession = LongScreenshotSession(
            initialMode: .screenRecording,
            initialVideoAsset: asset,
            deleteVideoAfter: false,
            initialVideoPrecision: videoPrecision
        )
    }

    private func launchFromPickedVideo(_ item: PhotosPickerItem) async {
        isLoadingSession = true
        errorMessage = nil
        guard let url = await Intake.videoURL(from: item) else {
            isLoadingSession = false
            errorMessage = LongScreenshotStitcher.Failure.videoHasNoFrames.localizedDescription
            return
        }
        isLoadingSession = false
        activeSession = LongScreenshotSession(
            initialMode: .screenRecording,
            initialVideoURL: url,
            initialVideoAsset: SendableAVAsset(asset: AVURLAsset(url: url)),
            deleteVideoAfter: true,
            initialVideoPrecision: videoPrecision
        )
    }

    private func consumePendingRequestIfNeeded() async {
        guard let req = shell.pendingStitchRequest else { return }
        shell.pendingStitchRequest = nil
        if req.mode == .screenRecording {
            scope = .screenRecording
            return
        }
        if !req.assets.isEmpty || !req.assetIDs.isEmpty {
            isLoadingSession = true
            errorMessage = nil
            let loaded: [CGImage] = if !req.assets.isEmpty {
                await Intake.images(assets: req.assets)
            } else {
                await Intake.images(localIdentifiers: req.assetIDs)
            }
            isLoadingSession = false
            if loaded.count >= 2 {
                activeSession = LongScreenshotSession(
                    initialMode: .multiImage,
                    initialDirection: direction,
                    initialImages: loaded
                )
            }
        }
    }
}

/// Preserved type namespace (`Mode`) and compatibility view for callers such as `ShellModel` / `PickerScreen`.
struct LongScreenshotStudioView: View {
    enum Mode: String, CaseIterable, Identifiable, Sendable {
        case multiImage
        case screenRecording

        var id: String { rawValue }
    }

    let isStandaloneTab: Bool
    let initialMode: Mode
    let initialAssets: [PHAsset]
    let initialAssetIDs: [String]
    let onComplete: (PictureSource) -> Void
    var onCompleteForExport: ((PictureSource) -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    @State private var modalSession: LongScreenshotSession?

    init(
        isStandaloneTab: Bool = false,
        initialMode: Mode = .multiImage,
        initialAssets: [PHAsset] = [],
        initialAssetIDs: [String] = [],
        onComplete: @escaping (PictureSource) -> Void,
        onCompleteForExport: ((PictureSource) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.isStandaloneTab = isStandaloneTab
        self.initialMode = initialMode
        self.initialAssets = initialAssets
        self.initialAssetIDs = initialAssetIDs
        self.onComplete = onComplete
        self.onCompleteForExport = onCompleteForExport
        self.onDismiss = onDismiss
    }

    var body: some View {
        Group {
            if let session = modalSession {
                LongScreenshotCanvasEditorView(
                    session: session,
                    onBack: { onDismiss?() },
                    onComplete: onComplete,
                    onCompleteForExport: onCompleteForExport
                )
            } else {
                LongScreenshotHubView(
                    onComplete: onComplete,
                    onCompleteForExport: onCompleteForExport
                )
            }
        }
        .task {
            if modalSession == nil && (!initialAssets.isEmpty || !initialAssetIDs.isEmpty) {
                let imgs = !initialAssets.isEmpty
                    ? await Intake.images(assets: initialAssets)
                    : await Intake.images(localIdentifiers: initialAssetIDs)
                if imgs.count >= 2 {
                    modalSession = LongScreenshotSession(initialMode: .multiImage, initialImages: imgs)
                }
            }
        }
    }
}

/// Modal compatibility wrapper around `LongScreenshotStudioView`.
struct LongScreenshotSheet: View {
    typealias Mode = LongScreenshotStudioView.Mode

    let initialMode: Mode
    let initialAssets: [PHAsset]
    let initialAssetIDs: [String]
    let onComplete: (PictureSource) -> Void
    var onCompleteForExport: ((PictureSource) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    init(
        initialMode: Mode = .multiImage,
        initialAssets: [PHAsset] = [],
        initialAssetIDs: [String] = [],
        onComplete: @escaping (PictureSource) -> Void,
        onCompleteForExport: ((PictureSource) -> Void)? = nil
    ) {
        self.initialMode = initialMode
        self.initialAssets = initialAssets
        self.initialAssetIDs = initialAssetIDs
        self.onComplete = onComplete
        self.onCompleteForExport = onCompleteForExport
    }

    var body: some View {
        NavigationStack {
            LongScreenshotStudioView(
                isStandaloneTab: false,
                initialMode: initialMode,
                initialAssets: initialAssets,
                initialAssetIDs: initialAssetIDs,
                onComplete: onComplete,
                onCompleteForExport: onCompleteForExport,
                onDismiss: { dismiss() }
            )
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Hub Cells

private struct HubPhotoCell: View {
    let item: LibraryAssetItem
    let store: PhotoLibraryStore
    let selectionOrder: Int?
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
                .overlay {
                    if selectionOrder != nil {
                        Color.black.opacity(0.20)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if let selectionOrder {
                        Text(verbatim: "\(selectionOrder)")
                            .font(.caption2.weight(.bold).monospacedDigit())
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Theme.accentButton, in: Circle())
                            .overlay(Circle().stroke(.white, lineWidth: 1.5))
                            .padding(6)
                            .transition(.scale(scale: 0.7).combined(with: .opacity))
                    } else {
                        Circle()
                            .stroke(.white.opacity(0.85), lineWidth: 1.5)
                            .fill(Color.black.opacity(0.22))
                            .frame(width: 22, height: 22)
                            .padding(6)
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
    }
}

private struct HubVideoCard: View {
    let video: LibraryVideoItem
    let onTap: () -> Void

    @State private var thumb: UIImage?

    private var formattedDuration: String {
        let secs = Int(video.duration.rounded())
        return String(format: "%d:%02d", secs / 60, secs % 60)
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomTrailing) {
                Color(.secondarySystemFill)
                    .aspectRatio(9.0 / 15.0, contentMode: .fit)
                    .overlay {
                        if let thumb {
                            Image(uiImage: thumb)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "video.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                HStack(spacing: 4) {
                    Image(systemName: "record.circle")
                        .font(.system(size: 10, weight: .semibold))
                    Text(verbatim: formattedDuration)
                        .font(.caption2.weight(.semibold).monospacedDigit())
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.65), in: Capsule())
                .padding(8)
            }
        }
        .buttonStyle(PressStyle(scale: 0.96))
        .task(id: video.id) {
            thumb = await Intake.videoThumbnail(localIdentifier: video.id, targetSize: CGSize(width: 280, height: 460))
        }
    }
}
