#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// SwiftUI reorderable list: drag items within and across sections, or switch `mode` to
/// `.sections` to reorder whole sections. Wraps `BaseReorderList`, because SwiftUI's `.onMove`
/// can't move items between sections.
///
///     @State private var sections = [
///         BaseReorderSection("To do", items: ["Design", "Build"]),
///         BaseReorderSection("Done", items: ["Plan"]),
///     ]
///     @State private var mode: BaseReorderMode = .items
///
///     BaseReorderListView(sections: $sections, mode: mode) { BaseReorderRow(title: $0) }
///
/// Fills the space it is given and scrolls itself; don't nest it in a `ScrollView`.
public struct BaseReorderListView<Item: Hashable>: UIViewRepresentable {
    @Binding private var sections: [BaseReorderSection<Item>]
    private let mode: BaseReorderMode
    private let allowsCrossSectionMoves: Bool
    private let emptySectionText: String?
    private let canMoveItem: ((Item) -> Bool)?
    private let row: (Item) -> BaseReorderRow

    public init(sections: Binding<[BaseReorderSection<Item>]>,
                mode: BaseReorderMode = .items,
                allowsCrossSectionMoves: Bool = true,
                emptySectionText: String? = "Drag items here",
                canMoveItem: ((Item) -> Bool)? = nil,
                row: @escaping (Item) -> BaseReorderRow) {
        self._sections = sections
        self.mode = mode
        self.allowsCrossSectionMoves = allowsCrossSectionMoves
        self.emptySectionText = emptySectionText
        self.canMoveItem = canMoveItem
        self.row = row
    }

    public func makeUIView(context: Context) -> BaseReorderList<Item> {
        let list = BaseReorderList(sections: sections, row: row)
        list.mode = mode
        list.allowsCrossSectionMoves = allowsCrossSectionMoves
        list.emptySectionText = emptySectionText
        list.canMoveItem = canMoveItem
        list.onChange = { sections = $0 }
        return list
    }

    public func updateUIView(_ list: BaseReorderList<Item>, context: Context) {
        list.onChange = { sections = $0 }
        list.allowsCrossSectionMoves = allowsCrossSectionMoves
        // Only push real changes, so a user move echoing back through the binding doesn't reload.
        if list.sections != sections { list.sections = sections }
        if list.mode != mode { list.mode = mode }
        if list.emptySectionText != emptySectionText { list.emptySectionText = emptySectionText }
    }
}
#endif
