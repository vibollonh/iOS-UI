#if canImport(UIKit)
import UIKit
import EasyAnchor

/// `UICollectionView` version of `BaseReorderList`: long-press and drag items within and across
/// sections (including into empty ones), or set `mode = .sections` to reorder whole sections.
/// Each section can use its own layout / cell type (list, grid, carousel, banner), and sections can
/// be pinned. For SwiftUI use `BaseReorderCollectionView`.
///
///     let board = BaseReorderCollection<App>(sections: [
///         BaseReorderSection("Featured", items: featured, layout: .banner, isPinned: true),
///         BaseReorderSection("Favorites", items: favorites, layout: .carousel),
///         BaseReorderSection("All apps", items: apps, layout: .grid(columns: 3)),
///     ]) { app in
///         BaseReorderRow(title: app.name, systemImage: app.icon)
///     }
///     board.onChange = { sections in save(sections) }
///
/// Fills its bounds and scrolls itself. To place it inside another scroll view, set
/// `isScrollEnabled = false`.
open class BaseReorderCollection<Item: Hashable>: UIView, UICollectionViewDataSource, UICollectionViewDelegate,
                                                  UICollectionViewDragDelegate, UICollectionViewDropDelegate {
  
  /// Setting this from code reloads the collection. User moves update it without a reload.
  public var sections: [BaseReorderSection<Item>] {
    didSet {
      guard !isCommittingMove else { return }
      cancelSectionDrag()
      collectionView.reloadData()
    }
  }
  
  public var mode: BaseReorderMode = .items {
    didSet {
      guard mode != oldValue else { return }
      UIView.transition(with: collectionView, duration: 0.25, options: .transitionCrossDissolve) {
        self.collectionView.reloadData()
      }
    }
  }
  
  /// Default layout for sections whose `layout` is `nil`.
  public var layout: BaseReorderCollectionLayout {
    didSet {
      guard layout != oldValue else { return }
      collectionView.collectionViewLayout.invalidateLayout()
      collectionView.reloadData()
    }
  }
  
  /// Describes each item's row / tile.
  public var row: (Item) -> BaseReorderRow {
    didSet { collectionView.reloadData() }
  }
  
  /// `false` keeps items inside their own section.
  public var allowsCrossSectionMoves = true
  
  /// Return `false` to pin an item. Other items can still move around it.
  public var canMoveItem: ((Item) -> Bool)? {
    didSet { collectionView.reloadData() }
  }
  
  /// Shown in a section that has no items; it is also the drop target. `nil` shows nothing,
  /// which also means empty sections can't receive items.
  public var emptySectionText: String? = "Drag items here" {
    didSet { collectionView.reloadData() }
  }
  
  /// Long-press a section header to drag the whole section, cells included (in `.items` mode).
  /// Pinned sections can't be dragged and stay in place.
  public var allowsSectionDragging = true {
    didSet { collectionView.reloadData() }
  }
  
  /// `true` while the user is dragging a whole section.
  public var isDraggingSection: Bool { sectionDrag != nil }
  
  /// Default cell size for sections without their own `itemSize`. `nil` uses each layout's defaults.
  public var itemSize: BaseReorderItemSize? {
    didSet {
      guard itemSize != oldValue else { return }
      collectionView.collectionViewLayout.invalidateLayout()
      collectionView.reloadData()
    }
  }
  
  /// Size of one specific cell, e.g. a wide featured card among small ones. Return `nil` (or `.automatic`
  /// dimensions) to use the section's `itemSize`. Sections that use this lay out with exact sizes, so
  /// `.estimated` values act as fixed there.
  ///
  ///     collection.sizeForItem = { item, section in
  ///         item.isFeatured ? .fixed(width: 260, height: 140) : nil
  ///     }
  public var sizeForItem: ((Item, BaseReorderSection<Item>) -> BaseReorderItemSize?)? {
    didSet { refreshSizes() }
  }
  
  /// Called after every user move with the new order.
  public var onChange: (([BaseReorderSection<Item>]) -> Void)?
  
  /// Set to `false` to embed the collection in an outer scroll view (e.g. a SwiftUI `ScrollView`):
  /// it stops scrolling, reports its full content height as its intrinsic size, and drags
  /// autoscroll the enclosing scroll view instead. Every cell is laid out, so keep embedded
  /// collections modest in size.
  public var isScrollEnabled = true {
    didSet {
      guard isScrollEnabled != oldValue else { return }
      collectionView.isScrollEnabled = isScrollEnabled
      // Embedded: the outer scroll view handles safe areas, and the content never scrolls.
      collectionView.contentInsetAdjustmentBehavior = isScrollEnabled ? .automatic : .never
      (collectionView as? BaseReorderContentCollectionView)?.isContentOffsetPinned = !isScrollEnabled
      invalidateIntrinsicContentSize()
    }
  }
  
  open override var intrinsicContentSize: CGSize {
    guard !isScrollEnabled else { return super.intrinsicContentSize }
    // At least 1pt: a collection view with empty bounds skips layout and never reports a content size.
    return CGSize(width: UIView.noIntrinsicMetric, height: max(collectionView.contentSize.height, 1))
  }
  
  /// The underlying collection view, for extra configuration.
  public private(set) var collectionView: UICollectionView!
  
  private var isCommittingMove = false
  private var sectionDrag: SectionDrag?
  /// Item drag in progress while embedded, for autoscrolling the enclosing scroll view.
  private weak var dropSession: UIDropSession?
  private var dropAutoscrollLink: CADisplayLink?
  private let gestureProxy = BaseReorderGestureProxy()
  
  private struct SectionDrag {
    var index: Int
    let startIndex: Int
    let snapshot: UIView
    /// Finger y minus snapshot center y, in this view's coordinates.
    let grabOffset: CGFloat
    var fingerY: CGFloat
    var displayLink: CADisplayLink?
  }
  private var listCellRegistration: UICollectionView.CellRegistration<BaseReorderListCell, IndexPath>!
  private var tileCellRegistration: UICollectionView.CellRegistration<BaseReorderTileCell, IndexPath>!
  private var cardCellRegistration: UICollectionView.CellRegistration<BaseReorderCardCell, IndexPath>!
  private var bannerCellRegistration: UICollectionView.CellRegistration<BaseReorderBannerCell, IndexPath>!
  private var headerRegistration: UICollectionView.SupplementaryRegistration<UICollectionViewListCell>!
  private var footerRegistration: UICollectionView.SupplementaryRegistration<UICollectionViewListCell>!
  
  public init(sections: [BaseReorderSection<Item>] = [],
              layout: BaseReorderCollectionLayout = .list,
              row: @escaping (Item) -> BaseReorderRow) {
    self.sections = sections
    self.layout = layout
    self.row = row
    super.init(frame: .zero)
    setUp()
  }
  
  @available(*, unavailable)
  public required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
  
  // MARK: Setup
  
  private func setUp() {
    let collectionView = BaseReorderContentCollectionView(frame: .zero, collectionViewLayout: makeLayout())
    collectionView.onContentSizeChange = { [weak self] in
      guard let self, !self.isScrollEnabled else { return }
      self.invalidateIntrinsicContentSize()
    }
    self.collectionView = collectionView
    collectionView.backgroundColor = .systemGroupedBackground
    collectionView.dataSource = self
    collectionView.delegate = self
    collectionView.dragDelegate = self
    collectionView.dropDelegate = self
    collectionView.dragInteractionEnabled = true   // off by default on iPhone
    collectionView.allowsSelection = false
    collectionView.layout {
      addSubview($0)
      $0.fill()
    }
    setUpSectionDragging()
    
    listCellRegistration = .init { [unowned self] cell, _, indexPath in
      let model = self.model(at: indexPath)
      var content = cell.defaultContentConfiguration()
      content.text = model.title
      content.secondaryText = model.subtitle
      content.secondaryTextProperties.color = .secondaryLabel
      content.image = model.systemImage.flatMap { UIImage(systemName: $0) }
      cell.contentConfiguration = content
      cell.accessories = [.customView(configuration: self.canMove(at: indexPath) ? Self.grabber() : Self.pin())]
      self.applyListRowHeight(to: cell, at: indexPath)
    }
    tileCellRegistration = .init { [unowned self] cell, _, indexPath in
      cell.configure(with: self.model(at: indexPath), isPinned: !self.canMove(at: indexPath))
    }
    cardCellRegistration = .init { [unowned self] cell, _, indexPath in
      cell.configure(with: self.model(at: indexPath), isPinned: !self.canMove(at: indexPath))
    }
    bannerCellRegistration = .init { [unowned self] cell, _, indexPath in
      cell.configure(with: self.model(at: indexPath), isPinned: !self.canMove(at: indexPath))
    }
    headerRegistration = .init(elementKind: UICollectionView.elementKindSectionHeader) { [unowned self] view, _, indexPath in
      var content = UIListContentConfiguration.groupedHeader()
      if self.mode == .items {
        let section = self.sections[indexPath.section]
        if !section.title.isEmpty {
          content.text = section.title
        }
        //                if section.isPinned {
        //                    content.image = UIImage(systemName: "pin.fill")
        //                    content.imageProperties.tintColor = .secondaryLabel
        //                    content.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .caption1)
        //                }
        //                let draggable = self.canDragSection(indexPath.section)
        //                view.accessories = draggable ? [.customView(configuration: Self.grabber())] : []
        //                view.accessibilityCustomActions = draggable ? self.sectionMoveActions(for: section.id) : nil
      } else {
        content.text = "Sections"
        view.accessories = []
        view.accessibilityCustomActions = nil
      }
      view.contentConfiguration = content
    }
    footerRegistration = .init(elementKind: UICollectionView.elementKindSectionFooter) { [unowned self] view, _, indexPath in
      var content = UIListContentConfiguration.groupedFooter()
      content.text = self.emptySectionText
      content.image = UIImage(systemName: "tray.and.arrow.down")
      content.imageProperties.tintColor = .tertiaryLabel
      // The list layout already insets its footers to the card edges; the grid footer spans the full
      // width, so inset it to line up with the tiles. Text stays 16pt inside the border.
      let inset: CGFloat = self.sectionLayout(at: indexPath.section) == .list ? 0 : 16
      content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 16, leading: inset + 16,
                                                                 bottom: 16, trailing: inset + 16)
      view.contentConfiguration = content
      var background = UIBackgroundConfiguration.clear()
      background.strokeColor = .tertiaryLabel
      background.strokeWidth = 1
      background.strokeOutset = 0
      background.cornerRadius = 12
      background.backgroundInsets = NSDirectionalEdgeInsets(top: 4, leading: inset, bottom: 4, trailing: inset)
      view.backgroundConfiguration = background
    }
  }
  
  private static func grabber() -> UICellAccessory.CustomViewConfiguration {
    let view = UIImageView(image: UIImage(systemName: "line.3.horizontal"))
    view.tintColor = .tertiaryLabel
    return .init(customView: view, placement: .trailing(), reservedLayoutWidth: .standard)
  }
  
  private static func pin() -> UICellAccessory.CustomViewConfiguration {
    let view = UIImageView(image: UIImage(systemName: "pin.fill"))
    view.tintColor = .tertiaryLabel
    view.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .footnote)
    view.accessibilityLabel = "Pinned"
    return .init(customView: view, placement: .trailing(), reservedLayoutWidth: .standard)
  }
  
  /// Effective layout of a section. Sections mode always shows a plain list of sections.
  func sectionLayout(at section: Int) -> BaseReorderCollectionLayout {
    guard mode == .items, sections.indices.contains(section) else { return .list }
    return sections[section].layout ?? layout
  }
  
  private func makeLayout() -> UICollectionViewLayout {
    UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
      guard let self else { return nil }
      let showsEmptyFooter = self.showsEmptyFooter(in: sectionIndex)
      let section: NSCollectionLayoutSection
      
      let size = self.itemSize(at: sectionIndex)
      let contentWidth = environment.container.effectiveContentSize.width - 32
      
      if self.usesFlowLayout(at: sectionIndex) {
        let flow = self.flow(at: sectionIndex, contentWidth: contentWidth)
        let frames = flow.frames
        let group = NSCollectionLayoutGroup.custom(layoutSize: .init(
          widthDimension: .absolute(max(contentWidth, flow.size.width)),
          heightDimension: .absolute(max(1, flow.size.height)))) { _ in
            frames.map { NSCollectionLayoutGroupCustomItem(frame: $0) }
          }
        let section = NSCollectionLayoutSection(group: group)
        if flow.size.width > contentWidth + 0.5 { section.orthogonalScrollingBehavior = .continuous }
        section.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 16, bottom: 20, trailing: 16)
        section.boundarySupplementaryItems = Self.boundaryItems(showsEmptyFooter: showsEmptyFooter)
        return section
      }
      
      switch self.sectionLayout(at: sectionIndex) {
      case .list:
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.headerMode = .supplementary
        config.footerMode = showsEmptyFooter ? .supplementary : .none
        config.backgroundColor = .systemGroupedBackground
        return NSCollectionLayoutSection.list(using: config, layoutEnvironment: environment)
        
      case .grid(let columns):
        let height = Self.layoutDimension(size.height, default: .estimated(110), contentWidth: contentWidth)
        switch size.width {
        case .absolute(let width), .estimated(let width):
          // As many columns of this width as fit; leftover space is spread between them.
          let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .absolute(width), heightDimension: height))
          let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: height), subitems: [item])
          group.interItemSpacing = .flexible(10)
          section = NSCollectionLayoutSection(group: group)
        default:
          var count = max(1, columns)
          if case .fractionalWidth(let fraction) = size.width, fraction > 0 {
            count = max(1, Int((1 / fraction).rounded()))
          }
          let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1 / CGFloat(count)),
                                                              heightDimension: height))
          let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: height),
            subitem: item, count: count)
          group.interItemSpacing = .fixed(10)
          section = NSCollectionLayoutSection(group: group)
        }
        
      case .carousel:
        let width = Self.layoutDimension(size.width, default: .absolute(150), contentWidth: contentWidth)
        let height = Self.layoutDimension(size.height, default: .estimated(130), contentWidth: contentWidth)
        section = Self.singleItemSection(width: width, height: height, horizontal: true)
        section.orthogonalScrollingBehavior = .continuous
        
      case .banner:
        let width = Self.layoutDimension(size.width, default: .fractionalWidth(1), contentWidth: contentWidth)
        let height = Self.layoutDimension(size.height, default: .estimated(120), contentWidth: contentWidth)
        section = Self.singleItemSection(width: width, height: height, horizontal: false)

      case .horizontalBanner:
        let width = Self.layoutDimension(size.width, default: .absolute(contentWidth), contentWidth: contentWidth)
        let height = Self.layoutDimension(size.height, default: .estimated(120), contentWidth: contentWidth)
        section = Self.singleItemSection(width: width, height: height, horizontal: true)
        section.orthogonalScrollingBehavior = .groupPaging
      }
      
      section.interGroupSpacing = 10
      section.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 16, bottom: 20, trailing: 16)
      section.boundarySupplementaryItems = Self.boundaryItems(showsEmptyFooter: showsEmptyFooter)
      return section
    }
  }
  
  /// Effective cell size of a section: its own, else the collection's, else layout defaults.
  func itemSize(at section: Int) -> BaseReorderItemSize {
    guard mode == .items, sections.indices.contains(section) else { return BaseReorderItemSize() }
    return sections[section].itemSize ?? itemSize ?? BaseReorderItemSize()
  }
  
  /// Sections with per-item sizes or a fixed height get exact frames from `BaseReorderFlow`.
  func usesFlowLayout(at section: Int) -> Bool {
    guard mode == .items, sections.indices.contains(section), sectionLayout(at: section) != .list else { return false }
    if sections[section].height != nil { return true }
    guard let sizeForItem else { return false }
    let model = sections[section]
    return model.items.contains { sizeForItem($0, model) != nil }
  }
  
  /// Item size after merging the per-item size over the section's / collection's `itemSize`.
  func mergedItemSize(at indexPath: IndexPath) -> BaseReorderItemSize {
    let base = itemSize(at: indexPath.section)
    guard mode == .items, let sizeForItem, sections.indices.contains(indexPath.section),
          sections[indexPath.section].items.indices.contains(indexPath.item) else { return base }
    let model = sections[indexPath.section]
    guard let custom = sizeForItem(model.items[indexPath.item], model) else { return base }
    return BaseReorderItemSize(width: custom.width == .automatic ? base.width : custom.width,
                               height: custom.height == .automatic ? base.height : custom.height)
  }
  
  /// Exact cell frames for a flow-laid-out section.
  func flow(at section: Int, contentWidth: CGFloat) -> BaseReorderFlow.Result {
    let layout = sectionLayout(at: section)
    let fixedHeight = sections[section].height
    let spacing: CGFloat = 10
    let sizes: [CGSize] = sections[section].items.indices.map { item in
      let size = mergedItemSize(at: IndexPath(item: item, section: section))
      let width: CGFloat
      switch size.width {
      case .absolute(let v), .estimated(let v): width = v
      case .fractionalWidth(let f):            width = contentWidth * f
      case .automatic:
        switch layout {
        case .carousel:          width = 150
        case .grid(let columns): width = (contentWidth - spacing * CGFloat(max(1, columns) - 1)) / CGFloat(max(1, columns))
        default:                 width = contentWidth
        }
      }
      let height: CGFloat
      switch size.height {
      case .absolute(let v), .estimated(let v): height = v
      case .fractionalWidth(let f):            height = contentWidth * f
      case .automatic:
        switch layout {
        case .carousel: height = fixedHeight ?? 130
        case .banner, .horizontalBanner: height = fixedHeight ?? 120
        default:        height = 110
        }
      }
      return CGSize(width: max(1, min(width, contentWidth)), height: max(1, height))
    }
    if layout.scrollsSideways { return BaseReorderFlow.row(sizes, spacing: spacing, height: fixedHeight) }
    return BaseReorderFlow.wrapping(sizes, width: contentWidth, spacing: spacing, maxHeight: fixedHeight)
  }
  
  /// Re-applies sizes without reloading data (safe for SwiftUI updates).
  func refreshSizes() {
    guard collectionView != nil, !collectionView.hasActiveDrag, !isDraggingSection else { return }
    collectionView.collectionViewLayout.invalidateLayout()
    // Next turn, so a reload issued in this one (e.g. new `sections`) lands first; reconfiguring
    // the pre-reload visible items leaves their cells showing the old content.
    DispatchQueue.main.async { [weak self] in
      guard let self, !self.collectionView.hasActiveDrag, !self.isDraggingSection else { return }
      self.collectionView.reconfigureItems(at: self.collectionView.indexPathsForVisibleItems)
    }
  }
  
  /// Maps a dimension to compositional layout. `contentWidth` turns `.fractionalWidth` into points so
  /// it means "fraction of the section's content width" in every layout (groups may be narrower).
  static func layoutDimension(_ dimension: BaseReorderItemSize.Dimension, default fallback: NSCollectionLayoutDimension,
                              contentWidth: CGFloat? = nil) -> NSCollectionLayoutDimension {
    switch dimension {
    case .automatic:                return fallback
    case .absolute(let points):     return .absolute(points)
    case .estimated(let points):    return .estimated(points)
    case .fractionalWidth(let f):   return contentWidth.map { .absolute(max(1, $0 * f)) } ?? .fractionalWidth(f)
    }
  }
  
  /// One item per group (carousel cards / banners). Estimated heights stay estimated on the item.
  private static func singleItemSection(width: NSCollectionLayoutDimension, height: NSCollectionLayoutDimension,
                                        horizontal: Bool) -> NSCollectionLayoutSection {
    let groupSize = NSCollectionLayoutSize(widthDimension: width, heightDimension: height)
    let itemHeight: NSCollectionLayoutDimension = height.isEstimated ? height : .fractionalHeight(1)
    let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: itemHeight))
    let group = horizontal
    ? NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
    : NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
    return NSCollectionLayoutSection(group: group)
  }
  
  private static func boundaryItems(showsEmptyFooter: Bool) -> [NSCollectionLayoutBoundarySupplementaryItem] {
    var items = [NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(36)),
      elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)]
    if showsEmptyFooter {
      let footer = NSCollectionLayoutBoundarySupplementaryItem(
        layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(60)),
        elementKind: UICollectionView.elementKindSectionFooter, alignment: .bottom)
      footer.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: -16, bottom: 0, trailing: -16)
      items.append(footer)
    }
    return items
  }
  
  /// List rows self-size from their content, so a custom height is applied while sizing.
  private func applyListRowHeight(to cell: BaseReorderListCell, at indexPath: IndexPath) {
    cell.fixedHeight = nil
    cell.minimumHeight = nil
    switch mergedItemSize(at: indexPath).height {
    case .automatic:                  break
    case .absolute(let points):       cell.fixedHeight = points
    case .estimated(let points):      cell.minimumHeight = points
    case .fractionalWidth(let f):     cell.fixedHeight = max(0, collectionView.bounds.width - 32) * f
    }
  }
  
  // MARK: Model
  
  private func model(at indexPath: IndexPath) -> BaseReorderRow {
    switch mode {
    case .items:
      return row(sections[indexPath.section].items[indexPath.item])
    case .sections:
      let section = sections[indexPath.item]
      let count = section.items.count == 1 ? "1 item" : "\(section.items.count) items"
      return BaseReorderRow(title: section.title,
                            subtitle: section.isPinned ? "Pinned · \(count)" : count,
                            systemImage: Self.symbol(for: section.layout ?? layout))
    }
  }
  
  private static func symbol(for layout: BaseReorderCollectionLayout) -> String {
    switch layout {
    case .list:     return "list.bullet"
    case .grid:     return "square.grid.2x2"
    case .carousel: return "rectangle.split.3x1"
    case .banner:   return "rectangle.fill"
    case .horizontalBanner: return "rectangle.split.2x1"
    }
  }
  
  /// Internal for tests.
  func canMove(at indexPath: IndexPath) -> Bool {
    switch mode {
    case .sections:
      return !sections[indexPath.item].isPinned
    case .items:
      let section = sections[indexPath.section]
      guard section.allowsItemMoves else { return false }
      return canMoveItem?(section.items[indexPath.item]) ?? true
    }
  }
  
  private func showsEmptyFooter(in section: Int) -> Bool {
    mode == .items && emptySectionText != nil
    && sections.indices.contains(section) && sections[section].items.isEmpty
    && sections[section].allowsItemMoves
  }
  
  private var itemCounts: [Int] {
    mode == .items ? sections.map(\.items.count) : [sections.count]
  }
  
  /// Applies a move to `sections` (no UI work). Internal for tests.
  func commitMove(from source: IndexPath, to destination: IndexPath) {
    isCommittingMove = true
    switch mode {
    case .items:    BaseReorder.moveItem(in: &sections, from: source, to: destination)
    case .sections:
      let target = BaseReorder.clampedSectionDestination(from: source.item, to: destination.item,
                                                         pinned: sections.map(\.isPinned))
      BaseReorder.moveSection(in: &sections, from: source.item, to: target)
    }
    isCommittingMove = false
  }
  
  /// Applies a swap (see `BaseReorderSection.swapsOnDrop`) to `sections` (no UI work). Internal for tests.
  func commitSwap(from source: IndexPath, with target: IndexPath) {
    isCommittingMove = true
    BaseReorder.swapItem(in: &sections, from: source, with: target)
    isCommittingMove = false
  }
  
  /// The full-width band a section occupies: header, items and (empty) drop-zone footer.
  private func frame(ofSection section: Int) -> CGRect {
    let path = IndexPath(item: 0, section: section)
    var frame = collectionView.layoutAttributesForSupplementaryElement(
      ofKind: UICollectionView.elementKindSectionHeader, at: path)?.frame ?? .null
    if showsEmptyFooter(in: section),
       let footer = collectionView.layoutAttributesForSupplementaryElement(
        ofKind: UICollectionView.elementKindSectionFooter, at: path)?.frame {
      frame = frame.union(footer)
    }
    let count = collectionView.numberOfItems(inSection: section)
    if count > 0,
       let first = collectionView.layoutAttributesForItem(at: path)?.frame,
       let last = collectionView.layoutAttributesForItem(at: IndexPath(item: count - 1, section: section))?.frame {
      frame = frame.union(first).union(last)
    }
    guard !frame.isNull else { return .null }
    return CGRect(x: 0, y: frame.minY, width: collectionView.bounds.width, height: frame.height)
  }
  
  /// The section under `location`. Sections count as contiguous bands (each reaches down to the next
  /// one), so the gaps between sections and the space below the last one still pick a section.
  private func section(at location: CGPoint) -> Int? {
    var match: Int?
    var first: Int?
    for index in 0..<collectionView.numberOfSections {
      let band = frame(ofSection: index)
      guard !band.isNull else { continue }
      if first == nil { first = index }
      if location.y >= band.minY { match = index }
    }
    return match ?? first
  }
  
  /// On-screen frame of an item (accounts for carousels scrolled sideways), else its layout frame.
  private func visibleFrame(of path: IndexPath) -> CGRect? {
    if let cell = collectionView.cellForItem(at: path) {
      return cell.convert(cell.bounds, to: collectionView)
    }
    return nil
  }
  
  /// Insertion index for `location` inside `section`, counted as if the dragged item were removed.
  private func insertionIndex(in section: Int, at location: CGPoint, source: IndexPath) -> Int {
    let layout = sectionLayout(at: section)
    let scrollsSideways = layout.scrollsSideways || usesFlowLayout(at: section)
    let count = collectionView.numberOfItems(inSection: section)
    let visible = collectionView.indexPathsForVisibleItems.filter { $0.section == section }.map(\.item)
    let firstVisible = visible.min() ?? 0
    var index = 0
    for item in 0..<count {
      let path = IndexPath(item: item, section: section)
      if path == source { continue }
      var frame = visibleFrame(of: path)
      if frame == nil, !scrollsSideways {
        frame = collectionView.layoutAttributesForItem(at: path)?.frame
      }
      guard let frame else {
        // Off-screen in a sideways-scrolling section: before the visible ones we've passed them,
        // after them we insert before.
        if item < firstVisible { index += 1; continue }
        return index
      }
      let before: Bool
      switch layout {
      case .list, .banner where !scrollsSideways:
        before = location.y < frame.midY
      case .carousel, .horizontalBanner:
        before = location.x < frame.midX
      default:   // grids and flow sections: row by row
        before = location.y < frame.minY || (location.y <= frame.maxY && location.x < frame.midX)
      }
      if before { return index }
      index += 1
    }
    return index
  }
  
  /// Where a drop lands: the section comes from the finger position, and the slot from the proposal when
  /// it's trustworthy (same section, regular layout) or from the cell frames under the finger otherwise.
  /// UIKit tends to propose slots in the *source* section while hovering a carousel, which used to send
  /// items back where they came from.
  private func resolvedDestination(for session: UIDropSession, proposed: IndexPath?, from source: IndexPath) -> IndexPath? {
    let location = session.location(in: collectionView)
    guard let hovered = section(at: location) else { return nil }
    if showsEmptyFooter(in: hovered) {
      return IndexPath(item: 0, section: hovered)
    }
    let trustProposal = proposed.map { $0.section == hovered && $0 != source } ?? false
    && !sectionLayout(at: hovered).scrollsSideways && !usesFlowLayout(at: hovered)
    let item = trustProposal ? proposed!.item : insertionIndex(in: hovered, at: location, source: source)
    return BaseReorder.clampedDestination(IndexPath(item: item, section: hovered), from: source, itemCounts: itemCounts)
  }
  
  /// Final drop target with section pins and item locks applied; `nil` when the drop isn't allowed.
  private func allowedDestination(for session: UIDropSession, proposed: IndexPath?, from source: IndexPath) -> IndexPath? {
    guard var target = resolvedDestination(for: session, proposed: proposed, from: source) else { return nil }
    switch mode {
    case .sections:
      target.item = BaseReorder.clampedSectionDestination(from: source.item, to: target.item,
                                                          pinned: sections.map(\.isPinned))
    case .items:
      guard sections[target.section].allowsItemMoves,
            allowsCrossSectionMoves || target.section == source.section else { return nil }
      if BaseReorder.swaps(in: sections, from: source, to: target) {
        target = swapTarget(in: target.section, at: session.location(in: collectionView), fallback: target)
        // The displaced item moves too, so it must be movable.
        guard canMove(at: target) else { return nil }
      }
    }
    return target
  }
  
  /// The item a swap lands on: the visible cell of `section` nearest the finger (carousels scroll
  /// sideways, so layout frames can't be trusted), else the item at the insertion slot.
  private func swapTarget(in section: Int, at location: CGPoint, fallback: IndexPath) -> IndexPath {
    let nearest = collectionView.indexPathsForVisibleItems
      .filter { $0.section == section }
      .compactMap { path in visibleFrame(of: path).map { (path, Self.distance(from: location, to: $0)) } }
      .min { $0.1 < $1.1 }?.0
    return nearest ?? BaseReorder.swapTarget(in: sections, at: fallback)
  }
  
  private static func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
    let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
    let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
    return hypot(dx, dy)
  }
  
  // MARK: Section dragging
  
  /// Moves a section up (negative offset) or down, respecting pinned sections. Also used by
  /// the VoiceOver actions on section headers. Returns `false` when nothing moved.
  @discardableResult
  public func moveSection(id: String, by offset: Int) -> Bool {
    guard let from = sections.firstIndex(where: { $0.id == id }) else { return false }
    let to = BaseReorder.clampedSectionDestination(from: from, to: from + offset, pinned: sections.map(\.isPinned))
    guard to != from else { return false }
    applySectionMove(from: from, to: to, completion: nil)
    onChange?(sections)
    return true
  }
  
  /// Updates the model inside the batch so the collection view sees consistent before / after counts.
  private func applySectionMove(from: Int, to: Int, completion: (() -> Void)?) {
    let commit = {
      self.isCommittingMove = true
      BaseReorder.moveSection(in: &self.sections, from: from, to: to)
      self.isCommittingMove = false
    }
    guard mode == .items, collectionView.window != nil else {
      commit()
      collectionView.reloadData()
      completion?()
      return
    }
    collectionView.performBatchUpdates {
      commit()
      collectionView.moveSection(from, toSection: to)
    } completion: { _ in completion?() }
  }
  
  func canDragSection(_ index: Int) -> Bool {
    allowsSectionDragging && mode == .items && sections.count > 1
    && sections.indices.contains(index) && !sections[index].isPinned
  }
  
  private func sectionMoveActions(for id: String) -> [UIAccessibilityCustomAction] {
    [
      UIAccessibilityCustomAction(name: "Move section up") { [weak self] _ in self?.moveSection(id: id, by: -1) ?? false },
      UIAccessibilityCustomAction(name: "Move section down") { [weak self] _ in self?.moveSection(id: id, by: 1) ?? false },
    ]
  }
  
  private func setUpSectionDragging() {
    let press = UILongPressGestureRecognizer(target: gestureProxy, action: #selector(BaseReorderGestureProxy.handle(_:)))
    press.minimumPressDuration = 0.3
    press.delegate = gestureProxy
    collectionView.addGestureRecognizer(press)
    
    gestureProxy.shouldBegin = { [weak self] gesture in
      guard let self, let section = self.headerSection(at: gesture.location(in: self.collectionView)) else { return false }
      return self.canDragSection(section)
    }
    gestureProxy.onChange = { [weak self] gesture in
      guard let self else { return }
      switch gesture.state {
      case .began:   self.beginSectionDrag(at: gesture.location(in: self.collectionView))
      case .changed: self.updateSectionDrag(fingerY: gesture.location(in: self).y)
      case .ended:   self.endSectionDrag()
      case .cancelled, .failed: self.endSectionDrag()
      default: break
      }
    }
    gestureProxy.onTick = { [weak self] in self?.autoscrollTick() }
  }
  
  /// The section whose header contains `point` (collection view coordinates).
  private func headerSection(at point: CGPoint) -> Int? {
    guard mode == .items else { return nil }
    let kind = UICollectionView.elementKindSectionHeader
    return collectionView.indexPathsForVisibleSupplementaryElements(ofKind: kind).first { path in
      collectionView.supplementaryView(forElementKind: kind, at: path)?.frame.contains(point) ?? false
    }?.section
  }
  
  private func beginSectionDrag(at point: CGPoint) {
    guard let index = headerSection(at: point), canDragSection(index) else { return }
    let band = frame(ofSection: index)
    guard !band.isNull,
          let snapshot = collectionView.resizableSnapshotView(from: band, afterScreenUpdates: false,
                                                              withCapInsets: .zero) else { return }
    snapshot.frame = collectionView.convert(band, to: self)
    snapshot.layer.shadowColor = UIColor.black.cgColor
    snapshot.layer.shadowOpacity = 0.18
    snapshot.layer.shadowRadius = 14
    snapshot.layer.shadowOffset = CGSize(width: 0, height: 6)
    addSubview(snapshot)
    
    let finger = convert(point, from: collectionView)
    sectionDrag = SectionDrag(index: index, startIndex: index, snapshot: snapshot,
                              grabOffset: finger.y - snapshot.center.y, fingerY: finger.y)
    updateDraggedSectionVisibility()
    UIView.animate(withDuration: 0.2) { snapshot.transform = CGAffineTransform(scaleX: 1.02, y: 1.02) }
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    
    let link = CADisplayLink(target: gestureProxy, selector: #selector(BaseReorderGestureProxy.tick))
    link.add(to: .main, forMode: .common)
    sectionDrag?.displayLink = link
  }
  
  private func updateSectionDrag(fingerY: CGFloat) {
    guard var drag = sectionDrag else { return }
    drag.fingerY = fingerY
    drag.snapshot.center.y = fingerY - drag.grabOffset
    sectionDrag = drag
    stepSectionTarget()
  }
  
  /// Swaps the dragged section one step when the finger passes the middle of a neighbour.
  private func stepSectionTarget() {
    guard let drag = sectionDrag else { return }
    let y = convert(CGPoint(x: 0, y: drag.fingerY), to: collectionView).y
    let index = drag.index
    var target = index
    if index + 1 < sections.count, y > frame(ofSection: index + 1).midY {
      target = index + 1
    } else if index > 0, y < frame(ofSection: index - 1).midY {
      target = index - 1
    }
    target = BaseReorder.clampedSectionDestination(from: index, to: target, pinned: sections.map(\.isPinned))
    guard target != index else { return }
    
    sectionDrag?.index = target
    applySectionMove(from: index, to: target) { [weak self] in self?.updateDraggedSectionVisibility() }
    updateDraggedSectionVisibility()
    UISelectionFeedbackGenerator().selectionChanged()
  }
  
  private func autoscrollTick() {
    guard let drag = sectionDrag else {
      // Item drag while embedded: UIKit only autoscrolls the (non-scrolling) collection view.
      guard let session = dropSession else { stopDropAutoscroll(); return }
      autoscroll(nearY: session.location(in: self).y)
      return
    }
    let moved = autoscroll(nearY: drag.fingerY)
    guard moved != 0 else { return }
    if scrollingView !== collectionView {
      // This view moved with the outer content; keep the finger and snapshot still on screen.
      sectionDrag?.fingerY += moved
      drag.snapshot.center.y += moved
    }
    stepSectionTarget()
  }
  
  /// The collection view itself, or the enclosing scroll view when `isScrollEnabled` is `false`.
  private var scrollingView: UIScrollView {
    guard !isScrollEnabled else { return collectionView }
    var view = superview
    while let current = view {
      if let scrollView = current as? UIScrollView { return scrollView }
      view = current.superview
    }
    return collectionView
  }
  
  /// Scrolls `scrollingView` when `y` (this view's coordinates) is near its visible top or bottom.
  /// Returns how far the content moved.
  @discardableResult
  private func autoscroll(nearY y: CGFloat) -> CGFloat {
    let scroller = scrollingView
    let inset = scroller.adjustedContentInset
    let bounds = scroller.convert(scroller.bounds, to: self)
    let visible = (top: bounds.minY + inset.top, bottom: bounds.maxY - inset.bottom)
    let edge: CGFloat = 80
    var delta: CGFloat = 0
    if y < visible.top + edge {
      delta = -min(visible.top + edge - y, edge) / edge * 14
    } else if y > visible.bottom - edge {
      delta = min(y - (visible.bottom - edge), edge) / edge * 14
    }
    guard delta != 0 else { return 0 }
    let minY = -inset.top
    let maxY = max(minY, scroller.contentSize.height - scroller.bounds.height + inset.bottom)
    let newY = min(max(scroller.contentOffset.y + delta, minY), maxY)
    let moved = newY - scroller.contentOffset.y
    guard moved != 0 else { return 0 }
    scroller.contentOffset.y = newY
    return moved
  }
  
  private func startDropAutoscroll(for session: UIDropSession) {
    guard !isScrollEnabled else { return }
    dropSession = session
    guard dropAutoscrollLink == nil else { return }
    let link = CADisplayLink(target: gestureProxy, selector: #selector(BaseReorderGestureProxy.tick))
    link.add(to: .main, forMode: .common)
    dropAutoscrollLink = link
  }
  
  private func stopDropAutoscroll() {
    dropAutoscrollLink?.invalidate()
    dropAutoscrollLink = nil
    dropSession = nil
  }
  
  private func endSectionDrag() {
    guard let drag = sectionDrag else { return }
    drag.displayLink?.invalidate()
    sectionDrag?.displayLink = nil
    collectionView.layoutIfNeeded()
    let target = collectionView.convert(frame(ofSection: drag.index), to: self)
    UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut]) {
      drag.snapshot.transform = .identity
      if !target.isNull { drag.snapshot.frame = target }
      drag.snapshot.layer.shadowOpacity = 0
    } completion: { [weak self] _ in
      drag.snapshot.removeFromSuperview()
      guard let self else { return }
      self.sectionDrag = nil
      self.updateDraggedSectionVisibility()
      if drag.index != drag.startIndex { self.onChange?(self.sections) }
    }
  }
  
  /// Drops the drag without animating, e.g. when `sections` is replaced mid-drag.
  private func cancelSectionDrag() {
    guard let drag = sectionDrag else { return }
    drag.displayLink?.invalidate()
    drag.snapshot.removeFromSuperview()
    sectionDrag = nil
    updateDraggedSectionVisibility()
  }
  
  /// Hides the real cells of the dragged section, leaving a gap under the floating snapshot.
  private func updateDraggedSectionVisibility() {
    let hidden = sectionDrag?.index
    for path in collectionView.indexPathsForVisibleItems {
      collectionView.cellForItem(at: path)?.alpha = path.section == hidden ? 0 : 1
    }
    for kind in [UICollectionView.elementKindSectionHeader, UICollectionView.elementKindSectionFooter] {
      for path in collectionView.indexPathsForVisibleSupplementaryElements(ofKind: kind) {
        collectionView.supplementaryView(forElementKind: kind, at: path)?.alpha = path.section == hidden ? 0 : 1
      }
    }
  }
  
  public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell,
                             forItemAt indexPath: IndexPath) {
    cell.alpha = sectionDrag?.index == indexPath.section ? 0 : 1
  }
  
  public func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView,
                             forElementKind elementKind: String, at indexPath: IndexPath) {
    view.alpha = sectionDrag?.index == indexPath.section ? 0 : 1
  }
  
  // MARK: Data source
  
  public func numberOfSections(in collectionView: UICollectionView) -> Int {
    mode == .items ? sections.count : 1
  }
  
  public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    mode == .items ? sections[section].items.count : sections.count
  }
  
  public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    switch sectionLayout(at: indexPath.section) {
    case .list:
      return collectionView.dequeueConfiguredReusableCell(using: listCellRegistration, for: indexPath, item: indexPath)
    case .grid:
      return collectionView.dequeueConfiguredReusableCell(using: tileCellRegistration, for: indexPath, item: indexPath)
    case .carousel:
      return collectionView.dequeueConfiguredReusableCell(using: cardCellRegistration, for: indexPath, item: indexPath)
    case .banner, .horizontalBanner:
      return collectionView.dequeueConfiguredReusableCell(using: bannerCellRegistration, for: indexPath, item: indexPath)
    }
  }
  
  public func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String,
                             at indexPath: IndexPath) -> UICollectionReusableView {
    kind == UICollectionView.elementKindSectionHeader
    ? collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
    : collectionView.dequeueConfiguredReusableSupplementary(using: footerRegistration, for: indexPath)
  }
  
  // MARK: Drag
  
  public func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession,
                             at indexPath: IndexPath) -> [UIDragItem] {
    guard canMove(at: indexPath) else { return [] }
    let item = UIDragItem(itemProvider: NSItemProvider())
    item.localObject = indexPath
    return [item]
  }
  
  public func collectionView(_ collectionView: UICollectionView,
                             dragSessionIsRestrictedToDraggingApplication session: UIDragSession) -> Bool { true }
  
  public func collectionView(_ collectionView: UICollectionView,
                             dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
    guard let cell = collectionView.cellForItem(at: indexPath) else { return nil }
    let parameters = UIDragPreviewParameters()
    parameters.visiblePath = UIBezierPath(roundedRect: cell.bounds, cornerRadius: 12)
    return parameters
  }
  
  // MARK: Drop
  
  public func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
    session.localDragSession != nil
  }
  
  public func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession,
                             withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
    guard let source = session.localDragSession?.items.first?.localObject as? IndexPath else {
      return UICollectionViewDropProposal(operation: .forbidden)
    }
    startDropAutoscroll(for: session)
    guard let target = allowedDestination(for: session, proposed: destinationIndexPath, from: source) else {
      return UICollectionViewDropProposal(operation: .forbidden)
    }
    // A swap highlights the item it replaces instead of opening a gap.
    let swaps = mode == .items && BaseReorder.swaps(in: sections, from: source, to: target)
    return UICollectionViewDropProposal(operation: .move,
                                        intent: swaps ? .insertIntoDestinationIndexPath : .insertAtDestinationIndexPath)
  }
  
  public func collectionView(_ collectionView: UICollectionView, dropSessionDidEnd session: UIDropSession) {
    stopDropAutoscroll()
  }
  
  public func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
    guard let dropItem = coordinator.items.first, let source = dropItem.sourceIndexPath else { return }
    guard let destination = allowedDestination(for: coordinator.session,
                                               proposed: coordinator.destinationIndexPath, from: source),
          destination != source else { return }
    
    if mode == .items, BaseReorder.swaps(in: sections, from: source, to: destination) {
      collectionView.performBatchUpdates {
        commitSwap(from: source, with: destination)
        // Both items change section: fresh cells of each section's type and size.
        collectionView.deleteItems(at: [source, destination])
        collectionView.insertItems(at: [source, destination])
      }
      coordinator.drop(dropItem.dragItem, toItemAt: destination)
      UISelectionFeedbackGenerator().selectionChanged()
      onChange?(sections)
      return
    }
    
    let crossesSections = mode == .items && source.section != destination.section
    // Drop zones appear / disappear when a section becomes empty or stops being empty.
    let needsReload = crossesSections
    && (sections[source.section].items.count == 1 || sections[destination.section].items.isEmpty)
    
    collectionView.performBatchUpdates {
      commitMove(from: source, to: destination)
      if crossesSections {
        // Delete + insert (not move) so the item gets a fresh cell of the destination
        // section's type and size; a moved cell keeps its old class.
        collectionView.deleteItems(at: [source])
        collectionView.insertItems(at: [destination])
      } else {
        collectionView.moveItem(at: source, to: destination)
      }
    } completion: { [weak self] _ in
      guard let self, needsReload else { return }
      UIView.performWithoutAnimation { self.collectionView.reloadData() }
    }
    coordinator.drop(dropItem.dragItem, toItemAt: destination)
    UISelectionFeedbackGenerator().selectionChanged()
    onChange?(sections)
  }
}

// MARK: - List cell

/// List cell that can be given a fixed or minimum height (`itemSize.height` on `.list` sections).
final class BaseReorderListCell: UICollectionViewListCell {
  var fixedHeight: CGFloat?
  var minimumHeight: CGFloat?
  
  override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes)
  -> UICollectionViewLayoutAttributes {
    let attributes = super.preferredLayoutAttributesFitting(layoutAttributes)
    if let fixedHeight {
      attributes.frame.size.height = fixedHeight
    } else if let minimumHeight {
      attributes.frame.size.height = max(attributes.frame.height, minimumHeight)
    }
    return attributes
  }
}

// MARK: - Content-size reporting collection view

/// Reports content size changes, so a non-scrolling (embedded) collection can resize itself, and can
/// pin its content offset (UIKit's drag autoscroll moves it even when scrolling is disabled).
final class BaseReorderContentCollectionView: UICollectionView {
  var onContentSizeChange: (() -> Void)?
  
  var isContentOffsetPinned = false {
    didSet { if isContentOffsetPinned { contentOffset = .zero } }
  }
  
  override var contentOffset: CGPoint {
    get { super.contentOffset }
    set { super.contentOffset = isContentOffsetPinned ? .zero : newValue }
  }
  
  override func setContentOffset(_ contentOffset: CGPoint, animated: Bool) {
    super.setContentOffset(isContentOffsetPinned ? .zero : contentOffset, animated: animated)
  }
  
  override var contentSize: CGSize {
    didSet { if contentSize != oldValue { onContentSizeChange?() } }
  }
}

// MARK: - Gesture proxy

/// Non-generic target / delegate for the section drag gesture and its autoscroll display link.
final class BaseReorderGestureProxy: NSObject, UIGestureRecognizerDelegate {
  var shouldBegin: (UIGestureRecognizer) -> Bool = { _ in false }
  var onChange: (UILongPressGestureRecognizer) -> Void = { _ in }
  var onTick: () -> Void = {}
  
  @objc func handle(_ gesture: UILongPressGestureRecognizer) { onChange(gesture) }
  @objc func tick() { onTick() }
  
  func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    shouldBegin(gestureRecognizer)
  }
}

// MARK: - Card cell (carousel)

final class BaseReorderCardCell: UICollectionViewCell {
  private let iconBadge = UIView()
  private let iconView = UIImageView()
  private let titleLabel = UILabel()
  private let subtitleLabel = UILabel()
  private let pinView = UIImageView(image: UIImage(systemName: "pin.fill"))
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    
    var background = UIBackgroundConfiguration.listGroupedCell()
    background.cornerRadius = 16
    backgroundConfiguration = background
    
    iconBadge.backgroundColor = tintColor.withAlphaComponent(0.12)
    iconBadge.layer.cornerRadius = 18
    iconView.contentMode = .scaleAspectFit
    iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .body)
    iconView.layout {
      iconBadge.addSubview($0)
      $0.center()
    }
    
    titleLabel.font = .preferredFont(forTextStyle: .subheadline).withTraits(.traitBold)
    titleLabel.adjustsFontForContentSizeCategory = true
    titleLabel.numberOfLines = 2
    
    subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
    subtitleLabel.adjustsFontForContentSizeCategory = true
    subtitleLabel.textColor = .secondaryLabel
    
    pinView.tintColor = .tertiaryLabel
    pinView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .caption2)
    
    let stack = UIStackView(arrangedSubviews: [iconBadge, titleLabel, subtitleLabel])
    stack.axis = .vertical
    stack.alignment = .leading
    stack.spacing = 4
    stack.setCustomSpacing(12, after: iconBadge)
    stack.layout {
      contentView.addSubview($0)
      $0.top(12).leading(12).trailing(12)
      $0.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12).isActive = true
    }
    iconBadge.layout { $0.size(equalTo: 36) }
    pinView.layout {
      contentView.addSubview($0)
      $0.top(10).trailing(10)
    }
    // Preferred minimum; a smaller custom itemSize height wins.
    let minHeight = contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 130)
    minHeight.priority = .defaultHigh
    minHeight.isActive = true
    contentView.clipsToBounds = true
    isAccessibilityElement = true
  }
  
  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
  
  override func tintColorDidChange() {
    super.tintColorDidChange()
    iconBadge.backgroundColor = tintColor.withAlphaComponent(0.12)
  }
  
  func configure(with model: BaseReorderRow, isPinned: Bool) {
    iconView.image = UIImage(systemName: model.systemImage ?? "square")
    titleLabel.text = model.title
    subtitleLabel.text = model.subtitle
    subtitleLabel.isHidden = model.subtitle == nil
    pinView.isHidden = !isPinned
    accessibilityLabel = [model.title, model.subtitle].compactMap { $0 }.joined(separator: ", ")
  }
}

// MARK: - Banner cell

final class BaseReorderBannerCell: UICollectionViewCell {
  private let iconView = UIImageView()
  private let titleLabel = UILabel()
  private let subtitleLabel = UILabel()
  private let pinView = UIImageView(image: UIImage(systemName: "pin.fill"))
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    applyBackground()
    
    iconView.contentMode = .scaleAspectFit
    iconView.tintColor = UIColor.white.withAlphaComponent(0.35)
    iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 52, weight: .semibold)
    iconView.setContentHuggingPriority(.required, for: .horizontal)
    iconView.setContentCompressionResistancePriority(.required, for: .horizontal)
    
    titleLabel.font = .preferredFont(forTextStyle: .title3).withTraits(.traitBold)
    titleLabel.adjustsFontForContentSizeCategory = true
    titleLabel.textColor = .white
    titleLabel.numberOfLines = 0
    
    subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
    subtitleLabel.adjustsFontForContentSizeCategory = true
    subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.85)
    subtitleLabel.numberOfLines = 0
    
    pinView.tintColor = UIColor.white.withAlphaComponent(0.8)
    pinView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .caption1)
    
    let text = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
    text.axis = .vertical
    text.spacing = 4
    let row = UIStackView(arrangedSubviews: [text, iconView])
    row.alignment = .center
    row.spacing = 12
    row.layout {
      contentView.addSubview($0)
      $0.fill(insets: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 24))
    }
    pinView.layout {
      contentView.addSubview($0)
      $0.top(12).trailing(12)
    }
    // Preferred minimum; a smaller custom itemSize height wins.
    let minHeight = contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 110)
    minHeight.priority = .defaultHigh
    minHeight.isActive = true
    contentView.clipsToBounds = true
    isAccessibilityElement = true
  }
  
  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
  
  override func tintColorDidChange() {
    super.tintColorDidChange()
    applyBackground()
  }
  
  private func applyBackground() {
    var background = UIBackgroundConfiguration.clear()
    background.backgroundColor = tintColor
    background.cornerRadius = 18
    backgroundConfiguration = background
  }
  
  func configure(with model: BaseReorderRow, isPinned: Bool) {
    iconView.image = model.systemImage.flatMap { UIImage(systemName: $0) }
    iconView.isHidden = iconView.image == nil
    titleLabel.text = model.title
    subtitleLabel.text = model.subtitle
    subtitleLabel.isHidden = model.subtitle == nil
    pinView.isHidden = !isPinned
    accessibilityLabel = [model.title, model.subtitle].compactMap { $0 }.joined(separator: ", ")
  }
}

private extension UIFont {
  func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
    guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
    return UIFont(descriptor: descriptor, size: 0)
  }
}

// MARK: - Tile cell

final class BaseReorderTileCell: UICollectionViewCell {
  private let iconView = UIImageView()
  private let titleLabel = UILabel()
  private let subtitleLabel = UILabel()
  private let pinView = UIImageView(image: UIImage(systemName: "pin.fill"))
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    
    var background = UIBackgroundConfiguration.listGroupedCell()
    background.cornerRadius = 12
    backgroundConfiguration = background
    
    iconView.contentMode = .scaleAspectFit
    iconView.tintColor = tintColor
    iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title2)
    
    titleLabel.font = .preferredFont(forTextStyle: .subheadline)
    titleLabel.adjustsFontForContentSizeCategory = true
    titleLabel.numberOfLines = 2
    titleLabel.textAlignment = .center
    
    subtitleLabel.font = .preferredFont(forTextStyle: .caption2)
    subtitleLabel.adjustsFontForContentSizeCategory = true
    subtitleLabel.textColor = .secondaryLabel
    subtitleLabel.numberOfLines = 1
    subtitleLabel.textAlignment = .center
    
    pinView.tintColor = .tertiaryLabel
    pinView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .caption2)
    
    let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, subtitleLabel])
    stack.axis = .vertical
    stack.alignment = .center
    stack.spacing = 6
    stack.layout {
      contentView.addSubview($0)
      $0.fill(insets: UIEdgeInsets(top: 14, left: 8, bottom: 14, right: 8))
    }
    pinView.layout {
      contentView.addSubview($0)
      $0.top(8).trailing(8)
    }
    isAccessibilityElement = true
  }
  
  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
  
  func configure(with model: BaseReorderRow, isPinned: Bool) {
    iconView.image = model.systemImage.flatMap { UIImage(systemName: $0) }
    iconView.isHidden = iconView.image == nil
    titleLabel.text = model.title
    subtitleLabel.text = model.subtitle
    subtitleLabel.isHidden = model.subtitle == nil
    pinView.isHidden = !isPinned
    accessibilityLabel = [model.title, model.subtitle].compactMap { $0 }.joined(separator: ", ")
  }
}
#endif
