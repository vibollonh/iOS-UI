#if canImport(UIKit)
import XCTest
@testable import BaseUI

@MainActor
final class BaseDropdownFieldTests: XCTestCase {

    private let cities = ["Phnom Penh", "Siem Reap", "Battambang"].map(BaseDropdownOption.init)

    func testStringOptionUsesTitleAsValue() {
        let option = BaseDropdownOption("Kampot")
        XCTAssertEqual(option.value, "Kampot")
        XCTAssertEqual(option.title, "Kampot")
    }

    func testOptionLookup() {
        XCTAssertEqual(cities.option(for: "Siem Reap")?.title, "Siem Reap")
        XCTAssertNil(cities.option(for: "Kep"))
        XCTAssertNil(cities.option(for: nil))
    }

    func testSelectingUnknownValueIsIgnored() {
        let field = BaseDropdownField<String>(options: cities)
        field.selectedValue = "Siem Reap"
        field.selectedValue = "Kep"
        XCTAssertEqual(field.selectedValue, "Siem Reap")
        field.selectedValue = nil
        XCTAssertNil(field.selectedOption)
    }

    func testRemovingSelectedOptionClearsSelection() {
        let field = BaseDropdownField<String>(options: cities)
        field.selectedValue = "Battambang"
        field.options = Array(cities.prefix(2))
        XCTAssertNil(field.selectedValue)
    }

    func testCustomValueType() {
        enum Bank: Hashable { case aba, acleda }
        let field = BaseDropdownField<Bank>(options: [
            BaseDropdownOption(value: .aba, title: "ABA", systemImage: "building.columns"),
            BaseDropdownOption(value: .acleda, title: "ACLEDA"),
        ])
        field.selectedValue = .acleda
        XCTAssertEqual(field.selectedOption?.title, "ACLEDA")
    }
}
#endif
