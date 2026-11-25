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
}

/// Native SwiftUI `Transferable` payload for `ShareLink` and iOS 27 `.copyable(_:)`,
/// eliminating UIKit `UIActivityViewController` representable boilerplate.
struct CoveredImageExport: Transferable, Sendable {
    let picture: PictureSource
    let findings: [Finding]
    let options: MaskRenderer.Options

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .image) { export in
            try await Task.detached(priority: .userInitiated) {
                try MaskRenderer.encode(
                    export.picture.source,
                    orientation: export.picture.orientation,
                    findings: export.findings,
                    options: export.options
                )
            }.value
        }
    }
}
