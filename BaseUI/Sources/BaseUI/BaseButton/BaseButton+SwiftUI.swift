#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// SwiftUI base button, matching `BaseButton` in UIKit.
///
///     BaseButtonView("Pay now", systemImage: "creditcard", size: .large, isLoading: isPaying) {
///         pay()
///     }
///
/// Need a custom label? Apply the style to any `Button`:
///
///     Button { ... } label: { MyLabel() }
///         .buttonStyle(.base(.outline, isFullWidth: true))
public struct BaseButtonView: View {
    private let title: String
    private let systemImage: String?
    private let style: BaseButtonStyle
    private let action: () -> Void

    public init(_ title: String,
                systemImage: String? = nil,
                variant: BaseButtonVariant = .primary,
                size: BaseButtonSize = .medium,
                isLoading: Bool = false,
                isFullWidth: Bool = false,
                appearance: BaseButtonAppearance = .shared,
                action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.style = BaseButtonStyle(variant: variant, size: size, isLoading: isLoading,
                                     isFullWidth: isFullWidth, appearance: appearance)
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .buttonStyle(style)
    }
}

public struct BaseButtonStyle: ButtonStyle {
    public var variant: BaseButtonVariant
    public var size: BaseButtonSize
    public var isLoading: Bool
    public var isFullWidth: Bool
    public var appearance: BaseButtonAppearance

    public init(variant: BaseButtonVariant = .primary,
                size: BaseButtonSize = .medium,
                isLoading: Bool = false,
                isFullWidth: Bool = false,
                appearance: BaseButtonAppearance = .shared) {
        self.variant = variant
        self.size = size
        self.isLoading = isLoading
        self.isFullWidth = isFullWidth
        self.appearance = appearance
    }

    public func makeBody(configuration: Configuration) -> some View {
        BaseButtonBody(configuration: configuration, style: self)
    }
}

public extension ButtonStyle where Self == BaseButtonStyle {
    static func base(_ variant: BaseButtonVariant = .primary,
                     size: BaseButtonSize = .medium,
                     isLoading: Bool = false,
                     isFullWidth: Bool = false) -> BaseButtonStyle {
        BaseButtonStyle(variant: variant, size: size, isLoading: isLoading, isFullWidth: isFullWidth)
    }
}

/// Separate view so `@Environment(\.isEnabled)` reflects `.disabled(_:)`.
private struct BaseButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let style: BaseButtonStyle

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let appearance = style.appearance
        let colors = appearance.colors(for: style.variant)
        let shape = BaseButtonShape(cornerRadius: appearance.cornerRadius)

        HStack(spacing: appearance.iconSpacing) {
            if style.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(uiColor: colors.foreground)))
            }
            configuration.label
                .lineLimit(1)
        }
        .font(Font(appearance.font(for: style.size) as CTFont))
        .foregroundColor(Color(uiColor: colors.foreground))
        .padding(.horizontal, style.size.horizontalPadding)
        .padding(.vertical, 8)
        .frame(maxWidth: style.isFullWidth ? .infinity : nil, minHeight: style.size.height)
        .background(shape.fill(Color(uiColor: colors.background)))
        .overlay {
            if let border = colors.border {
                shape.strokeBorder(Color(uiColor: border), lineWidth: appearance.borderWidth)
            }
        }
        .contentShape(shape)
        .opacity(appearance.opacity(isEnabled: isEnabled, isPressed: configuration.isPressed))
        .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
        .allowsHitTesting(!style.isLoading)
        .accessibilityValue(style.isLoading ? Text("Loading") : Text(""))
    }
}

/// Rounded rect whose radius is capped at half the height; `nil` radius gives a capsule.
struct BaseButtonShape: InsettableShape {
    var cornerRadius: CGFloat?
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let inset = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let radius = min((cornerRadius ?? .greatestFiniteMagnitude) - insetAmount, inset.height / 2)
        return Path(roundedRect: inset, cornerRadius: max(0, radius), style: .continuous)
    }

    func inset(by amount: CGFloat) -> BaseButtonShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}
#endif
