import CoreGraphics
import Foundation

// TEMP(fix-merge): until the branch is merged in which a finding carries its boxes itself, a
// finding has the one `quad`. The editor builds every item from `finding.quads` already, so that
// branch changes nothing below this file; this extension is deleted then.
extension Finding {
    /// The boxes of the finding: one, or several when a value was wrapped onto two lines
    /// (design.md §0, §5).
    var quads: [[CGPoint]] { [quad] }
}
