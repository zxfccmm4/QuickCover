import Photos
import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// 导出页存进照片、拷贝、分享用到的几样东西。用的都是 `EditorModel.exportData()` 给的文件，不重新编码。
enum ExportActions {

    /// 存进照片图库。第一次会弹系统的「只能添加」询问（copy.md 3.3.2）；没给就抛错，页面换成 6.4.2。
    static func saveToPhotos(_ data: Data) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: data, options: nil)
        }
    }

    /// 原样放到剪贴板，类型跟着文件走。
    @MainActor
    static func copy(_ data: Data, fileType: UTType?) {
        UIPasteboard.general.setData(data, forPasteboardType: (fileType ?? .jpeg).identifier)
    }
}

/// 拿去分享的文件。
struct ShareFile: Identifiable {
    let id = UUID()
    let data: Data
}

/// 系统的分享面板（design.md §7.5）。给的是文件本身。
struct ShareSheet: UIViewControllerRepresentable {
    let file: ShareFile

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [file.data], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
