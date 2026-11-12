import SwiftUI
import XCTest
@testable import Micabo

/// **Les écrans sur un vrai iPhone** (lot 11) : posés dans une fenêtre avec les marges de
/// sécurité de l'iPhone 15 Pro (59/34) et de l'iPhone SE (20/0), l'encoche et la barre
/// d'accueil dessinées par-dessus (`RenderGallery.renderDevice`). C'est là que se voient un
/// titre sous l'encoche, un bouton collé au bord bas ou caché par la barre d'onglets.
@MainActor
final class DeviceRenderTests: XCTestCase {
    override func setUpWithError() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
    }

    func testHomeOnDevice() throws {
        let exam = HomeExam(name: "Bac d'histoire", daysLeft: 12, readiness: nil)
        let session = HomeSession(eventID: UUID(), courseID: UUID(), title: "la guerre froide", startMinute: 18 * 60, endMinute: 18 * 60 + 30)
        let day = HomeDay(dueCount: 8, hasCourses: true, session: session, dueLessons: 2)
        let board = HomeBoard.resolve(HomeBoardInput(day: day, name: "Léa", greeting: .evening, hasLesson: true))
        try RenderGallery.renderDevice("device-home", RenderTabRoot {
            HomePage(board: board, exam: exam)
        })
    }
}

/// La page Home telle que `HomeView` la pose : l'écran, le fond sous les marges, le bloc du
/// bas au-dessus de la barre d'onglets.
struct HomePage: View {
    let board: HomeBoard
    var exam: HomeExam?
    var shortcuts: [HomeShortcut] = HomeShortcut.available(isNewcomer: false, hasLesson: true, dueCount: 8)
    var dueCount = 8
    var composer = LessonComposer()
    @FocusState private var focused: Bool

    var body: some View {
        HomeScreen(
            board: board,
            exam: HomeExamPill.resolve(exam),
            entry: .upgrade,
            xp: 30,
            streak: StudyStreak.Status(current: 12, best: 18, studiedToday: true),
            offerRemaining: nil,
            actions: HomeActions()
        )
        .background(V3Color.bg.ignoresSafeArea())
        .tabBarClearance {
            HomeDock(composer: composer, focused: $focused, shortcuts: shortcuts, dueCount: dueCount, isBusy: false, actions: HomeActions())
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
