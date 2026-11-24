import CoreGraphics

/// One cover on the screen: the preview's pixels with one box pressed in, and where they go.
struct CoverPatch: Identifiable {
    /// `"<item>.<box>"`: the item's id and which of its boxes.
    let id: String
    /// In preview pixels, top-left origin.
    let frame: CGRect
    let image: CGImage
}

/// What has to be drawn again: the boxes that are on, and the style they are drawn in.
struct CoverKey: Equatable {
    let items: [MaskItem]
    let style: MaskStyle

    init(items: [MaskItem], style: MaskStyle) {
        self.items = items.filter(\.isOn)
        self.style = style
    }
}

/// Draws the covers the way the export will (design.md §7.3.2): the same `MaskRenderer`, on the
/// preview's pixels, so what is on the screen is what the file gets. One patch per box, each made
/// from a crop of the preview around its box; a crop holds the whole box, so the renderer's cell
/// size and blur radius come out as they do for the whole picture.
enum CoverPainter {

    /// Pixels kept around a box, so a blur doesn't meet the crop's edge.
    static let margin: CGFloat = 4

    static func patches(for key: CoverKey, preview: CGImage, scale: CGSize) -> [CoverPatch] {
        patches(items: key.items, style: key.style, preview: preview, scale: scale)
    }

    static func patches(items: [MaskItem], style: MaskStyle, preview: CGImage, scale: CGSize) -> [CoverPatch] {
        guard preview.width > 0, preview.height > 0, scale.width > 0, scale.height > 0 else { return [] }
        let imageRect = CGRect(x: 0, y: 0, width: preview.width, height: preview.height)
        var patches: [CoverPatch] = []
        for item in items where item.isOn {
            for (index, finding) in item.findings.enumerated() {
                let inPreview = finding.scaled(by: CGSize(width: 1 / scale.width, height: 1 / scale.height))
                let box = inPreview.box.intersection(imageRect)
                // Whole pixels only, and the margin where the picture has it.
                let crop = box.insetBy(dx: -margin, dy: -margin)
                    .intersection(imageRect)
                    .integral
                guard crop.width >= 2, crop.height >= 2, let pixels = preview.cropping(to: crop) else { continue }
                // Sized as the export sizes it: `textHeight` and `drawnByHand` are what the cells
                // and the blur's grains are cut by, so they go along with the box.
                let moved = Finding(kind: inPreview.kind, rule: inPreview.rule,
                                    quad: inPreview.quad.map { CGPoint(x: $0.x - crop.minX, y: $0.y - crop.minY) },
                                    evidence: inPreview.evidence, tolerant: inPreview.tolerant,
                                    textHeight: inPreview.textHeight, drawnByHand: inPreview.drawnByHand)
                let drawn = MaskRenderer.flatten(pixels, findings: [moved], style: style)
                patches.append(CoverPatch(id: "\(item.id).\(index)", frame: crop,
                                          image: onlyCover(drawn, quad: moved.quad)))
            }
        }
        return patches
    }

    /// Keeps the box's own cover and makes the rest of the crop transparent. `flatten` gives back
    /// the whole crop with the cover pressed in; crops of neighbours overlap, and a later one
    /// would repaint the picture over an earlier one's cover.
    private static func onlyCover(_ image: CGImage, quad: [CGPoint]) -> CGImage {
        guard let first = quad.first, let context = CGImage.rgbaContext(width: image.width, height: image.height) else { return image }
        // Top-left pixel coordinates, as the quad is written.
        context.translateBy(x: 0, y: CGFloat(image.height))
        context.scaleBy(x: 1, y: -1)
        let path = CGMutablePath()
        path.move(to: first)
        for point in quad.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        context.addPath(path)
        context.clip()
        context.translateBy(x: 0, y: CGFloat(image.height))
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height)))
        return context.makeImage() ?? image
    }
}
