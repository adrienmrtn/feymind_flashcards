import XCTest
@testable import Micabo

/// Le glissé des notes : il tourne la page quand il est franc, et pas au moindre geste de
/// travers — c'est ce qui l'avait fait retirer.
final class NotesSwipeTests: XCTestCase {
    private func swipe(_ dx: CGFloat, _ dy: CGFloat = 0, predicted: CGFloat? = nil, rightToLeft: Bool = false) -> NotesSwipe.Direction? {
        NotesSwipe.direction(
            of: CGSize(width: dx, height: dy),
            predicted: CGSize(width: predicted ?? dx, height: dy),
            rightToLeft: rightToLeft
        )
    }

    func testAFrankSwipeTurnsThePageBothWays() {
        XCTAssertEqual(swipe(-90), .forward)
        XCTAssertEqual(swipe(90), .back)
    }

    func testASlantedGestureDoesNotTurnThePage() {
        // Un défilement vertical qui dérive : plus large que haut, mais pas assez.
        XCTAssertNil(swipe(-90, 60))
        XCTAssertNil(swipe(80, 40))
        XCTAssertEqual(swipe(-90, 30), .forward)
    }

    func testAShortDragDoesNotTurnThePageUnlessFlung() {
        XCTAssertNil(swipe(-50))
        XCTAssertEqual(swipe(-50, predicted: -220), .forward)
        // Lancé dans l'autre sens que le geste : rien.
        XCTAssertNil(swipe(-50, predicted: 220))
        XCTAssertNil(swipe(-20, predicted: -400))
    }

    func testRightToLeftMirrorsTheGesture() {
        XCTAssertEqual(swipe(90, rightToLeft: true), .forward)
        XCTAssertEqual(swipe(-90, rightToLeft: true), .back)
    }
}
