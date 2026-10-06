#if canImport(UIKit)
import XCTest
@testable import BaseUI

@MainActor
final class BaseButtonTests: XCTestCase {

    func testVariantColors() {
        var appearance = BaseButtonAppearance()
        appearance.tintColor = .systemGreen

        XCTAssertEqual(appearance.colors(for: .primary).background, .systemGreen)
        XCTAssertEqual(appearance.colors(for: .primary).foreground, appearance.onTintColor)
        XCTAssertEqual(appearance.colors(for: .outline).border, .systemGreen)
        XCTAssertEqual(appearance.colors(for: .ghost).background, .clear)
        XCTAssertNil(appearance.colors(for: .ghost).border)
        XCTAssertEqual(appearance.colors(for: .destructive).background, appearance.destructiveColor)
    }

    func testOpacity() {
        let appearance = BaseButtonAppearance()
        XCTAssertEqual(appearance.opacity(isEnabled: true, isPressed: false), 1)
        XCTAssertEqual(appearance.opacity(isEnabled: true, isPressed: true), appearance.pressedOpacity)
        XCTAssertEqual(appearance.opacity(isEnabled: false, isPressed: true), appearance.disabledOpacity)
    }

    func testSizesGrow() {
        XCTAssertLessThan(BaseButtonSize.small.height, BaseButtonSize.medium.height)
        XCTAssertLessThan(BaseButtonSize.medium.height, BaseButtonSize.large.height)
    }

    func testMinimumHeight() {
        let button = BaseButton(title: "Pay", size: .large)
        XCTAssertGreaterThanOrEqual(button.intrinsicContentSize.height, BaseButtonSize.large.height)
    }

    func testLoadingBlocksTaps() {
        let button = BaseButton(title: "Pay")
        button.isLoading = true
        XCTAssertFalse(button.isUserInteractionEnabled)
        button.isLoading = false
        XCTAssertTrue(button.isUserInteractionEnabled)
    }

    func testActionFires() {
        var tapped = false
        let button = BaseButton(title: "Pay") { tapped = true }
        button.sendActions(for: .primaryActionTriggered)
        XCTAssertTrue(tapped)
    }
}
#endif
