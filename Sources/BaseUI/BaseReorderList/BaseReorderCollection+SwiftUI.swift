#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// SwiftUI wrapper of `BaseReorderCollection`: long-press and drag items within and across sections
/// in a list or grid, or switch `mode` to `.sections` to reorder whole sections.
///
///     BaseReorderCollectionView(sections: $sections, layout: .grid(columns: 3)) { app in
///         BaseReorderRow(title: app.name, systemImage: app.icon)
///     }
///
/// Fills the space it is given and scrolls itself. Inside a `ScrollView`, pass
/// `isScrollEnabled: false` so it sizes to its content and the outer view does the scrolling.
public struct BaseReorderCollectionView<Item: Hashable>: UIViewRepresentable {
    @Binding private var sections: [BaseReorderSection<Item>]
    private let mode: BaseReorderMode
    private let layout: BaseReorderCollectionLayout
    private let itemSize: BaseReorderItemSize?
    private let sizeForItem: ((Item, BaseReorderSection<Item>) -> BaseReorderItemSize?)?
    private let allowsCrossSectionMoves: Bool
    private let emptySectionText: String?
    private let canMoveItem: ((Item) -> Bool)?
    private let isScrollEnabled: Bool
    private let row: (Item) -> BaseReorderRow

    public init(sections: Binding<[BaseReorderSection<Item>]>,
                mode: BaseReorderMode = .items,
                layout: BaseReorderCollectionLayout = .list,
                itemSize: BaseReorderItemSize? = nil,
                sizeForItem: ((Item, BaseReorderSection<Item>) -> BaseReorderItemSize?)? = nil,
                allowsCrossSectionMoves: Bool = true,
                emptySectionText: String? = "Drag items here",
                canMoveItem: ((Item) -> Bool)? = nil,
                isScrollEnabled: Bool = true,
                row: @escaping (Item) -> BaseReorderRow) {
        self._sections = sections
        self.mode = mode
        self.layout = layout
        self.itemSize = itemSize
        self.sizeForItem = sizeForItem
        self.allowsCrossSectionMoves = allowsCrossSectionMoves
        self.emptySectionText = emptySectionText
        self.canMoveItem = canMoveItem
        self.isScrollEnabled = isScrollEnabled
        self.row = row
    }

    public func makeUIView(context: Context) -> BaseReorderCollection<Item> {
        let collection = BaseReorderCollection(sections: sections, layout: layout, row: row)
        collection.mode = mode
        collection.itemSize = itemSize
        collection.sizeForItem = sizeForItem
        collection.allowsCrossSectionMoves = allowsCrossSectionMoves
        collection.emptySectionText = emptySectionText
        collection.canMoveItem = canMoveItem
        collection.isScrollEnabled = isScrollEnabled
        collection.onChange = { sections = $0 }
        return collection
    }

    public func updateUIView(_ collection: BaseReorderCollection<Item>, context: Context) {
        collection.onChange = { sections = $0 }
        // Don't fight an in-flight section drag; the final order arrives through onChange.
        guard !collection.isDraggingSection else { return }
        collection.allowsCrossSectionMoves = allowsCrossSectionMoves
        // Only push real changes, so a user move echoing back through the binding doesn't reload.
        if collection.sections != sections { collection.sections = sections }
        if collection.mode != mode { collection.mode = mode }
        if collection.layout != layout { collection.layout = layout }
        if collection.itemSize != itemSize { collection.itemSize = itemSize }
        // Closures can't be compared; re-applying only re-lays out visible cells (no reload).
        collection.sizeForItem = sizeForItem
        collection.isScrollEnabled = isScrollEnabled
        if collection.emptySectionText != emptySectionText { collection.emptySectionText = emptySectionText }
    }
}
#endif
