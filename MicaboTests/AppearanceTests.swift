import XCTest
@testable import Micabo

final class AppearanceTests: XCTestCase {
    func testOnlyThreeAppearances() {
        XCTAssertEqual(MicaboAppearance.allCases.map(\.rawValue), ["day", "night", "twilight"])
        XCTAssertEqual(MicaboAppearance.fromUnknown(nil), .day)
        XCTAssertEqual(MicaboAppearance.fromUnknown("sepia"), .day)
        XCTAssertEqual(MicaboAppearance.fromUnknown("twilight"), .twilight)
    }

    func testNightAndTwilightAreDark() {
        XCTAssertFalse(MicaboAppearance.day.isDark)
        XCTAssertTrue(MicaboAppearance.night.isDark)
        XCTAssertTrue(MicaboAppearance.twilight.isDark)
    }
}
