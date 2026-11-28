import CoreGraphics
import Photos
import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// Export actions backed directly by `MaskRenderer` without re-encoding.
enum ExportActions {

    /// Saves the flattened image data into the Photo Library as a new asset.
    static func saveToPhotos(_ data: Data) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: data, options: nil)
        }
    }

    /// Places the flattened image data on the general pasteboard with its exact UTType.
    @MainActor
    static func copy(_ data: Data, fileType: UTType?) {
        UIPasteboard.general.setData(data, forPasteboardType: (fileType ?? .jpeg).identifier)
    }

    /// Maps a resolved export UTType to a standard image filename extension for system share sheets.
    static func fileExtension(for fileType: UTType?) -> String {
        if fileType == .png { return "png" }
        if fileType == .heic { return "heic" }
        if fileType == .jpeg { return "jpg" }
        return fileType?.preferredFilenameExtension ?? "jpg"
    }

    /// Writes flattened image data to a uniquely named temporary file URL suitable for `UIActivityViewController`.
    static func makeShareFileURL(data: Data, fileType: UTType?) throws -> URL {
        let ext = fileExtension(for: fileType)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuickCover-\(UUID().uuidString.prefix(8))")
            .appendingPathExtension(ext)
        try data.write(to: url, options: .atomic)
        return url
    }
}

/// Native `UIActivityViewController` wrapper presenting an exported file URL cleanly on iOS/iPadOS.
struct ShareActivitySheet: UIViewControllerRepresentable {
    let fileURL: URL
    var onComplete: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        let url = fileURL
        let onComplete = onComplete
        controller.completionWithItemsHandler = { _, _, _, _ in
            try? FileManager.default.removeItem(at: url)
            Task { @MainActor in
                onComplete?()
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Concrete PNG `Transferable` payload for iOS `.copyable(_:)` drag/pasteboard interoperability.
struct CoveredImageExport: Transferable, Sendable {
    let picture: PictureSource
    let findings: [Finding]
    let options: MaskRenderer.Options

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { export in
            try await Task.detached(priority: .userInitiated) {
                var pngOptions = export.options
                pngOptions.format = .png
                return try MaskRenderer.encode(
                    export.picture.source,
                    orientation: export.picture.orientation,
                    findings: export.findings,
                    options: pngOptions
                )
            }.value
        }
    }
}
