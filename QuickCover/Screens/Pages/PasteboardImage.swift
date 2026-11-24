import UIKit

/// 剪贴板里有没有图（design.md §7.1）。只问有没有，不读内容，所以不会弹系统的「允许贴上」询问。
@MainActor
enum PasteboardImage {
    static var isPresent: Bool { UIPasteboard.general.hasImages }
}
