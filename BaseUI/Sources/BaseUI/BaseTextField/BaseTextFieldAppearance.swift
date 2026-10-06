#if canImport(UIKit)
import UIKit

/// Global look of every base text field (`BaseTextField` in UIKit, `BaseTextFieldView` in SwiftUI).
///
///     BaseTextFieldAppearance.shared.focusedBorderColor = UIColor(named: "Brand")!
///     BaseTextFieldAppearance.shared.font = UIFont(name: "KantumruyPro-Regular", size: 16)!
public struct BaseTextFieldAppearance {

    public static var shared = BaseTextFieldAppearance()

    public var font: UIFont = .systemFont(ofSize: 16)
    public var titleFont: UIFont = .systemFont(ofSize: 14, weight: .medium)
    public var messageFont: UIFont = .systemFont(ofSize: 12)
    /// Scale fonts with Dynamic Type.
    public var scalesWithDynamicType: Bool = true

    public var textColor: UIColor = .label
    public var placeholderColor: UIColor = .placeholderText
    public var titleColor: UIColor = .label
    public var helperColor: UIColor = .secondaryLabel
    public var iconColor: UIColor = .secondaryLabel
    public var backgroundColor: UIColor = .secondarySystemBackground

    public var borderColor: UIColor = .systemGray4
    public var focusedBorderColor: UIColor = .systemBlue
    public var errorColor: UIColor = .systemRed
    public var borderWidth: CGFloat = 1
    public var focusedBorderWidth: CGFloat = 1.5

    public var cornerRadius: CGFloat = 12
    /// Minimum height of the input box; grows with Dynamic Type.
    public var height: CGFloat = 50
    public var horizontalPadding: CGFloat = 14
    /// Gap between icon, text and the trailing button.
    public var iconSpacing: CGFloat = 10
    /// Gap between title, input box and message.
    public var spacing: CGFloat = 6
    public var disabledOpacity: CGFloat = 0.5

    public init() {}

    func scaled(_ font: UIFont, _ style: UIFont.TextStyle) -> UIFont {
        scalesWithDynamicType ? UIFontMetrics(forTextStyle: style).scaledFont(for: font) : font
    }

    var inputFont: UIFont { scaled(font, .body) }
    var scaledTitleFont: UIFont { scaled(titleFont, .subheadline) }
    var scaledMessageFont: UIFont { scaled(messageFont, .caption1) }

    func border(isFocused: Bool, hasError: Bool) -> (color: UIColor, width: CGFloat) {
        if hasError { return (errorColor, isFocused ? focusedBorderWidth : borderWidth) }
        if isFocused { return (focusedBorderColor, focusedBorderWidth) }
        return (borderColor, borderWidth)
    }

    func messageColor(hasError: Bool) -> UIColor {
        hasError ? errorColor : helperColor
    }
}

enum BaseTextFieldLimit {
    /// Cuts `text` to `maxLength` characters (grapheme clusters, so Khmer / emoji stay intact).
    static func apply(_ maxLength: Int?, to text: String) -> String {
        guard let maxLength, text.count > maxLength else { return text }
        return String(text.prefix(max(0, maxLength)))
    }
}
#endif
