import BaseUI
import EasyAnchor
import SwiftUI
import UIKit

struct DemoTask: Hashable {
    let id = UUID()
    var name: String
    var note: String
    var icon: String
}

private func sampleSections() -> [BaseReorderSection<DemoTask>] {
    [
        BaseReorderSection("To do", items: [
            DemoTask(name: "Design login screen", note: "Figma · 2 pts", icon: "paintbrush"),
            DemoTask(name: "Add Khmer localization", note: "Strings · 3 pts", icon: "character.bubble"),
            DemoTask(name: "QR payment flow", note: "Feature · 5 pts", icon: "qrcode"),
        ]),
        BaseReorderSection("In progress", items: [
            DemoTask(name: "Island toast", note: "BaseUI · 3 pts", icon: "capsule"),
        ]),
        BaseReorderSection("Done", items: [
            DemoTask(name: "Base button", note: "BaseUI · 2 pts", icon: "checkmark.circle"),
            DemoTask(name: "Base text field", note: "BaseUI · 3 pts", icon: "checkmark.circle"),
        ]),
        BaseReorderSection("Blocked", items: []),
    ]
}

private enum ReorderStyle: String, CaseIterable, Identifiable {
    case table = "Table", list = "List", grid = "Grid", mixed = "Mixed"
    var id: String { rawValue }
}

/// Each section has its own cell type; section 0 is pinned and its banner is locked.
private func mixedSections() -> [BaseReorderSection<DemoTask>] {
    [
        BaseReorderSection("Sprint goal", items: [
            DemoTask(name: "Ship BaseUI 0.2", note: "Buttons, fields, dropdowns and reorder lists", icon: "flag.checkered"),
            DemoTask(name: "Ship BaseUI 0.3", note: "Buttons, fields, dropdowns and reorder lists", icon: "flag.checkered"),
        ], layout: .horizontalBanner, isPinned: true, allowsItemMoves: false),
        
        BaseReorderSection("Favorites", items: [
            DemoTask(name: "QR payment flow", note: "5 pts", icon: "qrcode"),
            DemoTask(name: "Island toast", note: "3 pts", icon: "capsule"),
            DemoTask(name: "Dark mode", note: "2 pts", icon: "moon"),
            DemoTask(name: "Haptics", note: "1 pt", icon: "waveform"),
        ], layout: .carousel, isPinned: true, swapsOnDrop: true),   // fixed row: drops swap
        
        BaseReorderSection("", items: [ // TO DO
            DemoTask(name: "Design login screen", note: "Figma · 2 pts", icon: "paintbrush"),
            DemoTask(name: "Add Khmer localization", note: "Strings · 3 pts", icon: "character.bubble"),
        ], layout: .list, swapsOnDrop: true),
        
        BaseReorderSection("Done", items: [
            DemoTask(name: "Base button", note: "2 pts", icon: "checkmark.circle"),
            DemoTask(name: "Base text field", note: "3 pts", icon: "checkmark.circle"),
            DemoTask(name: "Dropdown", note: "2 pts", icon: "checkmark.circle"),
        ], layout: .grid(columns: 3),
                           itemSize: .init(width: .absolute(100), height: .absolute(110)),
                           swapsOnDrop: true),
        
        BaseReorderSection("Blocked", items: [], layout: .list, itemSize: .init(height: .absolute(60))),
    ]
}

struct BaseReorderListDemoView: View {
    @State private var sections = sampleSections()
    @State private var mixed = mixedSections()
    @State private var mode: BaseReorderMode = .items
    @State private var style: ReorderStyle = .table
    @State private var allowsCrossSection = true
    @State private var cardWidth: Double = 150
    @State private var cardHeight: Double = 130
    @State private var favoritesHeight: Double = 0   // 0 = automatic
    @State private var horizontalBanner = false

    var body: some View {
        Group {
            if style == .table {
                // The table keeps its own scrolling.
                VStack(spacing: 0) {
                    controls
                    BaseReorderListView(sections: $sections, mode: mode, allowsCrossSectionMoves: allowsCrossSection) { task in
                        BaseReorderRow(title: task.name, subtitle: task.note, systemImage: task.icon)
                    }
                }
            } else {
                // The collection sizes to its content and scrolls together with the controls.
                ScrollView {
                    VStack(spacing: 0) {
                        controls
                        collection
                    }
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Reorder List")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Reset", systemImage: "arrow.counterclockwise") {
                        sections = sampleSections()
                        mixed = mixedSections()
                        setBannerLayout(in: &mixed, horizontal: horizontalBanner)
                    }
                    NavigationLink {
                        UIKitReorderDemo()
                            .ignoresSafeArea(edges: .bottom)
                            .navigationTitle("UIKit Reorder")
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        Label("UIKit version", systemImage: "square.stack")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Picker("Mode", selection: $mode) {
                Text("Reorder items").tag(BaseReorderMode.items)
                Text("Reorder sections").tag(BaseReorderMode.sections)
            }
            .pickerStyle(.segmented)
            Picker("Style", selection: $style) {
                ForEach(ReorderStyle.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            if style != .table {
                Text(mode == .items
                     ? "Hold an item to move it. Hold a section header (≡) to move the whole section."
                     : "Hold a row to move that section.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Toggle("Allow moves across sections", isOn: $allowsCrossSection)
                .disabled(mode == .sections)
            if style == .mixed && mode == .items {
                Picker("Banner", selection: $horizontalBanner) {
                    Text("Banner vertical").tag(false)
                    Text("Banner horizontal").tag(true)
                }
                .pickerStyle(.segmented)
                HStack {
                    Text("Card width \(Int(cardWidth))").font(.caption).frame(width: 110, alignment: .leading)
                    Slider(value: $cardWidth, in: 100...300, step: 10)
                }
                HStack {
                    Text("Card height \(Int(cardHeight))").font(.caption).frame(width: 110, alignment: .leading)
                    Slider(value: $cardHeight, in: 90...220, step: 10)
                }
                HStack {
                    Text(favoritesHeight == 0 ? "Section h. auto" : "Section h. \(Int(favoritesHeight))")
                        .font(.caption).frame(width: 110, alignment: .leading)
                    Slider(value: $favoritesHeight, in: 0...260, step: 10)
                }
            }
            Text("Order: " + (style == .mixed ? mixed : sections).map { "\($0.title) (\($0.items.count))" }.joined(separator: " → "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }

    @ViewBuilder
    private var collection: some View {
        if style == .mixed {
            BaseReorderCollectionView(sections: $mixed, mode: mode,
                                      sizeForItem: demoItemSize,
                                      allowsCrossSectionMoves: allowsCrossSection,
                                      isScrollEnabled: false) { task in
                BaseReorderRow(title: task.name, subtitle: task.note, systemImage: task.icon)
            }
            .onChange(of: cardWidth) { _ in resizeFavorites() }
            .onChange(of: cardHeight) { _ in resizeFavorites() }
            .onChange(of: favoritesHeight) { _ in resizeFavorites() }
            .onChange(of: horizontalBanner) { setBannerLayout(in: &mixed, horizontal: $0) }
        } else {
            BaseReorderCollectionView(sections: $sections, mode: mode,
                                      layout: style == .grid ? .grid(columns: 3) : .list,
                                      allowsCrossSectionMoves: allowsCrossSection,
                                      isScrollEnabled: false) { task in
                BaseReorderRow(title: task.name, subtitle: task.note, systemImage: task.icon)
            }
        }
    }

    /// Applies the sliders to the carousel section (found by id, since sections can be reordered).
    private func resizeFavorites() {
        guard let index = mixed.firstIndex(where: { $0.id == "Favorites" }) else { return }
        mixed[index].itemSize = .fixed(width: cardWidth, height: cardHeight)
        mixed[index].height = favoritesHeight == 0 ? nil : favoritesHeight
    }

}

/// Shows the "Sprint goal" banners stacked vertically or paging horizontally (found by id, since
/// sections can be reordered).
private func setBannerLayout(in sections: inout [BaseReorderSection<DemoTask>], horizontal: Bool) {
    guard let index = sections.firstIndex(where: { $0.id == "Sprint goal" }) else { return }
    sections[index].layout = horizontal ? .horizontalBanner : .banner
}

/// Per-item sizes: "QR payment flow" is a wide featured card wherever it goes, and the
/// "Base text field" tile is double width in a grid.
private func demoItemSize(_ task: DemoTask, _ section: BaseReorderSection<DemoTask>) -> BaseReorderItemSize? {
    switch (task.name, section.layout) {
//    case ("QR payment flow", .carousel?): return .init(width: .absolute(240))
    case ("Base text field", .grid?):     return .init(width: .absolute(210))
    default:                              return nil
    }
}

// MARK: - UIKit

/// UIKit version of the demo. Table style uses `BaseReorderList`, which scrolls itself; List, Grid and
/// Mixed embed a non-scrolling `BaseReorderCollection` in a `UIScrollView` below the controls.
final class UIKitReorderDemoViewController: UIViewController {
    private var sections = sampleSections()
    private var mixed = mixedSections()
    private var style: ReorderStyle = .table
    private var mode: BaseReorderMode = .items

    private let list = BaseReorderList(sections: sampleSections()) { task in
        BaseReorderRow(title: task.name, subtitle: task.note, systemImage: task.icon)
    }
    private let collection = BaseReorderCollection(sections: sampleSections()) { task in
        BaseReorderRow(title: task.name, subtitle: task.note, systemImage: task.icon)
    }

    private let controls = UIStackView()
    private let hintLabel = UILabel()
    private let crossSectionSwitch = UISwitch()
    private let bannerControl = UISegmentedControl(items: ["Banner vertical", "Banner horizontal"])
    private let orderLabel = UILabel()

    /// Table style: controls on top, the list fills the rest.
    private let tableLayout = UIStackView()
    /// Collection styles: controls and collection scroll together.
    private let scrollView = UIScrollView()
    private let scrollContent = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setUpControls()
        setUpLists()
        setUpLayout()
        applyStyle()
    }

    // MARK: Setup

    private func setUpControls() {
        let modeControl = UISegmentedControl(items: ["Reorder items", "Reorder sections"])
        modeControl.selectedSegmentIndex = 0
        modeControl.addAction(UIAction { [weak self, weak modeControl] _ in
            guard let self, let modeControl else { return }
            self.mode = modeControl.selectedSegmentIndex == 1 ? .sections : .items
            self.list.mode = self.mode
            self.collection.mode = self.mode
            self.updateControls()
        }, for: .valueChanged)

        let styleControl = UISegmentedControl(items: ReorderStyle.allCases.map(\.rawValue))
        styleControl.selectedSegmentIndex = 0
        styleControl.addAction(UIAction { [weak self, weak styleControl] _ in
            guard let self, let styleControl else { return }
            self.style = ReorderStyle.allCases[styleControl.selectedSegmentIndex]
            self.applyStyle()
        }, for: .valueChanged)

        hintLabel.font = .preferredFont(forTextStyle: .caption1)
        hintLabel.textColor = .secondaryLabel
        hintLabel.numberOfLines = 0

        let crossSectionLabel = UILabel()
        crossSectionLabel.text = "Allow moves across sections"
        crossSectionSwitch.isOn = true
        crossSectionSwitch.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.list.allowsCrossSectionMoves = self.crossSectionSwitch.isOn
            self.collection.allowsCrossSectionMoves = self.crossSectionSwitch.isOn
        }, for: .valueChanged)
        let crossSectionRow = UIStackView(arrangedSubviews: [crossSectionLabel, crossSectionSwitch])

        orderLabel.font = .preferredFont(forTextStyle: .caption1)
        orderLabel.textColor = .secondaryLabel
        orderLabel.numberOfLines = 0

        bannerControl.selectedSegmentIndex = 0
        bannerControl.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            setBannerLayout(in: &self.mixed, horizontal: self.bannerControl.selectedSegmentIndex == 1)
            self.collection.sections = self.mixed
        }, for: .valueChanged)

        [modeControl, styleControl, hintLabel, crossSectionRow, bannerControl, orderLabel].forEach(controls.addArrangedSubview)
        controls.axis = .vertical
        controls.spacing = 12
        controls.isLayoutMarginsRelativeArrangement = true
        controls.directionalLayoutMargins = .init(top: 16, leading: 16, bottom: 16, trailing: 16)
    }

    private func setUpLists() {
        // "Done" items are pinned in the table.
        list.canMoveItem = { !$0.icon.hasPrefix("checkmark") }
        list.onChange = { [weak self] sections in
            self?.sections = sections
            self?.didChange(sections)
        }

        collection.isScrollEnabled = false   // the outer scroll view scrolls
        collection.onChange = { [weak self] sections in
            guard let self else { return }
            if self.style == .mixed { self.mixed = sections } else { self.sections = sections }
            self.didChange(sections)
        }
    }

    private func setUpLayout() {
        tableLayout.axis = .vertical
        tableLayout.addArrangedSubview(list)

        scrollContent.axis = .vertical
        scrollContent.addArrangedSubview(collection)
        scrollView.alwaysBounceVertical = true
        scrollView.addSubview(scrollContent)

        for container in [tableLayout, scrollView] as [UIView] {
            container.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(container)
        }
        scrollContent.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableLayout.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableLayout.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableLayout.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableLayout.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            scrollContent.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            scrollContent.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            scrollContent.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            scrollContent.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            scrollContent.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])
    }

    // MARK: State

    /// Moves the controls into the active layout and points the collection at the right data.
    private func applyStyle() {
        let isTable = style == .table
        (isTable ? tableLayout : scrollContent).insertArrangedSubview(controls, at: 0)
        tableLayout.isHidden = !isTable
        scrollView.isHidden = isTable

        if !isTable {
            collection.layout = style == .grid ? .grid(columns: 3) : .list
            collection.sizeForItem = style == .mixed ? demoItemSize : nil
            collection.sections = style == .mixed ? mixed : sections
        } else {
            list.sections = sections
        }
        updateControls()
    }

    private func updateControls() {
        hintLabel.text = mode == .items
            ? "Hold an item to move it. Hold a section header (≡) to move the whole section."
            : "Hold a row to move that section."
        hintLabel.isHidden = style == .table
        bannerControl.isHidden = style != .mixed || mode != .items
        crossSectionSwitch.isEnabled = mode == .items
        let current = style == .mixed ? mixed : sections
        orderLabel.text = "Order: " + current.map { "\($0.title) (\($0.items.count))" }.joined(separator: " → ")
    }

    private func didChange(_ sections: [BaseReorderSection<DemoTask>]) {
        updateControls()
        IslandToast.show(sections.map { "\($0.title) \($0.items.count)" }.joined(separator: " · "),
                         style: .info, duration: 1.5)
    }
}

struct UIKitReorderDemo: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIKitReorderDemoViewController { .init() }
    func updateUIViewController(_ uiViewController: UIKitReorderDemoViewController, context: Context) {}
}

#Preview {
    NavigationStack { BaseReorderListDemoView() }
}
