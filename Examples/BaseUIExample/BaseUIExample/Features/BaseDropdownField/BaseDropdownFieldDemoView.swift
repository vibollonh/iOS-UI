import SwiftUI
import UIKit
import BaseUI

enum DemoBank: String, CaseIterable, Hashable {
    case aba, acleda, wing

    var option: BaseDropdownOption<DemoBank> {
        switch self {
        case .aba:    return .init(value: self, title: "ABA Bank", subtitle: "Savings · 001 234 567", systemImage: "building.columns")
        case .acleda: return .init(value: self, title: "ACLEDA Bank", subtitle: "Current · 002 345 678", systemImage: "banknote")
        case .wing:   return .init(value: self, title: "Wing", subtitle: "Wallet · 012 345 678", systemImage: "wallet.pass")
        }
    }
}

struct BaseDropdownFieldDemoView: View {
    @State private var bank: DemoBank?
    @State private var province: String?
    @State private var currency: String? = "USD"
    @State private var showErrors = false

    private let provinces = ["Phnom Penh", "Siem Reap", "Battambang", "Kampot", "Kep", "Kampong Cham",
                             "Preah Sihanouk", "Takeo", "Kandal", "Koh Kong"].map(BaseDropdownOption.init)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("SwiftUI · BaseDropdownFieldView").font(.headline)

                BaseDropdownFieldView("From account", placeholder: "Select account", selection: $bank,
                                      options: DemoBank.allCases.map(\.option),
                                      helperText: "Option icon replaces the field icon",
                                      errorMessage: showErrors && bank == nil ? "Choose an account" : nil,
                                      systemImage: "creditcard")

                BaseDropdownFieldView("Province", placeholder: "Select province", selection: $province,
                                      options: provinces,
                                      errorMessage: showErrors && province == nil ? "Required" : nil,
                                      systemImage: "mappin.and.ellipse")

                BaseDropdownFieldView("Currency (disabled)", selection: $currency,
                                      options: ["USD", "KHR"].map(BaseDropdownOption.init))
                    .disabled(true)

                BaseTextFieldView("Amount", placeholder: "0.00", text: .constant(""), systemImage: "dollarsign")

                BaseButtonView("Continue", isFullWidth: true) { showErrors = true }

                Divider()

                Text("UIKit · BaseDropdownField").font(.headline)
                UIKitDropdownDemo()
                    .frame(height: 200)
            }
            .padding()
        }
        .navigationTitle("Dropdown Field")
    }
}

// MARK: - UIKit

final class UIKitDropdownDemoViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let bank = BaseDropdownField<DemoBank>(title: "To account", placeholder: "Select account",
                                               options: DemoBank.allCases.map(\.option),
                                               leadingIcon: UIImage(systemName: "creditcard"))
        bank.onSelect = { option in
            IslandToast.show("Selected \(option.title)", style: .info)
        }

        let purpose = BaseDropdownField<String>(title: "Purpose", placeholder: "Select purpose",
                                                options: ["Family", "Rent", "Business", "Other"].map(BaseDropdownOption.init),
                                                helperText: "Picking \"Other\" shows an error")
        purpose.onSelect = { [weak purpose] option in
            purpose?.errorMessage = option.value == "Other" ? "Please describe the purpose" : nil
        }

        let stack = UIStackView(arrangedSubviews: [bank, purpose])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }
}

struct UIKitDropdownDemo: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIKitDropdownDemoViewController { .init() }
    func updateUIViewController(_ uiViewController: UIKitDropdownDemoViewController, context: Context) {}
}

#Preview {
    NavigationStack { BaseDropdownFieldDemoView() }
}
