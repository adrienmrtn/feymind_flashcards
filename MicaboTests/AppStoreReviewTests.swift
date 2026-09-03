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

    /// Le cadeau est refermé avant même la session : le droit Pro le couvre déjà, mais
    /// il se présente pendant l'instant qui sépare la connexion du premier `refresh()`.
    func testTheGiftIsAlreadySeenForTheReviewAccount() {
        let name = "micabo.tests.review.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }

        XCTAssertFalse(DiscountOffer.isSeen(in: defaults))
        DiscountOffer.markSeen(in: defaults)
        XCTAssertTrue(DiscountOffer.isSeen(in: defaults))

        XCTAssertFalse(
            DiscountOffer.shouldPresentGift(isPro: true, courseCount: 1, seen: true, startedAt: nil)
        )
    }
}
