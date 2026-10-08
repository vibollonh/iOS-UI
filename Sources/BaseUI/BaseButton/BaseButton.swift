#if canImport(UIKit)
import UIKit

/// UIKit base button. For SwiftUI use `BaseButtonView` or `.buttonStyle(.base())`.
///
///     let pay = BaseButton(title: "Pay now", variant: .primary, size: .large) { [weak self] in
///         self?.pay()
///     }
///     pay.isLoading = true
///
/// Pressed and disabled states are handled automatically. While `isLoading` is true the button
/// shows a spinner and ignores taps.
open class BaseButton: UIButton {

    public var variant: BaseButtonVariant = .primary {
        didSet { setNeedsUpdateConfiguration() }
    }

    public var size: BaseButtonSize = .medium {
        didSet {
            setNeedsUpdateConfiguration()
            invalidateIntrinsicContentSize()
        }
    }

    public var title: String? {
        didSet { setNeedsUpdateConfiguration() }
    }

    public var icon: UIImage? {
        didSet { setNeedsUpdateConfiguration() }
    }

    /// `.leading` or `.trailing`.
    public var iconPlacement: NSDirectionalRectEdge = .leading {
        didSet { setNeedsUpdateConfiguration() }
    }

    public var isLoading = false {
        didSet {
            guard isLoading != oldValue else { return }
            isUserInteractionEnabled = !isLoading
            accessibilityValue = isLoading ? "Loading" : nil
            setNeedsUpdateConfiguration()
        }
    }

    /// Defaults to `BaseButtonAppearance.shared` at creation time.
    public var appearance: BaseButtonAppearance = .shared {
        didSet { setNeedsUpdateConfiguration() }
    }

    public init(title: String? = nil,
                icon: UIImage? = nil,
                variant: BaseButtonVariant = .primary,
                size: BaseButtonSize = .medium,
                action: (() -> Void)? = nil) {
        self.title = title
        self.icon = icon
        self.variant = variant
        self.size = size
        super.init(frame: .zero)
        commonInit()
        if let action {
            addAction(UIAction { _ in action() }, for: .primaryActionTriggered)
        }
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        configuration = .plain()
        setNeedsUpdateConfiguration()
    }

    open override var intrinsicContentSize: CGSize {
        var size = super.intrinsicContentSize
        size.height = max(size.height, self.size.height)
        return size
    }

    open override func updateConfiguration() {
        let colors = appearance.colors(for: variant)
        var config = UIButton.Configuration.plain()

        var background = UIBackgroundConfiguration.clear()
        background.backgroundColor = colors.background
        background.strokeColor = colors.border
        background.strokeWidth = colors.border == nil ? 0 : appearance.borderWidth
        if let radius = appearance.cornerRadius {
            background.cornerRadius = radius
            config.cornerStyle = .fixed
        } else {
            config.cornerStyle = .capsule
        }
        config.background = background

        let font = appearance.font(for: size)
        config.baseForegroundColor = colors.foreground
        if let title {
            config.attributedTitle = AttributedString(title, attributes: AttributeContainer([.font: font]))
        }
        config.titleLineBreakMode = .byTruncatingTail
        config.image = icon
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(font: font, scale: .medium)
        config.imagePlacement = iconPlacement
        config.imagePadding = appearance.iconSpacing
        config.showsActivityIndicator = isLoading
        config.activityIndicatorColorTransformer = UIConfigurationColorTransformer { _ in colors.foreground }
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: size.horizontalPadding,
                                                       bottom: 8, trailing: size.horizontalPadding)
        configuration = config

        alpha = appearance.opacity(isEnabled: isEnabled, isPressed: isHighlighted)
    }
}
#endif
