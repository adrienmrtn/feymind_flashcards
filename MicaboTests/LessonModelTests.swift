import SwiftData
import XCTest
@testable import Micabo

/// Le chemin d'une leçon, toujours construit de la même façon (`docs/refonte-parcours.md` § 5.1).
final class PathLayoutTests: XCTestCase {
    private func themes(_ count: Int) -> [PathTheme] {
        (0..<count).map { PathTheme(title: "Thème \($0 + 1)", icon: .book) }
    }

    /// 4 thèmes font 7 étapes, 6 en font 10, 12 en font 17 : Intro, les thèmes, un Checkpoint
    /// par palier sauf le dernier, le Quiz final.
    func testTheStepCounts() {
        XCTAssertEqual(PathLayout.circles(themes: themes(4)).count, 7)
        XCTAssertEqual(PathLayout.circles(themes: themes(6)).count, 10)
        XCTAssertEqual(PathLayout.circles(themes: themes(12)).count, 17)
    }

    func testGroupsOfTwoThenThreeBeyondEight() {
        XCTAssertEqual(PathLayout.groups(themeCount: 4).map(\.count), [2, 2])
        XCTAssertEqual(PathLayout.groups(themeCount: 5).map(\.count), [2, 3], "le dernier quiz couvre les 3 derniers")
        XCTAssertEqual(PathLayout.groups(themeCount: 7).map(\.count), [2, 2, 3])
        XCTAssertEqual(PathLayout.groups(themeCount: 8).map(\.count), [2, 2, 2, 2])
        XCTAssertEqual(PathLayout.groups(themeCount: 9).map(\.count), [3, 3, 3])
        XCTAssertEqual(PathLayout.groups(themeCount: 10).map(\.count), [3, 3, 2, 2])
        XCTAssertEqual(PathLayout.groups(themeCount: 11).map(\.count), [3, 3, 3, 2])
        XCTAssertEqual(PathLayout.groups(themeCount: 12).map(\.count), [3, 3, 3, 3])
    }

    /// Un ancien cours peut avoir de 1 à 30 chapitres : chaque thème est dans un groupe, une
    /// seule fois, dans l'ordre, et aucun quiz ne couvre plus de 3 thèmes.
    func testEveryThemeCountIsCoveredInOrder() {
        for count in 1...30 {
            let groups = PathLayout.groups(themeCount: count)
            XCTAssertEqual(groups.flatMap { $0 }, Array(0..<count), "\(count) thèmes")
            XCTAssertLessThanOrEqual(groups.map(\.count).max() ?? 0, 3, "\(count) thèmes")
        }
        XCTAssertEqual(PathLayout.groups(themeCount: 0), [])
    }

    func testAVeryShortLessonGoesStraightToTheFinalQuiz() {
        let circles = PathLayout.circles(themes: themes(4), singleQuiz: true)
        XCTAssertEqual(circles.map(\.id), ["intro", "notes:0", "notes:1", "notes:2", "notes:3", "final"])
    }

    func testThePathReadsLikeTheReference() {
        let steps = PathLayout.steps(themes: themes(4), groupNames: ["Les causes", "Les suites"])
        XCTAssertEqual(steps.map(\.id), ["intro", "notes:0", "notes:1", "quiz:0", "notes:2", "notes:3", "final"])
        let circles = steps.compactMap(\.circle)
        XCTAssertEqual(circles.map(\.number), Array(1...7), "« ÉTAPE 4 » se compte sur le chemin")
        XCTAssertEqual(circles[1].title, "Thème 1")
        XCTAssertEqual(circles[3].subtitle, "Les causes", "le Checkpoint dit le palier qu'il conclut")
        XCTAssertTrue(circles[3].isMilestone)
        XCTAssertFalse(circles[1].isMilestone)
        if case .quiz(_, let covered) = circles[3].kind {
            XCTAssertEqual(covered, [0, 1], "le Checkpoint porte sur les thèmes qui le précèdent")
        } else {
            XCTFail("la quatrième étape est le premier Checkpoint")
        }
        if case .final(let covered) = circles[6].kind {
            XCTAssertEqual(covered, [0, 1, 2, 3], "le Quiz final reprend toute la leçon")
        } else {
            XCTFail("la dernière étape est le Quiz final")
        }
    }

    /// Une progression d'avant le Quiz final ne perd pas sa fin.
    func testAnOldProgressKeepsItsEnd() {
        let circles = PathLayout.circles(themes: themes(4))
        XCTAssertTrue(PathLayout.migrated(done: ["conclusion"], circles: circles, finished: false).contains("final"))
        XCTAssertTrue(PathLayout.migrated(done: ["quiz:1"], circles: circles, finished: false).contains("final"), "le quiz du dernier palier valait la fin")
        XCTAssertTrue(PathLayout.migrated(done: [], circles: circles, finished: true).contains("final"))
        XCTAssertFalse(PathLayout.migrated(done: ["quiz:0"], circles: circles, finished: false).contains("final"))
    }

    func testEveryStepHasADifferentSymbol() {
        let themes = (0..<12).map { PathTheme(title: "T\($0)", icon: .book, symbol: PathSymbol.unique(Array(repeating: "flag", count: 12))[$0]) }
        let circles = PathLayout.circles(themes: themes)
        let symbols = circles.map(\.symbol)
        XCTAssertEqual(Set(symbols).count, symbols.count, "jamais deux ronds pareils")
    }

    /// On ne saute pas : seul le premier cercle non coché est « en cours ».
    func testOnlyTheFirstUndoneCircleIsCurrent() {
        let circles = PathLayout.circles(themes: themes(4))
        let done: Set<String> = ["intro", "notes:0"]
        XCTAssertEqual(PathLayout.current(in: circles, done: done)?.id, "notes:1")
        XCTAssertEqual(PathLayout.state(of: circles[0], in: circles, done: done), .done)
        XCTAssertEqual(PathLayout.state(of: circles[2], in: circles, done: done), .current)
        XCTAssertEqual(PathLayout.state(of: circles[3], in: circles, done: done), .upcoming)
        XCTAssertNil(PathLayout.current(in: circles, done: Set(circles.map(\.id))))
    }
}

/// Les formats JSON de la leçon : ce que le serveur écrit, l'app le lit, et inversement.
final class LessonFormatTests: XCTestCase {
    func testThemeNotesReadEveryBlockTheServerWrites() throws {
        let json = """
        {"oneLiner":"Deux blocs s'opposent sans guerre directe.",
         "blocks":[
           {"type":"subtitle","text":"Deux camps"},
           {"type":"paragraph","text":"Les **États-Unis** et l'**URSS** s'opposent."},
           {"type":"list","items":["Plan Marshall","Doctrine Truman","Kominform"]},
           {"type":"definition","term":"Endiguement","text":"Contenir l'expansion soviétique."},
           {"type":"dates","items":[{"date":"1947","text":"Doctrine Truman"},{"date":"1989","text":"Chute du Mur"}]},
           {"type":"formula","latex":"E = mc^2","caption":"Einstein"},
           {"type":"example","text":"Berlin, 1948."},
           {"type":"carousel","text":"Un bloc d'une version future."}
         ],
         "takeaways":["Un","Deux","Trois"]}
        """
        let notes = try XCTUnwrap(ThemeNotes.decode(from: Data(json.utf8)))
        XCTAssertEqual(notes.blocks.count, 8)
        XCTAssertEqual(notes.blocks[0], .subtitle("Deux camps"))
        XCTAssertEqual(notes.blocks[3], .definition(term: "Endiguement", text: "Contenir l'expansion soviétique."))
        XCTAssertEqual(notes.blocks[7], .paragraph("Un bloc d'une version future."), "un bloc inconnu se lit comme un paragraphe")
        XCTAssertTrue(notes.blocks[5].isBoxed)
        XCTAssertFalse(notes.plainText.contains("**"))

        let again = try XCTUnwrap(ThemeNotes.decode(from: notes.encoded()))
        XCTAssertEqual(again, notes)
    }

    /// Les formes `steps`, `table` et `quote` : leur champ `text` de repli est pour les
    /// anciennes versions, l'app le lit seulement quand le bloc est incomplet.
    func testTheNewBlocksReadTheirOwnFieldsAndRoundTrip() throws {
        let json = """
        {"oneLiner":"Une idée.",
         "blocks":[
           {"type":"steps","items":["Lire l'énoncé","Poser $x^2 = 4$"],"text":"1. Lire 2. Poser"},
           {"type":"table","columns":["Pays","Capitale"],"rows":[["France","Paris"],["Italie","Rome"]],"text":"France : Paris"},
           {"type":"quote","text":"Je pense, donc je suis.","author":"Descartes"},
           {"type":"quote","text":"Sans auteur.","author":"  "},
           {"type":"steps","items":[],"text":"Repli lisible."}
         ],
         "takeaways":["Un"]}
        """
        let notes = try XCTUnwrap(ThemeNotes.decode(from: Data(json.utf8)))
        XCTAssertEqual(notes.blocks, [
            .steps(["Lire l'énoncé", "Poser $x^2 = 4$"]),
            .table(columns: ["Pays", "Capitale"], rows: [["France", "Paris"], ["Italie", "Rome"]]),
            .quote(text: "Je pense, donc je suis.", author: "Descartes"),
            .quote(text: "Sans auteur.", author: nil),
            .paragraph("Repli lisible.")
        ])
        XCTAssertTrue(notes.blocks[0].isBoxed)
        XCTAssertTrue(notes.blocks[1].isBoxed)
        XCTAssertTrue(notes.blocks[2].isBoxed)
        XCTAssertTrue(notes.plainText.contains("2. Poser"))
        XCTAssertTrue(notes.plainText.contains("France | Paris"))

        let again = try XCTUnwrap(ThemeNotes.decode(from: notes.encoded()))
        XCTAssertEqual(again, notes)
    }

    /// L'encadré (`callout`) : son genre, son titre facultatif, son texte. Un genre inconnu se
    /// lit comme une astuce ; sans texte, il disparaît.
    func testCalloutsReadTheirKindAndTitleAndRoundTrip() throws {
        let json = """
        {"oneLiner":"Une idée.",
         "blocks":[
           {"type":"callout","kind":"mistake","title":"Le piège du signe","text":"On oublie le **signe moins**."},
           {"type":"callout","kind":"why","text":"Parce que la vitesse change."},
           {"type":"callout","kind":"remember","title":"  ","text":"Toujours l'unité."},
           {"type":"callout","kind":"carousel","text":"Un genre d'une version future."},
           {"type":"callout","text":"Sans genre."},
           {"type":"callout","kind":"tip","title":"Sans texte"},
           {"type":"callout","kind":"tip","text":"   "}
         ],
         "takeaways":[]}
        """
        let notes = try XCTUnwrap(ThemeNotes.decode(from: Data(json.utf8)))
        XCTAssertEqual(notes.blocks, [
            .callout(kind: .mistake, title: "Le piège du signe", text: "On oublie le **signe moins**."),
            .callout(kind: .why, title: nil, text: "Parce que la vitesse change."),
            .callout(kind: .remember, title: nil, text: "Toujours l'unité."),
            .callout(kind: .tip, title: nil, text: "Un genre d'une version future."),
            .callout(kind: .tip, title: nil, text: "Sans genre.")
        ])
        XCTAssertTrue(notes.blocks.allSatisfy(\.isBoxed))
        XCTAssertTrue(notes.plainText.contains("Le piège du signe : On oublie le signe moins."))

        let again = try XCTUnwrap(ThemeNotes.decode(from: notes.encoded()))
        XCTAssertEqual(again, notes)

        // Le serveur écrit toujours `text` : c'est aussi ce qu'une app d'avant lit.
        let encoded = try XCTUnwrap(notes.encoded())
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let first = try XCTUnwrap((object["blocks"] as? [[String: Any]])?.first)
        XCTAssertEqual(first["type"] as? String, "callout")
        XCTAssertEqual(first["kind"] as? String, "mistake")
        XCTAssertEqual(first["title"] as? String, "Le piège du signe")
        XCTAssertEqual(first["text"] as? String, "On oublie le **signe moins**.")
    }

    /// Chaque genre d'encadré a son titre traduit, et son pictogramme.
    @MainActor
    func testEveryCalloutKindHasATitleAndASymbol() {
        for kind in CalloutKind.allCases {
            XCTAssertNotNil(LessonI18nCatalogs.fr[kind.titleKey], kind.rawValue)
            XCTAssertNotNil(LessonI18nCatalogs.en[kind.titleKey], kind.rawValue)
            XCTAssertFalse(kind.promptLabel.isEmpty)
        }
        XCTAssertEqual(L10n.t(CalloutKind.mistake.titleKey, locale: .en), "Common mistake")
        XCTAssertEqual(Set(CalloutKind.allCases.map { NoteCallout.symbol(for: $0) }).count, CalloutKind.allCases.count)
    }

    /// Un bloc illisible disparaît : ni trou blanc, ni notes perdues.
    func testAnUnreadableBlockIsSkippedNotShownEmpty() throws {
        let json = """
        {"oneLiner":"Une idée.",
         "blocks":[
           {"type":"carousel"},
           {"type":"paragraph","text":"  "},
           {"type":"table","columns":["A"],"text":""},
           {"type":"definition","term":"Sans texte"},
           {"type":"paragraph","text":"Reste."}
         ],
         "takeaways":[]}
        """
        let notes = try XCTUnwrap(ThemeNotes.decode(from: Data(json.utf8)))
        XCTAssertEqual(notes.blocks, [.paragraph("Reste.")])
    }

    @MainActor
    func testInlineFormulasAreTransposedInNotesText() {
        let text = String(KeywordText.attributed("L'aire vaut $\\pi r^2$ et **E = mc^2**.").characters)
        XCTAssertFalse(text.contains("$"))
        XCTAssertFalse(text.contains("\\pi"))
        XCTAssertTrue(text.contains("π"))
        XCTAssertFalse(text.contains("**"))
        XCTAssertEqual(KeywordText.plain("**Δ** vaut $b^2 - 4ac$"), FormulaRenderer.stripped("Δ vaut $b^2 - 4ac$"))
    }

    func testTheNotesRhythmKeepsASubtitleWithItsBlock() {
        XCTAssertEqual(NoteRhythm.spacing(before: .paragraph("a"), after: nil), 0)
        XCTAssertEqual(NoteRhythm.spacing(before: .paragraph("a"), after: .subtitle("s")), NoteRhythm.afterSubtitle)
        XCTAssertEqual(NoteRhythm.spacing(before: .subtitle("s"), after: .paragraph("a")), NoteRhythm.beforeSubtitle)
        XCTAssertEqual(NoteRhythm.spacing(before: .list(["x"]), after: .paragraph("a")), NoteRhythm.between)
        XCTAssertLessThan(NoteRhythm.afterSubtitle, NoteRhythm.between)
    }

    func testThePathRoundTrips() throws {
        let path = LessonPath(
            icon: "globe",
            intro: .init(lines: ["Un", "Deux", "Trois"], minutes: 25),
            takeaways: ["A", "B", "C", "D", "E"],
            groups: [.init(name: "Les causes", themes: [0, 1])],
            status: .ready
        )
        XCTAssertEqual(LessonPath.decode(from: path.encoded()), path)
        XCTAssertNil(LessonPath.decode(from: nil))
        XCTAssertNil(LessonPath.decode(from: Data("{".utf8)))
    }

    func testTheQuizSplitsTheFinalQuestionFromTheReserve() {
        let questions = (0..<4).map {
            QuizQuestion(id: "t:\($0)", prompt: "Q\($0)", choices: ["a", "b", "c", "d"], answer: 1, why: "parce que")
        }
        let quiz = ThemeQuiz(questions: questions)
        XCTAssertEqual(quiz.final?.id, "t:0")
        XCTAssertEqual(quiz.reserve.map(\.id), ["t:1", "t:2", "t:3"])
        XCTAssertEqual(ThemeQuiz.decode(from: quiz.encoded()), quiz)
        XCTAssertTrue(questions[0].isValid)
        XCTAssertFalse(QuizQuestion(id: "x", prompt: "Q", choices: ["a"], answer: 3, why: "").isValid)
    }

    func testProgressKeepsTimeScoresAndMisses() throws {
        var progress = LessonProgress()
        progress.done = ["intro", "notes:0"]
        progress.addTime(120, to: .notes)
        progress.addTime(60, to: .quiz)
        progress.addTime(-5, to: .quiz)
        progress.addTime(10 * 3600, to: .quiz)
        progress.quizScores = ["quiz:0": [4, 5], "quiz:1": [3, 5]]
        progress.noteMissed("a")
        progress.noteMissed("b")
        progress.noteMissed("a")
        progress.noteRight("b")
        progress.finishedAt = Date(timeIntervalSince1970: 1_800_000_000)

        XCTAssertEqual(progress.totalSeconds, 180, "un temps négatif ou absurde ne compte pas")
        XCTAssertEqual(progress.averageQuizPercent, 70)
        XCTAssertEqual(progress.missed, ["a"])

        let decoded = LessonProgress.decode(from: progress.encoded())
        XCTAssertEqual(decoded, progress)
        XCTAssertEqual(LessonProgress.decode(from: nil), LessonProgress())
    }
}

/// Un cours vu comme une leçon.
final class CourseLessonTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: Course.self, Chapter.self, Flashcard.self, ReviewLog.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
    }

    func testAnOldCourseHasAStableToneAndAGuessedIcon() {
        let course = Course(title: "La guerre froide", subject: "Histoire")
        XCTAssertFalse(course.isLesson)
        XCTAssertEqual(course.tone, LessonTone.stable(for: course.id))
        XCTAssertEqual(course.icon, .scroll)
        course.iconID = "globe"
        course.toneRaw = LessonTone.mint.rawValue
        XCTAssertEqual(course.icon, .globe)
        XCTAssertEqual(course.tone, .mint)
    }

    func testIconGuessesTheSubject() {
        XCTAssertEqual(MicaboIcon.guess(subject: "Mathématiques", title: ""), .calculator)
        XCTAssertEqual(MicaboIcon.guess(subject: "Physique-chimie", title: ""), .atom)
        XCTAssertEqual(MicaboIcon.guess(subject: nil, title: "Chimie organique"), .flask)
        XCTAssertEqual(MicaboIcon.guess(subject: "Géographie", title: ""), .globe)
        XCTAssertEqual(MicaboIcon.guess(subject: "Tarih", title: ""), .scroll)
        XCTAssertEqual(MicaboIcon.guess(subject: nil, title: "Quelque chose"), .book)
    }

    func testProgressUpdatesDateTheCourse() throws {
        let course = Course(title: "Leçon")
        context.insert(course)
        let before = course.updatedAt
        course.updateProgress { $0.done.insert("intro") }
        XCTAssertEqual(course.progress.done, ["intro"])
        XCTAssertGreaterThanOrEqual(course.updatedAt, before)
    }

    /// Une flashcard apprise : son prochain rappel est à plus de sept jours.
    func testLearnedCardsAreDueInMoreThanAWeek() throws {
        let course = Course(title: "Leçon")
        context.insert(course)
        let now = Date()
        for (index, days) in [0.0, 3, 8, 30].enumerated() {
            let card = Flashcard(front: "Q\(index)", back: "R", position: index, course: course)
            context.insert(card)
            card.state = days == 0 ? .new : .review
            card.dueDate = now.addingTimeInterval(days * 86_400)
        }
        XCTAssertEqual(course.learnedCardCount(now: now), 2)
    }

    /// Un encadré reste sur l'écran du bloc qu'il commente ; un encadré en tête a le sien.
    func testACalloutStaysOnTheScreenOfTheBlockItComments() throws {
        let course = Course(title: "Leçon")
        context.insert(course)
        let chapter = Chapter(position: 0, title: "Thème", course: course)
        context.insert(chapter)
        chapter.notesData = ThemeNotes(
            oneLiner: "Une idée.",
            blocks: [
                .callout(kind: .why, title: nil, text: "Pourquoi."),
                .paragraph("Le mécanisme."),
                .callout(kind: .mistake, title: nil, text: "Le piège."),
                .subtitle("Partie deux"),
                .paragraph("La suite."),
                .callout(kind: .tip, title: nil, text: "L'astuce."),
                .example("Un cas.")
            ],
            takeaways: ["Un"]
        ).encoded()
        XCTAssertEqual(NotesPage.pages(for: chapter, hasQuestion: true), [
            .opening,
            .blocks(0..<1),
            .blocks(1..<3),
            .blocks(3..<6),
            .blocks(6..<7),
            .takeaways,
            .question
        ])
    }

    func testThePathOfALessonFollowsItsChapters() throws {
        let course = Course(title: "Leçon")
        context.insert(course)
        for index in 0..<4 {
            let chapter = Chapter(position: index, title: "Thème \(index + 1)", course: course)
            chapter.iconID = "ampoule"
            context.insert(chapter)
        }
        course.setLessonPath(LessonPath(
            icon: "globe",
            intro: .init(lines: [], minutes: 20),
            takeaways: [],
            groups: [.init(name: "Un", themes: [0, 1]), .init(name: "Deux", themes: [2, 3])]
        ))
        let steps = course.pathSteps()
        XCTAssertEqual(steps.count, 7)
        let circles = steps.compactMap(\.circle)
        XCTAssertEqual(circles[1].icon, .lightbulb)
        XCTAssertEqual(circles[1].symbol, "lightbulb", "une leçon d'avant les pictogrammes en reçoit d'après ses icônes")
        XCTAssertNotEqual(circles[2].symbol, circles[1].symbol)
        XCTAssertEqual(circles[3].subtitle, "Un")
    }
}

/// Ce qui voyage vers la base : la leçon, et la langue qui ne partait pas.
final class LessonSyncRecordTests: XCTestCase {
    private func keys(of record: some Encodable) throws -> Set<String> {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let object = try JSONSerialization.jsonObject(with: encoder.encode(record)) as? [String: Any]
        return Set(object?.keys.map { $0 } ?? [])
    }

    private func course(path: JSONCodable? = nil, language: String? = nil) -> CourseRecord {
        CourseRecord(
            id: UUID(), user_id: UUID(), title: "T", subject: nil, summary: "", emoji: nil,
            accent_hex: nil, source: "text", source_file_name: nil, language: language,
            fingerprint: "", raw_text: "", sheet: nil, context_text: "", is_from_library: false,
            visibility: "standard", created_at: Date(), updated_at: Date(), deleted_at: nil,
            folder_id: nil, path: path, tone: path == nil ? nil : "mint"
        )
    }

    func testTheLanguageNowTravels() throws {
        XCTAssertTrue(try keys(of: course(language: "fr")).contains("language"))
        XCTAssertFalse(try keys(of: course()).contains("language"))
    }

    /// Sans leçon, aucune colonne de leçon : une base sans la migration accepte la ligne.
    func testAnOldCourseSendsNoLessonColumn() throws {
        let sent = try keys(of: course())
        for column in ["path", "progress", "tone", "icon", "last_opened_at"] {
            XCTAssertFalse(sent.contains(column), column)
        }
    }

    func testALessonSendsItsPath() throws {
        let path = JSONCodable(data: Data(#"{"icon":"globe"}"#.utf8))
        let sent = try keys(of: course(path: path))
        XCTAssertTrue(sent.contains("path"))
        XCTAssertTrue(sent.contains("tone"))
    }

    func testAChapterRowFromTheServerCarriesItsNotes() throws {
        let json = """
        {"id":"\(UUID().uuidString)","user_id":"\(UUID().uuidString)","course_id":"\(UUID().uuidString)",
         "position":0,"title":"Thème","sheet":null,"created_at":"2026-10-16T08:00:00Z",
         "updated_at":"2026-10-16T08:00:00Z","deleted_at":null,"icon":"globe",
         "notes":{"oneLiner":"x","blocks":[],"takeaways":[]},"quiz":null,"status":"ready"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let record = try decoder.decode(ChapterRecord.self, from: Data(json.utf8))
        XCTAssertEqual(record.icon, "globe")
        XCTAssertEqual(record.status, "ready")
        XCTAssertNotNil(ThemeNotes.decode(from: record.notes?.data))
        XCTAssertNil(record.quiz)
    }
}

/// Les phrases de la refonte : mêmes clés dans les cinq langues, rien de vide, rien de recopié.
final class LessonI18nTests: XCTestCase {
    private let locales = ["fr", "en", "de", "es", "tr"]

    func testEveryLanguageHasTheSameKeys() {
        let french = Set(LessonI18nCatalogs.fr.keys)
        for locale in locales {
            XCTAssertEqual(Set(LessonI18nCatalogs.table(for: locale).keys), french, locale)
        }
        XCTAssertTrue(french.allSatisfy { $0.hasPrefix("lesson.") })
    }

    func testNoValueIsEmpty() {
        for locale in locales {
            for (key, value) in LessonI18nCatalogs.table(for: locale) {
                XCTAssertFalse(value.trimmingCharacters(in: .whitespaces).isEmpty, "\(locale) \(key)")
            }
        }
    }

    /// Chaque clé `lesson.*` écrite dans le code existe dans le catalogue : une clé oubliée
    /// s'afficherait telle quelle à l'écran.
    func testEveryKeyUsedInTheCodeIsTranslated() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Micabo", isDirectory: true)
        guard let files = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil) else {
            throw XCTSkip("les sources ne sont pas lisibles depuis ce simulateur")
        }
        let pattern = try NSRegularExpression(pattern: #""(lesson\.[A-Za-z0-9_.]+)""#)
        let known = Set(LessonI18nCatalogs.fr.keys)
        var missing: Set<String> = []
        var read = 0
        for case let url as URL in files where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            read += 1
            let range = NSRange(text.startIndex..., in: text)
            for match in pattern.matches(in: text, range: range) {
                guard let keyRange = Range(match.range(at: 1), in: text) else { continue }
                let key = String(text[keyRange])
                if !known.contains(key) { missing.insert(key) }
            }
        }
        guard read > 0 else { throw XCTSkip("aucune source lue") }
        XCTAssertEqual(missing.sorted(), [], "clés sans traduction")
    }

    /// Les clés de la refonte passent avant les autres catalogues, et une langue sans la clé
    /// retombe sur le français plutôt que d'afficher la clé.
    func testLookupFindsLessonKeys() {
        XCTAssertEqual(L10n.t("lesson.circle.conclusion", locale: .fr), "Conclusion")
        XCTAssertEqual(L10n.t("lesson.circle.conclusion", locale: .en), "Wrap-up")
        XCTAssertEqual(L10n.t("lesson.unknown", locale: .en), "lesson.unknown")
    }
}

/// Les formes de question (refonte v2) : une question d'avant reste un QCM, et chaque forme
/// sait dire si elle est jouable.
final class QuizKindTests: XCTestCase {
    func testAnOldQuestionDecodesAsAMultipleChoice() throws {
        let json = #"{"id":"t:0","prompt":"Q ?","choices":["a","b","c"],"answer":1,"why":"."}"#
        let question = try JSONDecoder().decode(QuizQuestion.self, from: Data(json.utf8))
        XCTAssertEqual(question.kind, .choice)
        XCTAssertEqual(question.difficulty, 2)
        XCTAssertTrue(question.matches.isEmpty)
        XCTAssertTrue(question.isValid)
    }

    func testAnUnknownKindFallsBackToAMultipleChoice() throws {
        let json = #"{"id":"t:0","kind":"hologram","prompt":"Q ?","choices":["a","b"],"answer":0,"why":"."}"#
        XCTAssertEqual(try JSONDecoder().decode(QuizQuestion.self, from: Data(json.utf8)).kind, .choice)
    }

    func testEachKindKnowsWhenItIsPlayable() {
        XCTAssertTrue(QuizQuestion(id: "o", kind: .order, prompt: "Ordre", choices: ["1", "2", "3"], answer: 0, why: "").isValid)
        XCTAssertFalse(QuizQuestion(id: "o", kind: .order, prompt: "Ordre", choices: ["1", "2"], answer: 0, why: "").isValid)
        XCTAssertTrue(QuizQuestion(id: "m", kind: .match, prompt: "Associe", choices: ["a", "b"], answer: 0, why: "", matches: ["x", "y"]).isValid)
        XCTAssertFalse(QuizQuestion(id: "m", kind: .match, prompt: "Associe", choices: ["a", "b"], answer: 0, why: "", matches: ["x"]).isValid)
        XCTAssertEqual(QuizQuestion(id: "m", kind: .match, prompt: "A", choices: ["a"], answer: 0, why: "", matches: ["x"]).answerText, "a : x")
        XCTAssertEqual(QuizQuestion(id: "q", prompt: "Q", choices: ["a", "b"], answer: 1, why: "", difficulty: 9).difficulty, 3)
    }

    func testAKindRoundTrips() throws {
        let question = QuizQuestion(id: "g", kind: .gap, prompt: "La … est rouge.", choices: ["pomme", "poire", "prune"], answer: 0, why: ".", difficulty: 1)
        let decoded = try JSONDecoder().decode(QuizQuestion.self, from: JSONEncoder().encode(question))
        XCTAssertEqual(decoded, question)
    }
}

/// Pour qui on écrit : la marche d'une filière et de son année, ce que l'app envoie.
final class LessonAudienceTests: XCTestCase {
    func testACollegeStudentIsNotWrittenForAsAHighSchooler() {
        let track = SchoolSystem.track(id: "fr.college", in: .fr)
        XCTAssertEqual(LessonAudience.tier(track: track, year: SchoolSystem.year(id: "fr.4e", in: track)), .lowerSecondary)
    }

    func testMasterYearsAreGraduate() {
        let track = SchoolSystem.track(id: "fr.universite", in: .fr)
        XCTAssertEqual(LessonAudience.tier(track: track, year: SchoolSystem.year(id: "fr.m1", in: track)), .graduate)
        XCTAssertEqual(LessonAudience.tier(track: track, year: SchoolSystem.year(id: "fr.l2", in: track)), .undergraduate)
        XCTAssertNil(LessonAudience.tier(track: nil, year: nil))
    }

    func testThePayloadCarriesTheLearnerAndTheKindsTheAppCanShow() {
        let audience = LessonAudience(level: "lycee", country: "tr", schoolStage: "Lise, YKS", language: "tr", tier: "competitive", track: "YKS hazırlık", year: "TYT")
            .preparing("YKS, le 2027-06-19")
        let payload = audience.payload
        XCTAssertEqual(payload["tier"] as? String, "competitive")
        XCTAssertEqual(payload["track"] as? String, "YKS hazırlık")
        XCTAssertEqual(payload["year"] as? String, "TYT")
        XCTAssertEqual(payload["exam"] as? String, "YKS, le 2027-06-19")
        XCTAssertEqual(payload["kinds"] as? [String], ["choice", "truefalse", "gap", "order", "match"])
        XCTAssertNil(LessonAudience(level: "", country: "fr", schoolStage: "", language: "fr").payload["tier"], "rien de vide ne part")
    }

    /// La note d'aujourd'hui, celle visée et les craintes ne partent que si elles sont là.
    func testThePayloadCarriesTheGoalOnlyWhenKnown() {
        let bare = LessonAudience(level: "lycee", country: "fr", schoolStage: "Terminale", language: "fr").payload
        for key in ["currentScore", "targetScore", "scoreLabel", "targetLabel", "worries"] {
            XCTAssertNil(bare[key], key)
        }

        let scale = DesiredGradeScale.for(.fr)
        let audience = LessonAudience(
            level: "lycee", country: "fr", schoolStage: "Terminale", language: "fr",
            currentScore: 12, targetScore: 16,
            scoreLabel: LessonAudience.gradeLabel(12, scale: scale),
            targetLabel: LessonAudience.gradeLabel(16, scale: scale),
            worries: ["examStress", "forgetting"]
        )
        let payload = audience.payload
        XCTAssertEqual(payload["currentScore"] as? Int, 12)
        XCTAssertEqual(payload["targetScore"] as? Int, 16)
        XCTAssertEqual(payload["scoreLabel"] as? String, "12/20")
        XCTAssertEqual(payload["targetLabel"] as? String, "16/20")
        XCTAssertEqual(payload["worries"] as? [String], ["examStress", "forgetting"])
        XCTAssertEqual(LessonAudience.gradeLabel(DesiredGradeScale.belowScore, scale: scale), "< 10/20")
    }

    func testPathSymbolsAreUniqueAndFromTheCatalog() {
        let symbols = PathSymbol.unique(["flag", "flag", "nope", ""])
        XCTAssertEqual(symbols.first, "flag")
        XCTAssertEqual(Set(symbols).count, 4)
        XCTAssertTrue(symbols.allSatisfy(PathSymbol.catalog.contains))
    }
}
