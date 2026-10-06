import SwiftUI
import UIKit
import BaseUI

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
        ], layout: .banner, isPinned: true, allowsItemMoves: false),
        
        BaseReorderSection("Favorites", items: [
            DemoTask(name: "QR payment flow", note: "5 pts", icon: "qrcode"),
            DemoTask(name: "Island toast", note: "3 pts", icon: "capsule"),
            DemoTask(name: "Dark mode", note: "2 pts", icon: "moon"),
            DemoTask(name: "Haptics", note: "1 pt", icon: "waveform"),
        ], layout: .carousel, isPinned: true),
        
        BaseReorderSection("To do", items: [
            DemoTask(name: "Design login screen", note: "Figma · 2 pts", icon: "paintbrush"),
            DemoTask(name: "Add Khmer localization", note: "Strings · 3 pts", icon: "character.bubble"),
        ], layout: .list),
        
        BaseReorderSection("Done", items: [
            DemoTask(name: "Base button", note: "2 pts", icon: "checkmark.circle"),
            DemoTask(name: "Base text field", note: "3 pts", icon: "checkmark.circle"),
            DemoTask(name: "Dropdown", note: "2 pts", icon: "checkmark.circle"),
        ], layout: .grid(columns: 3), itemSize: .init(width: .absolute(100), height: .absolute(110))),
        
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

    var body: some View {
        VStack(spacing: 0) {
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

            switch style {
            case .table:
                BaseReorderListView(sections: $sections, mode: mode, allowsCrossSectionMoves: allowsCrossSection) { task in
                    BaseReorderRow(title: task.name, subtitle: task.note, systemImage: task.icon)
                }
            case .mixed:
                BaseReorderCollectionView(sections: $mixed, mode: mode,
                                          sizeForItem: Self.demoItemSize,
                                          allowsCrossSectionMoves: allowsCrossSection) { task in
                    BaseReorderRow(title: task.name, subtitle: task.note, systemImage: task.icon)
                }
                .onChange(of: cardWidth) { _ in resizeFavorites() }
                .onChange(of: cardHeight) { _ in resizeFavorites() }
                .onChange(of: favoritesHeight) { _ in resizeFavorites() }
            case .list, .grid:
                BaseReorderCollectionView(sections: $sections, mode: mode,
                                          layout: style == .grid ? .grid(columns: 3) : .list,
                                          allowsCrossSectionMoves: allowsCrossSection) { task in
                    BaseReorderRow(title: task.name, subtitle: task.note, systemImage: task.icon)
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

    /// Applies the sliders to the carousel section (found by id, since sections can be reordered).
    private func resizeFavorites() {
        guard let index = mixed.firstIndex(where: { $0.id == "Favorites" }) else { return }
        mixed[index].itemSize = .fixed(width: cardWidth, height: cardHeight)
        mixed[index].height = favoritesHeight == 0 ? nil : favoritesHeight
    }

    /// Per-item sizes: "QR payment flow" is a wide featured card wherever it goes, and the
    /// "Base text field" tile is double width in a grid.
    private static func demoItemSize(_ task: DemoTask, _ section: BaseReorderSection<DemoTask>) -> BaseReorderItemSize? {
        switch (task.name, section.layout) {
        case ("QR payment flow", .carousel?): return .init(width: .absolute(240))
        case ("Base text field", .grid?):     return .init(width: .absolute(210))
        default:                              return nil
        }
    }
}

// MARK: - UIKit

final class UIKitReorderDemoViewController: UIViewController {
    private let list = BaseReorderList(sections: sampleSections()) { task in
        BaseReorderRow(title: task.name, subtitle: task.note, systemImage: task.icon)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        let modeControl = UISegmentedControl(items: ["Reorder items", "Reorder sections"])
        modeControl.selectedSegmentIndex = 0
        modeControl.addAction(UIAction { [weak self, weak modeControl] _ in
            self?.list.mode = modeControl?.selectedSegmentIndex == 1 ? .sections : .items
        }, for: .valueChanged)

        // "Done" items are pinned in this demo.
        list.canMoveItem = { !$0.icon.hasPrefix("checkmark") }
        list.onChange = { sections in
            IslandToast.show(sections.map { "\($0.title) \($0.items.count)" }.joined(separator: " · "),
                             style: .info, duration: 1.5)
        }

        modeControl.translatesAutoresizingMaskIntoConstraints = false
        list.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(modeControl)
        view.addSubview(list)
        NSLayoutConstraint.activate([
            modeControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            modeControl.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            modeControl.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            list.topAnchor.constraint(equalTo: modeControl.bottomAnchor, constant: 8),
            list.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            list.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            list.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}

struct UIKitReorderDemo: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIKitReorderDemoViewController { .init() }
    func updateUIViewController(_ uiViewController: UIKitReorderDemoViewController, context: Context) {}
}

#Preview {
    NavigationStack { BaseReorderListDemoView() }
}
