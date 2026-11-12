import SwiftData
import XCTest
@testable import Micabo

/// **Lot 10 : la Home, la leçon ouverte et la clarté des fonctionnalités** — la logique.
///
/// La Home ne dit qu'une chose et ne propose qu'une action : ce qu'elle choisit se décide dans
/// `HomeBoard`, sans écran. Une leçon range tout au même endroit : huit tuiles, un chemin. Et
/// chaque chose n'a qu'un nom (`MicaboName`).
@MainActor
final class Home10Tests: XCTestCase {
    private static let written: [UiLocale] = [.fr, .en, .de, .es, .tr, .ar]

    private func session(minutes: Int = 30, title: String = "La guerre froide") -> HomeSession {
        HomeSession(eventID: UUID(), courseID: UUID(), title: title, startMinute: 18 * 60, endMinute: 18 * 60 + minutes)
    }

    // MARK: - Ce que la journée propose

    /// L'ordre de priorité de la phrase : la séance prévue, les cartes dues, la leçon en cours,
    /// puis « tout est fait » ; le nouvel élève commence par créer.
    func testTheDayProposesOneThingInOrder() {
        var day = HomeDay(hasCourses: false)
        XCTAssertEqual(day.proposal, .newcomer)

        day = HomeDay(dueCount: 8, hasCourses: true, lessonTitle: "La photosynthèse", session: session(), lessonStep: 4)
        XCTAssertEqual(day.proposal, .session, "la séance du calendrier passe devant tout")

        day.session = nil
        XCTAssertEqual(day.proposal, .cards, "puis les cartes dues")

        day.dueCount = 0
        XCTAssertEqual(day.proposal, .lesson, "puis la leçon en cours")

        day.lessonAdvancedToday = true
        day.studiedToday = true
        XCTAssertEqual(day.proposal, .done, "la leçon a avancé aujourd'hui : la journée est faite")

        day.studiedToday = false
        XCTAssertEqual(day.proposal, .lesson)

        day = HomeDay(hasCourses: true, studiedToday: true)
        XCTAssertEqual(day.proposal, .done)

        day = HomeDay(hasCourses: true)
        XCTAssertEqual(day.proposal, .open, "rien de prévu, rien de fait")
    }

    /// Une leçon qui s'écrit, qui attend le réseau, qui a échoué ou qui attend Pro passe devant
    /// la journée.
    func testALessonBeingWrittenComesBeforeTheDay() {
        var input = HomeBoardInput(day: HomeDay(dueCount: 8, hasCourses: true, session: session()))
        XCTAssertEqual(HomeBoard.moment(for: input), .session)

        input.locked = HomeLockedLesson(supports: 1, pages: 4, words: 290)
        XCTAssertEqual(HomeBoard.moment(for: input), .locked)

        input.phase = .failed("Réseau indisponible")
        XCTAssertEqual(HomeBoard.moment(for: input), .failed)

        input.phase = .waiting
        XCTAssertEqual(HomeBoard.moment(for: input), .waiting)

        input.phase = .running
        XCTAssertEqual(HomeBoard.moment(for: input), .generating)
    }

    // MARK: - Une phrase, une action

    func testTheSessionPhraseGreetsAndNamesTheLesson() {
        let input = HomeBoardInput(
            day: HomeDay(hasCourses: true, session: session(minutes: 30, title: "la guerre froide")),
            name: "Léa",
            greeting: .evening
        )
        let board = HomeBoard.resolve(input, locale: .fr)
        XCTAssertEqual(board.moment, .session)
        XCTAssertEqual(board.phrase.plain, "Bonsoir Léa.\n30 min sur la guerre froide ?")
        XCTAssertEqual(board.phrase.keyword, "la guerre froide")
        XCTAssertEqual(board.action?.kind, .session)
        XCTAssertEqual(board.action?.title, "Démarrer la séance")
        XCTAssertNil(board.progress)
        XCTAssertNil(board.exit)
    }

    func testTheNewcomerIsAskedForAFirstLesson() {
        let board = HomeBoard.resolve(HomeBoardInput(name: "Lina"), locale: .fr)
        XCTAssertEqual(board.moment, .newcomer)
        XCTAssertEqual(board.phrase.plain, "On commence par\nquel cours, Lina ?")
        XCTAssertEqual(board.phrase.keyword, "Lina")
        XCTAssertEqual(board.action?.kind, .first)
        XCTAssertEqual(board.action?.title, "Créer ma première leçon")
        XCTAssertEqual(board.action?.analyticsStep, "create")
    }

    func testCardsThenLessonThenDone() {
        var day = HomeDay(dueCount: 8, hasCourses: true)
        var board = HomeBoard.resolve(HomeBoardInput(day: day, name: "Léa"), locale: .fr)
        XCTAssertEqual(board.phrase.plain, "8 cartes t'attendent,\nLéa.")
        XCTAssertEqual(board.phrase.keyword, "8 cartes")
        XCTAssertEqual(board.action?.kind, .cards)
        XCTAssertEqual(board.action?.title, "Réviser mes cartes")

        day = HomeDay(hasCourses: true, lessonTitle: "La photosynthèse", lessonStep: 4, lessonStarted: true)
        board = HomeBoard.resolve(HomeBoardInput(day: day, name: "Léa", hasLesson: true), locale: .fr)
        XCTAssertEqual(board.phrase.plain, "On reprend\nLa photosynthèse ?")
        XCTAssertEqual(board.action?.kind, .lesson)
        XCTAssertEqual(board.action?.title, "Continuer · Étape 4")

        day.lessonStarted = false
        board = HomeBoard.resolve(HomeBoardInput(day: day, hasLesson: true), locale: .fr)
        XCTAssertEqual(board.action?.title, "Commencer la leçon")

        day = HomeDay(hasCourses: true, studiedToday: true)
        board = HomeBoard.resolve(HomeBoardInput(day: day, name: "Léa", hasLesson: true), locale: .fr)
        XCTAssertEqual(board.moment, .done)
        XCTAssertEqual(board.phrase.plain, "Tout est fait pour aujourd'hui.\nBravo Léa !")
        XCTAssertEqual(board.phrase.mood, .happy)
        XCTAssertEqual(board.action?.kind, .more)
        XCTAssertEqual(board.action?.title, "Réviser quand même")
    }

    /// Pendant qu'une leçon s'écrit, la jauge prend la place de l'action ; elle avance avec le
    /// vrai travail, et l'élève peut toujours abandonner.
    func testWhileWritingTheGaugeReplacesTheAction() {
        var input = HomeBoardInput(day: HomeDay(hasCourses: true), name: "Léa", phase: .running, subject: "La guerre froide")
        var board = HomeBoard.resolve(input, locale: .fr)
        XCTAssertEqual(board.moment, .generating)
        XCTAssertEqual(board.phrase.plain, "J'écris ta leçon\nLa guerre froide…")
        XCTAssertEqual(board.phrase.mood, .write)
        XCTAssertNil(board.action)
        XCTAssertEqual(board.exit?.kind, .cancel)
        let first = board.progress ?? 0
        XCTAssertGreaterThan(first, 0)

        var previous = first
        for stage in LessonBuilder.Stage.allCases.dropFirst() {
            input.stage = stage
            board = HomeBoard.resolve(input, locale: .fr)
            let value = board.progress ?? 0
            XCTAssertGreaterThan(value, previous, "\(stage)")
            XCTAssertLessThan(value, 1)
            XCTAssertFalse(board.caption?.isEmpty ?? true)
            previous = value
        }

        input.subject = nil
        XCTAssertEqual(HomeBoard.resolve(input, locale: .fr).phrase.plain, "J'écris\nta leçon…")
    }

    /// Hors ligne, en panne ou derrière Pro : toujours une seule action, et une sortie.
    func testOfflineFailedAndLockedKeepOneAction() {
        var input = HomeBoardInput(day: HomeDay(hasCourses: true), phase: .waiting, subject: "Les volcans")
        var board = HomeBoard.resolve(input, locale: .fr)
        XCTAssertEqual(board.action?.kind, .retry)
        XCTAssertEqual(board.exit?.kind, .cancel)
        XCTAssertNil(board.progress)

        input.phase = .failed("Le serveur n'a pas répondu.")
        board = HomeBoard.resolve(input, locale: .fr)
        XCTAssertEqual(board.moment, .failed)
        XCTAssertEqual(board.phrase.mood, .sad)
        XCTAssertEqual(board.action?.kind, .retry)
        XCTAssertEqual(board.caption, "Le serveur n'a pas répondu.")

        input.phase = .idle
        input.locked = HomeLockedLesson(supports: 1, pages: 4, words: 290)
        board = HomeBoard.resolve(input, locale: .fr)
        XCTAssertEqual(board.moment, .locked)
        XCTAssertEqual(board.action?.kind, .unlock)
        XCTAssertEqual(board.action?.title, "Débloquer ma leçon")
        XCTAssertEqual(board.exit?.kind, .later)
        XCTAssertTrue(board.caption?.contains("290") ?? false)
    }

    /// Chaque phrase tient en deux lignes, a un mot-clé et un seul, ne laisse aucune accolade,
    /// dans les six langues écrites ; un titre trop long est coupé.
    func testEveryPhraseHasTwoLinesAndOneKeyword() {
        let long = "La plante, productrice de matière organique et actrice des échanges gazeux"
        var inputs: [HomeBoardInput] = []
        for name in ["Léa", nil] as [String?] {
            for greeting in [HomeGreeting.Moment.morning, .day, .evening, .night] {
                inputs.append(HomeBoardInput(day: HomeDay(hasCourses: true, session: session(title: long)), name: name, greeting: greeting))
            }
            inputs.append(HomeBoardInput(day: HomeDay(dueCount: 1, hasCourses: true), name: name))
            inputs.append(HomeBoardInput(day: HomeDay(dueCount: 12, hasCourses: true), name: name))
            inputs.append(HomeBoardInput(day: HomeDay(hasCourses: true, lessonTitle: long, lessonStep: 2, lessonStarted: true), name: name))
            inputs.append(HomeBoardInput(day: HomeDay(hasCourses: true, lessonTitle: long, lessonStep: 1), name: name))
            inputs.append(HomeBoardInput(day: HomeDay(hasCourses: true, studiedToday: true), name: name))
            inputs.append(HomeBoardInput(day: HomeDay(hasCourses: true), name: name))
            inputs.append(HomeBoardInput(name: name))
            inputs.append(HomeBoardInput(day: HomeDay(hasCourses: true), name: name, phase: .running, subject: long))
            inputs.append(HomeBoardInput(day: HomeDay(hasCourses: true), name: name, phase: .running))
            inputs.append(HomeBoardInput(day: HomeDay(hasCourses: true), name: name, phase: .waiting))
            inputs.append(HomeBoardInput(day: HomeDay(hasCourses: true), name: name, phase: .failed("x")))
            inputs.append(HomeBoardInput(day: HomeDay(hasCourses: true), name: name, locked: HomeLockedLesson(supports: 2, pages: 0, words: 120)))
        }
        for locale in Self.written {
            for input in inputs {
                let board = HomeBoard.resolve(input, locale: locale)
                let marked = board.phrase.marked
                let context = "\(locale.rawValue) \(board.moment.rawValue) : \(marked)"
                XCTAssertEqual(marked.components(separatedBy: "\n").count, 2, context)
                XCTAssertEqual(marked.components(separatedBy: "**").count, 3, context)
                XCTAssertNotNil(board.phrase.keyword, context)
                XCTAssertFalse(marked.contains("{") || marked.contains("}"), context)
                XCTAssertFalse(marked.contains(long), "un titre long est coupé : \(context)")
                // Jamais deux choses à la fois : une action, ou la jauge.
                XCTAssertFalse(board.action != nil && board.progress != nil, context)
            }
        }
    }

    func testKeywordsAreClipped() {
        XCTAssertEqual(HomeBoard.clip("La guerre froide"), "La guerre froide")
        let clipped = HomeBoard.clip("La plante, productrice de matière organique et actrice des échanges")
        XCTAssertLessThanOrEqual(clipped.count, HomeBoard.keywordLimit)
        XCTAssertTrue(clipped.hasSuffix("…"))
        XCTAssertEqual(HomeBoard.clip("  Deux\nlignes "), "Deux lignes")
    }

    // MARK: - La pastille de l'examen

    func testTheExamPillCountsDownOrInvites() {
        let pill = HomeExamPill.resolve(HomeExam(name: "Histoire", daysLeft: 12, readiness: nil), locale: .fr)
        XCTAssertEqual(pill.text, "Histoire · J-12")
        XCTAssertTrue(pill.hasExam)
        XCTAssertEqual(HomeExamPill.resolve(HomeExam(name: "Histoire", daysLeft: 0, readiness: nil), locale: .fr).text, "Histoire · Aujourd'hui")
        let none = HomeExamPill.resolve(nil, locale: .fr)
        XCTAssertEqual(none.text, "Ajouter mon examen")
        XCTAssertFalse(none.hasExam)
        XCTAssertEqual(ExamCountdown.label(daysLeft: 12, locale: .de), "noch 12 Tage")
    }

    // MARK: - Les raccourcis

    /// « Focus » d'abord ; le quiz demande une leçon, les cartes des cartes dues ; le nouvel
    /// élève voit les trois façons de donner son premier cours.
    func testShortcutsStartWithFocus() {
        XCTAssertEqual(
            HomeShortcut.available(isNewcomer: false, hasLesson: true, dueCount: 8),
            [.focus, .scan, .quiz, .cards, .importSource, .writing, .mock]
        )
        XCTAssertEqual(
            HomeShortcut.available(isNewcomer: false, hasLesson: false, dueCount: 0),
            [.focus, .scan, .importSource, .writing, .mock]
        )
        XCTAssertEqual(
            HomeShortcut.available(isNewcomer: true, hasLesson: false, dueCount: 0),
            [.photo, .pdf, .youtube, .focus, .scan]
        )
        XCTAssertEqual(HomeShortcut.cards.title(dueCount: 8, locale: .fr), "Cartes · 8")
        XCTAssertEqual(HomeShortcut.focus.title(locale: .fr), "Focus")
        XCTAssertEqual(HomeShortcut.scan.title(locale: .fr), "Scanner")
        XCTAssertEqual(HomeShortcut.scan.spokenTitle(locale: .fr), "Scanner un exo")
        XCTAssertEqual(HomeShortcut.photo.source, .photo)
        XCTAssertEqual(HomeShortcut.pdf.source, .pdf)
        XCTAssertEqual(HomeShortcut.youtube.source, .youtube)
        XCTAssertNil(HomeShortcut.focus.source)
    }

    /// Les noms envoyés aux statistiques sont des valeurs fixes, toutes différentes.
    func testShortcutAnalyticsNamesAreFixed() {
        XCTAssertEqual(
            HomeShortcut.allCases.map(\.analyticsName),
            ["focus", "scan", "quiz", "cards", "import", "writing", "mock", "photo", "pdf", "youtube", "chats"]
        )
        XCTAssertEqual(Set(HomeAction.Kind.allCases.map { HomeAction(kind: $0, title: "", symbol: "").analyticsStep }).count, HomeAction.Kind.allCases.count - 1,
                       "« créer » et « première leçon » partagent le nom historique `create`")
    }

    // MARK: - Rien d'introuvable

    /// Ce qui a quitté la Home reste à un geste : les cartes dues (la puce), l'examen blanc et
    /// l'import (les puces), le Calendrier (la pastille d'examen), la Concentration (Focus).
    func testWhatLeftHomeStaysOneTapAway() {
        let active = HomeShortcut.available(isNewcomer: false, hasLesson: true, dueCount: 3)
        for needed in [HomeShortcut.focus, .scan, .quiz, .cards, .importSource, .writing, .mock] {
            XCTAssertTrue(active.contains(needed), needed.rawValue)
        }
        // La pastille d'examen existe toujours : elle mène au Calendrier, avec ou sans examen.
        XCTAssertFalse(HomeExamPill.resolve(nil, locale: .fr).text.isEmpty)
        // Les cinq onglets restent : Accueil, Leçons, Calendrier, Focus, Profil.
        XCTAssertEqual(RootTab.tabs, [.today, .decks, .calendar, .focus, .profile])
    }

    /// La leçon range tout dans une grille : six tuiles, deux rangées égales de trois, et chaque
    /// mode de révision y a la sienne. « Écouter » et « À voix haute » sont retirés (lot 11).
    func testTheLessonGridHoldsEveryWayToStudy() {
        XCTAssertEqual(LessonTool.allCases, [.notes, .quiz, .cards, .mika, .mindMap, .sheet])
        XCTAssertEqual(LessonTool.rows(columns: 3).map(\.count), [3, 3])
        XCTAssertEqual(LessonTool.rows(columns: 2).map(\.count), [2, 2, 2])
        XCTAssertEqual(Set(LessonTool.allCases.compactMap(\.revision)), Set(RevisionMode.allCases))
        // Notes, Quiz, Cartes et Mika s'ouvrent toujours : leur tuile n'a pas de porte.
        for tool in [LessonTool.notes, .quiz, .cards, .mika] {
            XCTAssertNil(tool.revision, tool.rawValue)
        }
    }

    // MARK: - Un nom par chose

    func testEachThingHasOneFrenchName() {
        let names = Dictionary(uniqueKeysWithValues: MicaboName.allCases.map { ($0, $0.text(locale: .fr)) })
        XCTAssertEqual(names[.notes], "Notes")
        XCTAssertEqual(names[.quiz], "Quiz")
        XCTAssertEqual(names[.cards], "Cartes")
        XCTAssertEqual(names[.mika], "Mika")
        XCTAssertEqual(names[.mindMap], "Carte mentale")
        XCTAssertEqual(names[.sheet], "Fiche PDF")
        XCTAssertEqual(names[.mock], "Examen blanc")
        XCTAssertEqual(names[.scan], "Scanner un exo")
        XCTAssertEqual(names[.writing], "Corriger un texte")
        XCTAssertEqual(names[.quickQuiz], "Quiz éclair")
        XCTAssertEqual(names[.focus], "Focus")
    }

    /// Dans chaque langue écrite, deux choses n'ont jamais le même nom, et aucun nom n'est vide.
    func testNamesAreDistinctInEveryWrittenLanguage() {
        for locale in Self.written {
            let names = MicaboName.allCases.map { $0.text(locale: locale) }
            XCTAssertEqual(Set(names).count, names.count, "\(locale.rawValue) : \(names)")
            for name in names {
                XCTAssertFalse(name.isEmpty || name.contains("ios.") || name.contains("lesson."), "\(locale.rawValue) : \(name)")
            }
        }
    }

    /// Les tuiles d'une leçon, l'onglet et la page de la Concentration lisent le même nom.
    func testScreensReadTheSameNames() {
        for locale in UiLocale.allCases {
            let focus = MicaboName.focus.text(locale: locale)
            XCTAssertEqual(RootTab.focus.label(t: { L10n.t($0, locale: locale) }), focus, locale.rawValue)
            XCTAssertEqual(L10n.t("ios.focus.title", locale: locale), focus, locale.rawValue)
        }
        XCTAssertEqual(LessonTool.cards.name, .cards)
        XCTAssertEqual(LessonTool.sheet.name, .sheet)
        XCTAssertEqual(L10n.t("ios.cal.planMenu", locale: .fr), "Plan de révisions")
    }

    /// Les anciens mots ne sont plus appelés par le code : « Entraînement », « Revoir mes
    /// flashcards », « Aide aux devoirs », « Cercle ».
    func testRetiredWordsAreNoLongerCalled() throws {
        let retired = [
            "lesson.practice.title", "lesson.finished.cards", "ios.ku7.tools.homework", "lesson.path.circleNumber",
            "lesson.cards.empty", "lesson.quiz.missedBecomeCards", "lesson.menu.resetMessage", "ios.sup.voice.empty",
            "ios.sup.modes.listen", "ios.sup.modes.voice", "ios.home10.intro.listen", "ios.sup.voice.speak",
            "lesson.exam.addCards", "lesson.lessons.circle", "lesson.home.resumeCircle",
        ]
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Micabo", isDirectory: true)
        guard let files = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil) else {
            throw XCTSkip("les sources ne sont pas lisibles depuis ce simulateur")
        }
        var read = 0
        var offenders: [String] = []
        for case let url as URL in files where url.pathExtension == "swift" {
            guard !url.path.contains("/Services/I18n/"),
                  let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            read += 1
            for key in retired where text.contains("\"\(key)\"") {
                offenders.append("\(url.lastPathComponent) : \(key)")
            }
        }
        guard read > 0 else { throw XCTSkip("aucune source lue") }
        XCTAssertEqual(offenders.sorted(), [])
    }

    // MARK: - La première ouverture d'un outil

    func testEachToolIntroducesItselfOnce() throws {
        let suite = "home10.intro.tests"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        for tool in ToolIntro.allCases {
            XCTAssertTrue(ToolIntro.isFirstOpen(tool, defaults: defaults), tool.rawValue)
            ToolIntro.markOpened(tool, defaults: defaults)
            XCTAssertFalse(ToolIntro.isFirstOpen(tool, defaults: defaults), tool.rawValue)
        }
        for locale in Self.written {
            let phrases = ToolIntro.allCases.map { $0.text(locale: locale) }
            XCTAssertEqual(Set(phrases).count, phrases.count, locale.rawValue)
            for phrase in phrases {
                XCTAssertFalse(phrase.contains("ios.home10"), "\(locale.rawValue) : \(phrase)")
                // Une phrase, pas un tutoriel.
                XCTAssertLessThanOrEqual(phrase.count, 90, "\(locale.rawValue) : \(phrase)")
            }
        }
    }

    // MARK: - L'en-tête et la leçon qui s'écrit

    /// À gauche de l'en-tête : « PRO » seul pour un abonné, la pastille de l'offre tant qu'elle
    /// court, sinon « Passer en PRO ». Un abonné ne voit jamais l'offre.
    func testTheHeaderShowsProTheOfferOrTheUpgrade() {
        XCTAssertEqual(HomeProEntry.resolve(isPro: true, offerIsLive: false), .member)
        XCTAssertEqual(HomeProEntry.resolve(isPro: true, offerIsLive: true), .member)
        XCTAssertEqual(HomeProEntry.resolve(isPro: false, offerIsLive: true), .offer)
        XCTAssertEqual(HomeProEntry.resolve(isPro: false, offerIsLive: false), .upgrade)
    }

    /// Chaque puce a son pictogramme : une icône de la famille, ou un symbole dans sa couleur.
    func testEveryShortcutHasItsIcon() {
        for shortcut in HomeShortcut.allCases {
            XCTAssertFalse(shortcut.symbol.isEmpty, shortcut.rawValue)
            XCTAssertTrue(shortcut.icon != nil || shortcut.tone != nil, "\(shortcut.rawValue) : ni icône ni couleur")
            for locale in Self.written {
                XCTAssertFalse(shortcut.title(dueCount: 3, locale: locale).isEmpty, "\(locale.rawValue) \(shortcut.rawValue)")
                XCTAssertFalse(shortcut.spokenTitle(dueCount: 3, locale: locale).contains("{"), "\(locale.rawValue) \(shortcut.rawValue)")
            }
        }
    }

    /// Hors ligne, la demande attend au lieu de partir ; l'abandonner rend la main, et ce que
    /// l'élève avait tapé reste dans la barre.
    func testOfflineALessonWaitsAndCanBeCancelled() throws {
        let container = try ModelContainer(
            for: Course.self, CourseFolder.self, Chapter.self, Flashcard.self, ReviewLog.self, Exam.self, OffDay.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let composer = LessonComposer()
        composer.draft = "  La guerre froide "
        let generation = LessonGeneration()
        XCTAssertFalse(generation.isBusy)

        generation.start(
            composer: composer,
            builder: LessonBuilder(),
            context: ModelContext(container),
            examDate: nil,
            sendsAsFreeLesson: false,
            online: false
        )
        XCTAssertEqual(generation.phase, .waiting)
        XCTAssertTrue(generation.isBusy)
        XCTAssertEqual(generation.subject, "La guerre froide")
        XCTAssertFalse(generation.hasSupports)
        XCTAssertNil(generation.takeDelivered())
        XCTAssertNil(generation.takeRefusal())

        generation.cancel()
        XCTAssertEqual(generation.phase, .idle)
        XCTAssertFalse(generation.isBusy)
        XCTAssertNil(generation.subject)
        XCTAssertEqual(composer.draft, "  La guerre froide ", "ce que l'élève a tapé reste dans la barre")

        // Sans demande en attente, « Réessayer » et le retour du réseau ne lancent rien.
        generation.retry()
        generation.networkReturned()
        XCTAssertEqual(generation.phase, .idle)
    }

    // MARK: - L'onglet Leçons

    private func lesson(done: [String], finished: Bool = false) throws -> (ModelContainer, Course) {
        let container = try ModelContainer(
            for: Course.self, CourseFolder.self, Chapter.self, Flashcard.self, ReviewLog.self, Exam.self, OffDay.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let course = Course(title: "La guerre froide", subject: "Histoire")
        context.insert(course)
        for index in 0..<3 {
            let chapter = Chapter(position: index, title: "Thème \(index + 1)", course: course)
            chapter.statusRaw = ThemeStatus.ready.rawValue
            context.insert(chapter)
        }
        course.setLessonPath(LessonPath(
            icon: MicaboIcon.globe.rawValue,
            intro: LessonPath.Intro(lines: ["Un", "Deux"], minutes: 15),
            takeaways: [],
            groups: [LessonPath.Group(name: "", themes: [0, 1, 2])],
            status: .ready
        ))
        let circles = course.pathSteps().compactMap(\.circle)
        course.updateProgress { progress in
            progress.done = finished ? Set(circles.map(\.id)) : Set(done)
            if finished { progress.finishedAt = Date() }
        }
        try context.save()
        return (container, course)
    }

    /// Une carte de leçon dit « Étape k sur n », puis « Terminée » : le mot « cercle » a disparu.
    func testALessonCardSaysItsStepThenFinished() throws {
        let (first, going) = try lesson(done: ["intro", "notes:0"])
        _ = first
        let total = going.pathSteps().compactMap(\.circle).count
        let summary = LessonCardSummary(course: going, locale: .fr)
        XCTAssertEqual(summary.caption, "Étape 3 sur \(total)")
        XCTAssertGreaterThan(summary.percent, 0)
        XCTAssertLessThan(summary.percent, 100)

        let (second, done) = try lesson(done: [], finished: true)
        _ = second
        let finished = LessonCardSummary(course: done, locale: .fr)
        XCTAssertEqual(finished.caption, "Terminée")
        XCTAssertEqual(finished.percent, 100)
    }

    /// « Nouvelle leçon », depuis l'onglet Leçons, ramène à la Home et y demande la feuille des
    /// sources : une demande comptée, pas une minuterie.
    func testNewLessonFromTheLessonsTabAsksHome() {
        let router = TabRouter()
        router.selection = .decks
        let before = router.lessonCreationRequests
        router.requestLessonCreation()
        XCTAssertEqual(router.selection, .today)
        XCTAssertEqual(router.lessonCreationRequests, before + 1)
    }
}
