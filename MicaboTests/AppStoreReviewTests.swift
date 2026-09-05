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

    /// Sans droit Pro, le cadeau et le paywall se posent comme pour les autres.
    func testAFreeReviewSessionCanSeeTheGift() {
        XCTAssertTrue(
            DiscountOffer.shouldPresentGift(isPro: false, courseCount: 1, seen: false, startedAt: nil)
        )
    }
}
