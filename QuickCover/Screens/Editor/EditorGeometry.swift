import CoreGraphics

/// Where the picture goes on the editor (design.md §7.3.2, §7.4.3, §7.3.7). Pure geometry, in the
/// points of the picture area.
///
/// The area is the rect the picture may fill. The picture is fitted into it: its「fitted」rect, at
/// zoom 1. `zoom` is 1…4 about the picture's centre and `offset` moves that centre off the area's
/// centre. A point of the picture, in fitted points from its top-left corner, is at
/// `centre + offset + (point + fitted.origin - fitted.mid) * zoom` in the area.
enum EditorGeometry {

    /// Two fingers take the picture from the fitted size to four times that (§7.3.2).
    static let zoomRange: ClosedRange<CGFloat> = 1...4
    ///「Locate」takes it to at most three times (§7.4.3).
    static let locateZoomRange: ClosedRange<CGFloat> = 1...3
    /// A drawn box with a side shorter than this, on screen, is not a box (§7.3.7).
    static let minimumBoxSide: CGFloat = 12
    /// How long a finger has to stay down before the covers go off (§7.3.6, §8).
    static let holdDelay = Duration.milliseconds(350)
    /// A finger that moves further than this before `holdDelay` is dragging, not holding.
    static let holdSlop: CGFloat = 10
    /// A located item fills at most this much of the visible width, and half its height (§7.4.3).
    static let locateWidthShare: CGFloat = 0.62
    static let locateHeightShare: CGFloat = 0.5

    /// The picture of `size` pixels, aspect-fitted and centred in an area of `area` points.
    static func fitted(size: CGSize, in area: CGSize) -> CGRect {
        guard size.width > 0, size.height > 0, area.width > 0, area.height > 0 else { return .zero }
        let scale = min(area.width / size.width, area.height / size.height)
        let fitted = CGSize(width: (size.width * scale).rounded(.down), height: (size.height * scale).rounded(.down))
        return CGRect(x: ((area.width - fitted.width) / 2).rounded(.down),
                      y: ((area.height - fitted.height) / 2).rounded(.down),
                      width: fitted.width, height: fitted.height)
    }

    static func clampedZoom(_ zoom: CGFloat, range: ClosedRange<CGFloat> = zoomRange) -> CGFloat {
        min(max(zoom, range.lowerBound), range.upperBound)
    }

    /// Zooming from `zoom` to `newZoom` while the point of the picture under `anchor` (in the area)
    /// stays there.
    static func offset(zoomingFrom zoom: CGFloat, to newZoom: CGFloat, anchor: CGPoint, areaCentre: CGPoint, offset: CGSize) -> CGSize {
        let fromAnchor = CGSize(width: anchor.x - areaCentre.x, height: anchor.y - areaCentre.y)
        let ratio = newZoom / zoom
        return CGSize(width: fromAnchor.width - (fromAnchor.width - offset.width) * ratio,
                      height: fromAnchor.height - (fromAnchor.height - offset.height) * ratio)
    }

    /// The offset nearest to `offset` that keeps the picture over all of `visible`: where the
    /// picture is at least as wide (or tall) as `visible`, its edge never comes inside `visible`'s;
    /// where it is narrower, it is centred on `visible`. `picture` is the fitted size.
    static func clamped(_ offset: CGSize, picture: CGSize, zoom: CGFloat, areaCentre: CGPoint, visible: CGRect) -> CGSize {
        let shown = CGSize(width: picture.width * zoom, height: picture.height * zoom)
        return CGSize(width: clampedAxis(offset.width, shown: shown.width, centre: areaCentre.x, from: visible.minX, to: visible.maxX),
                      height: clampedAxis(offset.height, shown: shown.height, centre: areaCentre.y, from: visible.minY, to: visible.maxY))
    }

    private static func clampedAxis(_ offset: CGFloat, shown: CGFloat, centre: CGFloat, from: CGFloat, to: CGFloat) -> CGFloat {
        guard shown >= to - from else { return (from + to) / 2 - centre }
        // The least that keeps the picture's far edge on `to`; the most that keeps its near edge on `from`.
        let least = to - shown / 2 - centre
        let most = from + shown / 2 - centre
        return min(max(offset, least), most)
    }

    /// The zoom and offset that bring the box `item` (in fitted points, from the picture's top-left
    /// corner) to the middle of `visible` (in the area), as large as §7.4.3 allows.
    static func locate(item: CGRect, fitted: CGRect, areaCentre: CGPoint, visible: CGRect) -> (zoom: CGFloat, offset: CGSize) {
        let zoom = clampedZoom(min(locateWidthShare * visible.width / item.width,
                                   locateHeightShare * visible.height / item.height),
                               range: locateZoomRange)
        // The item's centre off the picture's centre, in fitted points.
        let itemCentre = CGPoint(x: item.midX - fitted.width / 2, y: item.midY - fitted.height / 2)
        let offset = CGSize(width: visible.midX - areaCentre.x - itemCentre.x * zoom,
                            height: visible.midY - areaCentre.y - itemCentre.y * zoom)
        return (zoom, clamped(offset, picture: fitted.size, zoom: zoom, areaCentre: areaCentre, visible: visible))
    }

    /// The box drawn from `start` to `end` (in the area, in points on screen), or nil when a side is
    /// shorter than `minimumBoxSide` (§7.3.7).
    static func drawnBox(from start: CGPoint, to end: CGPoint) -> CGRect? {
        let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(end.x - start.x), height: abs(end.y - start.y))
        guard rect.width >= minimumBoxSide, rect.height >= minimumBoxSide else { return nil }
        return rect
    }

    /// A rect of the area, in points, as the same place of the picture in fitted points.
    static func pictureRect(of rect: CGRect, fitted: CGRect, zoom: CGFloat, offset: CGSize, areaCentre: CGPoint) -> CGRect {
        let topLeft = picturePoint(of: rect.origin, fitted: fitted, zoom: zoom, offset: offset, areaCentre: areaCentre)
        return CGRect(origin: topLeft, size: CGSize(width: rect.width / zoom, height: rect.height / zoom))
    }

    static func picturePoint(of point: CGPoint, fitted: CGRect, zoom: CGFloat, offset: CGSize, areaCentre: CGPoint) -> CGPoint {
        CGPoint(x: (point.x - areaCentre.x - offset.width) / zoom - fitted.origin.x + fitted.midX,
                y: (point.y - areaCentre.y - offset.height) / zoom - fitted.origin.y + fitted.midY)
    }
}
