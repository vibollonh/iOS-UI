#if canImport(UIKit)
import XCTest
@testable import BaseUI

final class DeviceScreenTests: XCTestCase {

    func testKnownDynamicIslandModels() {
        for id in ["iPhone15,2", "iPhone15,4", "iPhone16,1", "iPhone17,1", "iPhone17,3", "iPhone18,1", "iPhone18,4"] {
            XCTAssertEqual(DeviceScreen.classify(modelIdentifier: id, safeAreaEdge: 0), .dynamicIsland, id)
        }
    }

    func testKnownNotchModels() {
        for id in ["iPhone10,3", "iPhone11,8", "iPhone13,2", "iPhone14,7", "iPhone17,5"] {
            XCTAssertEqual(DeviceScreen.classify(modelIdentifier: id, safeAreaEdge: 0), .notch, id)
        }
    }

    func testKnownIdentifierWinsOverSafeArea() {
        XCTAssertEqual(DeviceScreen.classify(modelIdentifier: "iPhone17,5", safeAreaEdge: 62), .notch)
        XCTAssertEqual(DeviceScreen.classify(modelIdentifier: "iPhone17,1", safeAreaEdge: 20), .dynamicIsland)
    }

    func testUnknownModelFallsBackToSafeArea() {
        let unknown = "iPhone99,1"
        XCTAssertEqual(DeviceScreen.classify(modelIdentifier: unknown, safeAreaEdge: 62), .dynamicIsland)
        XCTAssertEqual(DeviceScreen.classify(modelIdentifier: unknown, safeAreaEdge: 59), .dynamicIsland)
        XCTAssertEqual(DeviceScreen.classify(modelIdentifier: unknown, safeAreaEdge: 47), .notch)
        XCTAssertEqual(DeviceScreen.classify(modelIdentifier: unknown, safeAreaEdge: 20), .none)
        XCTAssertEqual(DeviceScreen.classify(modelIdentifier: unknown, safeAreaEdge: 0), .none)
    }

    func testSafeAreaBoundaries() {
        let unknown = "iPhone99,1"
        XCTAssertEqual(DeviceScreen.classify(modelIdentifier: unknown, safeAreaEdge: 51), .dynamicIsland)
        XCTAssertEqual(DeviceScreen.classify(modelIdentifier: unknown, safeAreaEdge: 50), .notch)
        XCTAssertEqual(DeviceScreen.classify(modelIdentifier: unknown, safeAreaEdge: 25), .notch)
        XCTAssertEqual(DeviceScreen.classify(modelIdentifier: unknown, safeAreaEdge: 24), .none)
    }

    func testDefaultIslandFrameIsCentered() {
        let frame = DeviceScreen.defaultDynamicIslandFrame(screenWidth: 393)
        XCTAssertEqual(frame.midX, 196.5, accuracy: 0.01)
        XCTAssertGreaterThan(frame.width, frame.height)
    }

    func testDisplayCornerRadius() {
        XCTAssertEqual(DeviceScreen.displayCornerRadius(modelIdentifier: "iPhone17,1", feature: .dynamicIsland), 62)
        XCTAssertEqual(DeviceScreen.displayCornerRadius(modelIdentifier: "iPhone14,7", feature: .notch), 47.33)
        XCTAssertEqual(DeviceScreen.displayCornerRadius(modelIdentifier: "iPhone99,1", feature: .dynamicIsland), 62)
        XCTAssertEqual(DeviceScreen.displayCornerRadius(modelIdentifier: "iPhone12,8", feature: .none), 0)
    }

    func testModelIdentifierIsNotEmpty() {
        XCTAssertFalse(DeviceScreen.modelIdentifier.isEmpty)
    }
}
#endif
