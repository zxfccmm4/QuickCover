import CoreGraphics
import Testing

@testable import QuickCover

/// 导出页的几样判断（design.md §7.5）：只算不画。
struct ExportFactsTests {

    @Test
    func solidShowsTheCoveredLineAndNoNotice() {
        let facts = ExportFacts(style: .solid, stripMetadata: true, blurPickedThisTime: false, coversText: true)
        #expect(facts.showsCoveredLine)
        #expect(!facts.showsNotice)
        #expect(!facts.showsBlurNotice && !facts.showsMosaicNotice)
        #expect(facts.pictureMaxHeight == 380)
    }

    /// 马赛克下都提醒，这次自己选的也一样（和模糊那条不一样）；图里得有文字类的遮罩（copy.md 6.2.4、6.3.3）。
    @Test(arguments: [true, false])
    func mosaicShowsItsNoticeWhoeverPickedItWhenTextIsCovered(blurPickedThisTime: Bool) {
        let facts = ExportFacts(style: .mosaic, stripMetadata: true, blurPickedThisTime: blurPickedThisTime, coversText: true)
        #expect(facts.showsMosaicNotice)
        #expect(!facts.showsBlurNotice, "它是马赛克那条，不是模糊那条")
        #expect(facts.showsNotice)
        #expect(!facts.showsCoveredLine, "马赛克下没有 6.2.4")
        #expect(facts.pictureMaxHeight == 285)
        #expect(facts.pictureSize(aspect: 0.5) == CGSize(width: 142.5, height: 285), "长图给提醒条让地方")
    }

    /// 6.3.3 说的是字。只有人脸的合照在马赛克下什么都不显示，图按没有提醒条排（Ato 定，2026-11-24）。
    @Test(arguments: [true, false])
    func mosaicOverFacesOnlyShowsNothing(blurPickedThisTime: Bool) {
        let facts = ExportFacts(style: .mosaic, stripMetadata: true, blurPickedThisTime: blurPickedThisTime, coversText: false)
        #expect(!facts.showsCoveredLine)
        #expect(!facts.showsNotice)
        #expect(!facts.showsMosaicNotice && !facts.showsBlurNotice)
        #expect(facts.pictureMaxHeight == 380)
        #expect(facts.pictureSize(aspect: 0.5) == CGSize(width: 190, height: 380))
    }

    @Test
    func aLeftoverBlurGetsTheNoticeAndAShorterPicture() {
        let facts = ExportFacts(style: .blur, stripMetadata: true, blurPickedThisTime: false, coversText: true)
        #expect(facts.showsBlurNotice)
        #expect(!facts.showsMosaicNotice)
        #expect(facts.showsNotice)
        #expect(!facts.showsCoveredLine, "模糊时没有 6.2.4")
        #expect(facts.pictureMaxHeight == 285)
    }

    @Test
    func aBlurPickedThisTimeIsntToldAboutAgain() {
        let facts = ExportFacts(style: .blur, stripMetadata: false, blurPickedThisTime: true, coversText: true)
        #expect(!facts.showsBlurNotice)
        #expect(!facts.showsMosaicNotice)
        #expect(!facts.showsNotice)
        #expect(!facts.showsCoveredLine, "样式还是模糊，6.2.4 还是没有")
        #expect(facts.pictureMaxHeight == 380)
    }

    @Test
    func stripesShowsItsNoticeWhenTextIsCoveredAndNoneForFacesOnly() {
        let withText = ExportFacts(style: .stripes, stripMetadata: true, blurPickedThisTime: false, coversText: true)
        #expect(withText.showsStripesNotice)
        #expect(withText.showsNotice)
        #expect(withText.noticeKey == "6.3.5")
        #expect(!withText.showsCoveredLine)
        #expect(withText.pictureMaxHeight == 285)

        let facesOnly = ExportFacts(style: .stripes, stripMetadata: true, blurPickedThisTime: false, coversText: false)
        #expect(!facesOnly.showsStripesNotice)
        #expect(!facesOnly.showsNotice)
        #expect(facesOnly.noticeKey == nil)
        #expect(facesOnly.pictureMaxHeight == 380)
    }

    @Test(arguments: [MaskStyle.solid, .conceal, .emoji])
    func zeroTraceStylesShowCoveredLineAndNoNotice(style: MaskStyle) {
        let facts = ExportFacts(style: style, stripMetadata: true, blurPickedThisTime: false, coversText: true)
        #expect(facts.showsCoveredLine)
        #expect(!facts.showsNotice)
        #expect(facts.noticeKey == nil)
        #expect(facts.pictureMaxHeight == 380)
    }

    /// Every combination of style × blurPickedThisTime × coversText across all 6 mask styles.
    @Test(arguments: MaskStyle.allCases.flatMap { style in
        [false, true].flatMap { picked in [false, true].map { covers in (style, picked, covers) } }
    })
    func thePictureIsShorterOnlyUnderANotice(style: MaskStyle, blurPickedThisTime: Bool, coversText: Bool) {
        let facts = ExportFacts(style: style, stripMetadata: true, blurPickedThisTime: blurPickedThisTime, coversText: coversText)
        #expect(facts.showsCoveredLine == style.leavesNoTrace)
        #expect(facts.showsBlurNotice == (style == .blur && !blurPickedThisTime))
        #expect(facts.showsMosaicNotice == (style == .mosaic && coversText))
        #expect(facts.showsStripesNotice == (style == .stripes && coversText))
        #expect(facts.showsNotice == (facts.showsBlurNotice || facts.showsMosaicNotice || facts.showsStripesNotice))
        #expect(facts.pictureMaxHeight == (facts.showsNotice ? 285 : 380))
    }

    @Test
    func theFootnoteFollowsTheSwitch() {
        #expect(ExportFacts(style: .mosaic, stripMetadata: true, blurPickedThisTime: false, coversText: true).footnote == "6.2.2")
        #expect(ExportFacts(style: .mosaic, stripMetadata: false, blurPickedThisTime: false, coversText: false).footnote == "6.2.3")
    }

    @Test
    func thePictureKeepsItsAspectRatioInsideTheBox() {
        // Mosaic with nothing read under the covers: no notice, the whole 380 for the picture.
        let facts = ExportFacts(style: .mosaic, stripMetadata: true, blurPickedThisTime: false, coversText: false)
        #expect(facts.pictureSize(aspect: 2) == CGSize(width: 300, height: 150), "宽图最宽 300")
        #expect(facts.pictureSize(aspect: 0.5) == CGSize(width: 190, height: 380), "长图最高 380")
        #expect(facts.pictureSize(aspect: 1) == CGSize(width: 300, height: 300))
        #expect(facts.pictureSize(aspect: 3, maxWidth: 240) == CGSize(width: 240, height: 80), "窄屏上照样两边留 60")
    }

    @Test
    func underTheMosaicNoticeThePictureStopsAt285() {
        let facts = ExportFacts(style: .mosaic, stripMetadata: true, blurPickedThisTime: false, coversText: true)
        #expect(facts.showsNotice)
        #expect(facts.pictureSize(aspect: 0.5) == CGSize(width: 142.5, height: 285), "长图最高 285")
        #expect(facts.pictureSize(aspect: 1) == CGSize(width: 285, height: 285))
        #expect(facts.pictureSize(aspect: 2) == CGSize(width: 300, height: 150), "宽图不受影响")
    }

    @Test
    func aBlurNoticeMakesRoomByHeightOnly() {
        let facts = ExportFacts(style: .blur, stripMetadata: true, blurPickedThisTime: false, coversText: true)
        #expect(facts.pictureSize(aspect: 2) == CGSize(width: 300, height: 150), "宽图本来就矮，不变")
        #expect(facts.pictureSize(aspect: 0.5) == CGSize(width: 142.5, height: 285))
    }

    @Test
    func aBadAspectRatioGivesNoPicture() {
        #expect(PictureFit.size(aspect: 0, maxWidth: 300, maxHeight: 380) == .zero)
        #expect(PictureFit.size(aspect: .nan, maxWidth: 300, maxHeight: 380) == .zero)
        #expect(PictureFit.size(aspect: .infinity, maxWidth: 300, maxHeight: 380) == .zero)
    }
}
