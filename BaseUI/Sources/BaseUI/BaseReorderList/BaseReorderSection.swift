import Foundation
import CoreGraphics

/// A titled group of items in a reorder list (`BaseReorderList`) or collection (`BaseReorderCollection`).
///
///     BaseReorderSection("Highlights", items: highlights, layout: .banner, isPinned: true)
public struct BaseReorderSection<Item: Hashable>: Identifiable, Hashable {
    public var id: String
    public var title: String
    public var items: [Item]
    /// Cell type and layout of this section in a `BaseReorderCollection`. `nil` uses the
    /// collection's `layout`. Ignored by the table-based `BaseReorderList`.
    public var layout: BaseReorderCollectionLayout?
    /// Keeps the section at its position: it can't be dragged, and other sections can't be
    /// dragged past it. Pin the first section(s) to keep them on top.
    public var isPinned: Bool
    /// `false` locks the items: they can't be dragged out and nothing can be dropped in.
    public var allowsItemMoves: Bool
    /// Width / height of this section's cells in a `BaseReorderCollection`. `nil` uses the
    /// collection's `itemSize`, then the layout's defaults.
    public var itemSize: BaseReorderItemSize?
    /// Fixed height of the section's cell area (header not included), in points. Cells that don't fit
    /// continue in further columns / pages that scroll sideways; cells with an automatic height in a
    /// carousel or banner section fill it. Ignored by `.list` sections (rows can't scroll inside a list).
    public var height: CGFloat?

    public init(id: String, title: String, items: [Item], layout: BaseReorderCollectionLayout? = nil,
                itemSize: BaseReorderItemSize? = nil, height: CGFloat? = nil,
                isPinned: Bool = false, allowsItemMoves: Bool = true) {
        self.id = id
        self.title = title
        self.items = items
        self.layout = layout
        self.itemSize = itemSize
        self.height = height
        self.isPinned = isPinned
        self.allowsItemMoves = allowsItemMoves
    }

    /// Uses the title as the id.
    public init(_ title: String, items: [Item], layout: BaseReorderCollectionLayout? = nil,
                itemSize: BaseReorderItemSize? = nil, height: CGFloat? = nil,
                isPinned: Bool = false, allowsItemMoves: Bool = true) {
        self.init(id: title, title: title, items: items, layout: layout, itemSize: itemSize, height: height,
                  isPinned: isPinned, allowsItemMoves: allowsItemMoves)
    }
}

/// Layout and cell type of a `BaseReorderCollection`, or of one of its sections.
public enum BaseReorderCollectionLayout: Hashable {
    /// Inset-grouped rows, like `BaseReorderList`.
    case list
    /// Tiles in a fixed number of columns.
    case grid(columns: Int)
    /// Cards in one horizontally scrolling row.
    case carousel
    /// Large full-width cards.
    case banner
}

/// Cell size for a `BaseReorderCollection` section.
///
///     BaseReorderItemSize(width: .absolute(200), height: .absolute(120))   // fixed cards
///     BaseReorderItemSize(width: .fractionalWidth(0.8))                    // 80% wide, self-sizing height
///     BaseReorderItemSize(width: .absolute(80), height: .fractionalWidth(0.25))  // grid: as many 80pt columns as fit
///
/// How width applies per layout: `.grid` — `.absolute` fits as many columns of that width as possible,
/// `.fractionalWidth(f)` makes `1/f` columns; `.carousel` / `.banner` — the cell width; `.list` — ignored
/// (rows fill the width). Height applies to every layout.
public struct BaseReorderItemSize: Hashable {

    public enum Dimension: Hashable {
        /// The layout's default.
        case automatic
        /// Exactly this many points.
        case absolute(CGFloat)
        /// A fraction of the section's content width (inside its 16pt side insets).
        /// For height this gives an aspect ratio, e.g. square grid tiles.
        case fractionalWidth(CGFloat)
        /// Starts at this many points and grows to fit the content.
        case estimated(CGFloat)
    }

    public var width: Dimension
    public var height: Dimension

    public init(width: Dimension = .automatic, height: Dimension = .automatic) {
        self.width = width
        self.height = height
    }

    public static func fixed(width: CGFloat, height: CGFloat) -> BaseReorderItemSize {
        .init(width: .absolute(width), height: .absolute(height))
    }
}

/// Frame math for sections with per-item sizes or a fixed height (pure, so it's unit-tested).
enum BaseReorderFlow {
    struct Result: Equatable {
        var frames: [CGRect]
        var size: CGSize
    }

    /// One row, left to right (carousels). With `height`, the row is that tall.
    static func row(_ sizes: [CGSize], spacing: CGFloat, height: CGFloat?) -> Result {
        var x: CGFloat = 0
        var frames: [CGRect] = []
        for size in sizes {
            frames.append(CGRect(x: x, y: 0, width: size.width, height: size.height))
            x += size.width + spacing
        }
        let tallest = sizes.map(\.height).max() ?? 0
        return Result(frames: frames, size: CGSize(width: max(0, x - spacing), height: height ?? tallest))
    }

    /// Rows that wrap at `width` (grids, banners). With `maxHeight`, a row that would overflow starts a
    /// new page to the right, so the section keeps a fixed height and scrolls sideways.
    static func wrapping(_ sizes: [CGSize], width: CGFloat, spacing: CGFloat, maxHeight: CGFloat?) -> Result {
        var frames: [CGRect] = []
        var pageX: CGFloat = 0, x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, contentHeight: CGFloat = 0
        for size in sizes {
            let size = CGSize(width: min(size.width, width), height: size.height)
            if x > 0, x + size.width > width + 0.5 {          // wrap to the next row
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            if let maxHeight, y > 0, y + size.height > maxHeight + 0.5 {   // next page
                pageX += width + spacing
                y = 0
            }
            frames.append(CGRect(x: pageX + x, y: y, width: size.width, height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            contentHeight = max(contentHeight, y + rowHeight)
        }
        return Result(frames: frames, size: CGSize(width: pageX + width, height: maxHeight ?? contentHeight))
    }
}

/// What the user drags.
public enum BaseReorderMode: Hashable {
    /// Drag items within and across sections.
    case items
    /// Each section collapses to one row; drag to reorder sections.
    case sections
}

/// How a row looks. Shared by the UIKit and SwiftUI lists.
public struct BaseReorderRow {
    public var title: String
    public var subtitle: String?
    public var systemImage: String?

    public init(title: String, subtitle: String? = nil, systemImage: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }
}

/// Pure move operations, matching `UITableView`'s "remove, then insert at the destination" semantics.
public enum BaseReorder {

    public static func moveItem<Item>(in sections: inout [BaseReorderSection<Item>],
                                      from source: IndexPath, to destination: IndexPath) {
        guard source != destination,
              sections.indices.contains(source.section),
              sections[source.section].items.indices.contains(source.row),
              sections.indices.contains(destination.section) else { return }
        let item = sections[source.section].items.remove(at: source.row)
        let row = min(max(0, destination.row), sections[destination.section].items.count)
        sections[destination.section].items.insert(item, at: row)
    }

    /// Keeps a proposed drop position inside the section's valid range. Within the same section the
    /// item is removed first, so the last valid row is `count - 1`; in another section it is `count`.
    static func clampedDestination(_ destination: IndexPath, from source: IndexPath, itemCounts: [Int]) -> IndexPath {
        guard itemCounts.indices.contains(destination.section) else { return source }
        let count = itemCounts[destination.section]
        let maxRow = destination.section == source.section ? max(0, count - 1) : count
        return IndexPath(item: min(max(0, destination.item), maxRow), section: destination.section)
    }

    /// Keeps a section move from crossing pinned sections: pinned sections never change index.
    /// Returns `source` when the section itself is pinned.
    public static func clampedSectionDestination(from source: Int, to destination: Int, pinned: [Bool]) -> Int {
        guard pinned.indices.contains(source), !pinned[source] else { return source }
        var target = min(max(0, destination), pinned.count - 1)
        if target < source, let wall = (target..<source).last(where: { pinned[$0] }) {
            target = wall + 1
        } else if target > source, let wall = ((source + 1)...target).first(where: { pinned[$0] }) {
            target = wall - 1
        }
        return target
    }

    public static func moveSection<Item>(in sections: inout [BaseReorderSection<Item>],
                                         from source: Int, to destination: Int) {
        guard source != destination, sections.indices.contains(source) else { return }
        let section = sections.remove(at: source)
        sections.insert(section, at: min(max(0, destination), sections.count))
    }
}
