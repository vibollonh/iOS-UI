#if canImport(UIKit)
import XCTest
@testable import BaseUI

@MainActor
final class BaseReorderListTests: XCTestCase {

    private func sample() -> [BaseReorderSection<String>] {
        [
            BaseReorderSection("To do", items: ["A", "B", "C"]),
            BaseReorderSection("Doing", items: ["D"]),
            BaseReorderSection("Done", items: []),
        ]
    }

    func testMoveWithinSection() {
        var sections = sample()
        BaseReorder.moveItem(in: &sections, from: IndexPath(row: 0, section: 0), to: IndexPath(row: 2, section: 0))
        XCTAssertEqual(sections[0].items, ["B", "C", "A"])
    }

    func testMoveAcrossSections() {
        var sections = sample()
        BaseReorder.moveItem(in: &sections, from: IndexPath(row: 1, section: 0), to: IndexPath(row: 0, section: 1))
        XCTAssertEqual(sections[0].items, ["A", "C"])
        XCTAssertEqual(sections[1].items, ["B", "D"])
    }

    func testMoveIntoEmptySection() {
        var sections = sample()
        BaseReorder.moveItem(in: &sections, from: IndexPath(row: 0, section: 1), to: IndexPath(row: 0, section: 2))
        XCTAssertEqual(sections[1].items, [])
        XCTAssertEqual(sections[2].items, ["D"])
    }

    func testInvalidMoveIsIgnored() {
        var sections = sample()
        BaseReorder.moveItem(in: &sections, from: IndexPath(row: 5, section: 0), to: IndexPath(row: 0, section: 1))
        BaseReorder.moveItem(in: &sections, from: IndexPath(row: 0, section: 0), to: IndexPath(row: 0, section: 9))
        XCTAssertEqual(sections, sample())
    }

    func testMoveSection() {
        var sections = sample()
        BaseReorder.moveSection(in: &sections, from: 2, to: 0)
        XCTAssertEqual(sections.map(\.title), ["Done", "To do", "Doing"])
        BaseReorder.moveSection(in: &sections, from: 0, to: 2)
        XCTAssertEqual(sections.map(\.title), ["To do", "Doing", "Done"])
    }

    func testListAppliesUserMoveAndReports() {
        let list = BaseReorderList(sections: sample()) { BaseReorderRow(title: $0) }
        var reported: [BaseReorderSection<String>]?
        list.onChange = { reported = $0 }

        list.tableView(list.tableView, moveRowAt: IndexPath(row: 0, section: 0), to: IndexPath(row: 1, section: 1))
        XCTAssertEqual(list.sections[1].items, ["D", "A"])
        XCTAssertEqual(reported, list.sections)
    }

    func testSectionsModeShowsOneRowPerSection() {
        let list = BaseReorderList(sections: sample()) { BaseReorderRow(title: $0) }
        list.mode = .sections
        XCTAssertEqual(list.numberOfSections(in: list.tableView), 1)
        XCTAssertEqual(list.tableView(list.tableView, numberOfRowsInSection: 0), 3)

        list.tableView(list.tableView, moveRowAt: IndexPath(row: 0, section: 0), to: IndexPath(row: 2, section: 0))
        XCTAssertEqual(list.sections.map(\.title), ["Doing", "Done", "To do"])
    }

    func testCrossSectionMovesCanBeDisabled() {
        let list = BaseReorderList(sections: sample()) { BaseReorderRow(title: $0) }
        list.allowsCrossSectionMoves = false
        let source = IndexPath(row: 0, section: 0)
        XCTAssertEqual(list.tableView(list.tableView, targetIndexPathForMoveFromRowAt: source,
                                      toProposedIndexPath: IndexPath(row: 0, section: 1)),
                       IndexPath(row: 2, section: 0))
    }

    func testPinnedItemsCannotMove() {
        let list = BaseReorderList(sections: sample()) { BaseReorderRow(title: $0) }
        list.canMoveItem = { $0 != "A" }
        XCTAssertFalse(list.tableView(list.tableView, canMoveRowAt: IndexPath(row: 0, section: 0)))
        XCTAssertTrue(list.tableView(list.tableView, canMoveRowAt: IndexPath(row: 1, section: 0)))
    }
}
#endif

#if canImport(UIKit)
@MainActor
final class BaseReorderCollectionTests: XCTestCase {

    private func sample() -> [BaseReorderSection<String>] {
        [
            BaseReorderSection("Home", items: ["Mail", "Maps", "Music"]),
            BaseReorderSection("Dock", items: ["Phone"]),
            BaseReorderSection("Hidden", items: []),
        ]
    }

    func testClampWithinSameSectionStopsAtLastItem() {
        let counts = [3, 1, 0]
        let source = IndexPath(item: 0, section: 0)
        XCTAssertEqual(BaseReorder.clampedDestination(IndexPath(item: 3, section: 0), from: source, itemCounts: counts),
                       IndexPath(item: 2, section: 0))
        XCTAssertEqual(BaseReorder.clampedDestination(IndexPath(item: 9, section: 1), from: source, itemCounts: counts),
                       IndexPath(item: 1, section: 1))
        XCTAssertEqual(BaseReorder.clampedDestination(IndexPath(item: 0, section: 2), from: source, itemCounts: counts),
                       IndexPath(item: 0, section: 2))
        XCTAssertEqual(BaseReorder.clampedDestination(IndexPath(item: 0, section: 7), from: source, itemCounts: counts),
                       source)
    }

    func testCountsPerMode() {
        let collection = BaseReorderCollection(sections: sample(), layout: .grid(columns: 3)) { BaseReorderRow(title: $0) }
        let view = collection.collectionView!
        XCTAssertEqual(collection.numberOfSections(in: view), 3)
        XCTAssertEqual(collection.collectionView(view, numberOfItemsInSection: 0), 3)

        collection.mode = .sections
        XCTAssertEqual(collection.numberOfSections(in: view), 1)
        XCTAssertEqual(collection.collectionView(view, numberOfItemsInSection: 0), 3)
    }

    func testCommitMoveAcrossSectionsAndSections() {
        let collection = BaseReorderCollection(sections: sample()) { BaseReorderRow(title: $0) }
        collection.commitMove(from: IndexPath(item: 1, section: 0), to: IndexPath(item: 0, section: 2))
        XCTAssertEqual(collection.sections[0].items, ["Mail", "Music"])
        XCTAssertEqual(collection.sections[2].items, ["Maps"])

        collection.mode = .sections
        collection.commitMove(from: IndexPath(item: 2, section: 0), to: IndexPath(item: 0, section: 0))
        XCTAssertEqual(collection.sections.map(\.title), ["Hidden", "Home", "Dock"])
    }

    func testPinnedItemsCannotMove() {
        let collection = BaseReorderCollection(sections: sample()) { BaseReorderRow(title: $0) }
        collection.canMoveItem = { $0 != "Phone" }
        XCTAssertTrue(collection.canMove(at: IndexPath(item: 0, section: 0)))
        XCTAssertFalse(collection.canMove(at: IndexPath(item: 0, section: 1)))
        collection.mode = .sections   // sections are always movable
        XCTAssertTrue(collection.canMove(at: IndexPath(item: 1, section: 0)))
    }
}
#endif

#if canImport(UIKit)
@MainActor
final class BaseReorderPinnedSectionTests: XCTestCase {

    private func mixed() -> [BaseReorderSection<String>] {
        [
            BaseReorderSection("Goal", items: ["Ship"], layout: .banner, isPinned: true, allowsItemMoves: false),
            BaseReorderSection("Favorites", items: ["A", "B"], layout: .carousel),
            BaseReorderSection("To do", items: ["C"], layout: .list),
            BaseReorderSection("Done", items: ["D"], layout: .grid(columns: 3)),
        ]
    }

    func testSectionDefaults() {
        let section = BaseReorderSection("Plain", items: [1, 2])
        XCTAssertNil(section.layout)
        XCTAssertFalse(section.isPinned)
        XCTAssertTrue(section.allowsItemMoves)
    }

    func testClampKeepsPinnedSectionsInPlace() {
        let pinned = [true, false, false, true, false]
        // Can't move above pinned section 0.
        XCTAssertEqual(BaseReorder.clampedSectionDestination(from: 2, to: 0, pinned: pinned), 1)
        // Can't cross pinned section 3 either way.
        XCTAssertEqual(BaseReorder.clampedSectionDestination(from: 1, to: 4, pinned: pinned), 2)
        XCTAssertEqual(BaseReorder.clampedSectionDestination(from: 4, to: 1, pinned: pinned), 4)
        // Free moves are unchanged; pinned sections never move.
        XCTAssertEqual(BaseReorder.clampedSectionDestination(from: 1, to: 2, pinned: pinned), 2)
        XCTAssertEqual(BaseReorder.clampedSectionDestination(from: 0, to: 2, pinned: pinned), 0)
    }

    func testCollectionRespectsPinAndLock() {
        let collection = BaseReorderCollection(sections: mixed()) { BaseReorderRow(title: $0) }
        // Items in the locked section can't move; others can.
        XCTAssertFalse(collection.canMove(at: IndexPath(item: 0, section: 0)))
        XCTAssertTrue(collection.canMove(at: IndexPath(item: 0, section: 1)))

        collection.mode = .sections
        XCTAssertFalse(collection.canMove(at: IndexPath(item: 0, section: 0)))
        // Dragging "Done" to the very top lands just below the pinned section.
        collection.commitMove(from: IndexPath(item: 3, section: 0), to: IndexPath(item: 0, section: 0))
        XCTAssertEqual(collection.sections.map(\.title), ["Goal", "Done", "Favorites", "To do"])
    }

    func testPerSectionLayouts() {
        let collection = BaseReorderCollection(sections: mixed(), layout: .list) { BaseReorderRow(title: $0) }
        XCTAssertEqual(collection.sectionLayout(at: 0), .banner)
        XCTAssertEqual(collection.sectionLayout(at: 1), .carousel)
        XCTAssertEqual(collection.sectionLayout(at: 3), .grid(columns: 3))
        collection.mode = .sections
        XCTAssertEqual(collection.sectionLayout(at: 0), .list)
    }

    func testTableRespectsPin() {
        let list = BaseReorderList(sections: mixed()) { BaseReorderRow(title: $0) }
        list.mode = .sections
        XCTAssertFalse(list.tableView(list.tableView, canMoveRowAt: IndexPath(row: 0, section: 0)))
        XCTAssertEqual(list.tableView(list.tableView, targetIndexPathForMoveFromRowAt: IndexPath(row: 2, section: 0),
                                      toProposedIndexPath: IndexPath(row: 0, section: 0)),
                       IndexPath(row: 1, section: 0))
    }
}
#endif

#if canImport(UIKit)
@MainActor
final class BaseReorderSectionDragTests: XCTestCase {

    private func make() -> BaseReorderCollection<String> {
        BaseReorderCollection(sections: [
            BaseReorderSection("Goal", items: ["Ship"], layout: .banner, isPinned: true),
            BaseReorderSection("Favorites", items: ["A", "B"], layout: .carousel),
            BaseReorderSection("To do", items: ["C"]),
        ]) { BaseReorderRow(title: $0) }
    }

    func testOnlyUnpinnedSectionsAreDraggable() {
        let collection = make()
        XCTAssertFalse(collection.canDragSection(0))
        XCTAssertTrue(collection.canDragSection(1))
        collection.allowsSectionDragging = false
        XCTAssertFalse(collection.canDragSection(1))
        collection.allowsSectionDragging = true
        collection.mode = .sections   // sections mode uses the collapsed rows instead
        XCTAssertFalse(collection.canDragSection(1))
    }

    func testMoveSectionByIDKeepsItemsAndRespectsPin() {
        let collection = make()
        var reported: [BaseReorderSection<String>]?
        collection.onChange = { reported = $0 }

        XCTAssertTrue(collection.moveSection(id: "To do", by: -1))
        XCTAssertEqual(collection.sections.map(\.title), ["Goal", "To do", "Favorites"])
        XCTAssertEqual(collection.sections[2].items, ["A", "B"])
        XCTAssertEqual(reported, collection.sections)

        // Can't move above the pinned section, and the pinned section can't move.
        XCTAssertFalse(collection.moveSection(id: "To do", by: -1))
        XCTAssertFalse(collection.moveSection(id: "Goal", by: 1))
        XCTAssertFalse(collection.moveSection(id: "Missing", by: 1))
    }
}
#endif

#if canImport(UIKit)
@MainActor
final class BaseReorderItemSizeTests: XCTestCase {

    /// Lays the collection out in a 390pt-wide window so real cell frames can be checked.
    private func laidOut(_ sections: [BaseReorderSection<String>],
                         itemSize: BaseReorderItemSize? = nil) -> (BaseReorderCollection<String>, UIWindow) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 2000))
        let collection = BaseReorderCollection(sections: sections) { BaseReorderRow(title: $0) }
        collection.itemSize = itemSize
        collection.frame = window.bounds
        window.addSubview(collection)
        window.isHidden = false
        collection.layoutIfNeeded()
        collection.collectionView.layoutIfNeeded()
        return (collection, window)
    }

    private func frame(_ collection: BaseReorderCollection<String>, _ item: Int, _ section: Int) -> CGRect {
        collection.collectionView.layoutAttributesForItem(at: IndexPath(item: item, section: section))?.frame ?? .null
    }

    func testCarouselFixedSize() {
        let (collection, window) = laidOut([
            BaseReorderSection("Cards", items: ["A", "B"], layout: .carousel, itemSize: .fixed(width: 200, height: 100)),
        ])
        defer { window.isHidden = true }
        XCTAssertEqual(frame(collection, 0, 0).size, CGSize(width: 200, height: 100))
    }

    func testCarouselFractionalWidth() {
        let (collection, window) = laidOut([
            BaseReorderSection("Cards", items: ["A"], layout: .carousel,
                               itemSize: .init(width: .fractionalWidth(0.5), height: .absolute(90))),
        ])
        defer { window.isHidden = true }
        // Half of the content width (390 - 2 × 16).
        XCTAssertEqual(frame(collection, 0, 0).width, 179, accuracy: 0.5)
    }

    func testGridAbsoluteWidthFitsColumns() {
        let (collection, window) = laidOut([
            BaseReorderSection("Grid", items: ["A", "B", "C", "D"], layout: .grid(columns: 2),
                               itemSize: .fixed(width: 100, height: 80)),
        ])
        defer { window.isHidden = true }
        // 358pt of content fits three 100pt tiles; the fourth wraps.
        XCTAssertEqual(frame(collection, 0, 0).size, CGSize(width: 100, height: 80))
        XCTAssertEqual(frame(collection, 2, 0).minY, frame(collection, 0, 0).minY)
        XCTAssertGreaterThan(frame(collection, 3, 0).minY, frame(collection, 0, 0).minY)
    }

    func testGridFractionalWidthSetsColumnsAndSquareHeight() {
        let (collection, window) = laidOut([
            BaseReorderSection("Grid", items: ["A", "B", "C", "D", "E"], layout: .grid(columns: 2),
                               itemSize: .init(width: .fractionalWidth(0.25), height: .fractionalWidth(0.25))),
        ])
        defer { window.isHidden = true }
        let first = frame(collection, 0, 0)
        XCTAssertEqual(frame(collection, 3, 0).minY, first.minY)          // 4 columns
        XCTAssertGreaterThan(frame(collection, 4, 0).minY, first.minY)
        XCTAssertEqual(first.height, 358 * 0.25, accuracy: 0.5)
    }

    func testBannerAndCollectionDefault() {
        let (collection, window) = laidOut([
            BaseReorderSection("Banner", items: ["A"], layout: .banner, itemSize: .init(height: .absolute(160))),
            BaseReorderSection("Cards", items: ["B"], layout: .carousel),
        ], itemSize: .fixed(width: 120, height: 140))
        defer { window.isHidden = true }
        XCTAssertEqual(frame(collection, 0, 0).height, 160)
        XCTAssertEqual(frame(collection, 0, 0).width, 358)
        // Sections without their own size use the collection's.
        XCTAssertEqual(frame(collection, 0, 1).size, CGSize(width: 120, height: 140))
    }

    func testListRowHeight() {
        let (collection, window) = laidOut([
            BaseReorderSection("List", items: ["A", "B"], layout: .list, itemSize: .init(height: .absolute(72))),
        ])
        defer { window.isHidden = true }
        // List rows self-size, so check the real cell after a layout pass.
        collection.collectionView.layoutIfNeeded()
        let cell = collection.collectionView.cellForItem(at: IndexPath(item: 0, section: 0))
        XCTAssertEqual(cell?.frame.height ?? 0, 72, accuracy: 0.5)
    }
}
#endif

#if canImport(UIKit)
@MainActor
final class BaseReorderFlowTests: XCTestCase {

    func testRowPlacesCellsLeftToRight() {
        let result = BaseReorderFlow.row([CGSize(width: 100, height: 50), CGSize(width: 200, height: 80)],
                                         spacing: 10, height: nil)
        XCTAssertEqual(result.frames, [CGRect(x: 0, y: 0, width: 100, height: 50),
                                       CGRect(x: 110, y: 0, width: 200, height: 80)])
        XCTAssertEqual(result.size, CGSize(width: 310, height: 80))
        XCTAssertEqual(BaseReorderFlow.row([CGSize(width: 10, height: 10)], spacing: 10, height: 150).size.height, 150)
    }

    func testWrappingWrapsRows() {
        let tiles = Array(repeating: CGSize(width: 100, height: 50), count: 4)
        let result = BaseReorderFlow.wrapping(tiles, width: 330, spacing: 10, maxHeight: nil)
        XCTAssertEqual(result.frames[2].origin, CGPoint(x: 220, y: 0))
        XCTAssertEqual(result.frames[3].origin, CGPoint(x: 0, y: 60))
        XCTAssertEqual(result.size, CGSize(width: 330, height: 110))
    }

    func testFixedHeightStartsNewPage() {
        let tiles = Array(repeating: CGSize(width: 100, height: 50), count: 5)
        // 2 per row, 1 row fits in 60pt → each pair goes on its own page.
        let result = BaseReorderFlow.wrapping(tiles, width: 210, spacing: 10, maxHeight: 60)
        XCTAssertEqual(result.frames[2].origin, CGPoint(x: 220, y: 0))
        XCTAssertEqual(result.frames[4].origin, CGPoint(x: 440, y: 0))
        XCTAssertEqual(result.size, CGSize(width: 650, height: 60))
    }

    // MARK: Real layout

    private func laidOut(_ sections: [BaseReorderSection<String>],
                         sizeForItem: ((String, BaseReorderSection<String>) -> BaseReorderItemSize?)? = nil)
        -> (BaseReorderCollection<String>, UIWindow) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 2000))
        let collection = BaseReorderCollection(sections: sections) { BaseReorderRow(title: $0) }
        collection.sizeForItem = sizeForItem
        collection.frame = window.bounds
        window.addSubview(collection)
        window.isHidden = false
        collection.layoutIfNeeded()
        collection.collectionView.layoutIfNeeded()
        return (collection, window)
    }

    private func size(_ c: BaseReorderCollection<String>, _ item: Int, _ section: Int) -> CGSize {
        c.collectionView.layoutAttributesForItem(at: IndexPath(item: item, section: section))?.size ?? .zero
    }

    func testPerItemSizeOverridesSection() {
        let (collection, window) = laidOut([
            BaseReorderSection("Cards", items: ["A", "Wide", "C"], layout: .carousel,
                               itemSize: .fixed(width: 120, height: 100)),
        ], sizeForItem: { item, _ in item == "Wide" ? .init(width: .absolute(260)) : nil })
        defer { window.isHidden = true }
        XCTAssertEqual(size(collection, 0, 0), CGSize(width: 120, height: 100))
        XCTAssertEqual(size(collection, 1, 0), CGSize(width: 260, height: 100))   // height from the section
    }

    func testSectionHeightFillsCarouselCells() {
        let (collection, window) = laidOut([
            BaseReorderSection("Cards", items: ["A", "B"], layout: .carousel, height: 180),
        ])
        defer { window.isHidden = true }
        XCTAssertEqual(size(collection, 0, 0), CGSize(width: 150, height: 180))
    }

    func testListRowPerItemHeight() {
        let (collection, window) = laidOut([
            BaseReorderSection("List", items: ["A", "Tall"], layout: .list),
        ], sizeForItem: { item, _ in item == "Tall" ? .init(height: .absolute(90)) : nil })
        defer { window.isHidden = true }
        collection.collectionView.layoutIfNeeded()
        let tall = collection.collectionView.cellForItem(at: IndexPath(item: 1, section: 0))
        XCTAssertEqual(tall?.frame.height ?? 0, 90, accuracy: 0.5)
    }
}
#endif
