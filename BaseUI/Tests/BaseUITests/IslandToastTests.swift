#if canImport(UIKit)
import XCTest
@testable import BaseUI

final class IslandToastTests: XCTestCase {

    func testPresetSymbolsExist() {
        let presets: [IslandToastStyle] = [.success, .error, .warning, .info]
        for style in presets {
            XCTAssertNotNil(UIImage(systemName: style.symbolName), style.symbolName)
        }
    }

    func testMessagesAreUniqueByID() {
        let a = IslandToastMessage("Same text")
        let b = IslandToastMessage("Same text")
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(a, a)
    }

    func testConfigurationDefaults() {
        let config = IslandToastConfiguration()
        XCTAssertEqual(config.maxLines, 2)
        XCTAssertTrue(config.hidesStatusBarOnIsland)
        XCTAssertTrue(config.tapToDismiss)
        XCTAssertNil(config.islandFrame)
    }
}
#endif
