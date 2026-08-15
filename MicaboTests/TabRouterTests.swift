import XCTest
@testable import Micabo

final class TabRouterTests: XCTestCase {
    func testRootStateFollowsTheVisibleTab() {
        let router = TabRouter()
        router.selection = .courses
        router.setDepth(1, for: .courses)
        XCTAssertFalse(router.isAtRoot)

        // Un détail ouvert ailleurs ne concerne pas l'onglet affiché.
        router.selection = .profile
        XCTAssertTrue(router.isAtRoot)
    }

    func testReturningToARootRestoresTheTabBar() {
        let router = TabRouter()
        XCTAssertTrue(router.isAtRoot)

        router.setDepth(1, for: .dashboard)
        XCTAssertFalse(router.isAtRoot)

        router.setDepth(0, for: .dashboard)
        XCTAssertTrue(router.isAtRoot)
    }
}
