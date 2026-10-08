#if canImport(UIKit)
import XCTest
@testable import BaseUI

@MainActor
final class BaseZoomTransitionTests: XCTestCase {

    func testConfigurationDefaults() {
        let config = BaseZoomConfiguration()
        XCTAssertEqual(config.dismissGestures, .all)
        XCTAssertEqual(config.dismissDistance, 120)
        XCTAssertEqual(config.minimumScale, 0.7)
        XCTAssertNil(config.sourceCornerRadius)
        XCTAssertFalse(config.dismissesFromPushedScreens)
    }

    func testDismissGestureFlags() {
        XCTAssertEqual(BaseZoomDismissGestures.all, [.down, .right])
        XCTAssertFalse(BaseZoomDismissGestures.right.contains(.down))
        XCTAssertTrue(BaseZoomDismissGestures([]).isEmpty)
    }

    func testAttachMakesCustomPresentationAndKeepsTransitionAlive() {
        let controller = UIViewController()
        weak var weakTransition: BaseZoomTransition?
        do {
            let transition = BaseZoomTransition(source: UIView())
            transition.attach(to: controller)
            weakTransition = transition
        }
        XCTAssertEqual(controller.modalPresentationStyle, .custom)
        XCTAssertNotNil(weakTransition, "the presented controller retains its transition")
        XCTAssertTrue(controller.transitioningDelegate === weakTransition)
    }

    func testSourceCornerRadiusFallsBackToLayer() {
        let source = UIView()
        source.layer.cornerRadius = 16
        let transition = BaseZoomTransition(source: source)
        XCTAssertEqual(transition.sourceCornerRadius, 16)
        transition.configuration.sourceCornerRadius = 8
        XCTAssertEqual(transition.sourceCornerRadius, 8)
    }

    func testOffscreenSourceHasNoFrame() {
        let transition = BaseZoomTransition(source: UIView())   // not in a window
        XCTAssertNil(transition.sourceFrame(in: UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 600))))
    }
}
#endif
