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
