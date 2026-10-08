import EasyAnchor
import SwiftUI
import UIKit
import BaseUI

struct BaseTextFieldDemoView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var phone = ""
    @State private var note = "Read only"
    @State private var showErrors = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("SwiftUI · BaseTextFieldView").font(.headline)

                BaseTextFieldView("Email", placeholder: "you@example.com", text: $email,
                                  helperText: "We'll send a receipt here",
                                  errorMessage: emailError,
                                  systemImage: "envelope")
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                BaseTextFieldView("Password", placeholder: "At least 8 characters", text: $password,
                                  errorMessage: passwordError,
                                  systemImage: "lock", isSecure: true)
                    .textContentType(.password)

                BaseTextFieldView("Phone", placeholder: "012 345 678", text: $phone,
                                  helperText: "\(phone.count)/10 · maxLength", systemImage: "phone",
                                  maxLength: 10)
                    .keyboardType(.phonePad)

                BaseTextFieldView("Disabled", text: $note)
                    .disabled(true)

                BaseButtonView("Validate", isFullWidth: true) { showErrors = true }

                Divider()

                Text("UIKit · BaseTextField").font(.headline)
                UIKitTextFieldsDemo()
                    .frame(height: 280)
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Base Text Field")
    }

    private var emailError: String? {
        guard showErrors, !email.contains("@") else { return nil }
        return "Enter a valid email"
    }

    private var passwordError: String? {
        guard showErrors, password.count < 8 else { return nil }
        return "Password must be at least 8 characters"
    }
}

// MARK: - UIKit

final class UIKitTextFieldsDemoViewController: UIViewController {
  
  private var normalTextView = BaseTextField().config {
    $0.leadingIcon = UIImage(systemName: "person")
    $0.placeholder = "Normal Text"
  }

    override func viewDidLoad() {
        super.viewDidLoad()
        let name = BaseTextField(title: "Full name",
                                 placeholder: "Sokha Chan",
                                 helperText: "As shown on your ID",
                                 leadingIcon: UIImage(systemName: "person"))
        name.textField.textContentType = .name
        name.textField.returnKeyType = .next

        let pin = BaseTextField(title: "PIN", placeholder: "4 digits",
                                leadingIcon: UIImage(systemName: "key"), isSecure: true)
        pin.textField.keyboardType = .numberPad
        pin.maxLength = 4
        pin.onTextChange = { [weak pin] text in
            pin?.errorMessage = text.isEmpty || text.count == 4 ? nil : "PIN must be 4 digits"
        }

        name.onReturn = { [weak pin] in pin?.becomeFirstResponder() }

        let stack = UIStackView(arrangedSubviews: [normalTextView ,name, pin])
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

struct UIKitTextFieldsDemo: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIKitTextFieldsDemoViewController { .init() }
    func updateUIViewController(_ uiViewController: UIKitTextFieldsDemoViewController, context: Context) {}
}

#Preview {
    NavigationStack { BaseTextFieldDemoView() }
}
