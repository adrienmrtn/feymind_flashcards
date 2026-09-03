import XCTest
@testable import Micabo

final class AppStoreReviewTests: XCTestCase {
    func testOnlyTheAppleReviewAddressMatches() {
        XCTAssertTrue(AppStoreReview.matches("review@apple.com"))
        XCTAssertTrue(AppStoreReview.matches("  Review@Apple.com  "))
        XCTAssertFalse(AppStoreReview.matches("review@icloud.com"))
        XCTAssertFalse(AppStoreReview.matches("eleve@micabo.app"))
        XCTAssertFalse(AppStoreReview.matches(nil))
        XCTAssertFalse(AppStoreReview.matches(""))
    }

    func testTheLocalSessionKeepsTheReviewIdentity() {
        let session = AppStoreReview.localSession()

        XCTAssertEqual(session.user.email, AppStoreReview.email)
        XCTAssertEqual(session.user.id, AppStoreReview.userID)
        XCTAssertFalse(session.isExpired)
    }
}
