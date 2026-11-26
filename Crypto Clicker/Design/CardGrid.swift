import SwiftUI

/// Cards in equal columns, as many as fit at `minimum` wide or more, each row as tall as its
/// tallest card (which every card in it stretches to). Unlike a lazy grid, every card is laid out
/// up front, so a long page's height never changes while it scrolls: lazy grids stacked on one
/// page guessed the height of rows they hadn't drawn yet, and the page jumped when they drew them.
struct CardGrid: Layout {
    var minimum: CGFloat = 160
    var spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? (minimum * 2 + spacing)
        let rows = rowHeights(width: width, subviews: subviews)
        let height = rows.reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let count = columns(for: bounds.width)
        let width = columnWidth(for: bounds.width, columns: count)
        let rows = rowHeights(width: bounds.width, subviews: subviews)
        var y = bounds.minY
        for (row, height) in rows.enumerated() {
            for column in 0..<count {
                let index = row * count + column
                guard index < subviews.count else { break }
                subviews[index].place(at: CGPoint(x: bounds.minX + CGFloat(column) * (width + spacing), y: y),
                                      proposal: ProposedViewSize(width: width, height: height))
            }
            y += height + spacing
        }
    }

    private func columns(for width: CGFloat) -> Int {
        max(1, Int((width + spacing) / (minimum + spacing)))
    }

    private func columnWidth(for width: CGFloat, columns: Int) -> CGFloat {
        max(0, (width - spacing * CGFloat(columns - 1)) / CGFloat(columns))
    }

    /// The height of each row: its tallest card at the column width.
    private func rowHeights(width: CGFloat, subviews: Subviews) -> [CGFloat] {
        let count = columns(for: width)
        let column = columnWidth(for: width, columns: count)
        return stride(from: 0, to: subviews.count, by: count).map { start in
            (start..<min(start + count, subviews.count))
                .map { subviews[$0].sizeThatFits(ProposedViewSize(width: column, height: nil)).height }
                .max() ?? 0
        }
    }
}
