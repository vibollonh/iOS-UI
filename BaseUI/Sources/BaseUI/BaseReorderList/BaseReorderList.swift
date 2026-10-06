#if canImport(UIKit)
import UIKit
import EasyAnchor

/// UIKit list whose items can be dragged within and across sections, and whose sections can be
/// reordered (`mode = .sections`). For SwiftUI use `BaseReorderListView`.
///
///     let list = BaseReorderList<Task>(sections: [
///         BaseReorderSection("To do", items: todo),
///         BaseReorderSection("Done", items: done),
///     ]) { task in
///         BaseReorderRow(title: task.name, subtitle: task.note, systemImage: "checklist")
///     }
///     list.onChange = { sections in save(sections) }
///     list.mode = .sections   // drag whole sections
///
/// Fills its bounds and scrolls itself; don't nest it in a scroll view.
open class BaseReorderList<Item: Hashable>: UIView, UITableViewDataSource, UITableViewDelegate {

    /// Setting this from code reloads the list. User moves update it without a reload.
    public var sections: [BaseReorderSection<Item>] {
        didSet {
            if !isCommittingMove { tableView.reloadData() }
        }
    }

    public var mode: BaseReorderMode = .items {
        didSet {
            guard mode != oldValue else { return }
            UIView.transition(with: tableView, duration: 0.25, options: .transitionCrossDissolve) {
                self.tableView.reloadData()
            }
        }
    }

    /// Describes each item's row.
    public var row: (Item) -> BaseReorderRow {
        didSet { tableView.reloadData() }
    }

    /// `false` keeps items inside their own section.
    public var allowsCrossSectionMoves = true

    /// Return `false` to pin an item (no drag handle). Other items can still move around it.
    public var canMoveItem: ((Item) -> Bool)? {
        didSet { tableView.reloadData() }
    }

    /// Shown under a section that has no items, as a drop hint. `nil` shows nothing.
    public var emptySectionText: String? = "Drag items here" {
        didSet { tableView.reloadData() }
    }

    /// Called after every user move with the new order.
    public var onChange: (([BaseReorderSection<Item>]) -> Void)?

    /// The underlying table, for extra configuration (insets, background, header views…).
    public let tableView: UITableView

    private var isCommittingMove = false
    private let cellID = "BaseReorderListCell"

    public init(sections: [BaseReorderSection<Item>] = [],
                style: UITableView.Style = .insetGrouped,
                row: @escaping (Item) -> BaseReorderRow) {
        self.sections = sections
        self.row = row
        self.tableView = UITableView(frame: .zero, style: style)
        super.init(frame: .zero)
        setUp()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func setUp() {
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellID)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.isEditing = true
        tableView.allowsSelectionDuringEditing = false
        tableView.layout {
            addSubview($0)
            $0.fill()
        }
    }

    // MARK: Data source

    public func numberOfSections(in tableView: UITableView) -> Int {
        mode == .items ? sections.count : 1
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        mode == .items ? sections[section].items.count : sections.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellID, for: indexPath)
        var content = cell.defaultContentConfiguration()
        switch mode {
        case .items:
            let model = row(sections[indexPath.section].items[indexPath.row])
            content.text = model.title
            content.secondaryText = model.subtitle
            content.image = model.systemImage.flatMap { UIImage(systemName: $0) }
        case .sections:
            let section = sections[indexPath.row]
            content.text = section.title
            let count = section.items.count == 1 ? "1 item" : "\(section.items.count) items"
            content.secondaryText = section.isPinned ? "Pinned · \(count)" : count
            content.image = UIImage(systemName: section.isPinned ? "pin.fill" : "square.stack.3d.up")
        }
        content.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = content
        cell.selectionStyle = .none
        return cell
    }

    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        mode == .items ? sections[section].title : "Sections"
    }

    public func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard mode == .items, sections[section].items.isEmpty, sections[section].allowsItemMoves else { return nil }
        return emptySectionText
    }

    public func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        switch mode {
        case .sections:
            return !sections[indexPath.row].isPinned
        case .items:
            let section = sections[indexPath.section]
            guard section.allowsItemMoves else { return false }
            return canMoveItem?(section.items[indexPath.row]) ?? true
        }
    }

    public func tableView(_ tableView: UITableView, moveRowAt source: IndexPath, to destination: IndexPath) {
        isCommittingMove = true
        switch mode {
        case .items:   BaseReorder.moveItem(in: &sections, from: source, to: destination)
        case .sections:
            let target = BaseReorder.clampedSectionDestination(from: source.row, to: destination.row,
                                                               pinned: sections.map(\.isPinned))
            BaseReorder.moveSection(in: &sections, from: source.row, to: target)
        }
        isCommittingMove = false
        UISelectionFeedbackGenerator().selectionChanged()

        if mode == .items, source.section != destination.section {
            // Refresh the empty-section hints once the drop animation has finished.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.mode == .items else { return }
                let changed = IndexSet([source.section, destination.section])
                    .filteredIndexSet { $0 < self.sections.count }
                UIView.performWithoutAnimation { self.tableView.reloadSections(changed, with: .none) }
            }
        }
        onChange?(sections)
    }

    // MARK: Delegate

    public func tableView(_ tableView: UITableView,
                          editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle { .none }

    public func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool { false }

    public func tableView(_ tableView: UITableView,
                          targetIndexPathForMoveFromRowAt source: IndexPath,
                          toProposedIndexPath proposed: IndexPath) -> IndexPath {
        if mode == .sections {
            let row = BaseReorder.clampedSectionDestination(from: source.row, to: proposed.row,
                                                            pinned: sections.map(\.isPinned))
            return IndexPath(row: row, section: 0)
        }
        let blocked = !sections[proposed.section].allowsItemMoves
            || (!allowsCrossSectionMoves && proposed.section != source.section)
        guard blocked else { return proposed }
        // Clamp to the first / last slot of the item's own section.
        let lastRow = max(0, sections[source.section].items.count - 1)
        return IndexPath(row: proposed.section < source.section ? 0 : lastRow, section: source.section)
    }
}
#endif
