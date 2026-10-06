#if canImport(UIKit)
import UIKit
import EasyAnchor

/// UIKit dropdown that looks like `BaseTextField` and opens a native menu.
/// For SwiftUI use `BaseDropdownFieldView`.
///
///     let account = BaseDropdownField<String>(title: "Account", placeholder: "Select account")
///     account.options = ["Savings", "Current"].map(BaseDropdownOption.init)
///     account.onSelect = { [weak self] option in self?.didPick(option.value) }
///     account.selectedValue = "Savings"
///     account.errorMessage = "Required"   // nil clears it
///
/// Styled by `BaseTextFieldAppearance`, so it matches the text fields around it.
open class BaseDropdownField<Value: Hashable>: UIView {

    public var options: [BaseDropdownOption<Value>] = [] {
        didSet {
            if options.option(for: selectedValue) == nil { selectedValue = nil }
            updateValue()
        }
    }

    /// The selected option's value. Must match one of `options`, otherwise it is ignored.
    public var selectedValue: Value? {
        didSet {
            if selectedValue != nil, options.option(for: selectedValue) == nil { selectedValue = oldValue }
            updateValue()
        }
    }

    public var selectedOption: BaseDropdownOption<Value>? { options.option(for: selectedValue) }

    /// Called when the user picks an option (not when `selectedValue` is set in code).
    public var onSelect: ((BaseDropdownOption<Value>) -> Void)?

    public var title: String? {
        didSet { updateTexts() }
    }

    /// Shown in the box while nothing is selected.
    public var placeholder: String? {
        didSet { updateValue() }
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

    /// Shown when the selected option has no `systemImage`.
    public var leadingIcon: UIImage? {
        didSet { updateValue() }
    }

    public var isEnabled = true {
        didSet {
            button.isEnabled = isEnabled
            alpha = isEnabled ? 1 : appearance.disabledOpacity
        }
    }

    /// Defaults to `BaseTextFieldAppearance.shared` at creation time.
    public var appearance: BaseTextFieldAppearance = .shared {
        didSet { applyAppearance() }
    }

    private let stack = UIStackView()
    private let titleLabel = UILabel()
    private let box = UIView()
    private let boxStack = UIStackView()
    private let iconView = UIImageView()
    private let valueLabel = UILabel()
    private let chevronView = UIImageView(image: UIImage(systemName: "chevron.up.chevron.down"))
    private let messageLabel = UILabel()
    private let button = UIButton(type: .custom)
    private var boxHeight: NSLayoutConstraint!

    public init(title: String? = nil,
                placeholder: String? = nil,
                options: [BaseDropdownOption<Value>] = [],
                helperText: String? = nil,
                leadingIcon: UIImage? = nil) {
        super.init(frame: .zero)
        setUp()
        self.title = title
        self.placeholder = placeholder
        self.options = options
        self.helperText = helperText
        self.leadingIcon = leadingIcon
        applyAppearance()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
        applyAppearance()
    }

    // MARK: Setup

    private func setUp() {
        titleLabel.numberOfLines = 0
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.isAccessibilityElement = false   // read via the button's label

        messageLabel.numberOfLines = 0
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.isAccessibilityElement = false // read via the button's hint

        box.layer.cornerCurve = .continuous

        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)

        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.lineBreakMode = .byTruncatingTail
        valueLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        chevronView.contentMode = .scaleAspectFit
        chevronView.setContentHuggingPriority(.required, for: .horizontal)
        chevronView.setContentCompressionResistancePriority(.required, for: .horizontal)

        button.showsMenuAsPrimaryAction = true
        button.accessibilityTraits.insert(.button)

        boxStack.axis = .horizontal
        boxStack.alignment = .center
        boxStack.isUserInteractionEnabled = false
        boxStack.isLayoutMarginsRelativeArrangement = true
        boxStack.addArrangedSubview(iconView)
        boxStack.addArrangedSubview(valueLabel)
        boxStack.addArrangedSubview(chevronView)

        stack.axis = .vertical
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(box)
        stack.addArrangedSubview(messageLabel)

        stack.layout {
            addSubview($0)
            $0.fill()
        }
        boxStack.layout {
            box.addSubview($0)
            $0.fill(insets: UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0))
        }
        button.layout {
            box.addSubview($0)
            $0.fill()
        }
        boxHeight = box.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        boxHeight.isActive = true
    }

    private func applyAppearance() {
        stack.spacing = appearance.spacing
        titleLabel.font = appearance.scaledTitleFont
        titleLabel.textColor = appearance.titleColor
        messageLabel.font = appearance.scaledMessageFont
        valueLabel.font = appearance.inputFont
        iconView.tintColor = appearance.iconColor
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(font: appearance.inputFont)
        chevronView.tintColor = appearance.iconColor
        chevronView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(font: appearance.scaledMessageFont)
        box.backgroundColor = appearance.backgroundColor
        box.layer.cornerRadius = appearance.cornerRadius
        boxStack.spacing = appearance.iconSpacing
        boxStack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: appearance.horizontalPadding,
                                                                    bottom: 0, trailing: appearance.horizontalPadding)
        boxHeight.constant = UIFontMetrics(forTextStyle: .body).scaledValue(for: appearance.height)
        alpha = isEnabled ? 1 : appearance.disabledOpacity
        updateTexts()
        updateValue()
        updateBorder()
    }

    // MARK: State

    private func updateTexts() {
        titleLabel.text = title
        titleLabel.isHidden = title?.isEmpty ?? true
        button.accessibilityLabel = title ?? placeholder

        let message = errorMessage ?? helperText
        messageLabel.text = message
        messageLabel.textColor = appearance.messageColor(hasError: errorMessage != nil)
        messageLabel.isHidden = message?.isEmpty ?? true
        button.accessibilityHint = message
    }

    private func updateValue() {
        let selected = selectedOption
        valueLabel.text = selected?.title ?? placeholder
        valueLabel.textColor = selected == nil ? appearance.placeholderColor : appearance.textColor
        button.accessibilityValue = selected?.title

        let icon = selected?.systemImage.flatMap { UIImage(systemName: $0) } ?? leadingIcon
        iconView.image = icon
        iconView.isHidden = icon == nil

        button.menu = makeMenu()
    }

    private func updateBorder() {
        let border = appearance.border(isFocused: false, hasError: errorMessage != nil)
        box.layer.borderColor = border.color.resolvedColor(with: traitCollection).cgColor
        box.layer.borderWidth = border.width
    }

    private func makeMenu() -> UIMenu {
        let actions = options.map { option in
            UIAction(title: option.title,
                     subtitle: option.subtitle,
                     image: option.systemImage.flatMap { UIImage(systemName: $0) },
                     state: option.value == selectedValue ? .on : .off) { [weak self] _ in
                self?.select(option)
            }
        }
        return UIMenu(title: title ?? "", options: .singleSelection, children: actions)
    }

    private func select(_ option: BaseDropdownOption<Value>) {
        selectedValue = option.value
        UISelectionFeedbackGenerator().selectionChanged()
        onSelect?(option)
    }

    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // CGColor borders don't follow light / dark automatically.
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateBorder()
        }
    }
}
#endif
