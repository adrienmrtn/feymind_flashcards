import SwiftUI
import XCTest
@testable import Micabo

/// **Les rendus du lot 12** sur un vrai iPhone (marges simulées, `RenderGallery.renderDevice`) :
/// la caméra mode par mode et ses états (page vide, illisible, caméra refusée, hors ligne,
/// limite), le résultat de chaque mode dans la conversation, la feuille Outils, le tiroir des
/// conversations (plein, vide, recherche) ; iPhone SE, clair et nuit, allemand, arabe.
@MainActor
final class Scan12RenderTests: XCTestCase {
    override func setUpWithError() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
        previousLocale = UserDefaults.standard.string(forKey: UiLocale.storageKey)
        UserDefaults.standard.set(UiLocale.fr.rawValue, forKey: UiLocale.storageKey)
    }

    override func tearDown() {
        if let previousLocale {
            UserDefaults.standard.set(previousLocale, forKey: UiLocale.storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: UiLocale.storageKey)
        }
    }

    private var previousLocale: String?

    private func use(_ locale: UiLocale) {
        UserDefaults.standard.set(locale.rawValue, forKey: UiLocale.storageKey)
    }

    private func rtl<V: View>(_ view: V) -> some View {
        view.environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: - Les pages photographiées

    private static let course = ["Chapitre 4", "La photosynthèse", "Les plantes vertes fabriquent", "leur matière organique", "grâce à la lumière.", "La chlorophylle capte", "l'énergie lumineuse."]
    private static let english = ["Unit 3", "My weekend", "On Saturday I went", "to the market with", "my grandmother.", "We bought apples", "and fresh bread."]
    private static let equation = ["Exercice 2", "Résoudre :", "2x² − 8x + 6 = 0", "Exercice 3", "Calculer f'(x)"]

    private func pageImage(_ label: String, lines: Int = 9) -> UIImage {
        let size = CGSize(width: 300, height: 400)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor(white: 0.97, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.systemBlue.withAlphaComponent(0.2).setFill()
            for row in 0..<lines {
                context.fill(CGRect(x: 24, y: 90 + row * 30, width: 250 - (row % 3) * 40, height: 6))
            }
            (label as NSString).draw(at: CGPoint(x: 24, y: 36), withAttributes: [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: UIColor(red: 0.12, green: 0.14, blue: 0.19, alpha: 1),
            ])
        }
    }

    // MARK: - La caméra

    private func camera(_ state: ScanChromeState, lines: [String] = course, still: UIImage? = nil) -> some View {
        ScanCameraRender(state: state, lines: lines, still: still)
            .environment(\.homeStill, true)
            .environment(\.mikaStill, true)
    }

    func testCameraEachMode() throws {
        let lines: [ScanMode: [String]] = [.solve: Self.equation, .equation: Self.equation, .translate: Self.english, .vocabulary: Self.english]
        for mode in ScanMode.allCases {
            var state = ScanChromeState(mode: mode, target: .en, hasTorch: true)
            if mode == .summary { state.torchOn = true }
            try RenderGallery.renderDevice("scan12-camera-\(mode.rawValue)", devices: [.iPhone15Pro], camera(state, lines: lines[mode] ?? Self.course))
        }
        try RenderGallery.renderDevice("scan12-camera-solve", devices: [.iPhoneSE], camera(ScanChromeState(mode: .solve), lines: Self.equation))
    }

    func testCameraPagesAndStates() throws {
        let pages = [
            ScanPage(image: pageImage("p. 1"), state: .read("x")),
            ScanPage(image: pageImage("p. 2"), state: .read("x")),
            ScanPage(image: pageImage("", lines: 0), state: .empty),
            ScanPage(image: pageImage("p. 4"), state: .reading),
        ]
        try RenderGallery.renderDevice("scan12-camera-pages", camera(ScanChromeState(mode: .summary, hasTorch: false, pages: pages)))
        try RenderGallery.renderDevice("scan12-camera-equation-cadre", devices: [.iPhone15Pro], camera(ScanChromeState(mode: .equation, stage: .still), lines: Self.equation, still: pageImage("2x² − 8x + 6 = 0", lines: 0)))
        try RenderGallery.renderDevice("scan12-camera-illisible", devices: [.iPhone15Pro, .iPhoneSE], camera(ScanChromeState(mode: .explain, stage: .unreadable)))
        try RenderGallery.renderDevice("scan12-camera-refusee", devices: [.iPhone15Pro, .iPhoneSE], camera(ScanChromeState(mode: .translate, cameraAvailable: false, cameraRefused: true), lines: []))
        try RenderGallery.renderDevice("scan12-camera-horsligne-limite", devices: [.iPhone15Pro], camera(ScanChromeState(mode: .vocabulary, offline: true, limitReached: true), lines: Self.english))
    }

    func testCameraOtherLanguages() throws {
        use(.de)
        try RenderGallery.renderDevice("scan12-camera-translate-de", devices: [.iPhoneSE], camera(ScanChromeState(mode: .translate, target: .en), lines: Self.english))
        use(.ar)
        try RenderGallery.renderDevice("scan12-camera-flashcards-ar", devices: [.iPhone15Pro], rtl(camera(ScanChromeState(mode: .flashcards, pages: [ScanPage(image: pageImage("1"), state: .read("x"))]))))
    }

    // MARK: - Le résultat, mode par mode

    private struct Result {
        var mode: ScanMode
        var target: UiLocale? = nil
        var reply: String
        var cards: [GeneratedFlashcard] = []
        var card: GeneratedFlashcard? = nil
        var typed = ""
    }

    private lazy var photo: [String] = [ChatPhotoStore.shared.save(pageImage("p. 1"))].compactMap { $0 }

    private func results() -> [Result] {
        [
            Result(mode: .solve, reply: "On cherche $x$ tel que $3x + 1 = 7$.\n\n**Étape 1.** On enlève 1 des deux côtés : $3x = 6$.\n\n**Étape 2.** On divise par 3 : $x = 2$.\n\nLa réponse : **$x = 2$**.", card: GeneratedFlashcard(front: "Comment isoler x dans 3x + 1 = 7 ?", back: "On enlève 1, puis on divise par 3.")),
            Result(mode: .equation, reply: "On divise tout par 2 : $x^2 - 4x + 3 = 0$.\n\nLe discriminant : $\\Delta = 16 - 12 = 4$.\n\nLes racines : $x = \\frac{4 \\pm 2}{2}$.\n\nDonc **$x = 1$ ou $x = 3$**. Vérification : $2 - 8 + 6 = 0$."),
            Result(mode: .explain, reply: "**L'idée** : la plante fabrique sa propre matière avec la lumière.\n\nLa **chlorophylle** des feuilles capte l'énergie du soleil. Avec l'eau et le $CO_2$, la plante en fait du glucose et rejette de l'oxygène.\n\n*Exemple* : une plante dans le noir finit par jaunir, faute de lumière."),
            Result(mode: .summary, reply: "La **photosynthèse** permet aux plantes vertes de fabriquer leur matière grâce à la lumière.\n\nElle a lieu dans les **chloroplastes**, grâce à la **chlorophylle**.\n\nElle consomme du $CO_2$ et de l'eau, et rejette du **dioxygène**."),
            Result(mode: .translate, target: .fr, reply: "Unité 3\n\nMon week-end\n\nSamedi, je suis allé\n\nau marché avec\n\nma grand-mère."),
            Result(mode: .vocabulary, reply: "**market** : un lieu où l'on achète des produits frais. *We go to the market on Saturday.*\n\n**grandmother** : la mère d'un de tes parents. *My grandmother lives in Lyon.*", cards: [
                GeneratedFlashcard(front: "market", back: "un lieu où l'on achète des produits frais."),
                GeneratedFlashcard(front: "grandmother", back: "la mère d'un de tes parents."),
                GeneratedFlashcard(front: "fresh bread", back: "du pain du jour."),
            ]),
            Result(mode: .flashcards, reply: L10n.t("ios.scan12.cards.reply", locale: .fr, vars: ["count": "8"]), cards: [
                GeneratedFlashcard(front: "Où a lieu la photosynthèse ?", back: "Dans les chloroplastes."),
                GeneratedFlashcard(front: "Quel pigment capte la lumière ?", back: "La chlorophylle."),
                GeneratedFlashcard(front: "Que rejette la plante ?", back: "Du dioxygène."),
                GeneratedFlashcard(front: "Que consomme la photosynthèse ?", back: "Du $CO_2$ et de l'eau."),
                GeneratedFlashcard(front: "Que fabrique la plante ?", back: "Du glucose."),
            ] + Array(repeating: GeneratedFlashcard(front: "Q", back: "R"), count: 3)),
        ]
    }

    private func conversation(_ result: Result) -> some View {
        let bubbles = [
            ChatBubble(role: .user, text: result.typed, photoNames: photo, scanMode: result.mode, scanTarget: result.target),
            ChatBubble(role: .mika, text: result.reply, card: result.card, cards: result.cards),
        ]
        let session = ChatSession(preview: bubbles, title: ScanPrompts.threadTitle(result.mode, target: result.target, firstText: "La photosynthèse"))
        return ScanChatPreview(session: session)
            .environment(\.mikaStill, true)
            .environment(\.homeStill, true)
    }

    func testResultEachMode() throws {
        for result in results() {
            try RenderGallery.renderDevice("scan12-resultat-\(result.mode.rawValue)", devices: [.iPhone15Pro], conversation(result))
        }
        let pending = ChatSession(
            preview: [],
            pending: [ChatPendingPhoto(image: pageImage("p. 1"), state: .read("x")), ChatPendingPhoto(image: pageImage("p. 2"), state: .read("x"))],
            pendingMode: .summary
        )
        try RenderGallery.renderDevice("scan12-resultat-en-attente", devices: [.iPhone15Pro], ScanChatPreview(session: pending).environment(\.mikaStill, true))
        let limit = ChatSession(preview: [ChatBubble(role: .user, text: "", photoNames: photo, scanMode: .summary)], limitReached: true)
        try RenderGallery.renderDevice("scan12-resultat-limite", devices: [.iPhoneSE], ScanChatPreview(session: limit).environment(\.mikaStill, true))
        let offline = ChatSession(preview: [ChatBubble(role: .user, text: "", photoNames: photo, scanMode: .translate, scanTarget: .en)], failure: AIServiceError.network("hors ligne").errorDescription ?? "Pas de réseau.")
        try RenderGallery.renderDevice("scan12-resultat-horsligne", devices: [.iPhoneSE], ScanChatPreview(session: offline).environment(\.mikaStill, true))
        let vocabulary = results().first { $0.mode == .vocabulary }!
        try RenderGallery.renderDevice("scan12-resultat-vocabulary", devices: [.iPhoneSE], conversation(vocabulary))
        use(.ar)
        try RenderGallery.renderDevice("scan12-resultat-flashcards-ar", devices: [.iPhone15Pro], rtl(conversation(results().first { $0.mode == .flashcards }!)))
    }

    // MARK: - La feuille Outils

    private func tools(_ context: ToolsContext, _ availability: ToolsAvailability) -> some View {
        ToolsSheet(context: context, availability: availability) { _ in }
            .environment(\.homeStill, true)
    }

    func testToolsSheet() throws {
        try RenderGallery.renderDevice("scan12-outils", tools(.home, ToolsAvailability(hasLesson: true, hasLessons: true)))
        try RenderGallery.renderDevice("scan12-outils-nouveau", devices: [.iPhone15Pro], tools(.home, ToolsAvailability()))
        try RenderGallery.renderDevice("scan12-outils-chat", devices: [.iPhone15Pro], tools(.chat, ToolsAvailability(hasLesson: true)))
        use(.de)
        try RenderGallery.renderDevice("scan12-outils-de", devices: [.iPhoneSE], tools(.home, ToolsAvailability(hasLesson: true, hasLessons: true)))
        use(.ar)
        try RenderGallery.renderDevice("scan12-outils-ar", devices: [.iPhone15Pro], rtl(tools(.home, ToolsAvailability(hasLesson: true, hasLessons: true))))
    }

    // MARK: - Le tiroir

    private struct Copy {
        var titles: [String]
        var lessons: [String?]
        var name: String
    }

    private let french = Copy(
        titles: ["Résume cette page · La photosynthèse", "Pourquoi le ciel est bleu ?", "Les équations du second degré", "Traduis en anglais · My weekend", "C'est quoi une cellule ?", "Explique-moi ce passage · La guerre froide", "Résous cette équation · 2x² − 8x + 6 = 0"],
        lessons: [nil, nil, "Le second degré", nil, "La cellule", nil, nil],
        name: "Léa"
    )

    private let arabic = Copy(
        titles: ["لخّص هذه الصفحة · التركيب الضوئي", "لماذا السماء زرقاء؟", "معادلات الدرجة الثانية", "ترجم إلى الإنجليزية · My weekend", "ما هي الخلية؟", "اشرح لي هذا المقطع · الحرب الباردة", "حلّ هذه المعادلة"],
        lessons: [nil, nil, "الدرجة الثانية", nil, "الخلية", nil, nil],
        name: "ليلى"
    )

    private func rows(_ copy: Copy) -> [ChatHistoryRow] {
        let now = Date()
        let origins: [ChatOrigin] = [.scan, .home, .lesson, .scan, .quiz, .scan, .scan]
        let offsets: [TimeInterval] = [-600, -5_000, -86_400, -90_000, -3 * 86_400, -12 * 86_400, -40 * 86_400]
        return copy.titles.indices.map { index in
            ChatHistoryRow(title: copy.titles[index], preview: "", date: now.addingTimeInterval(offsets[index]), origin: origins[index], courseTitle: copy.lessons[index])
        }
    }

    private func drawer(_ copy: Copy, rows: [ChatHistoryRow], query: String = "") -> some View {
        SideDrawer(isOpen: .constant(true), still: true) {
            HomeUnderDrawer()
        } drawer: {
            ChatDrawerContent(rows: rows, totalCount: rows.isEmpty && query.isEmpty ? 0 : 7, name: copy.name, currentID: rows.first?.id, query: .constant(query), onOpen: { _ in }, onSettings: {}, still: true)
        }
        .environment(\.homeStill, true)
        .environment(\.mikaStill, true)
    }

    func testDrawer() throws {
        let all = rows(french)
        try RenderGallery.renderDevice("scan12-tiroir", drawer(french, rows: all))
        try RenderGallery.renderDevice("scan12-tiroir-vide", drawer(french, rows: []))
        let found = ChatStoreSearchPreview.filter(all, query: "équation")
        try RenderGallery.renderDevice("scan12-tiroir-recherche", devices: [.iPhone15Pro], drawer(french, rows: found, query: "équation"))
        try RenderGallery.renderDevice("scan12-tiroir-recherche-rien", devices: [.iPhoneSE], drawer(french, rows: [], query: "volcan"))
        try RenderGallery.renderDevice("scan12-home-menu", devices: [.iPhone15Pro, .iPhoneSE], RenderTabRoot { HomeUnderDrawer() })
        use(.ar)
        try RenderGallery.renderDevice("scan12-tiroir-ar", devices: [.iPhone15Pro, .iPhoneSE], rtl(drawer(arabic, rows: rows(arabic))))
    }
}

// MARK: - Les vues posées

/// La caméra posée sans appareil : la page de démonstration (ou la photo figée) derrière les
/// commandes, le cadre placé comme l'écran le place.
private struct ScanCameraRender: View {
    let state: ScanChromeState
    let lines: [String]
    var still: UIImage?
    @State private var frame: CGRect = .zero

    var body: some View {
        ScanCaptureChrome(state: state, frame: $frame) {
            if let still {
                Color.black.overlay { Image(uiImage: still).resizable().aspectRatio(contentMode: .fit) }
            } else if state.cameraRefused {
                SolverNoCamera()
            } else {
                SolverDemoDesk(lines: lines)
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear.onAppear {
                    frame = state.mode.framing == .line ? ScanCaptureChrome<EmptyView>.lineFrame(in: proxy.size) : SolverCrop.initialFrame(in: proxy.size)
                }
            }
            .ignoresSafeArea()
        }
    }
}

/// Une conversation posée telle que l'écran la montre.
private struct ScanChatPreview: View {
    let session: ChatSession
    @FocusState private var focused: Bool

    var body: some View {
        ChatConversationView(session: session, focused: $focused, showsMakeLesson: true, still: true)
    }
}

/// La Home sous le tiroir : la page qu'on voit glisser.
private struct HomeUnderDrawer: View {
    var body: some View {
        let exam = HomeExam(name: "Bac de français", daysLeft: 12, readiness: nil)
        let day = HomeDay(dueCount: 8, hasCourses: true, dueLessons: 2)
        let board = HomeBoard.resolve(HomeBoardInput(day: day, name: "Léa", greeting: .evening, hasLesson: true))
        HomePage(board: board, exam: exam)
    }
}

/// La recherche de l'historique, sur des lignes posées (la vraie lit des `ChatThread`).
private enum ChatStoreSearchPreview {
    static func filter(_ rows: [ChatHistoryRow], query: String) -> [ChatHistoryRow] {
        let needle = ChatStore.fold(query)
        return rows.filter { ChatStore.fold($0.title).contains(needle) || ChatStore.fold($0.courseTitle ?? "").contains(needle) }
    }
}
