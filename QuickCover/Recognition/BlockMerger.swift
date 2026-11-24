import CoreGraphics
import Foundation

/// Joins text hits that sit side by side on one line into one block, so the strip between them
/// is covered as well: when the rules catch only the pieces of one number, the digits in between
/// would otherwise stay visible. Brief §6: one checklist item is one block on the picture.
enum BlockMerger {

    /// How close is "close": under this many line heights between two hits, they are one block.
    /// Two characters of the line, at most.
    static let defaultGapEm: CGFloat = 2

    struct Options: Equatable, Sendable {
        /// Hits whose edges are closer than this many line heights are joined. 0 joins nothing.
        var maxGapEm: CGFloat = BlockMerger.defaultGapEm
        /// How much two hits must overlap vertically to count as one line, as a share of the shorter one.
        var minLineOverlap: CGFloat = 0.5

        static let off = Options(maxGapEm: 0)
    }

    /// The findings with each group of close text hits replaced by its block. Faces and codes stay
    /// as they are, and everything keeps its place.
    static func merge(_ findings: [Finding], options: Options = Options()) -> [Finding] {
        let blocks = groups(findings, options: options)
        // A block stands where the first hit of its group stood; the other hits leave with it.
        var out: [Finding] = []
        var next = 0
        for finding in findings {
            if finding.kind == .text {
                guard next < blocks.count, finding == blocks[next].first else { continue }
                out.append(block(blocks[next]))
                next += 1
            } else {
                out.append(finding)
            }
        }
        return out
    }

    /// The text hits, each with the other hits it is joined to: a group of one for a hit that
    /// stands alone. Groups come in the order of their first hit.
    static func groups(_ findings: [Finding], options: Options = Options()) -> [[Finding]] {
        let text = findings.filter { $0.kind == .text }
        guard options.maxGapEm > 0, text.count > 1 else { return text.map { [$0] } }

        // The closest joinable pair goes first, until no pair is left.
        var blocks = text.map { [$0] }
        while true {
            // The line each block stands on, not its whole box: a value wrapped onto two lines
            // spans both, and is still joined with what stands beside its first piece.
            let bounds = blocks.map { block($0).lineBox }
            var best: (Int, Int)?
            var bestGap = CGFloat.greatestFiniteMagnitude
            for i in bounds.indices {
                for j in bounds.indices where j > i {
                    guard let gap = joinGap(bounds[i], bounds[j], options), gap < bestGap else { continue }
                    best = (i, j)
                    bestGap = gap
                }
            }
            guard let (i, j) = best else { break }
            blocks[i] += blocks[j]
            blocks.remove(at: j)
        }
        return blocks
    }

    /// The gap between two boxes that can be joined, in pixels, or nil when they cannot: not on
    /// the same line, overlapping, or too far apart.
    static func joinGap(_ a: CGRect, _ b: CGRect, _ options: Options) -> CGFloat? {
        let shared = min(a.maxY, b.maxY) - max(a.minY, b.minY)
        guard shared >= options.minLineOverlap * min(a.height, b.height) else { return nil }
        let gap = max(a.minX, b.minX) - min(a.maxX, b.maxX)
        guard gap >= 0 else { return nil }
        let em = (a.height + b.height) / 2
        return gap <= options.maxGapEm * em ? gap : nil
    }

    /// The block that covers every hit of the group: from the left edge of the leftmost one to
    /// the right edge of the rightmost. Hits of different rules are just "text" in the checklist.
    static func block(_ group: [Finding]) -> Finding {
        group.dropFirst().reduce(group[0]) { joined($0, $1) }
    }

    static func joined(_ a: Finding, _ b: Finding) -> Finding {
        let (left, right) = a.lineBox.minX <= b.lineBox.minX ? (a, b) : (b, a)
        // The rectangle stands for both hits. Their own boxes go with it: what either carried
        // from another line stays, and nothing of the rectangle they were absorbed into.
        return Finding(kind: .text,
                       rule: a.rule == b.rule ? a.rule : nil,
                       pieces: [[left.quad[0], right.quad[1], right.quad[2], left.quad[3]]] + a.parts + b.parts,
                       evidence: left.evidence + " " + right.evidence,
                       tolerant: a.tolerant || b.tolerant)
    }
}
