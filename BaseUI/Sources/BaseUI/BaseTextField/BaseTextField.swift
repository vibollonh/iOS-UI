#if canImport(UIKit)
import UIKit

/// UIKit base text field: title, bordered input box, optional icon, password toggle and a
/// helper / error message. For SwiftUI use `BaseTextFieldView`.
///
///     let email = BaseTextField(title: "Email", placeholder: "you@example.com",
///                               leadingIcon: UIImage(systemName: "envelope"))
///     email.textField.keyboardType = .emailAddress
///     email.onTextChange = { [weak self] in self?.validate($0) }
///     email.errorMessage = "Invalid email"   // nil clears the error and shows `helperText`
///
/// Keyboard, content type, delegate etc. are configured on the underlying `textField`.
open class BaseTextField: UIView {

    /// The real input. Configure keyboard / content type / delegate here.
    public let textField = UITextField()

    public var title: String? {
        didSet { updateTexts() }
    }

    public var placeholder: String? {
        didSet { updatePlaceholder() }
    }

    public var text: String {
        get { textField.text ?? "" }
        set { textField.text = BaseTextFieldLimit.apply(maxLength, to: newValue) }
    }

    /// Shown under the box when there is no error.
    public var helperText: String? {
        didSet { updateTexts() }
    }

    /// Non-nil puts the field in the error state and replaces `helperText`.
    public var errorMessage: String? {
        didSet {
            updateTexts()
            updateBorder()
            if let errorMessage, errorMessage != oldValue {
                UIAccessibility.post(notification: .announcement, argument: errorMessage)
            }
        }
    }

    public var leadingIcon: UIImage? {
        didSet {
            iconView.image = leadingIcon
            iconView.isHidden = leadingIcon == nil
        }
    }

    /// Hides the text and adds a show / hide button.
    public var isSecure = false {
        didSet {
            isRevealed = false
            secureToggle.isHidden = !isSecure
            updateSecureEntry()
        }
    }

    /// Max characters; extra input is cut off once composition (e.g. Khmer / Korean IME) ends.
    public var maxLength: Int? {
        didSet { text = text }
    }

    public var isEnabled = true {
        didSet {
            textField.isEnabled = isEnabled
            secureToggle.isEnabled = isEnabled
            alpha = isEnabled ? 1 : appearance.disabledOpacity
        }
    }

    public var onTextChange: ((String) -> Void)?
    /// Called on the return key, after the keyboard is dismissed. Focus the next field here if needed.
    public var onReturn: (() -> Void)?

    /// Defaults to `BaseTextFieldAppearance.shared` at creation time.
    public var appearance: BaseTextFieldAppearance = .shared {
        didSet { applyAppearance() }
    }

    public private(set) var isEditing = false {
        didSet { updateBorder() }
    }

    private let stack = UIStackView()
    private let titleLabel = UILabel()
    private let box = UIView()
    private let boxStack = UIStackView()
    private let iconView = UIImageView()
    private let secureToggle = UIButton(type: .system)
    private let messageLabel = UILabel()
    private var boxHeight: NSLayoutConstraint!
    private var isRevealed = false

    public init(title: String? = nil,
                placeholder: String? = nil,
                helperText: String? = nil,
                leadingIcon: UIImage? = nil,
                isSecure: Bool = false) {
        super.init(frame: .zero)
        setUp()
        self.title = title
        self.placeholder = placeholder
        self.helperText = helperText
        self.leadingIcon = leadingIcon
        self.isSecure = isSecure
        refreshAll()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
        refreshAll()
    }

    @discardableResult
    open override func becomeFirstResponder() -> Bool { textField.becomeFirstResponder() }

    @discardableResult
    open override func resignFirstResponder() -> Bool { textField.resignFirstResponder() }

    open override var isFirstResponder: Bool { textField.isFirstResponder }

    // MARK: Setup

    private func setUp() {
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        titleLabel.numberOfLines = 0
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.isAccessibilityElement = false   // read via the text field's label

        messageLabel.numberOfLines = 0
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.isAccessibilityElement = false // read via the text field's hint

        box.layer.cornerCurve = .continuous
        box.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(boxTapped)))

        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)

        textField.borderStyle = .none
        textField.clearButtonMode = .whileEditing
        textField.adjustsFontForContentSizeCategory = true
        textField.addTarget(self, action: #selector(editingChanged), for: .editingChanged)
        textField.addTarget(self, action: #selector(editingDidBegin), for: .editingDidBegin)
        textField.addTarget(self, action: #selector(editingDidEnd), for: .editingDidEnd)
        textField.addTarget(self, action: #selector(returnTapped), for: .editingDidEndOnExit)

        secureToggle.setContentHuggingPriority(.required, for: .horizontal)
        secureToggle.setContentCompressionResistancePriority(.required, for: .horizontal)
        secureToggle.addAction(UIAction { [weak self] _ in self?.toggleReveal() }, for: .touchUpInside)

        boxStack.axis = .horizontal
        boxStack.alignment = .center
        boxStack.translatesAutoresizingMaskIntoConstraints = false
        boxStack.addArrangedSubview(iconView)
        boxStack.addArrangedSubview(textField)
        boxStack.addArrangedSubview(secureToggle)
        box.addSubview(boxStack)

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(box)
        stack.addArrangedSubview(messageLabel)

        boxHeight = box.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            boxHeight,
            boxStack.topAnchor.constraint(equalTo: box.topAnchor, constant: 8),
            boxStack.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -8),
            boxStack.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            boxStack.trailingAnchor.constraint(equalTo: box.trailingAnchor),
        ])
    }

    private func refreshAll() {
        applyAppearance()
        iconView.image = leadingIcon
        iconView.isHidden = leadingIcon == nil
        secureToggle.isHidden = !isSecure
        updateSecureEntry()
    }

    private func applyAppearance() {
        stack.spacing = appearance.spacing
        titleLabel.font = appearance.scaledTitleFont
        titleLabel.textColor = appearance.titleColor
        messageLabel.font = appearance.scaledMessageFont
        textField.font = appearance.inputFont
        textField.textColor = appearance.textColor
        textField.tintColor = appearance.focusedBorderColor
        iconView.tintColor = appearance.iconColor
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(font: appearance.inputFont)
        secureToggle.tintColor = appearance.iconColor
        box.backgroundColor = appearance.backgroundColor
        box.layer.cornerRadius = appearance.cornerRadius
        boxStack.spacing = appearance.iconSpacing
        boxStack.isLayoutMarginsRelativeArrangement = true
        boxStack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: appearance.horizontalPadding,
                                                                    bottom: 0, trailing: appearance.horizontalPadding)
        boxHeight.constant = UIFontMetrics(forTextStyle: .body).scaledValue(for: appearance.height)
        alpha = isEnabled ? 1 : appearance.disabledOpacity
        updatePlaceholder()
        updateTexts()
        updateBorder()
    }

    // MARK: State

    private func updateTexts() {
        titleLabel.text = title
        titleLabel.isHidden = title?.isEmpty ?? true
        textField.accessibilityLabel = title ?? placeholder

        let message = errorMessage ?? helperText
        messageLabel.text = message
        messageLabel.textColor = appearance.messageColor(hasError: errorMessage != nil)
        messageLabel.isHidden = message?.isEmpty ?? true
        textField.accessibilityHint = message
    }

    private func updatePlaceholder() {
        textField.attributedPlaceholder = placeholder.map {
            NSAttributedString(string: $0, attributes: [.foregroundColor: appearance.placeholderColor,
                                                        .font: appearance.inputFont])
        }
        textField.accessibilityLabel = title ?? placeholder
    }

    private func updateBorder() {
        let border = appearance.border(isFocused: isEditing, hasError: errorMessage != nil)
        UIView.animate(withDuration: 0.15) {
            self.box.layer.borderColor = border.color.resolvedColor(with: self.traitCollection).cgColor
            self.box.layer.borderWidth = border.width
        }
    }

    private func updateSecureEntry() {
        textField.isSecureTextEntry = isSecure && !isRevealed
        let symbol = isRevealed ? "eye.slash" : "eye"
        secureToggle.setImage(UIImage(systemName: symbol), for: .normal)
        secureToggle.accessibilityLabel = isRevealed ? "Hide password" : "Show password"
    }

    private func toggleReveal() {
        isRevealed.toggle()
        // Re-set the text so toggling secure entry doesn't wipe it on the next keystroke.
        let current = textField.text
        updateSecureEntry()
        textField.text = nil
        textField.text = current
    }

    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // CGColor borders don't follow light / dark automatically.
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateBorder()
        }
    }

    // MARK: Events

    @objc private func boxTapped() { textField.becomeFirstResponder() }

    @objc private func editingChanged() {
        // Wait until IME composition ends, otherwise cutting the text breaks the input.
        if textField.markedTextRange == nil, let maxLength, (textField.text ?? "").count > maxLength {
            textField.text = BaseTextFieldLimit.apply(maxLength, to: textField.text ?? "")
        }
        onTextChange?(text)
    }

    @objc private func editingDidBegin() { isEditing = true }

    @objc private func editingDidEnd() { isEditing = false }

    @objc private func returnTapped() { onReturn?() }
}
#endif
