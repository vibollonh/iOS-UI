#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// SwiftUI dropdown matching `BaseDropdownField` in UIKit; opens a native menu.
///
///     @State private var account: String?
///
///     BaseDropdownFieldView("Account", placeholder: "Select account", selection: $account,
///                           options: ["Savings", "Current"].map(BaseDropdownOption.init),
///                           errorMessage: account == nil ? "Required" : nil)
///
/// Styled by `BaseTextFieldAppearance`, so it matches the text fields around it.
public struct BaseDropdownFieldView<Value: Hashable>: View {
    private let title: String?
    private let placeholder: String
    @Binding private var selection: Value?
    private let options: [BaseDropdownOption<Value>]
    private let helperText: String?
    private let errorMessage: String?
    private let systemImage: String?
    private let appearance: BaseTextFieldAppearance

    @Environment(\.isEnabled) private var isEnabled

    public init(_ title: String? = nil,
                placeholder: String = "",
                selection: Binding<Value?>,
                options: [BaseDropdownOption<Value>],
                helperText: String? = nil,
                errorMessage: String? = nil,
                systemImage: String? = nil,
                appearance: BaseTextFieldAppearance = .shared) {
        self.title = title
        self.placeholder = placeholder
        self._selection = selection
        self.options = options
        self.helperText = helperText
        self.errorMessage = errorMessage
        self.systemImage = systemImage
        self.appearance = appearance
    }

    public var body: some View {
        let selected = options.option(for: selection)
        let border = appearance.border(isFocused: false, hasError: errorMessage != nil)
        let shape = RoundedRectangle(cornerRadius: appearance.cornerRadius, style: .continuous)
        let message = errorMessage ?? helperText

        VStack(alignment: .leading, spacing: appearance.spacing) {
            if let title, !title.isEmpty {
                Text(title)
                    .font(Font(appearance.scaledTitleFont as CTFont))
                    .foregroundColor(Color(uiColor: appearance.titleColor))
                    .accessibilityHidden(true)
            }

            Menu {
                // Toggles show a checkmark *and* keep the subtitle; a Picker drops subtitles.
                Section(title ?? "") {
                    ForEach(options, id: \.value) { option in
                        Toggle(isOn: isSelected(option)) { optionLabel(option) }
                    }
                }
            } label: {
                HStack(spacing: appearance.iconSpacing) {
                    if let icon = selected?.systemImage ?? systemImage {
                        Image(systemName: icon)
                            .foregroundColor(Color(uiColor: appearance.iconColor))
                    }
                    Text(selected?.title ?? placeholder)
                        .font(Font(appearance.inputFont as CTFont))
                        .foregroundColor(Color(uiColor: selected == nil ? appearance.placeholderColor
                                                                        : appearance.textColor))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(Font(appearance.scaledMessageFont as CTFont))
                        .foregroundColor(Color(uiColor: appearance.iconColor))
                }
                .padding(.horizontal, appearance.horizontalPadding)
                .padding(.vertical, 8)
                .frame(minHeight: appearance.height)
                .background(shape.fill(Color(uiColor: appearance.backgroundColor)))
                .overlay(shape.strokeBorder(Color(uiColor: border.color), lineWidth: border.width))
                .contentShape(shape)
            }
            .accessibilityLabel(title ?? placeholder)
            .accessibilityValue(selected?.title ?? "")
            .accessibilityHint(message ?? "")

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
        .onChange(of: errorMessage) { newValue in
            if let newValue { UIAccessibility.post(notification: .announcement, argument: newValue) }
        }
    }

    /// Picking an option selects it; picking the selected one again keeps it.
    private func isSelected(_ option: BaseDropdownOption<Value>) -> Binding<Bool> {
        Binding {
            selection == option.value
        } set: { _ in
            guard selection != option.value else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            selection = option.value
        }
    }

    /// Menus map flat `Text`, `Text`, `Image` children to title, subtitle and icon.
    @ViewBuilder
    private func optionLabel(_ option: BaseDropdownOption<Value>) -> some View {
        Text(option.title)
        if let subtitle = option.subtitle { Text(subtitle) }
        if let icon = option.systemImage { Image(systemName: icon) }
    }
}
#endif
