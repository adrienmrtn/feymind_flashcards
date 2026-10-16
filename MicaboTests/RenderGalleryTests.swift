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
    /// Mika dans ses huit humeurs, à trois instants de chaque animation.
    func testMika() throws {
        let instants: [Double] = [0.25, 0.7, 1.4]
        try RenderGallery.render(
            "mika-moods",
            VStack(spacing: 4) {
                ForEach(MikaMood.allCases) { mood in
                    HStack(spacing: 12) {
                        Text(mood.rawValue)
                            .font(MicaboFont.ui(11, weight: .bold))
                            .foregroundStyle(MicaboColor.inkSecondary)
                            .frame(width: 64, alignment: .leading)
                        ForEach(instants, id: \.self) { instant in
                            MikaMascot(mood: mood, size: 84, frozenAt: instant)
                        }
                    }
                }
            }
            .padding(16)
        )
        try RenderGallery.render(
            "mika-large",
            MikaMascot(mood: .wave, size: 300, frozenAt: 0.5)
                .padding(40)
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

    /// Home : Mika et sa question, la barre avec deux supports, les chiffres, « Reprendre »,
    /// l'écran de génération et la barre d'onglets.
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
        try context.save()

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

        let resume = try XCTUnwrap(ResumeTarget.pick(from: [course]))
        try RenderGallery.render(
            "home", night: true,
            VStack(alignment: .leading, spacing: 28) {
                HomeTitle()
                    .padding(.bottom, HomePerch.height)
                ComposerBarPreview(composer: composer)
                HomeStatsRow(stats: HomeStats(seconds: 5_400, learnedLessons: 3, learnedCards: 42))
                ResumeCard(course: resume.0, target: resume.1) {}
                MicaboTabBar().environment(TabRouter())
            }
            .padding(20)
        )
        try RenderGallery.render(
            "home-generating",
            VStack(spacing: 28) {
                MikaMascot(mood: .think, size: 170, frozenAt: 0.6)
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
        let schemes: [(ColorScheme, String)] = night ? [(.light, name), (.dark, "\(name)-nuit")] : [(.light, name)]
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

/// La barre de Home a besoin d'un focus : une vue le porte, le temps du rendu.
private struct ComposerBarPreview: View {
    let composer: LessonComposer
    @FocusState private var focused: Bool

    var body: some View {
        HomeComposerBar(composer: composer, focused: $focused, isPro: true, onImport: { _ in }, onSend: {})
    }
}
