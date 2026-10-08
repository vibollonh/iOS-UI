import SwiftUI
import UIKit
import BaseUI

struct WalletCard: Identifiable, Hashable {
    let id: String
    let amount: String
    let icon: String
    let color: UIColor

    static let samples: [WalletCard] = [
        WalletCard(id: "Savings", amount: "$12,480", icon: "banknote", color: .systemTeal),
        WalletCard(id: "Travel", amount: "$3,210", icon: "airplane", color: .systemIndigo),
        WalletCard(id: "Bills", amount: "$860", icon: "doc.text", color: .systemOrange),
        WalletCard(id: "Groceries", amount: "$420", icon: "cart", color: .systemBrown),
        WalletCard(id: "Gifts", amount: "$150", icon: "gift", color: .systemPink),
        WalletCard(id: "Health", amount: "$95", icon: "heart", color: .systemBlue),
    ]

    static let details: [(String, String)] = [
        ("Monthly goal", "$500"), ("Last deposit", "2 days ago"), ("Auto-save", "On"), ("Interest", "2.1%"),
        ("Opened", "Jan 2024"), ("Account", "•••• 4821"), ("Owner", "You"), ("Currency", "USD"),
    ]
}

struct WalletTransaction: Identifiable, Hashable {
    let id: Int
    let title: String
    let amount: String
    let date: String
    let icon: String

    var details: [(String, String)] {
        [("Amount", amount), ("Date", date), ("Status", "Completed"), ("Reference", "TX-\(4810 + id)")]
    }

    static func samples(for card: WalletCard) -> [WalletTransaction] {
        let names = [("Coffee", "cup.and.saucer"), ("Taxi", "car"), ("Hotel", "bed.double"), ("Market", "basket"),
                     ("Flight", "airplane"), ("Pharmacy", "cross.case"), ("Books", "book"), ("Dinner", "fork.knife")]
        return names.enumerated().map { index, item in
            WalletTransaction(id: index, title: "\(item.0) · \(card.id)", amount: "-$\(12 + index * 17).00",
                              date: "Oct \(7 - index % 7), 2026", icon: item.1)
        }
    }
}

/// Screens pushed inside the zoomed detail.
enum WalletRoute: Hashable {
    case transactions
    case transaction(WalletTransaction)
    case statements
}

private let statements: [(String, String)] = [
    ("September 2026", "$1,240.00"), ("August 2026", "$980.50"), ("July 2026", "$1,105.20"), ("June 2026", "$860.00"),
]

private let cardCornerRadius: CGFloat = 16

/// Shared demo settings, mapped onto `BaseZoomConfiguration`.
struct ZoomDemoSettings {
    var dragDown = true
    var dragRight = true
    var dismissDistance: Double = 120
    var minimumScale: Double = 0.7
    var dimsBackground = true

    var configuration: BaseZoomConfiguration {
        var config = BaseZoomConfiguration()
        config.dismissGestures = []
        if dragDown { config.dismissGestures.insert(.down) }
        if dragRight { config.dismissGestures.insert(.right) }
        config.dismissDistance = dismissDistance
        config.minimumScale = minimumScale
        config.dimmingAlpha = dimsBackground ? 0.35 : 0
        config.sourceCornerRadius = cardCornerRadius
        return config
    }

    var hint: String {
        switch (dragDown, dragRight) {
        case (true, true):  return "Drag down or right to close"
        case (true, false): return "Drag down to close"
        case (false, true): return "Drag right to close"
        case (false, false): return "Tap × to close"
        }
    }
}

// MARK: - SwiftUI

struct BaseZoomTransitionDemoView: View {
    @State private var settings = ZoomDemoSettings()
    @State private var selected: WalletCard.ID?

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Tap a card to open it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(WalletCard.samples) { card in
                        WalletCardView(card: card)
                            .onTapGesture { selected = card.id }
                            .baseZoomPresentation(isPresented: binding(for: card), configuration: settings.configuration) {
                                WalletDetailView(card: card, hint: settings.hint) { selected = nil }
                            }
                    }
                }

                settingsPanel
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Zoom Presentation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    UIKitZoomDemo(settings: settings)
                        .ignoresSafeArea(edges: .bottom)
                        .navigationTitle("UIKit Zoom")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label("UIKit version", systemImage: "square.stack")
                }
            }
        }
    }

    private func binding(for card: WalletCard) -> Binding<Bool> {
        Binding(get: { selected == card.id },
                set: { if !$0, selected == card.id { selected = nil } })
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dismiss gestures").font(.footnote).foregroundStyle(.secondary)
            Toggle("Drag down (shrinks and follows)", isOn: $settings.dragDown)
            Toggle("Drag right (slides and zooms out)", isOn: $settings.dragRight)
            Divider()
            HStack {
                Text("Dismiss at \(Int(settings.dismissDistance))pt").font(.footnote).frame(width: 120, alignment: .leading)
                Slider(value: $settings.dismissDistance, in: 60...220, step: 10)
            }
            HStack {
                Text("Min scale \(settings.minimumScale, specifier: "%.2f")").font(.footnote).frame(width: 120, alignment: .leading)
                Slider(value: $settings.minimumScale, in: 0.5...0.9, step: 0.05)
            }
            Toggle("Dim background", isOn: $settings.dimsBackground)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct WalletCardView: View {
    let card: WalletCard

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Image(systemName: card.icon).font(.title3)
            Spacer()
            Text(card.id).font(.footnote)
            Text(card.amount).font(.title3.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .background(Color(uiColor: card.color), in: RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: cardCornerRadius))
    }
}

/// The zoomed detail: its own NavigationStack, so rows push screens with the normal animation.
/// Drags only close from this first screen; pushed screens go back with the back button / edge swipe.
private struct WalletDetailView: View {
    let card: WalletCard
    let hint: String
    let close: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Image(systemName: card.icon).font(.largeTitle).padding(.bottom, 20)
                    Text(card.id).font(.headline)
                    Text(card.amount).font(.system(size: 40, weight: .bold)).padding(.bottom, 24)
                    navigationRow("Transactions", icon: "list.bullet", route: .transactions)
                    navigationRow("Statements", icon: "doc.plaintext", route: .statements)
                    ForEach(WalletCard.details, id: \.0) { row in
                        Divider().overlay(.white.opacity(0.4))
                        HStack { Text(row.0); Spacer(); Text(row.1) }.padding(.vertical, 14)
                    }
                    Text(hint + ". Pushed screens don't close by dragging: go back first.")
                        .font(.footnote).opacity(0.8).padding(.top, 24)
                }
                .padding(24)
                .foregroundStyle(.white)
            }
            .background(Color(uiColor: card.color).ignoresSafeArea())
            .navigationTitle(card.id)
            .navigationBarTitleDisplayMode(.inline)
            // The dark (white title) bar style only applies to a visible background, so paint it the card color.
            .toolbarBackground(Color(uiColor: card.color), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: close) { Image(systemName: "xmark") }
                        .tint(.white)
                        .accessibilityLabel("Close")
                }
            }
            .navigationDestination(for: WalletRoute.self) { route in
                switch route {
                case .transactions:
                    WalletTransactionsView(card: card)
                case .transaction(let transaction):
                    KeyValueListView(title: transaction.title, rows: transaction.details)
                case .statements:
                    KeyValueListView(title: "Statements", rows: statements)
                }
            }
        }
        .tint(Color(uiColor: card.color))   // back buttons on the pushed (light) screens
    }

    private func navigationRow(_ title: String, icon: String, route: WalletRoute) -> some View {
        VStack(spacing: 0) {
            Divider().overlay(.white.opacity(0.4))
            NavigationLink(value: route) {
                HStack {
                    Label(title, systemImage: icon)
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).opacity(0.7)
                }
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .foregroundStyle(.white)
        }
    }
}

private struct WalletTransactionsView: View {
    let card: WalletCard

    var body: some View {
        List(WalletTransaction.samples(for: card)) { transaction in
            NavigationLink(value: WalletRoute.transaction(transaction)) {
                HStack {
                    Label(transaction.title, systemImage: transaction.icon)
                    Spacer()
                    Text(transaction.amount).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Transactions")
    }
}

private struct KeyValueListView: View {
    let title: String
    let rows: [(String, String)]

    var body: some View {
        List(rows, id: \.0) { row in
            LabeledContent(row.0, value: row.1)
        }
        .navigationTitle(title)
    }
}

// MARK: - UIKit

struct UIKitZoomDemo: UIViewControllerRepresentable {
    let settings: ZoomDemoSettings
    func makeUIViewController(context: Context) -> UIKitZoomDemoViewController { .init(settings: settings) }
    func updateUIViewController(_ controller: UIKitZoomDemoViewController, context: Context) {}
}

/// Same demo in UIKit: `present(_:zoomingFrom:configuration:)` from a card view.
final class UIKitZoomDemoViewController: UIViewController {
    private var settings: ZoomDemoSettings

    init(settings: ZoomDemoSettings) {
        self.settings = settings
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        let gestures = UISegmentedControl(items: ["Down + right", "Down", "Right", "None"])
        gestures.selectedSegmentIndex = 0
        gestures.addAction(UIAction { [weak self, weak gestures] _ in
            guard let self, let index = gestures?.selectedSegmentIndex else { return }
            self.settings.dragDown = index == 0 || index == 1
            self.settings.dragRight = index == 0 || index == 2
        }, for: .valueChanged)

        let rows = stride(from: 0, to: WalletCard.samples.count, by: 2).map { start -> UIStackView in
            let row = UIStackView(arrangedSubviews: WalletCard.samples[start..<min(start + 2, WalletCard.samples.count)]
                .map(makeCard))
            row.distribution = .fillEqually
            row.spacing = 12
            return row
        }
        let stack = UIStackView(arrangedSubviews: [gestures] + rows)
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(20, after: gestures)

        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.addSubview(stack)
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
        ])
    }

    private func makeCard(_ card: WalletCard) -> UIView {
        let icon = UIImageView(image: UIImage(systemName: card.icon))
        icon.tintColor = .white
        let name = UILabel()
        name.text = card.id
        name.font = .preferredFont(forTextStyle: .footnote)
        let amount = UILabel()
        amount.text = card.amount
        amount.font = .systemFont(ofSize: 20, weight: .semibold)
        [name, amount].forEach { $0.textColor = .white }

        let stack = UIStackView(arrangedSubviews: [icon, UIView(), name, amount])
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = .init(top: 12, leading: 12, bottom: 12, trailing: 12)
        stack.backgroundColor = card.color
        stack.layer.cornerRadius = cardCornerRadius
        stack.layer.cornerCurve = .continuous
        stack.heightAnchor.constraint(equalToConstant: 150).isActive = true
        stack.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cardTapped(_:))))
        stack.accessibilityIdentifier = card.id
        return stack
    }

    @objc private func cardTapped(_ tap: UITapGestureRecognizer) {
        guard let source = tap.view, let card = WalletCard.samples.first(where: { $0.id == source.accessibilityIdentifier })
        else { return }
        // UIKit reads the corner radius from the source's layer, so no sourceCornerRadius needed.
        var config = settings.configuration
        config.sourceCornerRadius = nil
        let navigation = UINavigationController(rootViewController: WalletDetailViewController(card: card, hint: settings.hint))
        navigation.navigationBar.tintColor = card.color   // back buttons on the pushed (light) screens
        present(navigation, zoomingFrom: source, configuration: config)
    }
}

/// UIKit detail screen inside a UINavigationController: rows push screens; close button in the bar.
final class WalletDetailViewController: UIViewController {
    private let card: WalletCard
    private let hint: String

    init(card: WalletCard, hint: String) {
        self.card = card
        self.hint = hint
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = card.color

        // Transparent bar with white items over the card color; pushed screens keep the default bar.
        title = card.id
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        let close = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        close.tintColor = .white
        navigationItem.rightBarButtonItem = close

        let header = UIImageView(image: UIImage(systemName: card.icon,
                                                withConfiguration: UIImage.SymbolConfiguration(textStyle: .largeTitle)))
        header.tintColor = .white
        header.contentMode = .left
        let name = label(card.id, font: .preferredFont(forTextStyle: .headline))
        let amount = label(card.amount, font: .systemFont(ofSize: 40, weight: .bold))
        var arranged: [UIView] = [header, name, amount]
        arranged += navigationRow("Transactions", icon: "list.bullet") { [weak self] in
            guard let self else { return }
            self.navigationController?.pushViewController(WalletTransactionsViewController(card: self.card), animated: true)
        }
        arranged += navigationRow("Statements", icon: "doc.plaintext") { [weak self] in
            self?.navigationController?.pushViewController(KeyValueViewController(title: "Statements", rows: statements),
                                                           animated: true)
        }
        for (title, value) in WalletCard.details {
            let divider = UIView()
            divider.backgroundColor = UIColor.white.withAlphaComponent(0.4)
            divider.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
            let row = UIStackView(arrangedSubviews: [label(title), UIView(), label(value)])
            arranged += [divider, row]
        }
        let hintLabel = label(hint + ". Pushed screens don't close by dragging: go back first.",
                              font: .preferredFont(forTextStyle: .footnote))
        hintLabel.numberOfLines = 0
        hintLabel.alpha = 0.8
        arranged.append(hintLabel)

        let stack = UIStackView(arrangedSubviews: arranged)
        stack.axis = .vertical
        stack.spacing = 14
        stack.setCustomSpacing(20, after: header)
        stack.setCustomSpacing(24, after: amount)
        stack.setCustomSpacing(24, after: arranged[arranged.count - 2])

        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.addSubview(stack)
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
        ])
    }

    private func label(_ text: String, font: UIFont = .preferredFont(forTextStyle: .body)) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = .white
        return label
    }

    /// Divider plus a full-width tappable row with a chevron.
    private func navigationRow(_ title: String, icon: String, action: @escaping () -> Void) -> [UIView] {
        let divider = UIView()
        divider.backgroundColor = UIColor.white.withAlphaComponent(0.4)
        divider.heightAnchor.constraint(equalToConstant: 0.5).isActive = true

        var config = UIButton.Configuration.plain()
        config.title = title
        config.image = UIImage(systemName: icon)
        config.imagePadding = 10
        config.baseForegroundColor = .white
        config.contentInsets = .init(top: 4, leading: 0, bottom: 4, trailing: 0)
        let button = UIButton(configuration: config, primaryAction: UIAction { _ in action() })
        button.contentHorizontalAlignment = .leading
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = UIColor.white.withAlphaComponent(0.7)
        chevron.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(chevron)
        NSLayoutConstraint.activate([
            chevron.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            chevron.centerYAnchor.constraint(equalTo: button.centerYAnchor),
        ])
        return [divider, button]
    }
}

/// Pushed: the card's transactions; tapping one pushes its details.
final class WalletTransactionsViewController: UITableViewController {
    private let transactions: [WalletTransaction]

    init(card: WalletCard) {
        transactions = WalletTransaction.samples(for: card)
        super.init(style: .insetGrouped)
        title = "Transactions"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { transactions.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let transaction = transactions[indexPath.row]
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        var content = UIListContentConfiguration.valueCell()
        content.text = transaction.title
        content.secondaryText = transaction.amount
        content.image = UIImage(systemName: transaction.icon)
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let transaction = transactions[indexPath.row]
        navigationController?.pushViewController(KeyValueViewController(title: transaction.title, rows: transaction.details),
                                                 animated: true)
    }
}

/// Pushed: a plain list of label / value rows.
final class KeyValueViewController: UITableViewController {
    private let rows: [(String, String)]

    init(title: String, rows: [(String, String)]) {
        self.rows = rows
        super.init(style: .insetGrouped)
        self.title = title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        var content = UIListContentConfiguration.valueCell()
        content.text = rows[indexPath.row].0
        content.secondaryText = rows[indexPath.row].1
        cell.contentConfiguration = content
        cell.selectionStyle = .none
        return cell
    }
}

#Preview {
    NavigationStack { BaseZoomTransitionDemoView() }
}
