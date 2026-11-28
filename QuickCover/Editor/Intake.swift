import AVFoundation
import Photos
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum PhotosAccess: Equatable, Sendable {
    /// The app may look for the newest screenshot itself.
    case full
    /// Only the pictures the person chose; every picture comes through the system picker.
    case limited
    case denied
}

/// Lightweight local screenshot thumbnail shown in PickerScreen's recent-screenshots carousel.
struct RecentScreenshot: Identifiable, Sendable {
    let id: String
    let thumbnail: CGImage
}

/// Lightweight video metadata item shown in the Screen Recording long-screenshot picker.
struct LibraryVideoItem: Identifiable, Hashable, Sendable {
    let id: String
    let duration: TimeInterval
}

/// Native SwiftUI `Transferable` wrapper for copying a picked screen recording movie to a temporary
/// file URL so `AVAssetImageGenerator` can extract scroll keyframes strictly on-device.
struct PickedMovieTransferable: Transferable, Sendable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("quickcover-rec-\(UUID().uuidString)")
                .appendingPathExtension(ext)
            if FileManager.default.fileExists(atPath: dest.path) {
                try? FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: received.file, to: dest)
            return Self(url: dest)
        }
    }
}

/// Thread-safe wrapper for passing `AVAsset` across Swift 6 concurrency boundaries.
struct SendableAVAsset: @unchecked Sendable {
    let asset: AVAsset
}

/// Brings a picture in: recent screenshots, PhotosPicker, Files, Document Scanner, or clipboard.
/// Nothing downloads from iCloud and nothing asks for full access unless explicitly authorized.
enum Intake {

    /// Asks once if it has to.
    static func photosAccess() async -> PhotosAccess {
        switch await PHPhotoLibrary.requestAuthorization(for: .readWrite) {
        case .authorized: .full
        case .limited: .limited
        default: .denied
        }
    }

    /// The newest screenshot that is on this device; nil when there is none stored locally.
    static func latestScreenshot() async -> PictureSource? {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaSubtype & %d != 0", PHAssetMediaSubtype.photoScreenshot.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 5
        let assets = PHAsset.fetchAssets(with: PHAssetMediaType.image, options: options)
        for index in 0..<assets.count {
            if let data = await imageData(of: assets.object(at: index)), let source = try? PictureSource(data: data) {
                return source
            }
        }
        return nil
    }

    /// Fetches up to `limit` locally cached recent screenshots for PickerScreen's quick strip.
    /// Returns empty immediately unless the user already granted `.authorized` full library access.
    static func recentScreenshots(limit: Int = 10, targetPixels: CGSize = CGSize(width: 240, height: 340)) async -> [RecentScreenshot] {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized else { return [] }
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaSubtype & %d != 0", PHAssetMediaSubtype.photoScreenshot.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = limit
        let assets = PHAsset.fetchAssets(with: PHAssetMediaType.image, options: options)
        var results: [RecentScreenshot] = []
        results.reserveCapacity(assets.count)
        for index in 0..<assets.count {
            let asset = assets.object(at: index)
            if let thumb = await thumbnail(of: asset, targetSize: targetPixels) {
                results.append(RecentScreenshot(id: asset.localIdentifier, thumbnail: thumb))
            }
        }
        return results
    }

    /// Loads full-resolution original data for an asset picked from the Photo Library grid.
    /// Works under both `.authorized` and `.limited` library permissions.
    static func picture(localIdentifier: String) async -> PictureSource? {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return nil }
        let fetched = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = fetched.firstObject, let data = await imageData(of: asset) else { return nil }
        return try? PictureSource(data: data)
    }

    /// Loads full-resolution original data directly from a `PHAsset`.
    static func picture(asset: PHAsset) async -> PictureSource? {
        guard let data = await imageData(of: asset) else { return nil }
        return try? PictureSource(data: data)
    }

    /// Loads upright `CGImage` frames in order from already-resolved `PHAsset`s (local-only,
    /// falling back from raw file data to rendered local `PHImageManager` output when needed).
    static func images(assets: [PHAsset]) async -> [CGImage] {
        var result: [CGImage] = []
        result.reserveCapacity(assets.count)
        for asset in assets {
            if let source = await picture(asset: asset), let cg = try? source.uprightImage() {
                result.append(cg)
            } else if let fallback = await localRenderedCGImage(of: asset) {
                result.append(fallback)
            }
        }
        return result
    }

    /// Loads upright `CGImage` frames in order from PhotoKit identifiers (for long-screenshot stitching).
    static func images(localIdentifiers: [String]) async -> [CGImage] {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited, !localIdentifiers.isEmpty else { return [] }
        let fetched = PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil)
        var byID: [String: PHAsset] = [:]
        byID.reserveCapacity(fetched.count)
        for index in 0..<fetched.count {
            let asset = fetched.object(at: index)
            byID[asset.localIdentifier] = asset
        }
        let orderedAssets = localIdentifiers.compactMap { byID[$0] }
        return await images(assets: orderedAssets)
    }

    private static func localRenderedCGImage(of asset: PHAsset) async -> CGImage? {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        options.resizeMode = .exact

        let uiImage: UIImage? = await withCheckedContinuation { continuation in
            let lock = NSLock()
            var resumed = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 2200, height: 2200),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: image)
            }
        }
        guard let uiImage else { return nil }
        return uprightCGImage(from: uiImage)
    }

    private static func uprightCGImage(from image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cg = image.cgImage {
            return cg
        }
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image.cgImage }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.cgImage
    }

    /// Lists local videos (including iOS screen recordings) ordered newest-first for long-screenshot extraction.
    static func recentVideos(limit: Int = 24) -> [LibraryVideoItem] {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return [] }
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = limit
        let assets = PHAsset.fetchAssets(with: .video, options: options)
        var items: [LibraryVideoItem] = []
        items.reserveCapacity(assets.count)
        for index in 0..<assets.count {
            let asset = assets.object(at: index)
            items.append(LibraryVideoItem(id: asset.localIdentifier, duration: asset.duration))
        }
        return items
    }

    /// Loads a video preview thumbnail from PhotoKit.
    static func videoThumbnail(localIdentifier: String, targetSize: CGSize) async -> UIImage? {
        let fetched = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = fetched.firstObject else { return nil }
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        return await withCheckedContinuation { continuation in
            let lock = NSLock()
            var resumed = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                let hasError = info?[PHImageErrorKey] != nil
                if isDegraded && !isCancelled && !hasError {
                    return
                }
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: image)
            }
        }
    }

    /// Resolves a PhotoKit video as `AVAsset` (supports both `AVURLAsset` and trimmed `AVComposition`).
    static func videoAsset(localIdentifier: String) async -> SendableAVAsset? {
        let fetched = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = fetched.firstObject else { return nil }
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .highQualityFormat
        return await withCheckedContinuation { continuation in
            let lock = NSLock()
            var resumed = false
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: avAsset.map { SendableAVAsset(asset: $0) })
            }
        }
    }

    /// Resolves a local `URL` for a PhotoKit video asset (returns nil if only in iCloud or `AVComposition`).
    static func videoURL(localIdentifier: String) async -> URL? {
        let fetched = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = fetched.firstObject else { return nil }
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .highQualityFormat
        return await withCheckedContinuation { continuation in
            let lock = NSLock()
            var resumed = false
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
                let url = (avAsset as? AVURLAsset)?.url
                continuation.resume(returning: url)
            }
        }
    }

    /// Loads a local video file URL from a system `PhotosPickerItem` (caller removes temp file when done).
    static func videoURL(from item: PhotosPickerItem) async -> URL? {
        (try? await item.loadTransferable(type: PickedMovieTransferable.self))?.url
    }

    private static func thumbnail(of asset: PHAsset, targetSize: CGSize) async -> CGImage? {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image?.cgImage)
            }
        }
    }

    private static func imageData(of asset: PHAsset) async -> Data? {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .highQualityFormat
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }

    /// A picture picked with the system picker. The original file comes through as it is.
    static func picture(from item: PhotosPickerItem) async -> PictureSource? {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
        return try? PictureSource(data: data)
    }

    /// A picture picked in the Files picker.
    static func picture(at url: URL) -> PictureSource? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return try? PictureSource(url: url)
    }

    /// A scanned page from VisionKit Document Camera encoded cleanly as JPEG data.
    static func picture(from uiImage: UIImage) -> PictureSource? {
        guard let data = uiImage.jpegData(compressionQuality: 0.96) else { return nil }
        return try? PictureSource(data: data)
    }

    /// An image on the clipboard, as its file when there is one, else as PNG.
    static func pictureFromPasteboard() -> PictureSource? {
        let pasteboard = UIPasteboard.general
        let types = [UTType.heic, .jpeg, .png, .tiff, .gif, .webP].map(\.identifier)
        for type in types where pasteboard.contains(pasteboardTypes: [type]) {
            if let data = pasteboard.data(forPasteboardType: type), let source = try? PictureSource(data: data) {
                return source
            }
        }
        if let data = pasteboard.image?.pngData() {
            return try? PictureSource(data: data)
        }
        return nil
    }
}
