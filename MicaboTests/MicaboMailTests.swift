import XCTest
@testable import Micabo

final class MicaboMailTests: XCTestCase {
    func testTheTeamAddressIsThePublicOne() {
        XCTAssertEqual(MicaboMail.team, "team@micabo.app")
    }

    func testABugOpensAMailAlreadyAddressed() throws {
        let url = try XCTUnwrap(MicaboMail.composeURL(kind: .bug, message: "  La carte reste bloquée.  "))
        XCTAssertEqual(url.scheme, "mailto")
        XCTAssertTrue(url.absoluteString.hasPrefix("mailto:team@micabo.app"))
        XCTAssertTrue(url.absoluteString.contains("Bug"))
        XCTAssertTrue(url.absoluteString.contains("La%20carte%20reste%20bloqu"))
    }
}
