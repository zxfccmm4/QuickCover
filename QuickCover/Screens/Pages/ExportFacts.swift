import CoreGraphics
import SwiftUI

/// 导出页从编辑页读出来的几样东西（design.md §7.5）。只算不画，测试直接调。
struct ExportFacts: Equatable {
    let style: MaskStyle
    let stripMetadata: Bool
    /// 这张图开着的时候自己选过模糊（design.md §7.5.2）。上面还是上次留下的模糊、这次没碰过时是 false。
    let blurPickedThisTime: Bool
    /// 导出的图里有没有文字类的遮罩（`EditorModel.coversText`）。
    let coversText: Bool

    /// 上次留下的模糊才提醒，这次自己选的不吵（§7.5.2）。
    var showsBlurNotice: Bool { style == .blur && !blurPickedThisTime }
    /// 马赛克下都提醒，这次自己选的也一样（和模糊那条不一样）：格子里的深浅还留着字的痕迹（copy.md 6.3.3）。
    /// 那句说的是字，所以只在图里有文字类的遮罩时出：只有人脸的合照、只有码或自己框的图什么都不显示（Ato 定，2026-11-24）。
    var showsMosaicNotice: Bool { style == .mosaic && coversText }
    /// 卡片下面有没有提醒条：模糊那条或马赛克那条。
    var showsNotice: Bool { showsBlurNotice || showsMosaicNotice }
    /// 打勾那一行（6.2.4）只在纯色下有（copy.md 6.2.4 的说明：Ato 定，2026-11-24）。
    var showsCoveredLine: Bool { style == .solid }
    /// 开着时念 6.2.2，关掉后念 6.2.3。
    var footnote: LocalizedStringKey { stripMetadata ? "6.2.2" : "6.2.3" }
    /// 图最高 380；有提醒条时给提醒让地方，最高 285（§7.5.2）。
    var pictureMaxHeight: CGFloat { showsNotice ? 285 : 380 }

    /// 图在页面上占的大小：按原图比例，宽最多 `maxWidth`（最多 300），高最多 `pictureMaxHeight`。
    func pictureSize(aspect: CGFloat, maxWidth: CGFloat = 300) -> CGSize {
        PictureFit.size(aspect: aspect, maxWidth: maxWidth, maxHeight: pictureMaxHeight)
    }
}

/// 按比例缩进一个框。
enum PictureFit {
    static func size(aspect: CGFloat, maxWidth: CGFloat, maxHeight: CGFloat) -> CGSize {
        guard aspect.isFinite, aspect > 0 else { return .zero }
        if maxWidth / aspect <= maxHeight {
            return CGSize(width: maxWidth, height: maxWidth / aspect)
        }
        return CGSize(width: maxHeight * aspect, height: maxHeight)
    }
}

/// 「已存到照片」「已拷貝」小条的时间（design.md §8、§7.5.4）：淡入 0.25 秒、停 1.6 秒、淡出 0.3 秒。
enum ExportToastTiming {
    static let fadeIn: Double = 0.25
    static let fadeOut: Double = 0.3
    static let shows: Duration = .seconds(1.6)
    /// 淡出走完 0.1 秒后把小条从页面上拿掉。
    static let clears: Duration = .seconds(fadeOut + 0.1)
}
