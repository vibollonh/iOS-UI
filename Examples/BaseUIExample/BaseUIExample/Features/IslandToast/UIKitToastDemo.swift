import SwiftUI
import UIKit
import BaseUI

/// Exercises the toast from plain UIKit (buttons, UIAlertController, UIKit sheet).
final class UIKitToastDemoViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        let stack = UIStackView(arrangedSubviews: [
            makeButton("Show success") {
                IslandToast.show("Saved from UIKit", style: .success)
            },
            makeButton("Present UIAlertController + toast") { [weak self] in
                self?.presentAlertThenToast()
            },
            makeButton("Present UIKit sheet + toast") { [weak self] in
                self?.presentSheetThenToast()
            },
        ])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func makeButton(_ title: String, action: @escaping () -> Void) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.cornerStyle = .large
        return UIButton(configuration: config, primaryAction: UIAction { _ in action() })
    }

    private func presentAlertThenToast() {
        let alert = UIAlertController(title: "Alert",
                                      message: "The toast should appear above this.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true) {
            IslandToast.show("Visible over UIAlertController", style: .info)
        }
    }

    private func presentSheetThenToast() {
        let sheet = UIViewController()
        sheet.view.backgroundColor = .secondarySystemBackground
        sheet.sheetPresentationController?.detents = [.medium()]
        present(sheet, animated: true) {
            IslandToast.show("Visible over a UIKit sheet", style: .success)
        }
    }
}

struct UIKitToastDemo: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIKitToastDemoViewController { .init() }
    func updateUIViewController(_ uiViewController: UIKitToastDemoViewController, context: Context) {}
}
