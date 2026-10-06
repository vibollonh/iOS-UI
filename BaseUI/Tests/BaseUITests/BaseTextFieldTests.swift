#if canImport(UIKit)
import XCTest
@testable import BaseUI

@MainActor
final class BaseTextFieldTests: XCTestCase {

    func testLimitCountsCharactersNotScalars() {
        XCTAssertEqual(BaseTextFieldLimit.apply(3, to: "abcdef"), "abc")
        XCTAssertEqual(BaseTextFieldLimit.apply(nil, to: "abcdef"), "abcdef")
        XCTAssertEqual(BaseTextFieldLimit.apply(2, to: "👨‍👩‍👧👍🏽x"), "👨‍👩‍👧👍🏽")
        XCTAssertEqual(BaseTextFieldLimit.apply(10, to: "ផ្ទេរ"), "ផ្ទេរ")
    }

    func testBorderPriority() {
        let appearance = BaseTextFieldAppearance()
        XCTAssertEqual(appearance.border(isFocused: false, hasError: false).color, appearance.borderColor)
        XCTAssertEqual(appearance.border(isFocused: true, hasError: false).color, appearance.focusedBorderColor)
        XCTAssertEqual(appearance.border(isFocused: true, hasError: true).color, appearance.errorColor)
    }

    func testMaxLengthAppliesToText() {
        let field = BaseTextField()
        field.maxLength = 4
        field.text = "123456"
        XCTAssertEqual(field.text, "1234")
    }

    func testSecureToggleState() {
        let field = BaseTextField(isSecure: true)
        XCTAssertTrue(field.textField.isSecureTextEntry)
        field.isSecure = false
        XCTAssertFalse(field.textField.isSecureTextEntry)
    }

    func testErrorReplacesHelperInAccessibilityHint() {
        let field = BaseTextField(title: "Email", helperText: "We never share it")
        XCTAssertEqual(field.textField.accessibilityHint, "We never share it")
        field.errorMessage = "Invalid email"
        XCTAssertEqual(field.textField.accessibilityHint, "Invalid email")
        field.errorMessage = nil
        XCTAssertEqual(field.textField.accessibilityHint, "We never share it")
    }
}
#endif
