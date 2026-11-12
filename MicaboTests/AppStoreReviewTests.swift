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

    /// Sans droit Pro, l'offre de réduction se présente comme pour les autres : à la
    /// fermeture d'un paywall, et par la rangée des Réglages qui garde le tarif atteignable.
    func testAFreeReviewSessionCanSeeTheOffer() {
        XCTAssertTrue(DiscountOffer.paywallClosed(isPro: false, startedAt: nil, declined: false))
        XCTAssertTrue(DiscountOffer.isReachable(isPro: false, courseCount: 0))
    }
}
