import Observation
import Photos
import SwiftUI
import UIKit

/// Filter segment for QuickCover's Apple Photos-style gallery grid.
enum PhotoLibraryFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case screenshots

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .all: "library.filter.all"
        case .screenshots: "library.filter.screenshots"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "photo.on.rectangle"
        case .screenshots: "camera.viewfinder"
        }
    }
}

/// Lightweight metadata entry for one photo asset displayed in the Apple Photos grid.
struct LibraryAssetItem: Identifiable, Hashable, Sendable {
    let id: String
    let isScreenshot: Bool
}

/// Live PhotoKit gallery store using `PHCachingImageManager` and `PHPhotoLibraryChangeObserver`
/// so the home grid behaves like Apple Photos: instant edge-to-edge thumbnails, smooth 120fps
/// scrolling, automatic refresh when new screenshots arrive, and full support for both `.authorized`
/// and `.limited` photo library permissions.
@MainActor
@Observable
final class PhotoLibraryStore: NSObject, PHPhotoLibraryChangeObserver {

    private(set) var authorization: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    private(set) var items: [LibraryAssetItem] = []
    private(set) var totalPhotoCount: Int = 0
    private(set) var screenshotCount: Int = 0
    private(set) var hasLoadedOnce = false

    var filter: PhotoLibraryFilter = .all {
        didSet {
            if filter != oldValue {
                reloadAssets()
            }
        }
    }

    @ObservationIgnored private let imageManager = PHCachingImageManager()
    @ObservationIgnored private var assetsByID: [String: PHAsset] = [:]
    @ObservationIgnored private var isObserving = false

    override init() {
        super.init()
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    var canBrowseGrid: Bool {
        authorization == .authorized || authorization == .limited
    }

    func startObservingAndLoad() {
        authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if !isObserving && canBrowseGrid {
            PHPhotoLibrary.shared().register(self)
            isObserving = true
        }
        reloadAssets()
    }

    func refreshAuthorizationAndLoad() {
        let next = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        authorization = next
        if !isObserving && canBrowseGrid {
            PHPhotoLibrary.shared().register(self)
            isObserving = true
        }
        reloadAssets()
    }

    func requestAccess() async {
        _ = await Intake.photosAccess()
        refreshAuthorizationAndLoad()
    }

    func asset(for id: String) -> PHAsset? {
        assetsByID[id]
    }

    /// Requests a crisp aspect-fill square thumbnail via `PHCachingImageManager`.
    /// Calls `onImage` as soon as a fast preview or final high-quality thumbnail is available.
    @discardableResult
    func requestThumbnail(
        for id: String,
        pixelSize: CGSize,
        onImage: @escaping @MainActor (UIImage?) -> Void
    ) -> PHImageRequestID {
        guard let asset = assetsByID[id] else {
            onImage(nil)
            return PHInvalidImageRequestID
        }
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false

        return imageManager.requestImage(
            for: asset,
            targetSize: pixelSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            Task { @MainActor in
                onImage(image)
            }
        }
    }

    func cancelThumbnailRequest(_ requestID: PHImageRequestID) {
        guard requestID != PHInvalidImageRequestID else { return }
        imageManager.cancelImageRequest(requestID)
    }

    func reloadAssets() {
        authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard canBrowseGrid else {
            items = []
            assetsByID = [:]
            totalPhotoCount = 0
            screenshotCount = 0
            hasLoadedOnce = true
            return
        }

        // Count all photos & screenshots cleanly for subtitle & filter badges.
        let allOptions = PHFetchOptions()
        allOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let allResult = PHAsset.fetchAssets(with: .image, options: allOptions)
        totalPhotoCount = allResult.count

        let shotOptions = PHFetchOptions()
        shotOptions.predicate = NSPredicate(
            format: "mediaSubtype & %d != 0",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        shotOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let shotResult = PHAsset.fetchAssets(with: .image, options: shotOptions)
        screenshotCount = shotResult.count

        let active = (filter == .screenshots) ? shotResult : allResult
        let limit = min(active.count, 300)
        var nextItems: [LibraryAssetItem] = []
        var nextMap: [String: PHAsset] = [:]
        nextItems.reserveCapacity(limit)
        nextMap.reserveCapacity(limit)

        for idx in 0..<limit {
            let asset = active.object(at: idx)
            let isShot = asset.mediaSubtypes.contains(.photoScreenshot)
            nextItems.append(LibraryAssetItem(id: asset.localIdentifier, isScreenshot: isShot))
            nextMap[asset.localIdentifier] = asset
        }

        items = nextItems
        assetsByID = nextMap
        hasLoadedOnce = true
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor [weak self] in
            self?.reloadAssets()
        }
    }
}
