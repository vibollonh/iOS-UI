import SwiftUI
import UIKit
import BaseUI

struct BaseButtonDemoView: View {
    @State private var size: BaseButtonSize = .medium
    @State private var isLoading = false
    @State private var isDisabled = false
    @State private var isCapsule = BaseButtonAppearance.shared.cornerRadius == nil

    var body: some View {
        Form {
            Section("Options") {
                Picker("Size", selection: $size) {
                    Text("Small").tag(BaseButtonSize.small)
                    Text("Medium").tag(BaseButtonSize.medium)
                    Text("Large").tag(BaseButtonSize.large)
                }
                .pickerStyle(.segmented)
                Toggle("Loading", isOn: $isLoading)
                Toggle("Disabled", isOn: $isDisabled)
                Toggle("Capsule", isOn: $isCapsule)
            }

            Section("SwiftUI · BaseButtonView") {
                VStack(spacing: 12) {
                    ForEach(BaseButtonVariant.allCases, id: \.self) { variant in
                        BaseButtonView(variant.title, systemImage: variant.icon, variant: variant, size: size,
                                       isLoading: isLoading, isFullWidth: true, appearance: appearance) {
                            IslandToast.show("\(variant.title) tapped", style: .info)
                        }
                    }
                    HStack {
                        BaseButtonView("Cancel", variant: .outline, size: size, isFullWidth: true,
                                       appearance: appearance) {}
                        BaseButtonView("Confirm", size: size, isFullWidth: true, appearance: appearance) {}
                    }
                }
                .disabled(isDisabled)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section("SwiftUI · .buttonStyle(.base())") {
                Button {
                    IslandToast.show("Custom label", style: .success)
                } label: {
                    HStack {
                        Image(systemName: "qrcode")
                        VStack(alignment: .leading) {
                            Text("Scan to pay")
                            Text("Any label works").font(.caption).opacity(0.8)
                        }
                    }
                }
                .buttonStyle(.base(.secondary, size: size, isLoading: isLoading))
                .disabled(isDisabled)
                .listRowBackground(Color.clear)
            }

            Section("UIKit · BaseButton") {
                UIKitButtonsDemo(size: size, isLoading: isLoading, isDisabled: isDisabled, appearance: appearance)
                    .frame(height: 340)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
        .navigationTitle("Base Button")
    }

    private var appearance: BaseButtonAppearance {
        var appearance = BaseButtonAppearance.shared
        appearance.cornerRadius = isCapsule ? nil : 12
        return appearance
    }
}

private extension BaseButtonVariant {
    var title: String {
        switch self {
        case .primary:     return "Primary"
        case .secondary:   return "Secondary"
        case .outline:     return "Outline"
        case .ghost:       return "Ghost"
        case .destructive: return "Destructive"
        }
    }

    var icon: String? {
        switch self {
        case .primary:     return "paperplane.fill"
        case .destructive: return "trash"
        default:           return nil
        }
    }
}

// MARK: - UIKit

final class UIKitButtonsDemoViewController: UIViewController {
    private var buttons: [BaseButton] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        buttons = BaseButtonVariant.allCases.map { variant in
            let button = BaseButton(title: "UIKit \(variant.title)",
                                    icon: variant.icon.flatMap { UIImage(systemName: $0) },
                                    variant: variant) {
                IslandToast.show("UIKit \(variant.title) tapped", style: .info)
            }
            return button
        }
        let stack = UIStackView(arrangedSubviews: buttons)
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    func apply(size: BaseButtonSize, isLoading: Bool, isDisabled: Bool, appearance: BaseButtonAppearance) {
        for button in buttons {
            button.size = size
            button.isLoading = isLoading
            button.isEnabled = !isDisabled
            button.appearance = appearance
        }
    }
}

struct UIKitButtonsDemo: UIViewControllerRepresentable {
    let size: BaseButtonSize
    let isLoading: Bool
    let isDisabled: Bool
    let appearance: BaseButtonAppearance

    func makeUIViewController(context: Context) -> UIKitButtonsDemoViewController { .init() }

    func updateUIViewController(_ controller: UIKitButtonsDemoViewController, context: Context) {
        controller.loadViewIfNeeded()
        controller.apply(size: size, isLoading: isLoading, isDisabled: isDisabled, appearance: appearance)
    }
}

#Preview {
    NavigationStack { BaseButtonDemoView() }
}
