import Foundation

/// One choice in a `BaseDropdownField` (UIKit) or `BaseDropdownFieldView` (SwiftUI).
///
///     let banks = [
///         BaseDropdownOption(value: Bank.aba, title: "ABA Bank", systemImage: "building.columns"),
///         BaseDropdownOption(value: Bank.acleda, title: "ACLEDA", subtitle: "Savings"),
///     ]
///     let cities: [BaseDropdownOption<String>] = ["Phnom Penh", "Siem Reap"].map(BaseDropdownOption.init)
public struct BaseDropdownOption<Value: Hashable>: Hashable {
    public var value: Value
    public var title: String
    public var subtitle: String?
    /// SF Symbol shown next to the title in the menu and in the field.
    public var systemImage: String?

    public init(value: Value, title: String, subtitle: String? = nil, systemImage: String? = nil) {
        self.value = value
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }
}

public extension BaseDropdownOption where Value == String {
    /// Uses the title as the value.
    init(_ title: String) {
        self.init(value: title, title: title)
    }
}

extension Array {
    func option<Value>(for value: Value?) -> Element? where Element == BaseDropdownOption<Value> {
        guard let value else { return nil }
        return first { $0.value == value }
    }
}
