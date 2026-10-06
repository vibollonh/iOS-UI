#if canImport(UIKit)
import UIKit

/// Visual role of a button. Shared by `BaseButton` (UIKit) and `BaseButtonView` / `.buttonStyle(.base())` (SwiftUI).
public enum BaseButtonVariant: CaseIterable {
    /// Filled with the tint color.
    case primary
    /// Tinted background, tint-colored text.
    case secondary
    /// Clear background with a tint-colored border.
    case outline
    /// Text only.
    case ghost
    /// Filled with the destructive color.
    case destructive
}

public enum BaseButtonSize: CaseIterable {
    case small, medium, large

    /// Minimum height; grows with Dynamic Type.
    public var height: CGFloat {
        switch self {
        case .small:  return 36
        case .medium: return 44
        case .large:  return 52
        }
    }

    public var fontSize: CGFloat {
        switch self {
        case .small:  return 14
        case .medium: return 16
        case .large:  return 17
        }
    }

    public var horizontalPadding: CGFloat {
        switch self {
        case .small:  return 12
        case .medium: return 16
        case .large:  return 20
        }
    }
}

/// Global look of every base button. Set once at launch:
///
///     BaseButtonAppearance.shared.tintColor = UIColor(named: "Brand")!
///     BaseButtonAppearance.shared.font = UIFont(name: "KantumruyPro-SemiBold", size: 16)!
///
/// Each button can also take its own copy via its `appearance` property / parameter.
public struct BaseButtonAppearance {

    public static var shared = BaseButtonAppearance()

    /// Family and weight of the title. The point size comes from `BaseButtonSize.fontSize`.
    public var font: UIFont = .systemFont(ofSize: 16, weight: .semibold)
    public var tintColor: UIColor = .systemBlue
    /// Text / icon color on filled (`primary`, `destructive`) buttons.
    public var onTintColor: UIColor = .white
    public var destructiveColor: UIColor = .systemRed
    /// Alpha of the tint behind `secondary` buttons.
    public var secondaryBackgroundAlpha: CGFloat = 0.12
    /// `nil` makes a capsule.
    public var cornerRadius: CGFloat? = 12
    public var borderWidth: CGFloat = 1.5
    public var iconSpacing: CGFloat = 8
    public var pressedOpacity: CGFloat = 0.7
    public var disabledOpacity: CGFloat = 0.4
    /// Scale the title with Dynamic Type (relative to `.body`).
    public var scalesWithDynamicType: Bool = true

    public init() {}

    /// Title font for a given size, scaled for Dynamic Type when enabled.
    public func font(for size: BaseButtonSize) -> UIFont {
        let base = font.withSize(size.fontSize)
        return scalesWithDynamicType ? UIFontMetrics(forTextStyle: .body).scaledFont(for: base) : base
    }

    func colors(for variant: BaseButtonVariant) -> BaseButtonColors {
        switch variant {
        case .primary:
            return .init(background: tintColor, foreground: onTintColor, border: nil)
        case .secondary:
            return .init(background: tintColor.withAlphaComponent(secondaryBackgroundAlpha),
                         foreground: tintColor, border: nil)
        case .outline:
            return .init(background: .clear, foreground: tintColor, border: tintColor)
        case .ghost:
            return .init(background: .clear, foreground: tintColor, border: nil)
        case .destructive:
            return .init(background: destructiveColor, foreground: onTintColor, border: nil)
        }
    }

    func opacity(isEnabled: Bool, isPressed: Bool) -> CGFloat {
        if !isEnabled { return disabledOpacity }
        return isPressed ? pressedOpacity : 1
    }
}

struct BaseButtonColors: Equatable {
    let background: UIColor
    let foreground: UIColor
    let border: UIColor?
}
#endif
