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
        try context.save()

        let session = LessonSession(course: course)
        try RenderGallery.render(
            "lesson-path",
            PathMapView(session: session, tone: course.tone, width: 393, onOpen: { _ in }, onRetry: { _ in })
                .padding(.top, 40)
        )
        try RenderGallery.render(
            "lesson-notes",
            VStack(alignment: .leading, spacing: 22) {
                ThemeHeader(chapter: course.orderedChapters[0])
                ThemeNotesView(notes: Self.sampleNotes, tone: course.tone)
            }
            .padding(20)
        )
        try RenderGallery.render(
            "lesson-question",
            VStack(spacing: 24) {
                QuestionCard(question: Self.sampleQuestion(id: "a"), tone: course.tone, answered: nil) { _ in }
                QuestionCard(question: Self.sampleQuestion(id: "b"), tone: course.tone, answered: 2) { _ in }
                LessonNavbar(dueCount: 8) { _ in }
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
    /// l'écrit sous `<nom>.png`. Sans dossier de rendu, ne fait rien.
    static func render<V: View>(
        _ name: String,
        width: CGFloat = 393,
        height: CGFloat? = nil,
        _ view: V
    ) throws {
        guard let directory else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
        FontLoader.registerFonts()
        let framed = view
            .frame(width: width, height: height)
            .background(MicaboColor.canvas)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: framed)
        renderer.scale = 3
        guard let data = renderer.uiImage?.pngData() else {
            XCTFail("rendu vide : \(name)")
            return
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appendingPathComponent("\(name).png"))
    }
}
