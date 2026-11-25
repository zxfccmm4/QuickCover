import SwiftUI
import VisionKit

/// Native VisionKit document camera wrapper for scanning ID cards, contracts, invoices,
/// and paper receipts directly into the on-device privacy redaction studio.
struct DocumentScannerView: UIViewControllerRepresentable {
    let onScan: @Sendable @MainActor (UIImage) -> Void
    let onCancel: @Sendable @MainActor () -> Void

    static var isSupported: Bool {
        VNDocumentCameraViewController.isSupported
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: @Sendable @MainActor (UIImage) -> Void
        let onCancel: @Sendable @MainActor () -> Void

        init(
            onScan: @escaping @Sendable @MainActor (UIImage) -> Void,
            onCancel: @escaping @Sendable @MainActor () -> Void
        ) {
            self.onScan = onScan
            self.onCancel = onCancel
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            guard scan.pageCount > 0 else {
                let cancel = onCancel
                Task { @MainActor in cancel() }
                return
            }
            let image = scan.imageOfPage(at: 0)
            let finish = onScan
            Task { @MainActor in finish(image) }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            let cancel = onCancel
            Task { @MainActor in cancel() }
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            let cancel = onCancel
            Task { @MainActor in cancel() }
        }
    }
}
