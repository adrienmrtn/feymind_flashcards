import SwiftData
import SwiftUI
import XCTest
@testable import Micabo

/// **Lot 6, « Apprendre et réviser » : les rendus.** L'en-tête d'une leçon (où j'en suis, ce que
/// je fais maintenant, les autres façons de réviser), l'onglet Leçons, les flashcards, le score,
/// Mika dans la leçon et l'examen blanc — de jour, de nuit, en allemand, en arabe, en très grand
/// texte, sur un iPhone SE (375 pt), pour un élève neuf et pour un élève qui avance, et pour
/// cinq systèmes scolaires.
///
/// Les écrans sont posés sans défilement : `ImageRenderer` ne dessine pas le contenu d'une
/// `ScrollView` ni les animations.
@MainActor
final class PolishLearnRenderTests: XCTestCase {
    override func setUpWithError() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
    }

    // MARK: - Les données

    private struct Fixture {
        let container: ModelContainer
        let course: Course
        let session: LessonSession
    }

    private func lesson(
        title: String = "La guerre froide",
        tone: LessonTone = .mint,
        done: [String],
        pending: Set<Int> = [],
        finished: Bool = false,
        cards: Int = 6
    ) throws -> Fixture {
        let container = try ModelContainer(
            for: Course.self, CourseFolder.self, Chapter.self, Flashcard.self, ReviewLog.self, Exam.self, OffDay.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let course = Course(title: title, subject: "Histoire")
        course.toneRaw = tone.rawValue
        course.iconID = MicaboIcon.globe.rawValue
        context.insert(course)
        let themes = ["Deux blocs face à face", "Berlin, ville coupée", "Cuba au bord du gouffre", "La détente"]
        for (index, theme) in themes.enumerated() {
            let chapter = Chapter(position: index, title: theme, course: course)
            chapter.statusRaw = (pending.contains(index) ? ThemeStatus.pending : ThemeStatus.ready).rawValue
            context.insert(chapter)
        }
        course.setLessonPath(LessonPath(
            icon: MicaboIcon.globe.rawValue,
            intro: LessonPath.Intro(lines: ["Pourquoi deux blocs", "Les crises"], minutes: 25),
            takeaways: ["Deux blocs s'opposent sans guerre directe."],
            groups: [LessonPath.Group(name: "Les débuts", themes: [0, 1]), LessonPath.Group(name: "Les crises", themes: [2, 3])],
            status: .ready
        ))
        let samples: [(String, String)] = [
            ("Rideau de fer", "La frontière qui coupe l'Europe en deux blocs."),
            ("Plan Marshall", "L'aide américaine à la reconstruction de l'Europe, 1947."),
            ("Blocus de Berlin", "Staline coupe les routes vers Berlin-Ouest en 1948."),
            ("Crise de Cuba", "Octobre 1962 : des missiles soviétiques à 150 km des États-Unis."),
            ("Détente", "Le dégel des relations entre les deux blocs, après 1962."),
            ("Mur de Berlin", "Construit en 1961, il tombe le 9 novembre 1989."),
        ]
        for index in 0..<cards {
            let sample = samples[index % samples.count]
            let card = Flashcard(front: sample.0, back: sample.1, position: index, course: course)
            if index % 3 == 1 {
                card.state = .review
                card.intervalDays = 30
            } else if index % 3 == 2 {
                card.state = .learning
                card.intervalDays = 2
            }
            context.insert(card)
        }
        try context.save()
        let session = LessonSession(course: course)
        course.updateProgress { progress in
            progress.done = finished ? Set(session.circles.map(\.id)) : Set(done)
            progress.inCircle = finished ? 0 : 0.4
            if finished { progress.finishedAt = Date() }
        }
        session.reload()
        return Fixture(container: container, course: course, session: session)
    }

    /// L'écran d'une leçon, tel qu'il s'ouvre : la barre du haut, l'en-tête et son bouton, les
    /// modes, le début du chemin, et la barre du bas.
    private func lessonScreen(_ fixture: Fixture, dueCount: Int, exam: Exam? = nil, isPro: Bool = false, width: CGFloat = 393) -> some View {
        let next = LessonNextAction.resolve(session: fixture.session, dueCount: dueCount)
        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                MicaboCircleButton(systemImage: "chevron.backward", style: .light, size: 40) {}
                Spacer(minLength: 0)
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .frame(width: 40, height: 40)
                    .background(MicaboColor.surface, in: Circle())
                MikaAvatar(size: 40)
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.vertical, 8)
            LessonPathHeader(course: fixture.course, session: fixture.session, exam: exam, next: next)
                .padding(.top, 4)
                .padding(.bottom, MicaboSpacing.lg)
            RevisionModesRow(isPro: isPro, tone: fixture.course.tone) { _ in }
                .padding(.bottom, MicaboSpacing.xl)
            PathMapView(session: fixture.session, tone: fixture.course.tone, width: width, onOpen: { _ in }, onRetry: { _ in })
                .frame(height: 300, alignment: .top)
                .clipped()
            LessonNavbar(dueCount: dueCount) { _ in }
        }
        .environment(\.homeStill, true)
        .environment(\.mikaStill, true)
    }

    private func lessonsTab(_ items: [Fixture]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            MicaboPageHeading(title: L10n.t("lesson.tab.lessons", locale: .resolved()), subtitle: L10n.t("lesson.lessons.count", locale: .resolved(), vars: ["count": "\(items.count + 4)"]))
                .padding(.bottom, 4)
            LessonFolderCard(name: "Révisions du bac blanc de printemps", count: 4) {}
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                LessonCard(course: item.course, dueCount: index == 0 ? 8 : 0, examDays: index == 0 ? 12 : nil, onRename: {}, onMove: {}, onDelete: {}) {}
            }
            NewLessonRow {}
        }
        .padding(20)
        .environment(\.mikaStill, true)
    }

    private func emptyLessons() -> some View {
        VStack(alignment: .leading, spacing: 18) {
            MicaboPageHeading(title: L10n.t("lesson.tab.lessons", locale: .resolved()), subtitle: L10n.t("lesson.lessons.none", locale: .resolved()))
            MicaboEmptyState(
                systemImage: "books.vertical",
                title: L10n.t("lesson.lessons.emptyTitle", locale: .resolved()),
                message: L10n.t("lesson.lessons.emptyBody", locale: .resolved()),
                actionTitle: L10n.t("lesson.lessons.new", locale: .resolved()),
                mika: .wave
            ) {}
        }
        .padding(20)
        .environment(\.mikaStill, true)
    }

    private func flashcards(_ fixture: Fixture) -> some View {
        let cards = fixture.course.cards.sorted { $0.position < $1.position }
        return VStack(spacing: 18) {
            LessonCardsHub(session: fixture.session)
                .frame(height: 760, alignment: .top)
                .clipped()
            HStack(alignment: .top, spacing: 12) {
                FlashcardFace(card: cards[3], flipped: false, tone: fixture.course.tone)
                FlashcardFace(card: cards[3], flipped: true, tone: fixture.course.tone)
            }
            .padding(.horizontal, MicaboSpacing.screen)
        }
        .environment(\.homeStill, true)
        .environment(\.mikaStill, true)
    }

    private func score(_ fixture: Fixture) -> some View {
        let question = QuizQuestion(
            id: "long",
            prompt: "Quel événement de 1962 place les États-Unis et l'Union soviétique au bord d'une guerre nucléaire, après la découverte de rampes de missiles sur une île des Caraïbes ?",
            choices: ["La crise de Cuba", "Le blocus de Berlin", "La guerre de Corée", "La construction du mur"],
            answer: 0,
            why: "En octobre 1962, des missiles soviétiques sont découverts à Cuba ; après treize jours de tension, Khrouchtchev accepte de les retirer."
        )
        return VStack(spacing: 18) {
            QuestionCard(question: question, tone: fixture.course.tone, answered: QuizAnswer(right: false, picked: 1), shuffleSeed: 4, showsFeedback: false) { _ in }
                .padding(.horizontal, MicaboSpacing.screen)
            AnswerPanel(question: question, right: false, isLast: false) {}
            QuizScoreView(right: 6, total: 10, tone: fixture.course.tone, doneTitle: L10n.t("lesson.quiz.finish", locale: .resolved()), onDone: {}, onMore: {})
                .frame(height: 560)
        }
        .environment(\.mikaStill, true)
    }

    private func modes(_ fixture: Fixture) -> some View {
        VStack(spacing: 18) {
            RevisionModeHeader(mode: .listen, lessonTitle: fixture.course.title, tone: fixture.course.tone) {}
            RevisionModeHeader(mode: .voice, lessonTitle: fixture.course.title, tone: fixture.course.tone, closesLeading: true) {}
            RevisionModesRow(isPro: true, tone: fixture.course.tone) { _ in }
        }
        .padding(.vertical, 12)
    }

    // MARK: - L'examen blanc, par pays

    private struct Profile {
        let name: String
        let country: SchoolingCountry
        let track: String?
        let year: String?
        let locale: UiLocale
    }

    private let profiles = [
        Profile(name: "FR lycée", country: .fr, track: "fr.lyceeGeneral", year: "fr.terminale", locale: .fr),
        Profile(name: "FR collège", country: .fr, track: "fr.college", year: "fr.3e", locale: .fr),
        Profile(name: "FR université", country: .fr, track: "fr.universite", year: nil, locale: .fr),
        Profile(name: "DE Gymnasium", country: .de, track: "de.gymnasium", year: "de.klasse12", locale: .de),
        Profile(name: "US high school", country: .us, track: "us.high", year: "us.hs11", locale: .en),
    ]

    private func examsByCountry() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(profiles, id: \.name) { profile in
                let result = ExamPaperResult(
                    id: UUID(), examID: nil, title: ExamNaming.placeholder(country: profile.country, trackID: profile.track, yearID: profile.year, tier: nil, locale: profile.locale),
                    date: Date(), correct: 14, total: 20, seconds: 1_500, minutes: 25, lessons: []
                )
                VStack(alignment: .leading, spacing: 6) {
                    Text(profile.name)
                        .font(MicaboFont.ui(13, weight: .heavy))
                        .foregroundStyle(MicaboColor.inkSecondary)
                    MockResultRow(result: result, country: profile.country)
                }
            }
        }
        .padding(20)
    }

    private func examTab(_ fixture: Fixture, country: SchoolingCountry) -> some View {
        let exam = Exam(name: country == .de ? "Abitur Geschichte" : country == .us ? "SAT" : "Bac d'histoire", date: Date().addingTimeInterval(12 * 86_400), courseIDs: [fixture.course.id])
        let result = ExamPaperResult(
            id: UUID(), examID: exam.id, title: exam.name, date: Date(), correct: 15, total: 20, seconds: 1_500, minutes: 30,
            lessons: [.init(title: "La guerre froide", correct: 9, total: 12)]
        )
        return VStack(alignment: .leading, spacing: 18) {
            ExamHero(exam: exam, lessons: [fixture.course], best: result, onMock: {}, onEdit: {})
            ExamRow(exam: Exam(name: "Contrôle de géographie sur la mondialisation et ses territoires", date: Date().addingTimeInterval(40 * 86_400), courseIDs: []), lessonCount: 1) {}
            MockResultRow(result: result)
        }
        .padding(20)
        .environment(\.mikaStill, true)
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

    private func inCountry(_ country: SchoolingCountry, _ body: () throws -> Void) rethrows {
        let previous = OnboardingPreferences.schoolingCountry
        defer { OnboardingPreferences.schoolingCountry = previous }
        OnboardingPreferences.schoolingCountry = country
        try body()
    }

    // MARK: - Les rendus

    func testLessonScreen() throws {
        try inLanguage(.fr) {
            let fresh = try lesson(done: [], cards: 0)
            try RenderGallery.render("learn-lesson-new", night: true, lessonScreen(fresh, dueCount: 0))
            let going = try lesson(done: ["intro", "notes:0", "notes:1"])
            let exam = Exam(name: "Bac d'histoire", date: Date().addingTimeInterval(12 * 86_400), courseIDs: [going.course.id])
            try RenderGallery.render("learn-lesson-active", night: true, lessonScreen(going, dueCount: 8, exam: exam))
            let writing = try lesson(done: ["intro", "notes:0"], pending: [1])
            try RenderGallery.render("learn-lesson-writing", lessonScreen(writing, dueCount: 0))
            let done = try lesson(done: [], finished: true)
            try RenderGallery.render("learn-lesson-done", night: true, lessonScreen(done, dueCount: 5, isPro: true))
            // Un titre long, en très grand texte, sur un iPhone SE.
            let long = try lesson(title: "La plante, productrice de matière organique et actrice des échanges", tone: .lilac, done: ["intro"])
            try RenderGallery.render("learn-lesson-se-xxxl", width: 375, lessonScreen(long, dueCount: 3, width: 375).environment(\.dynamicTypeSize, .xxxLarge))
        }
    }

    func testLessonScreenInOtherLanguages() throws {
        try inLanguage(.de) {
            let going = try lesson(title: "Der Kalte Krieg und die Teilung Europas", done: ["intro", "notes:0"])
            try RenderGallery.render("learn-lesson-de", lessonScreen(going, dueCount: 12))
            let done = try lesson(title: "Der Kalte Krieg", done: [], finished: true)
            try RenderGallery.render("learn-lesson-done-de", width: 375, lessonScreen(done, dueCount: 4, width: 375))
        }
        try inLanguage(.fi) {
            let going = try lesson(title: "Kylmä sota", done: ["intro"])
            try RenderGallery.render("learn-lesson-fi", width: 375, lessonScreen(going, dueCount: 2, width: 375))
        }
        try inLanguage(.ar) {
            let going = try lesson(title: "الحرب الباردة", done: ["intro", "notes:0"])
            try RenderGallery.render("learn-lesson-ar", lessonScreen(going, dueCount: 7).environment(\.layoutDirection, .rightToLeft))
        }
    }

    func testLessonsTab() throws {
        try inLanguage(.fr) {
            let first = try lesson(title: "Les fonctions affines", tone: .lilac, done: ["intro", "notes:0"])
            let second = try lesson(title: "La plante, productrice de matière organique", tone: .yellow, done: [], finished: true)
            let third = try lesson(title: "Ancien cours", tone: .blue, done: [])
            try RenderGallery.render("learn-lessons", night: true, lessonsTab([first, second, third]))
            try RenderGallery.render("learn-lessons-empty", night: true, emptyLessons())
            try RenderGallery.render("learn-lessons-se-xxxl", width: 375, lessonsTab([first, second]).environment(\.dynamicTypeSize, .xxxLarge))
        }
        try inLanguage(.de) {
            let first = try lesson(title: "Lineare Funktionen", tone: .lilac, done: ["intro", "notes:0"])
            try RenderGallery.render("learn-lessons-de", lessonsTab([first]))
        }
        try inLanguage(.ar) {
            let first = try lesson(title: "الدوال الخطية", tone: .lilac, done: ["intro", "notes:0"])
            try RenderGallery.render("learn-lessons-ar", lessonsTab([first]).environment(\.layoutDirection, .rightToLeft))
        }
    }

    func testFlashcardsAndQuiz() throws {
        try inLanguage(.fr) {
            let going = try lesson(done: ["intro", "notes:0"])
            try RenderGallery.render("learn-cards", night: true, flashcards(going))
            try RenderGallery.render("learn-score", night: true, score(going))
            try RenderGallery.render("learn-modes", night: true, modes(going))
        }
        try inLanguage(.de) {
            let going = try lesson(done: ["intro", "notes:0"])
            try RenderGallery.render("learn-cards-de", width: 375, flashcards(going))
        }
        try inLanguage(.ar) {
            let going = try lesson(done: ["intro", "notes:0"])
            try RenderGallery.render("learn-cards-ar", flashcards(going).environment(\.layoutDirection, .rightToLeft))
        }
    }

    func testExamsByCountry() throws {
        try RenderGallery.render("learn-exam-countries", examsByCountry())
        let fixture = try lesson(done: ["intro"])
        try inLanguage(.fr) {
            try inCountry(.fr) { try RenderGallery.render("learn-exam-fr", night: true, examTab(fixture, country: .fr)) }
        }
        try inLanguage(.de) {
            try inCountry(.de) { try RenderGallery.render("learn-exam-de", width: 375, examTab(fixture, country: .de)) }
        }
        try inLanguage(.en) {
            try inCountry(.us) { try RenderGallery.render("learn-exam-us", examTab(fixture, country: .us)) }
        }
        try inLanguage(.ar) {
            try inCountry(.ma) { try RenderGallery.render("learn-exam-ar", examTab(fixture, country: .ma).environment(\.layoutDirection, .rightToLeft)) }
        }
    }
}
