import XCTest
@testable import Micabo

final class AppearanceTests: XCTestCase {
    func testOnlyTheDayRemains() {
        XCTAssertEqual(MicaboAppearance.allCases.map(\.rawValue), ["day"])
        XCTAssertEqual(MicaboAppearance.fromUnknown(nil), .day)
        XCTAssertEqual(MicaboAppearance.fromUnknown("sepia"), .day)
        // Les anciens réglages « night » et « twilight » retombent sur le jour.
        XCTAssertEqual(MicaboAppearance.fromUnknown("night"), .day)
        XCTAssertEqual(MicaboAppearance.fromUnknown("twilight"), .day)
    }

    func testTheDayIsLight() {
        XCTAssertFalse(MicaboAppearance.day.isDark)
        XCTAssertEqual(MicaboAppearance.day.colorScheme, .light)
    }
}
