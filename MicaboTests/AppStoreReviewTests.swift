import XCTest
@testable import Micabo

final class AppStoreReviewTests: XCTestCase {
    func testTheAppleReviewAddressMatches() {
        XCTAssertTrue(AppStoreReview.matches("review@apple.com"))
        XCTAssertTrue(AppStoreReview.matches("  Review@Apple.com  "))
    }

    /// `review2@apple.com` a demandé un lien le 5 septembre, et il a rebondi : l'égalité
    /// stricte ne reconnaissait pas la variante qu'un relecteur avait tapée.
    func testTheVariantsAReviewerInventsMatchToo() {
        XCTAssertTrue(AppStoreReview.matches("review2@apple.com"))
        XCTAssertTrue(AppStoreReview.matches("appreview@apple.com"))
        XCTAssertTrue(AppStoreReview.matches("app.review@apple.com"))
        XCTAssertTrue(AppStoreReview.matches("REVIEW-3@APPLE.COM"))
    }

    func testItStopsAtApplesDomain() {
        XCTAssertFalse(AppStoreReview.matches("review@icloud.com"))
        XCTAssertFalse(AppStoreReview.matches("review@apple.com.attaquant.fr"))
        XCTAssertFalse(AppStoreReview.matches("review@notapple.com"))
        XCTAssertFalse(AppStoreReview.matches("eleve@micabo.app"))
        XCTAssertFalse(AppStoreReview.matches("apple.com"))
        XCTAssertFalse(AppStoreReview.matches("@apple.com"))
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
