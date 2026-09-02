import XCTest
@testable import Micabo

final class MicaboMailTests: XCTestCase {
    func testTheTeamAddressIsThePublicOne() {
        XCTAssertEqual(MicaboMail.team, "team@micabo.app")
    }

    func testKindsMatchTheWebInbox() {
        XCTAssertEqual(MicaboMail.Kind.bug.rawValue, "bug")
        XCTAssertEqual(MicaboMail.Kind.idea.rawValue, "idea")
        XCTAssertEqual(MicaboMail.Kind.bug.subject, "Bug — Micabo")
        XCTAssertEqual(MicaboMail.Kind.idea.subject, "Idée — Micabo")
    }
}
