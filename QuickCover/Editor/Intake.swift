import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

enum PhotosAccess: Equatable, Sendable {
    /// The app may look for the newest screenshot itself.
    case full
    /// Only the pictures the person chose; every picture comes through the system picker.
    case limited
    case denied
}

/// Brings a picture in: the newest screenshot, one picked in the system picker or a file, or the clipboard.
/// Nothing here asks for the photo library to read anything the person did not choose, except with
/// `.full` access, and nothing downloads from iCloud.
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
