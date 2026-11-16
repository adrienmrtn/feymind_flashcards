import XCTest
@testable import Micabo

/// **Lot 13 — la leçon au centre, et la langue de l'élève.**
///
/// Écrire une leçon est la fonction principale de l'app : la Home vide y pousse (en reprenant le
/// sujet du parcours d'accueil), des supports déposés deviennent « Écrire ma leçon », la rangée
/// commence par « + Nouvelle leçon », et la barre dit qu'elle pose une question à Mika. Une
/// leçon commencée dans une langue se termine dans la même.
@MainActor
final class Core13Tests: XCTestCase {
    private static let written: [UiLocale] = [.fr, .en, .de, .es, .tr, .ar]

    // MARK: - La Home vide

    /// Le sujet choisi au parcours d'accueil revient tant qu'aucune leçon n'est écrite : une
    /// seule action, la pilule blanche « Écrire ma leçon ». Sans sujet, la Home vide dit ce
    /// que la leçon deviendra.
    func testTheEmptyHomeOffersTheOnboardingTopic() {
        let board = HomeBoard.resolve(HomeBoardInput(name: "Lina", firstTopic: "la guerre froide"), locale: .fr)
        XCTAssertEqual(board.moment, .newcomer)
        XCTAssertEqual(board.phrase.keyword, "la guerre froide")
        XCTAssertEqual(board.action?.kind, .first)
        XCTAssertEqual(board.action?.title, "Écrire ma leçon")
        XCTAssertTrue(board.action?.isPrimary ?? false)
        // Un élève qui a déjà des leçons ne voit plus ce sujet.
        let active = HomeBoard.resolve(HomeBoardInput(day: HomeDay(hasCourses: true), firstTopic: "la guerre froide"), locale: .fr)
        XCTAssertNotEqual(active.moment, .newcomer)
        // Des supports déposés passent devant le sujet : ce sont eux qui deviennent la leçon.
        XCTAssertEqual(HomeBoard.moment(for: HomeBoardInput(composing: .ready, firstTopic: "la guerre froide")), .composing)
        let plain = HomeBoard.resolve(HomeBoardInput(name: "Lina"), locale: .fr)
        XCTAssertEqual(plain.caption, "Ton cours devient un parcours : notes, quiz, cartes, examen blanc.")
    }

    // MARK: - Des supports déposés

    /// Un PDF ou des photos dans la barre : Mika les lit (sans action), puis propose « Écrire ma
    /// leçon » en bouton principal. Une leçon qui s'écrit ou qui attend Pro passe devant.
    func testDepositedSupportsBecomeWriteMyLesson() {
        var input = HomeBoardInput(day: HomeDay(dueCount: 8, hasCourses: true, session: HomeSession(eventID: UUID(), courseID: UUID(), title: "x", startMinute: 600, endMinute: 630)))
        input.composing = .reading
        var board = HomeBoard.resolve(input, locale: .fr)
        XCTAssertEqual(board.moment, .composing, "les supports passent devant la journée")
        XCTAssertNil(board.action)
        XCTAssertEqual(board.phrase.plain, "Je lis\nton cours…")

        input.composing = .ready
        board = HomeBoard.resolve(input, locale: .fr)
        XCTAssertEqual(board.action?.kind, .write)
        XCTAssertEqual(board.action?.title, "Écrire ma leçon")
        XCTAssertTrue(board.action?.isPrimary ?? false)
        XCTAssertEqual(board.action?.analyticsStep, "write")

        input.locked = HomeLockedLesson(supports: 1, pages: 2, words: 100)
        XCTAssertEqual(HomeBoard.moment(for: input), .locked)
        input.locked = nil
        input.phase = .running
        XCTAssertEqual(HomeBoard.moment(for: input), .generating)
    }

    /// Les actions de la journée restent des puces : une seule pilule blanche par écran.
    func testOnlyWritingALessonIsThePrimaryButton() {
        for kind in HomeAction.Kind.allCases {
            let action = HomeAction(kind: kind, title: "", symbol: "")
            XCTAssertEqual(action.isPrimary, kind == .first || kind == .write, kind.rawValue)
        }
    }

    // MARK: - L'écriture

    /// « Étape 3 sur 4 · J'écris tes notes » : la ligne sous la jauge dit où en est le travail.
    func testTheGaugeNamesItsStep() {
        let input = HomeBoardInput(day: HomeDay(hasCourses: true), phase: .running, stage: .writing, subject: "Les volcans")
        let board = HomeBoard.resolve(input, locale: .fr)
        XCTAssertEqual(board.caption, "Étape 3 sur 4 · J'écris tes notes")
        let first = HomeBoard.resolve(HomeBoardInput(day: HomeDay(hasCourses: true), phase: .running), locale: .en)
        XCTAssertTrue(first.caption?.hasPrefix("Step 1 of 4 · ") ?? false, first.caption ?? "")
    }

    /// Les nouvelles phrases suivent la règle de la Home dans les six langues : deux lignes, un
    /// mot-clé, aucune accolade.
    func testNewPhrasesKeepTheHomeRules() {
        let long = "La plante, productrice de matière organique et actrice des échanges gazeux"
        let inputs = [
            HomeBoardInput(firstTopic: long),
            HomeBoardInput(firstTopic: "Les volcans"),
            HomeBoardInput(day: HomeDay(hasCourses: true), composing: .reading),
            HomeBoardInput(day: HomeDay(hasCourses: true), composing: .ready),
        ]
        for locale in Self.written {
            for input in inputs {
                let board = HomeBoard.resolve(input, locale: locale)
                let marked = board.phrase.marked
                let context = "\(locale.rawValue) \(board.moment.rawValue) : \(marked)"
                XCTAssertEqual(marked.components(separatedBy: "\n").count, 2, context)
                XCTAssertEqual(marked.components(separatedBy: "**").count, 3, context)
                XCTAssertFalse(marked.contains("{") || marked.contains("}"), context)
                XCTAssertFalse(marked.contains(long), context)
                for text in [board.caption, board.action?.title].compactMap({ $0 }) {
                    XCTAssertFalse(text.contains("ios.") || text.contains("{"), "\(locale.rawValue) : \(text)")
                }
            }
        }
    }

    // MARK: - La rangée et la barre

    /// « + Nouvelle leçon » ouvre la rangée de l'élève actif ; le nouvel élève a déjà son bouton.
    func testNewLessonLeadsTheRow() {
        let active = HomeShortcut.available(isNewcomer: false, hasLesson: true, dueCount: 0)
        XCTAssertEqual(active.first, .newLesson)
        XCTAssertEqual(active.dropFirst().first, .focus, "Focus reste le premier des outils")
        XCTAssertFalse(HomeShortcut.available(isNewcomer: true, hasLesson: false, dueCount: 0).contains(.newLesson))
        XCTAssertEqual(HomeShortcut.newLesson.title(locale: .fr), "Nouvelle leçon")
        XCTAssertEqual(HomeShortcut.newLesson.analyticsName, "new_lesson")
    }

    /// La barre seule ouvre le chat : son invite le dit, dans chaque langue écrite.
    func testTheBarSaysItAsksMika() {
        XCTAssertEqual(L10n.t("ios.core13.bar.ask", locale: .fr), "Pose une question à Mika…")
        for locale in Self.written {
            XCTAssertTrue(L10n.t("ios.core13.bar.ask", locale: locale).contains(locale == .ar ? "ميكا" : "Mika"), locale.rawValue)
        }
    }

    // MARK: - La feuille « Nouvelle leçon »

    func testTheNewLessonSheetPutsCommonSupportsFirst() {
        XCTAssertEqual(HomeSourcesSheet.grid.first, [.photo, .pdf, .youtube])
        XCTAssertEqual(HomeSourcesSheet.grid[1].first, .audio)
        XCTAssertEqual(Set(HomeSourcesSheet.grid.flatMap { $0 }).count, 9)
        XCTAssertFalse(HomeSourcesSheet.canWrite(" a "))
        XCTAssertTrue(HomeSourcesSheet.canWrite("Les volcans"))
        XCTAssertEqual(LessonPathSteps.titles(locale: .fr), ["Thèmes", "Notes", "Quiz", "Cartes", "Examen blanc"])
    }

    // MARK: - Les clés

    /// Les clés du lot, dans les six langues écrites, sans repli sur une autre langue.
    func testCoreKeysAreWrittenInSixLanguages() {
        let keys = [
            "ios.core13.bar.ask", "ios.core13.cta.write", "ios.core13.home.promise",
            "ios.core13.home.reading", "ios.core13.home.readingCaption", "ios.core13.home.ready", "ios.core13.gen.step",
            "ios.core13.new.promise", "ios.core13.new.topicLabel", "ios.core13.new.topicPlaceholder",
            "ios.core13.new.orSupport", "ios.core13.path.themes", "ios.core13.lessons.emptyTitle",
            "ios.core13.lessons.emptyBody", "ios.core13.restore.title", "ios.core13.restore.help", "ios.core13.restore.done", "ios.core13.lesson.mock",
        ]
        for key in keys {
            var seen: [String: UiLocale] = [:]
            for locale in Self.written {
                let text = L10n.t(key, locale: locale)
                XCTAssertNotEqual(text, key, "\(locale.rawValue) \(key)")
                if let other = seen[text], text.count > 6 {
                    XCTFail("\(key) : \(locale.rawValue) reprend le texte de \(other.rawValue)")
                }
                seen[text] = locale
            }
        }
    }

    // MARK: - La langue d'une leçon

    /// Une leçon commencée en français se termine en français : les thèmes écrits ensuite, les
    /// nouvelles questions et la conversion suivent la langue de la leçon, pas celle de l'app.
    func testALessonKeepsItsLanguage() {
        let audience = LessonAudience(level: "", country: "FR", schoolStage: "", language: "en")
        XCTAssertEqual(audience.writing(in: "fr").language, "fr")
        XCTAssertEqual(audience.writing(in: "fr").payload["language"] as? String, "fr")
        XCTAssertEqual(audience.writing(in: nil).language, "en", "sans langue connue : celle de l'app")
        XCTAssertEqual(audience.writing(in: " ").language, "en")
        XCTAssertEqual(audience.writing(in: "fr").country, "FR", "le reste de l'audience ne bouge pas")
    }

    /// L'interface suit le téléphone (repli anglais) ; une langue qu'on ne parle pas laisse la
    /// place à la suivante de la liste ; le choix fait dans l'app passe devant.
    func testTheInterfaceFollowsThePhone() {
        XCTAssertEqual(UiLocale.fromPreferredLanguages(["de-CH"]), .de)
        XCTAssertEqual(UiLocale.fromPreferredLanguages(["xx-XX", "fr-FR"]), .fr, "une langue inconnue cède à la suivante")
        XCTAssertEqual(UiLocale.fromPreferredLanguages(["xx-XX"]), .en, "repli anglais")
        XCTAssertEqual(UiLocale.fromPreferredLanguages(["pt-BR"]), .ptBR)
        XCTAssertEqual(UiLocale.fromPreferredLanguages(["es-MX"]), .es419)
        let defaults = UserDefaults(suiteName: "core13.locale.\(UUID().uuidString)")!
        defaults.set("tr", forKey: UiLocale.storageKey)
        XCTAssertEqual(UiLocale.resolved(defaults: defaults), .tr, "le choix fait dans les réglages prime")
        // Les cours suivent la langue de l'interface.
        for locale in UiLocale.allCases {
            XCTAssertFalse(locale.contentLanguage.rawValue.isEmpty)
        }
        XCTAssertEqual(UiLocale.pt.contentLanguage, .pt)
        XCTAssertEqual(UiLocale.es419.contentLanguage, .es419)
    }
}
