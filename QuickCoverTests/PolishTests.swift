import Testing

@testable import QuickCover

/// 收尾这一轮定下的几个数（design.md §8）。
struct PolishTests {

    /// 导出页的 toast（§8 的表）：淡入 0.25 秒、停 1.6 秒、淡出 0.3 秒；淡出走完才把小条从页面上拿掉。
    @Test
    func theToastFadesAsTheSpecSays() {
        #expect(ExportToastTiming.fadeIn == 0.25)
        #expect(ExportToastTiming.fadeOut == 0.3)
        #expect(ExportToastTiming.shows == .seconds(1.6))
        #expect(ExportToastTiming.clears >= .seconds(ExportToastTiming.fadeOut))
    }

    /// `Toast` 自己的默认值和导出页传给它的是同一对。
    @Test
    @MainActor
    func theToastDefaultsMatchTheExportPage() {
        let toast = Toast(text: "6.4.1", isShown: false)
        #expect(toast.fadeIn == ExportToastTiming.fadeIn)
        #expect(toast.fadeOut == ExportToastTiming.fadeOut)
    }
}
