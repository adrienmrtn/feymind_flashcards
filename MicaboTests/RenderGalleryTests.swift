import SwiftData
import SwiftUI
import XCTest
@testable import Micabo

/// **Des écrans en PNG, pour regarder l'interface sans simulateur.**
///
/// La CI compile et teste sur une machine que personne ne voit ; ces rendus sont ce qu'elle
/// rapporte de l'écran. Ils ne vérifient rien : un test qui comparerait des pixels casserait
/// à chaque retouche de la refonte. Ils dessinent, et l'artefact « rendus » les garde.
///
/// Rien ne se dessine hors de la CI : sans `MICABO_RENDER_DIR`, chaque test s'arrête aussitôt.
@MainActor
final class RenderGalleryTests: XCTestCase {
    /// Mika dans ses treize humeurs (images fixes : les rendus ne dessinent pas les animations), sur
    /// le papier de l'app (étincelle bleue) et sur le bleu Micabo (étincelle blanche) ; ses
    /// trois cadres ; et l'écran de lancement, de jour et de nuit.
    func testMika() throws {
        try RenderGallery.render(
            "mika-moods", night: true,
            VStack(spacing: 10) {
                ForEach(MikaMood.allCases) { mood in
                    HStack(spacing: 10) {
                        Text(mood.rawValue)
                            .font(MicaboFont.ui(12, weight: .bold))
                            .foregroundStyle(MicaboColor.inkSecondary)
                            .frame(width: 70, alignment: .leading)
                        // En demi, au bas de sa carte, sur le papier.
                        MikaPeek(mood: mood, width: 92)
                            .padding(.horizontal, 10)
                            .padding(.top, 8)
                            .background(MicaboColor.surface)
                            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14))
                        // En entier.
                        MikaMascot(mood: mood, size: 76, frozenAt: 0)
                        MikaAvatar(size: 36)
                    }
                }
            }
            .padding(16)
        )
        try RenderGallery.render(
            "mika-frames", night: true,
            VStack(spacing: 24) {
                // En entier, debout sur le papier ; l'icône ; l'avatar.
                HStack(alignment: .bottom, spacing: 18) {
                    MikaMascot(mood: .wave, size: 140, frozenAt: 0)
                    MikaMascot(mood: .happy, size: 110, frozenAt: 0, frame: .rounded)
                    MikaAvatar(size: 40)
                    MikaAvatar(size: 28)
                }
                // En demi, sur une ligne.
                VStack(spacing: 0) {
                    MikaPeek(mood: .wink, width: MikaPeek.line)
                    Capsule().fill(MicaboColor.stroke).frame(width: 140, height: 2)
                }
                // En demi, qui dépasse du bas d'une carte.
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous).fill(MicaboColor.surface)
                    Text("Objectif du jour")
                        .font(MicaboFont.ui(20, weight: .heavy))
                        .foregroundStyle(MicaboColor.ink)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(18)
                    MikaPeek(mood: .happy, width: MikaPeek.card)
                        .padding(.trailing, 12)
                }
                .frame(height: 130)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .padding(24)
        )
        // Quelques places de Mika dans l'app : la fête de l'objectif, les deux retours d'une
        // question, l'attente du parcours d'accueil, Mika au pied d'une page.
        try RenderGallery.render(
            "mika-places", night: true,
            VStack(spacing: 18) {
                XPGoalCard(showsButton: false)
                QuestionFeedback(question: Self.sampleQuestion(id: "mika-right"), right: true)
                QuestionFeedback(question: Self.sampleQuestion(id: "mika-wrong"), right: false)
                HStack {
                    OnboardingFooterMika(cheers: 0)
                    Spacer()
                }
            }
            .padding(20)
        )
        try RenderGallery.render(
            "mika-loading", height: 700,
            MikaLoadingView(progress: 0.6, title: "Mika prépare ton plan", subtitle: "Calibrage de ton niveau", stepLabel: "Étape 3")
        )
        try RenderGallery.render(
            "mika-launch", width: 300, height: 650, night: true,
            // L'écran de lancement n'a plus d'image : l'aplat bleu, que le premier écran
            // reprend tel quel (`LaunchCurtain`).
            Color("LaunchBackground")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
        try RenderGallery.render(
            "mika-brand",
            HStack(spacing: 16) {
                MicaboBrandMark(size: 96)
                MicaboBrandLockup(size: 40)
            }
            .padding(24)
        )
    }

    /// La base d'icônes, et les replis dessinés de ce qui n'y est pas.
    func testIcons() throws {
        let columns = Array(repeating: GridItem(.fixed(58), spacing: 6), count: 6)
        try RenderGallery.render(
            "icons",
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(MicaboIcon.allCases) { icon in
                    VStack(spacing: 2) {
                        MicaboIconView(icon: icon, size: 40)
                        Text(icon.rawValue)
                            .font(MicaboFont.ui(8, weight: .bold))
                            .foregroundStyle(MicaboColor.inkSecondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(12)
        )
    }

    /// Le papier, l'encre, l'accent, les cinq tons, et le barème typographique des notes.
    func testPaletteAndType() throws {
        try RenderGallery.render(
            "palette-type",
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    swatch(MicaboColor.canvas, "ivoire")
                    swatch(MicaboColor.surface, "surface")
                    swatch(MicaboColor.ink, "encre")
                    swatch(MicaboColor.accent, "bleu")
                    swatch(MicaboColor.keyword, "violet")
                    swatch(MicaboColor.correct, "juste")
                    swatch(MicaboColor.wrong, "faux")
                }
                HStack(spacing: 8) {
                    ForEach(LessonTone.allCases) { tone in
                        VStack(spacing: 3) {
                            RoundedRectangle(cornerRadius: 10).fill(tone.pale).frame(height: 28)
                            Circle().fill(tone.vivid).frame(width: 28, height: 28)
                            Text(tone.rawValue).font(MicaboFont.small).foregroundStyle(tone.ink)
                        }
                    }
                }
                Text("La guerre froide").font(MicaboFont.title).foregroundStyle(MicaboColor.ink)
                Text("Deux blocs face à face").font(MicaboFont.subtitle).foregroundStyle(MicaboColor.ink)
                (Text("Après 1945, les ")
                    + Text("États-Unis").font(MicaboFont.keyword).foregroundColor(MicaboColor.keyword)
                    + Text(" et l'URSS s'opposent sans jamais se faire directement la guerre."))
                    .font(MicaboFont.notes)
                    .foregroundStyle(MicaboColor.ink)
                Text("Cercle 4 · 12 min")
                    .font(MicaboFont.small)
                    .tracking(MicaboTracking.caps)
                    .textCase(.uppercase)
                    .foregroundStyle(MicaboColor.inkSecondary)
            }
            .padding(20)
        )
    }

    /// Une leçon de démonstration : son chemin à mi-parcours, les notes d'un thème avec tous
    /// les blocs, une question ratée, la navbar.
    func testLessonScreens() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
        let container = try ModelContainer(
            for: Course.self, CourseFolder.self, Chapter.self, Flashcard.self, ReviewLog.self, Exam.self, OffDay.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let course = Course(title: "La guerre froide", subject: "Histoire")
        course.toneRaw = LessonTone.mint.rawValue
        course.iconID = MicaboIcon.globe.rawValue
        context.insert(course)
        let themes: [(String, MicaboIcon)] = [
            ("Deux blocs face à face", .globe),
            ("Berlin, ville coupée", .flag),
            ("Cuba au bord du gouffre", .hourglass),
            ("La détente", .puzzle),
            ("La chute du mur", .trophy),
        ]
        for (index, theme) in themes.enumerated() {
            let chapter = Chapter(position: index, title: theme.0, course: course)
            chapter.iconID = theme.1.rawValue
            chapter.setNotes(Self.sampleNotes)
            chapter.setQuiz(ThemeQuiz(questions: [Self.sampleQuestion(id: "\(chapter.id.uuidString):0")]))
            chapter.statusRaw = (index == 4 ? ThemeStatus.pending : ThemeStatus.ready).rawValue
            context.insert(chapter)
        }
        course.setLessonPath(LessonPath(
            icon: MicaboIcon.globe.rawValue,
            intro: LessonPath.Intro(lines: ["Pourquoi deux blocs", "Les crises", "La fin"], minutes: 25),
            takeaways: ["Deux blocs s'opposent sans guerre directe."],
            groups: [LessonPath.Group(name: "Les débuts", themes: [0, 1]), LessonPath.Group(name: "Les crises", themes: [2, 3, 4])],
            status: .generating
        ))
        course.updateProgress { progress in
            progress.done = ["intro", "notes:0", "notes:1"]
            progress.inCircle = 0.4
        }
        let cards: [(String, String, CardState, Double)] = [
            ("Gains de pouvoir d'achat", "Hausse du pouvoir d'achat permise par des prix plus bas.", .learning, 2),
            ("Trilemme de Rodrik", "On ne peut avoir à la fois intégration, souveraineté et démocratie.", .new, 0),
            ("GATT", "Accord de 1947 qui baisse peu à peu les droits de douane.", .review, 30),
            ("Rideau de fer", "La frontière qui coupe l'Europe en deux blocs.", .new, 0),
        ]
        for (index, card) in cards.enumerated() {
            let flashcard = Flashcard(front: card.0, back: card.1, position: index, course: course)
            flashcard.state = card.2
            flashcard.intervalDays = card.3
            context.insert(flashcard)
        }
        let cloze = Flashcard(front: "La doctrine \(ClozeGap.marker) veut contenir le communisme.", back: "Truman", position: 9, course: course)
        cloze.kindRaw = CardKind.cloze.rawValue
        context.insert(cloze)
        try context.save()

        let session = LessonSession(course: course)
        try RenderGallery.render(
            "lesson-cards", night: true,
            LessonCardsHub(session: session)
                .environment(\.homeStill, true)
                .frame(height: 980)
        )
        try RenderGallery.render(
            "lesson-notes-reader",
            LessonNotesReader(session: session)
                .frame(height: 900)
        )
        try RenderGallery.render(
            "lesson-path", night: true,
            VStack(spacing: 0) {
                LessonPathHeader(course: course, session: session, exam: nil)
                    .padding(.top, 40)
                    .padding(.bottom, 44)
                PathMapView(session: session, tone: course.tone, width: 393, onOpen: { _ in }, onRetry: { _ in })
                LessonNavbar(dueCount: 8) { _ in }
            }
        )
        let chapter = course.orderedChapters[0]
        try RenderGallery.render(
            "lesson-notes", night: true,
            VStack(spacing: 0) {
                NotesSegments(count: 6, page: 2, tone: course.tone, onClose: {}, onBack: {})
                NotesPageView(page: .opening, chapter: chapter, tone: course.tone, question: nil, answer: nil) { _ in }
                    .frame(height: 420)
                NotesPageView(page: .blocks(0..<2), chapter: chapter, tone: course.tone, question: nil, answer: nil) { _ in }
                    .frame(height: 360)
                NotesPageView(page: .takeaways, chapter: chapter, tone: course.tone, question: nil, answer: nil) { _ in }
                    .frame(height: 460)
            }
        )
        let question = Self.sampleQuestion(id: "b")
        try RenderGallery.render(
            "lesson-question",
            VStack(spacing: 24) {
                QuestionCard(question: Self.sampleQuestion(id: "a"), tone: course.tone, answered: nil, shuffleSeed: 3) { _ in }
                QuestionCard(question: question, tone: course.tone, answered: QuizAnswer(right: false, picked: 2), showsFeedback: false) { _ in }
                AnswerPanel(question: question, right: false, isLast: false) {}
                AnswerPanel(question: question, right: true, isLast: true) {}
            }
            .padding(.vertical, 20)
        )
        try RenderGallery.render(
            "lesson-kinds", night: true,
            VStack(alignment: .leading, spacing: 32) {
                QuestionCard(question: Self.kindQuestion(.truefalse), tone: course.tone, answered: QuizAnswer(right: true, picked: 0), showsFeedback: false) { _ in }
                QuestionCard(question: Self.kindQuestion(.gap), tone: course.tone, answered: nil, shuffleSeed: 5) { _ in }
                QuestionCard(question: Self.kindQuestion(.order), tone: course.tone, answered: nil, shuffleSeed: 9) { _ in }
                QuestionCard(question: Self.kindQuestion(.match), tone: course.tone, answered: nil, shuffleSeed: 2) { _ in }
                StreakBadge(count: 4, tone: course.tone)
            }
            .padding(20)
        )
    }

    private static func kindQuestion(_ kind: QuizKind) -> QuizQuestion {
        switch kind {
        case .truefalse:
            QuizQuestion(id: "tf", kind: .truefalse, prompt: "Le mur de Berlin tombe en 1989.", choices: ["Vrai", "Faux"], answer: 0, why: "Il tombe le 9 novembre 1989.")
        case .gap:
            QuizQuestion(id: "gap", kind: .gap, prompt: "La doctrine \(ClozeGap.marker) veut contenir le communisme.", choices: ["Truman", "Jdanov", "Monroe"], answer: 0, why: "Annoncée en mars 1947.", difficulty: 1)
        case .order:
            QuizQuestion(id: "order", kind: .order, prompt: "Remets ces événements dans l'ordre.", choices: ["Plan Marshall", "Blocus de Berlin", "Construction du mur", "Chute du mur"], answer: 0, why: "1947, 1948, 1961, 1989.")
        case .match:
            QuizQuestion(id: "match", kind: .match, prompt: "Associe chaque crise à son année.", choices: ["Blocus de Berlin", "Crise de Cuba", "Chute du mur"], answer: 0, why: ".", matches: ["1948", "1962", "1989"])
        case .choice:
            sampleQuestion(id: "choice")
        }
    }

    /// Home : la rangée du haut, la scène bleue (Mika, sa bulle, la barre), les outils et
    /// « Aujourd'hui » — pour un élève qui avance (une leçon, des cartes dues, de l'XP, une
    /// série) et pour un élève tout neuf, gratuit, sans leçon ; la barre avec deux supports,
    /// la feuille du « + », l'allemand, le turc, l'arabe, l'écran de génération, la barre
    /// d'onglets et l'aperçu de la leçon verrouillée.
    func testHomeScreens() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
        let container = try ModelContainer(
            for: Course.self, CourseFolder.self, Chapter.self, Flashcard.self, ReviewLog.self, Exam.self, OffDay.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let course = Course(title: "La photosynthèse", subject: "Biologie")
        course.toneRaw = LessonTone.yellow.rawValue
        context.insert(course)
        for index in 0..<4 {
            context.insert(Chapter(position: index, title: ["La lumière", "La chlorophylle", "Le cycle de Calvin", "Le bilan"][index], course: course))
        }
        course.setLessonPath(LessonPath(
            icon: MicaboIcon.flask.rawValue,
            intro: LessonPath.Intro(lines: [], minutes: 20),
            takeaways: [],
            groups: [LessonPath.Group(name: "", themes: [0, 1]), LessonPath.Group(name: "", themes: [2, 3])],
            status: .ready
        ))
        course.iconID = MicaboIcon.flask.rawValue
        course.updateProgress { progress in
            progress.done = ["intro", "notes:0", "notes:1"]
            progress.addTime(2_700, to: .notes)
        }
        course.lastOpenedAt = Date()
        for index in 0..<8 {
            let card = Flashcard(front: "Question \(index)", back: "Réponse", position: index, course: course)
            card.state = .review
            card.dueDate = Date().addingTimeInterval(-3_600)
            context.insert(card)
        }
        try context.save()
        let resume = try XCTUnwrap(ResumeTarget.pick(from: [course]))

        // L'XP vit dans une suite à part : les rendus ne touchent pas aux réglages de l'app.
        let suite = "micabo.render.home"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let busyXP = XPStore(defaults: defaults)
        busyXP.award(points: 30)
        let emptyDefaults = try XCTUnwrap(UserDefaults(suiteName: suite + ".empty"))
        emptyDefaults.removePersistentDomain(forName: suite + ".empty")
        let freshXP = XPStore(defaults: emptyDefaults)

        // **Le plan du jour d'un élève de terminale** : le bac d'histoire dans douze jours,
        // préparé à 64 %, et à 17 h 55 la séance de 18 h sur la guerre froide. L'agenda garde
        // l'examen blanc conseillé, le DM de maths et une seconde séance ce soir ; les cours du
        // matin et la séance de concentration menée sont passés.
        let today = MicaboCalendar.shared.startOfDay(for: Date())
        let examID = UUID()
        let agenda = [
            AgendaItem(id: "m", kind: .milestone, title: "Bac blanc d'histoire", day: today, tintIndex: StudyAgenda.examTint, examID: examID, milestone: .mock, minutes: 15),
            AgendaItem(id: "t", kind: .task, title: "Rendre le DM de maths", day: today, tintIndex: StudyAgenda.taskTint, taskID: UUID()),
            AgendaItem(id: "a", kind: .lesson, title: "Mathématiques", day: today, startMinute: 8 * 60, endMinute: 9 * 60 + 30, tintIndex: CalendarTint.classesIndex, emoji: "🏫", calendarName: "Cours", room: "B12"),
            AgendaItem(id: "f", kind: .focus, title: "", day: today, startMinute: 14 * 60, endMinute: 14 * 60 + 25, tintIndex: StudyAgenda.focusTint, minutes: 25, isDone: true),
            AgendaItem(id: "r", kind: .revision, title: "La guerre froide", day: today, startMinute: 18 * 60, endMinute: 18 * 60 + 30, tintIndex: CalendarTint.revisionIndex, emoji: "📚", calendarName: "Révisions", examID: examID, eventID: UUID()),
            AgendaItem(id: "r2", kind: .revision, title: "La décolonisation", day: today, startMinute: 20 * 60 + 30, endMinute: 21 * 60, tintIndex: CalendarTint.revisionIndex, emoji: "📚", calendarName: "Révisions", examID: examID, eventID: UUID()),
        ]
        let evening = CalendarTime.date(minute: 17 * 60 + 55, on: today)
        let session = HomeSession.next(in: agenda, now: evening, examNames: [examID: "Bac d'histoire"])
        XCTAssertEqual(session?.title, "La guerre froide")
        let lessons = [
            HomeLessonCard(id: course.id, title: "La photosynthèse", icon: .flask, tone: .yellow, percent: resume.1.percent),
            HomeLessonCard(id: UUID(), title: "La guerre froide", icon: .globe, tone: .pink, percent: 70),
            HomeLessonCard(id: UUID(), title: "Les fonctions affines", icon: .calculator, tone: .blue, percent: 15),
            HomeLessonCard(id: UUID(), title: "Le passé composé", icon: .quill, tone: .mint, percent: 100),
        ]
        let examPlan = HomePlan(
            exam: HomeExam(name: "Bac d'histoire", daysLeft: 12, readiness: 64),
            agenda: HomePlan.upcoming(agenda, now: evening, excluding: session),
            lessons: lessons
        )
        XCTAssertEqual(examPlan.agenda.map(\.id), ["m", "t", "r2"])

        func busyHome(composer: LessonComposer? = nil, session: HomeSession? = session, plan: HomePlan = examPlan, moment: HomeGreeting.Moment = .evening) -> AnyView {
            let day = HomeDay(
                dueCount: 8,
                reviewedToday: 0,
                hasCourses: true,
                lessonTitle: resume.1.title,
                lessonCircle: resume.1.circleNumber.map { L10n.t("lesson.path.circleNumber", locale: .resolved(), vars: ["n": String($0)]) },
                lessonAdvancedToday: false,
                studiedToday: true,
                session: session
            )
            return AnyView(HomeScreenPreview(
                composer: composer ?? LessonComposer(),
                isPro: false,
                name: "Léa",
                moment: moment,
                day: day,
                resume: resume,
                plan: plan,
                streak: StudyStreak.Status(current: 12, best: 18, studiedToday: true)
            )
            .environment(busyXP))
        }

        /// Ce qu'on voit en ouvrant l'app : le premier écran, coupé à la hauteur d'un iPhone.
        func fold(_ view: AnyView) -> some View {
            view
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: 852, alignment: .top)
                .clipped()
        }

        try RenderGallery.render("home", night: true, busyHome())
        try RenderGallery.render("home-top", night: true, fold(busyHome()))
        // Le texte agrandi : rien ne se coupe, le plan du jour reste lisible.
        try RenderGallery.render("home-top-xl", fold(busyHome()).environment(\.dynamicTypeSize, .xxxLarge))
        // Sans examen ni séance : la leçon en cours, les cartes en seconde ligne, « Ajouter
        // un examen » dans le haut de la scène.
        try RenderGallery.render(
            "home-noexam",
            busyHome(session: nil, plan: HomePlan(exam: nil, agenda: [], lessons: lessons), moment: .morning)
        )
        try RenderGallery.render(
            "home-new", night: true,
            HomeScreenPreview(
                composer: LessonComposer(),
                isPro: false,
                name: nil,
                moment: .day,
                day: HomeDay(hasCourses: false, studiedToday: false),
                resume: nil,
                plan: HomePlan(),
                streak: StudyStreak.Status(current: 0, best: 0, studiedToday: false)
            )
            .environment(freshXP)
        )

        let composer = LessonComposer()
        composer.draft = "Les étapes clés"
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
        composer.begin(.youtube, title: "YouTube")
        try RenderGallery.render("home-composer", night: true, busyHome(composer: composer))

        try RenderGallery.render(
            "home-sources", night: true,
            HomeSourcesSheet(isPro: false, freeLessonLeft: true) { _ in }
                .environment(\.homeStill, true)
        )

        // Les phrases longues : l'allemand et le finnois, sur le même élève ; l'arabe, de
        // droite à gauche.
        do {
            let localeDefaults = UserDefaults.standard
            let previousLocale = localeDefaults.string(forKey: UiLocale.storageKey)
            localeDefaults.set(UiLocale.de.rawValue, forKey: UiLocale.storageKey)
            defer {
                if let previousLocale { localeDefaults.set(previousLocale, forKey: UiLocale.storageKey) }
                else { localeDefaults.removeObject(forKey: UiLocale.storageKey) }
            }
            try RenderGallery.render("home-de", busyHome())
            try RenderGallery.render("home-noexam-de", fold(busyHome(session: nil, plan: HomePlan(exam: nil, agenda: [], lessons: lessons), moment: .morning)))
            localeDefaults.set(UiLocale.fi.rawValue, forKey: UiLocale.storageKey)
            try RenderGallery.render("home-fi", fold(busyHome()))
            localeDefaults.set(UiLocale.ar.rawValue, forKey: UiLocale.storageKey)
            try RenderGallery.render("home-ar", busyHome().environment(\.layoutDirection, .rightToLeft))
        }

        // La leçon lue, sous cadenas : l'aperçu dans son état final, puis pendant la lecture.
        let summary = LessonReadSummary(documents: [ImportedDocument(
            text: "La photosynthèse\nLa lumière est captée par la chlorophylle des feuilles.\nElle sert à fabriquer du glucose à partir d'eau et de CO2.\nLe dioxygène est rejeté dans l'air.",
            pageImages: [],
            coverImage: nil,
            pageCount: 4,
            fileName: "Chapitre 3",
            source: .pdf,
            extractionNote: nil
        )])
        try RenderGallery.render(
            "home-locked", night: true,
            LockedLessonPreview(summary: summary, revealed: true, onUnlock: {}, onClose: {}, onRevealed: {})
                .environment(\.homeStill, true)
        )
        try RenderGallery.render(
            "home-locked-reading",
            LockedLessonPreview(summary: summary, onUnlock: {}, onClose: {}, onRevealed: {})
                .environment(\.homeStill, true)
        )

        try RenderGallery.render(
            "home-tabbar", night: true,
            MicaboTabBar().environment(TabRouter())
                .padding(20)
        )
        try RenderGallery.render(
            "home-generating",
            VStack(spacing: 28) {
                MikaMascot(mood: .write, size: 128, frozenAt: 0.6)
                GenerationSteps(current: .writing, hasSupports: true)
            }
            .padding(40)
        )
    }

    /// Leçons et Profil : une carte de leçon, un dossier, « Nouvelle leçon », la carte profil,
    /// « Passer en Pro » et le support.
    func testLessonsAndProfile() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
        let container = try ModelContainer(
            for: Course.self, CourseFolder.self, Chapter.self, Flashcard.self, ReviewLog.self, Exam.self, OffDay.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let course = Course(title: "Les fonctions affines", subject: "Mathématiques")
        course.toneRaw = LessonTone.lilac.rawValue
        context.insert(course)
        for index in 0..<3 {
            context.insert(Chapter(position: index, title: "Thème \(index + 1)", course: course))
        }
        course.setLessonPath(LessonPath(
            icon: MicaboIcon.calculator.rawValue,
            intro: LessonPath.Intro(lines: [], minutes: 15),
            takeaways: [],
            groups: [LessonPath.Group(name: "", themes: [0, 1, 2])],
            status: .ready
        ))
        course.iconID = MicaboIcon.calculator.rawValue
        course.updateProgress { $0.done = ["intro", "notes:0"] }
        let old = Course(title: "Ancien cours d'histoire", subject: "Histoire")
        context.insert(old)
        try context.save()

        try RenderGallery.render(
            "lessons", night: true,
            VStack(spacing: 12) {
                LessonFolderCard(name: "Bac de maths", count: 4) {}
                LessonCard(course: course, dueCount: 8, examDays: 12) {}
                LessonCard(course: old) {}
                NewLessonRow {}
            }
            .padding(20)
        )
        try RenderGallery.render(
            "profile", night: true,
            VStack(alignment: .leading, spacing: 22) {
                ProfileCard(name: "Marie", identity: "@marie", studies: "Terminale") {}
                ProUpgradeCard {}
                ProfileSettingsGroup()
                ProfileSupportGroup()
            }
            .padding(20)
        )
    }

    func testExamScreens() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
        let container = try ModelContainer(
            for: Course.self, CourseFolder.self, Chapter.self, Flashcard.self, ReviewLog.self, Exam.self, OffDay.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let course = Course(title: "La guerre froide", subject: "Histoire")
        course.iconID = MicaboIcon.calculator.rawValue
        context.insert(course)
        // Un titre long : il revient à la ligne dans la carte au lieu d'en sortir coupé.
        let plant = Course(title: "La plante, productrice de matière organique", subject: "SVT")
        context.insert(plant)
        let exam = Exam(name: "Bac d'histoire", date: Date().addingTimeInterval(12 * 86_400), courseIDs: [course.id, plant.id])
        let later = Exam(name: "Partiel de bio", date: Date().addingTimeInterval(40 * 86_400), courseIDs: [course.id])
        context.insert(exam)
        context.insert(later)
        try context.save()
        let result = ExamPaperResult(
            id: UUID(), examID: exam.id, title: "Bac d'histoire", date: Date(), correct: 14, total: 20, seconds: 1_500, minutes: 30,
            lessons: [.init(title: "La guerre froide", correct: 9, total: 12), .init(title: "La décolonisation", correct: 5, total: 8)]
        )

        try RenderGallery.render(
            "exam-tab", night: true,
            VStack(alignment: .leading, spacing: 18) {
                MicaboPageHeading(title: "Examen", subtitle: "2 examens à venir")
                ExamHero(exam: exam, lessons: [course, plant], best: result, onMock: {}, onEdit: {})
                ExamRow(exam: later, lessonCount: 1) {}
                MockResultRow(result: result)
            }
            .padding(20)
            .modelContainer(container)
        )

        let question = Self.sampleQuestion(id: "exam:0")
        try RenderGallery.render(
            "exam-run", night: true,
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    TimerPill(remaining: 754, total: 1_800)
                    TimerPill(remaining: 45, total: 1_800)
                }
                QuestionCard(question: question, tone: .blue, answered: QuizAnswer(right: false, picked: 2), showsFeedback: false, reveals: false) { _ in }
            }
            .padding(20)
        )

        try RenderGallery.render(
            "exam-result", night: true,
            VStack(alignment: .leading, spacing: 12) {
                ForEach([SchoolingCountry.fr, .de, .ch, .us, .uk, .tr], id: \.self) { country in
                    Text("\(country.rawValue) : \(ExamGrade.label(0.7, country: country))")
                        .font(MicaboFont.ui(15, weight: .bold))
                }
                CorrectionRow(number: 1, question: question, answer: QuizAnswer(right: false, picked: 2), seed: 0)
                CorrectionRow(number: 2, question: question, answer: nil, seed: 0)
            }
            .padding(20)
        )
    }

    /// Le parcours d'accueil : la leçon dans le téléphone, les six écrans de Mika, une
    /// question avec Mika au pied de la page, la barre du haut.
    func testOnboardingScreens() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
        let model = OnboardingModel()
        model.displayName = "Lina"

        try RenderGallery.render(
            "onboarding-hook",
            height: 560,
            OnboardingHookMockup()
                .environment(\.onboardingStill, true)
        )
        // Les scènes seules : la page entière défile, et un `ScrollView` ne se dessine pas.
        for page in MikaPage.allCases {
            try RenderGallery.render(
                "onboarding-mika-scene-\(page.rawValue)",
                height: 360,
                MikaPageScene(page: page)
                    .environment(model)
                    .environment(\.onboardingStill, true)
            )
        }
        for page in MikaPage.allCases {
            try RenderGallery.render(
                "onboarding-mika-\(page.rawValue)",
                height: 780,
                MikaStepView(page: page)
                    .environment(model)
                    .environment(\.onboardingStill, true)
            )
        }
        try RenderGallery.render(
            "onboarding-question",
            height: 780,
            VStack(spacing: 0) {
                OnboardingTopBar(progress: 0.42, showsBack: true, isVisible: true, onBack: {})
                WorriesStepView()
            }
            .environment(model)
        )
        try RenderGallery.render(
            "onboarding-time",
            height: 780,
            DailyTimeStepView()
                .environment(model)
        )
        try RenderGallery.render(
            "onboarding-sample-card",
            height: 900,
            SampleCardStepView(previewAnswer: 1)
                .environment(model)
                .environment(\.onboardingStill, true)
        )

        // « Voici ce qui va changer pour toi » : un profil rempli, puis une moyenne sous le
        // barème, dont l'étiquette est la plus longue.
        let profiled = OnboardingModel()
        profiled.displayName = "Lina"
        profiled.subjects = ["Mathématiques", "Histoire", "Physique-chimie"]
        profiled.worries = [.forgetting, .examStress]
        profiled.currentScore = 12
        profiled.targetScore = 16
        profiled.dailyMinutes = 15
        profiled.studyHour = 18
        try RenderGallery.render(
            "onboarding-social-profile",
            height: 1_100,
            ProfileSummaryStepView()
                .environment(profiled)
                .environment(\.onboardingStill, true)
        )
        profiled.currentScore = DesiredGradeScale.belowScore
        profiled.worries = []
        try RenderGallery.render(
            "onboarding-social-profile-low",
            height: 1_100,
            ProfileSummaryStepView()
                .environment(profiled)
                .environment(\.onboardingStill, true)
        )
        // La fin du parcours : le même paywall que dans l'app, au prénom de l'élève.
        try RenderGallery.render(
            "onboarding-paywall",
            PaywallScreen(name: "Lina", isPurchasing: false, onClose: {}, onSubscribe: { _ in }, onRestore: {})
                .environment(\.onboardingStill, true)
        )
    }

    /// Le paywall, en un écran : de jour et de nuit, ouvert par « Passer en Pro » ; ouvert par
    /// la leçon lue ; en allemand ; et dans la variante « à la semaine » du test de prix.
    func testPaywallScreens() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
        func paywall(_ trigger: PaywallTrigger?, name: String?) -> some View {
            PaywallScreen(trigger: trigger, name: name, isPurchasing: false, onClose: {}, onSubscribe: { _ in }, onRestore: {})
                .environment(\.onboardingStill, true)
        }
        try RenderGallery.render("paywall", night: true, paywall(.upgrade, name: "Léa"))
        try RenderGallery.render("paywall-lesson", paywall(.lessonReady, name: nil))

        let previousDisplay = PriceDisplay.forced(in: .standard)
        PriceDisplay.setOverride(.weekly)
        try RenderGallery.render("paywall-weekly", paywall(nil, name: "Léa"))
        PriceDisplay.setOverride(previousDisplay)

        let localeDefaults = UserDefaults.standard
        let previousLocale = localeDefaults.string(forKey: UiLocale.storageKey)
        defer {
            if let previousLocale { localeDefaults.set(previousLocale, forKey: UiLocale.storageKey) }
            else { localeDefaults.removeObject(forKey: UiLocale.storageKey) }
        }
        localeDefaults.set(UiLocale.de.rawValue, forKey: UiLocale.storageKey)
        try RenderGallery.render("paywall-de", paywall(.mika, name: "Léa"))
        localeDefaults.set(UiLocale.ar.rawValue, forKey: UiLocale.storageKey)
        try RenderGallery.render("paywall-ar", paywall(nil, name: nil).environment(\.layoutDirection, .rightToLeft))
    }

    private static let sampleNotes = ThemeNotes(
        oneLiner: "Après 1945, les **États-Unis** et l'**URSS** s'opposent sans jamais se battre directement.",
        blocks: [
            .subtitle("Deux visions du monde"),
            .paragraph("D'un côté le **capitalisme** et la démocratie libérale, de l'autre le **communisme** et le parti unique."),
            .list(["Plan Marshall en 1947", "Pacte de Varsovie en 1955", "Course aux armements"]),
            .definition(term: "Rideau de fer", text: "La frontière qui coupe l'Europe en deux blocs."),
            .dates([
                NoteBlock.DateItem(date: "1947", text: "Doctrine Truman"),
                NoteBlock.DateItem(date: "1961", text: "Mur de Berlin"),
                NoteBlock.DateItem(date: "1989", text: "Chute du mur"),
            ]),
            .formula(latex: "E = mc^2", caption: "Une formule, pour voir le bloc"),
            .example("Berlin-Ouest ravitaillée par avion pendant onze mois."),
        ],
        takeaways: ["Deux blocs, deux modèles.", "Une guerre sans affrontement direct.", "L'Europe coupée en deux."]
    )

    private static func sampleQuestion(id: String) -> QuizQuestion {
        QuizQuestion(
            id: id,
            prompt: "Quelle année voit la construction du mur de Berlin ?",
            choices: ["1949", "1961", "1975", "1989"],
            answer: 1,
            why: "Le mur est construit en août 1961 pour arrêter les départs vers l'Ouest."
        )
    }

    private func swatch(_ color: Color, _ name: String) -> some View {
        VStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 10)
                .fill(color)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(MicaboColor.stroke))
                .frame(width: 44, height: 44)
            Text(name).font(MicaboFont.ui(9, weight: .bold)).foregroundStyle(MicaboColor.inkSecondary)
        }
    }
}

/// Le dessin d'une vue en PNG, à la densité d'un iPhone.
@MainActor
enum RenderGallery {
    static var directory: URL? {
        guard let path = ProcessInfo.processInfo.environment["MICABO_RENDER_DIR"],
              !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    /// Dessine `view` sur la largeur d'un écran, à sa hauteur naturelle (ou à `height`), et
    /// l'écrit sous `<nom>.png` — et sous `<nom>-nuit.png` en sombre quand `night` est vrai.
    /// Sans dossier de rendu, ne fait rien.
    static func render<V: View>(
        _ name: String,
        width: CGFloat = 393,
        height: CGFloat? = nil,
        night: Bool = false,
        _ view: V
    ) throws {
        guard let directory else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
        FontLoader.registerFonts()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Le marine est le thème de référence depuis le lot 10 : chaque écran y est dessiné,
        // demandé ou non. Le clair garde le nom nu, pour que les anciens rendus se comparent.
        _ = night
        let schemes: [(ColorScheme, String)] = [(.light, name), (.dark, "\(name)-nuit")]
        for (scheme, file) in schemes {
            let framed = view
                .frame(width: width, height: height)
                .background(MicaboColor.canvas)
                .environment(\.colorScheme, scheme)
            let renderer = ImageRenderer(content: framed)
            renderer.scale = 3
            guard let data = renderer.uiImage?.pngData() else {
                XCTFail("rendu vide : \(file)")
                continue
            }
            try data.write(to: directory.appendingPathComponent("\(file).png"))
        }
    }
}

/// Home a besoin d'un focus pour sa barre : une vue le porte, le temps du rendu. L'écran est
/// posé immobile (`homeStill`) : ni entrée, ni frappe, ni dérive, tout dans son état final.
private struct HomeScreenPreview: View {
    let composer: LessonComposer
    let isPro: Bool
    let name: String?
    var moment: HomeGreeting.Moment = .day
    let day: HomeDay
    let resume: (Course, ResumeTarget)?
    var plan = HomePlan()
    let streak: StudyStreak.Status
    @FocusState private var focused: Bool

    var body: some View {
        HomeScreen(
            composer: composer,
            focused: $focused,
            isPro: isPro,
            name: name,
            hello: HomeGreeting.hello(name: name, moment: moment),
            greeting: HomeGreeting.lines(name: name, moment: moment, dueCount: day.dueCount),
            day: day,
            resume: resume,
            plan: plan,
            motion: HomeMotion(still: true, reduceMotion: false),
            appeared: true,
            streakPreview: streak,
            actions: HomeActions()
        )
        .environment(\.homeStill, true)
    }
}
