import CoreGraphics
import Testing

@testable import QuickCover

/// 导出页的几样判断（design.md §7.5）：只算不画。
struct ExportFactsTests {

    @Test(arguments: [MaskStyle.mosaic, .solid])
    func mosaicAndSolidShowTheCoveredLineAndNoNotice(style: MaskStyle) {
        let facts = ExportFacts(style: style, stripMetadata: true, blurPickedThisTime: false)
        #expect(facts.showsCoveredLine)
        #expect(!facts.showsBlurNotice)
        #expect(facts.pictureMaxHeight == 380)
    }

    @Test
    func aLeftoverBlurGetsTheNoticeAndAShorterPicture() {
        let facts = ExportFacts(style: .blur, stripMetadata: true, blurPickedThisTime: false)
        #expect(facts.showsBlurNotice)
        #expect(!facts.showsCoveredLine, "模糊时没有 6.2.4")
        #expect(facts.pictureMaxHeight == 285)
    }

    @Test
    func aBlurPickedThisTimeIsntToldAboutAgain() {
        let facts = ExportFacts(style: .blur, stripMetadata: false, blurPickedThisTime: true)
        #expect(!facts.showsBlurNotice)
        #expect(!facts.showsCoveredLine, "样式还是模糊，6.2.4 还是没有")
        #expect(facts.pictureMaxHeight == 380)
    }

    @Test
    func theFootnoteFollowsTheSwitch() {
        #expect(ExportFacts(style: .mosaic, stripMetadata: true, blurPickedThisTime: false).footnote == "6.2.2")
        #expect(ExportFacts(style: .mosaic, stripMetadata: false, blurPickedThisTime: false).footnote == "6.2.3")
    }

    @Test
    func thePictureKeepsItsAspectRatioInsideTheBox() {
        let facts = ExportFacts(style: .mosaic, stripMetadata: true, blurPickedThisTime: false)
        #expect(facts.pictureSize(aspect: 2) == CGSize(width: 300, height: 150), "宽图最宽 300")
        #expect(facts.pictureSize(aspect: 0.5) == CGSize(width: 190, height: 380), "长图最高 380")
        #expect(facts.pictureSize(aspect: 1) == CGSize(width: 300, height: 300))
        #expect(facts.pictureSize(aspect: 3, maxWidth: 240) == CGSize(width: 240, height: 80), "窄屏上照样两边留 60")
    }

    @Test
    func aBlurNoticeMakesRoomByHeightOnly() {
        let facts = ExportFacts(style: .blur, stripMetadata: true, blurPickedThisTime: false)
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
