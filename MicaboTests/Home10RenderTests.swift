import SwiftUI
import XCTest
@testable import Micabo

/// **La Home posée pour un rendu** : l'écran, le bloc du bas (puces d'outils et barre de saisie)
/// et la barre d'onglets, à la taille d'un iPhone, immobile. Ce que la maquette
/// `mock13/home.png` montre, vue pour vue.
struct Home10Board: View {
    let board: HomeBoard
    var exam: HomeExam?
    var entry: HomeProEntry = .upgrade
    var xp = 30
    var streak = StudyStreak.Status(current: 12, best: 18, studiedToday: true)
    /// Les secondes qui restent sur l'offre, quand `entry` vaut `.offer`.
    var offerRemaining: Int?
    var shortcuts: [HomeShortcut] = HomeShortcut.available(isNewcomer: false, hasLesson: true, dueCount: 8)
    var dueCount = 8
    let composer: LessonComposer
    var isBusy = false
    var height: CGFloat = 852

    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HomeScreen(
                board: board,
                exam: HomeExamPill.resolve(exam),
                entry: entry,
                xp: xp,
                streak: streak,
                offerRemaining: offerRemaining,
                actions: HomeActions()
            )
            HomeDock(
                composer: composer,
                focused: $focused,
                shortcuts: shortcuts,
                dueCount: dueCount,
                isBusy: isBusy,
                actions: HomeActions()
            )
            MicaboTabBar()
        }
        // La barre d'état en haut, l'indicateur d'accueil en bas.
        .padding(.top, 54)
        .padding(.bottom, 26)
        .frame(height: height)
        .background(V3Color.bg)
        .environment(TabRouter())
        .environment(\.homeStill, true)
        .environment(\.mikaStill, true)
    }
}

/// **Lot 10 : les rendus de la Home V3.3** — l'élève actif et le nouvel élève de la maquette,
/// puis chaque état : une leçon qui s'écrit, tout est fait, les cartes dues, la leçon en cours,
/// l'abonné, l'offre qui court, la leçon qui attend Pro, la panne, hors ligne, sans examen ; de
/// jour et de nuit, en allemand, en finnois, en arabe, et en très grand texte sur un iPhone SE.
@MainActor
final class Home10RenderTests: XCTestCase {
    override func setUpWithError() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
    }

    private func inLanguage(_ locale: UiLocale, _ body: () throws -> Void) rethrows {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: UiLocale.storageKey)
        defer {
            if let previous { defaults.set(previous, forKey: UiLocale.storageKey) } else { defaults.removeObject(forKey: UiLocale.storageKey) }
        }
        defaults.set(locale.rawValue, forKey: UiLocale.storageKey)
        try body()
    }

    // MARK: - Les journées

    private func session(_ title: String, minutes: Int = 30) -> HomeSession {
        HomeSession(eventID: UUID(), courseID: UUID(), title: title, startMinute: 18 * 60, endMinute: 18 * 60 + minutes)
    }

    /// L'élève actif de la maquette : une séance prévue ce soir, des cartes dues.
    private func active(name: String? = "Léa", lesson: String = "la guerre froide") -> HomeBoardInput {
        HomeBoardInput(
            day: HomeDay(dueCount: 8, hasCourses: true, session: session(lesson), dueLessons: 2),
            name: name,
            greeting: .evening,
            hasLesson: true
        )
    }

    private func board(_ input: HomeBoardInput) -> HomeBoard {
        HomeBoard.resolve(input)
    }

    private var newcomerShortcuts: [HomeShortcut] {
        HomeShortcut.available(isNewcomer: true, hasLesson: false, dueCount: 0)
    }

    /// Le nouvel élève de la maquette : pas de leçon, un examen donné au parcours d'accueil.
    private func newcomer(name: String? = "Lina", exam: HomeExam?) -> Home10Board {
        Home10Board(
            board: board(HomeBoardInput(name: name)),
            exam: exam,
            xp: 0,
            streak: .empty,
            shortcuts: newcomerShortcuts,
            dueCount: 0,
            composer: LessonComposer()
        )
    }

    // MARK: - Les rendus

    /// Les deux écrans de la maquette, de nuit (le marine, par défaut) et de jour.
    func testHomeLikeTheMockup() throws {
        try inLanguage(.fr) {
            let exam = HomeExam(name: "Bac d'histoire", daysLeft: 12, readiness: nil)
            try RenderGallery.render(
                "home10-active", height: 852, night: true,
                Home10Board(board: board(active()), exam: exam, composer: LessonComposer())
            )
            try RenderGallery.render(
                "home10-newcomer", height: 852, night: true,
                newcomer(exam: HomeExam(name: "Bac", daysLeft: 212, readiness: nil))
            )
        }
    }

    /// Chaque état de la phrase et de son action.
    func testHomeStates() throws {
        try inLanguage(.fr) {
            let exam = HomeExam(name: "Bac d'histoire", daysLeft: 12, readiness: nil)
            let day = HomeDay(hasCourses: true)

            // Une leçon s'écrit : la jauge à la place de l'action, la barre patiente.
            let writing = HomeBoardInput(day: day, name: "Léa", phase: .running, stage: .writing, subject: "La guerre froide")
            try RenderGallery.render(
                "home10-generating", height: 852, night: true,
                Home10Board(board: board(writing), exam: exam, shortcuts: HomeShortcut.available(isNewcomer: false, hasLesson: true, dueCount: 0), dueCount: 0, composer: LessonComposer(), isBusy: true)
            )

            // Tout est fait pour aujourd'hui.
            let done = HomeBoardInput(day: HomeDay(hasCourses: true, studiedToday: true), name: "Léa", hasLesson: true)
            try RenderGallery.render(
                "home10-done", height: 852, night: true,
                Home10Board(board: board(done), exam: exam, xp: 120, shortcuts: HomeShortcut.available(isNewcomer: false, hasLesson: true, dueCount: 0), dueCount: 0, composer: LessonComposer())
            )

            // Les cartes dues, puis la leçon en cours.
            let cards = HomeBoardInput(day: HomeDay(dueCount: 8, hasCourses: true), name: "Léa", hasLesson: true)
            try RenderGallery.render("home10-cards", height: 852, Home10Board(board: board(cards), exam: exam, composer: LessonComposer()))
            let lesson = HomeBoardInput(
                day: HomeDay(hasCourses: true, lessonTitle: "La photosynthèse", lessonStep: 4, lessonStarted: true),
                name: "Léa",
                hasLesson: true
            )
            try RenderGallery.render(
                "home10-lesson", height: 852,
                Home10Board(board: board(lesson), exam: nil, streak: StudyStreak.Status(current: 3, best: 9, studiedToday: false), shortcuts: HomeShortcut.available(isNewcomer: false, hasLesson: true, dueCount: 0), dueCount: 0, composer: LessonComposer())
            )

            // L'abonné : « PRO » seul. L'offre qui court : sa pastille à la place de « Passer en PRO ».
            try RenderGallery.render(
                "home10-pro", height: 852, night: true,
                Home10Board(board: board(active()), exam: exam, entry: .member, xp: 240, composer: LessonComposer())
            )
            try RenderGallery.render(
                "home10-offer", height: 852, night: true,
                Home10Board(board: board(active()), exam: exam, entry: .offer, offerRemaining: 3_125, composer: LessonComposer())
            )

            // La leçon lue qui attend Pro, la panne, hors ligne.
            let locked = HomeBoardInput(day: day, name: "Léa", locked: HomeLockedLesson(supports: 1, pages: 4, words: 290))
            try RenderGallery.render("home10-locked", height: 852, Home10Board(board: board(locked), exam: exam, composer: LessonComposer(), isBusy: true))
            let failed = HomeBoardInput(day: day, name: "Léa", phase: .failed("Le serveur n'a pas répondu. Réessaie dans un instant."), subject: "La guerre froide")
            try RenderGallery.render("home10-failed", height: 852, Home10Board(board: board(failed), exam: exam, composer: LessonComposer(), isBusy: true))
            let waiting = HomeBoardInput(day: day, name: "Léa", phase: .waiting, subject: "La guerre froide")
            try RenderGallery.render("home10-offline", height: 852, Home10Board(board: board(waiting), exam: exam, composer: LessonComposer(), isBusy: true))

            // Un sujet tapé : la flèche d'envoi prend la place de l'appareil photo ; un PDF
            // déposé s'aligne au-dessus des puces.
            let composer = LessonComposer()
            composer.draft = "Les étapes clés de la photosynthèse"
            if let id = composer.begin(.pdf, title: "Chapitre 3.pdf") {
                composer.finish(id, with: ImportedDocument(
                    text: String(repeating: "La lumière est captée par la chlorophylle. ", count: 10),
                    pageImages: [],
                    coverImage: nil,
                    pageCount: 4,
                    fileName: "Chapitre 3",
                    source: .pdf,
                    extractionNote: nil
                ))
            }
            try RenderGallery.render("home10-typing", height: 852, night: true, Home10Board(board: board(active()), exam: exam, composer: composer))

            // Le clavier est monté : il ne reste que la phrase et son action au-dessus de la barre.
            try RenderGallery.render("home10-keyboard", height: 500, Home10Board(board: board(active()), exam: exam, composer: LessonComposer(), height: 500))
        }
    }

    /// L'allemand et le finnois (les phrases longues), le turc, l'arabe de droite à gauche.
    func testHomeInOtherLanguages() throws {
        try inLanguage(.de) {
            let exam = HomeExam(name: "Abitur Geschichte", daysLeft: 12, readiness: nil)
            try RenderGallery.render(
                "home10-active-de", height: 852, night: true,
                Home10Board(board: board(active(name: "Lea", lesson: "Der Kalte Krieg")), exam: exam, composer: LessonComposer())
            )
            try RenderGallery.render("home10-newcomer-de", height: 852, newcomer(exam: nil))
        }
        try inLanguage(.fi) {
            try RenderGallery.render(
                "home10-active-fi", height: 852,
                Home10Board(board: board(active(name: "Aino", lesson: "Kylmä sota")), exam: HomeExam(name: "Historian koe", daysLeft: 12, readiness: nil), composer: LessonComposer())
            )
        }
        try inLanguage(.tr) {
            try RenderGallery.render(
                "home10-active-tr", height: 852,
                Home10Board(board: board(active(name: "Elif", lesson: "Soğuk Savaş")), exam: HomeExam(name: "Tarih sınavı", daysLeft: 12, readiness: nil), composer: LessonComposer())
            )
        }
        try inLanguage(.ar) {
            let exam = HomeExam(name: "امتحان التاريخ", daysLeft: 12, readiness: nil)
            try RenderGallery.render(
                "home10-active-ar", height: 852, night: true,
                Home10Board(board: board(active(name: "ليلى", lesson: "الحرب الباردة")), exam: exam, composer: LessonComposer())
                    .environment(\.layoutDirection, .rightToLeft)
            )
            try RenderGallery.render(
                "home10-newcomer-ar", height: 852,
                newcomer(name: "ليلى", exam: nil).environment(\.layoutDirection, .rightToLeft)
            )
        }
    }

    /// Un iPhone SE (375 × 667) en très grand texte : Mika rétrécit, rien n'est coupé.
    func testHomeOnASmallPhoneWithLargeText() throws {
        try inLanguage(.fr) {
            let exam = HomeExam(name: "Bac d'histoire", daysLeft: 12, readiness: nil)
            try RenderGallery.render(
                "home10-active-se", width: 375, height: 667, night: true,
                Home10Board(board: board(active()), exam: exam, composer: LessonComposer(), height: 667)
            )
            try RenderGallery.render(
                "home10-active-se-xxxl", width: 375, height: 667, night: true,
                Home10Board(board: board(active()), exam: exam, composer: LessonComposer(), height: 667)
                    .environment(\.dynamicTypeSize, .xxxLarge)
            )
            try RenderGallery.render(
                "home10-newcomer-se-xxxl", width: 375, height: 667,
                newcomerBoard(height: 667).environment(\.dynamicTypeSize, .xxxLarge)
            )
            let writing = HomeBoardInput(day: HomeDay(hasCourses: true), name: "Léa", phase: .running, stage: .cutting, subject: "La guerre froide")
            try RenderGallery.render(
                "home10-generating-se-xxxl", width: 375, height: 667,
                Home10Board(board: board(writing), exam: exam, composer: LessonComposer(), isBusy: true, height: 667)
                    .environment(\.dynamicTypeSize, .xxxLarge)
            )
        }
        try inLanguage(.de) {
            try RenderGallery.render(
                "home10-active-se-xxxl-de", width: 375, height: 667,
                Home10Board(board: board(active(name: "Lea", lesson: "Der Kalte Krieg")), exam: HomeExam(name: "Abitur Geschichte", daysLeft: 12, readiness: nil), composer: LessonComposer(), height: 667)
                    .environment(\.dynamicTypeSize, .xxxLarge)
            )
        }
    }

    private func newcomerBoard(height: CGFloat) -> Home10Board {
        var view = newcomer(exam: HomeExam(name: "Bac", daysLeft: 212, readiness: nil))
        view.height = height
        return view
    }
}
