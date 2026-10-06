#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// SwiftUI base text field, matching `BaseTextField` in UIKit.
///
///     BaseTextFieldView("Email", placeholder: "you@example.com", text: $email,
///                       errorMessage: isValid ? nil : "Invalid email",
///                       systemImage: "envelope")
///         .keyboardType(.emailAddress)
///         .textContentType(.emailAddress)
///
/// Standard modifiers (`.keyboardType`, `.textContentType`, `.submitLabel`, `.onSubmit`,
/// `.disabled`, `.focused`) pass through to the inner field.
public struct BaseTextFieldView: View {
    private let title: String?
    private let placeholder: String
    @Binding private var text: String
    private let helperText: String?
    private let errorMessage: String?
    private let systemImage: String?
    private let isSecure: Bool
    private let maxLength: Int?
    private let appearance: BaseTextFieldAppearance

    @FocusState private var isFocused: Bool
    @State private var isRevealed = false
    @Environment(\.isEnabled) private var isEnabled

    public init(_ title: String? = nil,
                placeholder: String = "",
                text: Binding<String>,
                helperText: String? = nil,
                errorMessage: String? = nil,
                systemImage: String? = nil,
                isSecure: Bool = false,
                maxLength: Int? = nil,
                appearance: BaseTextFieldAppearance = .shared) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.helperText = helperText
        self.errorMessage = errorMessage
        self.systemImage = systemImage
        self.isSecure = isSecure
        self.maxLength = maxLength
        self.appearance = appearance
    }

    public var body: some View {
        let border = appearance.border(isFocused: isFocused, hasError: errorMessage != nil)
        let shape = RoundedRectangle(cornerRadius: appearance.cornerRadius, style: .continuous)
        let message = errorMessage ?? helperText

        VStack(alignment: .leading, spacing: appearance.spacing) {
            if let title, !title.isEmpty {
                Text(title)
                    .font(Font(appearance.scaledTitleFont as CTFont))
                    .foregroundColor(Color(uiColor: appearance.titleColor))
                    .accessibilityHidden(true)
            }

            HStack(spacing: appearance.iconSpacing) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundColor(Color(uiColor: appearance.iconColor))
                        .accessibilityHidden(true)
                }

                field
                    .font(Font(appearance.inputFont as CTFont))
                    .foregroundColor(Color(uiColor: appearance.textColor))
                    .tint(Color(uiColor: appearance.focusedBorderColor))
                    .focused($isFocused)
                    .accessibilityLabel(title ?? placeholder)
                    .accessibilityHint(message ?? "")

                if isSecure {
                    Button {
                        isRevealed.toggle()
                    } label: {
                        Image(systemName: isRevealed ? "eye.slash" : "eye")
                            .foregroundColor(Color(uiColor: appearance.iconColor))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isRevealed ? "Hide password" : "Show password")
                }
            }
            .padding(.horizontal, appearance.horizontalPadding)
            .padding(.vertical, 8)
            .frame(minHeight: appearance.height)
            .background(shape.fill(Color(uiColor: appearance.backgroundColor)))
            .overlay(shape.strokeBorder(Color(uiColor: border.color), lineWidth: border.width))
            .contentShape(shape)
            .onTapGesture { isFocused = true }
            .animation(.easeOut(duration: 0.15), value: isFocused)

            if let message, !message.isEmpty {
                Text(message)
                    .font(Font(appearance.scaledMessageFont as CTFont))
                    .foregroundColor(Color(uiColor: appearance.messageColor(hasError: errorMessage != nil)))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
            }
        }
        .opacity(isEnabled ? 1 : appearance.disabledOpacity)
        .animation(.easeOut(duration: 0.15), value: errorMessage)
        .onChange(of: text) { newValue in
            let limited = BaseTextFieldLimit.apply(maxLength, to: newValue)
            if limited != newValue { text = limited }
        }
        .onChange(of: errorMessage) { newValue in
            if let newValue { UIAccessibility.post(notification: .announcement, argument: newValue) }
        }
    }

    @ViewBuilder
    private var field: some View {
        let prompt = Text(placeholder).foregroundColor(Color(uiColor: appearance.placeholderColor))
        if isSecure && !isRevealed {
            SecureField("", text: $text, prompt: prompt)
        } else {
            TextField("", text: $text, prompt: prompt)
        }
    }
}
#endif
