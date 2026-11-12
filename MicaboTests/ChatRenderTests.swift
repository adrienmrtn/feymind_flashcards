import SwiftUI
import XCTest
@testable import Micabo

/// **Les rendus du chat Mika et de la séance liée à une leçon** (lot 11), sur un vrai iPhone :
/// les marges de l'iPhone 15 Pro et de l'iPhone SE, l'encoche et la barre d'accueil dessinées
/// (`RenderGallery.renderDevice`). Vide, conversation, photos en attente, panne de réseau,
/// limite atteinte, historique, appareil photo ; en français, en allemand et en arabe.
@MainActor
final class ChatRenderTests: XCTestCase {
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

    // MARK: - Les contenus

    private struct Copy {
        var question: String
        var answer: String
        var front: String
        var back: String
        var followUp: String
        var lesson: String
        var draft: String
        var titles: [String]
        var previews: [String]
    }

    private let french = Copy(
        question: "Je comprends pas l'exercice 2, tu peux m'aider ?",
        answer: "Sur ta photo, l'exercice 2 demande de résoudre $3x + 1 = 7$.\n\nOn isole $x$ : on enlève **1** des deux côtés, puis on divise par **3**. Ça donne $x = 2$.\n\nVérifie toujours en remplaçant : $3 \\times 2 + 1 = 7$. C'est bon !",
        front: "Comment isoler x dans 3x + 1 = 7 ?",
        back: "On enlève 1 des deux côtés, puis on divise par 3 : x = 2.",
        followUp: "Et si c'était 3x − 1 = 7 ?",
        lesson: "Les équations du premier degré",
        draft: "Pourquoi on divise par 3 ?",
        titles: ["Je comprends pas l'exercice 2", "3 photos", "Les causes de la Révolution", "C'est quoi une cellule ?"],
        previews: ["On isole x : on enlève 1 des deux côtés, puis on divise par 3.", "Les trois pages parlent de la photosynthèse.", "La crise financière, les idées des Lumières et la colère du peuple.", "La plus petite unité du vivant."]
    )

    private let german = Copy(
        question: "Ich verstehe Aufgabe 2 nicht, kannst du mir helfen?",
        answer: "Auf deinem Foto sollst du in Aufgabe 2 die Gleichung $3x + 1 = 7$ lösen.\n\nDu isolierst $x$: Zieh auf beiden Seiten **1** ab und teil dann durch **3**. Das ergibt $x = 2$.\n\nMach immer die Probe: $3 \\times 2 + 1 = 7$. Passt!",
        front: "Wie isoliert man x in 3x + 1 = 7?",
        back: "Auf beiden Seiten 1 abziehen, dann durch 3 teilen: x = 2.",
        followUp: "Und wenn es 3x − 1 = 7 wäre?",
        lesson: "Lineare Gleichungen",
        draft: "Warum teilt man durch 3?",
        titles: ["Ich verstehe Aufgabe 2 nicht", "3 Fotos", "Ursachen der Französischen Revolution", "Was ist eine Zelle?"],
        previews: ["Du isolierst x: Zieh auf beiden Seiten 1 ab und teil durch 3.", "Alle drei Seiten handeln von der Fotosynthese.", "Finanzkrise, Ideen der Aufklärung und Wut des Volkes.", "Die kleinste Einheit des Lebens."]
    )

    private let arabic = Copy(
        question: "لم أفهم التمرين 2، هل يمكنك مساعدتي؟",
        answer: "في صورتك، يطلب التمرين 2 حلّ المعادلة $3x + 1 = 7$.\n\nنعزل $x$: نطرح **1** من الطرفين، ثم نقسم على **3**. فنحصل على $x = 2$.\n\nتحقق دائماً بالتعويض: $3 \\times 2 + 1 = 7$. صحيح!",
        front: "كيف نعزل x في 3x + 1 = 7؟",
        back: "نطرح 1 من الطرفين ثم نقسم على 3: x = 2.",
        followUp: "وإذا كانت 3x − 1 = 7؟",
        lesson: "معادلات الدرجة الأولى",
        draft: "لماذا نقسم على 3؟",
        titles: ["لم أفهم التمرين 2", "3 صور", "أسباب الثورة الفرنسية", "ما هي الخلية؟"],
        previews: ["نعزل x: نطرح 1 من الطرفين ثم نقسم على 3.", "الصفحات الثلاث تتحدث عن التركيب الضوئي.", "الأزمة المالية وأفكار التنوير وغضب الشعب.", "أصغر وحدة في الكائن الحي."]
    )

    /// Une page de cahier, dessinée : ce que l'élève photographie.
    private func page(_ label: String, tint: UIColor) -> UIImage {
        let size = CGSize(width: 300, height: 400)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor(white: 0.97, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            tint.withAlphaComponent(0.25).setFill()
            for row in 0..<12 {
                context.fill(CGRect(x: 20, y: 40 + row * 28, width: 260, height: 2))
            }
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 34, weight: .bold),
                .foregroundColor: UIColor(red: 0.12, green: 0.14, blue: 0.19, alpha: 1),
            ]
            (label as NSString).draw(at: CGPoint(x: 24, y: 60), withAttributes: attributes)
        }
    }

    private lazy var photoNames: [String] = [
        ChatPhotoStore.shared.save(page("Ex. 1", tint: .systemBlue)),
        ChatPhotoStore.shared.save(page("Ex. 2", tint: .systemPink)),
    ].compactMap { $0 }

    private func conversation(_ copy: Copy, linked: Bool = false, failure: String? = nil, limit: Bool = false, thinking: Bool = false) -> ChatSession {
        var bubbles = [
            ChatBubble(role: .user, text: copy.question, photoNames: photoNames),
            ChatBubble(role: .mika, text: copy.answer, card: GeneratedFlashcard(front: copy.front, back: copy.back)),
        ]
        if failure != nil || limit || thinking {
            bubbles.append(ChatBubble(role: .user, text: copy.followUp))
        }
        return ChatSession(
            preview: bubbles,
            title: copy.titles[0],
            courseTitle: linked ? copy.lesson : nil,
            thinking: thinking,
            failure: failure,
            limitReached: limit
        )
    }

    private func screen(_ session: ChatSession, makeLesson: Bool = true) -> some View {
        ChatPreview(session: session, showsMakeLesson: makeLesson)
            .environment(\.mikaStill, true)
            .environment(\.homeStill, true)
    }

    private func history(_ copy: Copy, empty: Bool = false) -> some View {
        let now = Date()
        let origins: [ChatOrigin] = [.camera, .camera, .home, .scan]
        let offsets: [TimeInterval] = [-600, -3_600, -86_400, -4 * 86_400]
        let rows = empty ? [] : (0..<4).map { index in
            ChatHistoryRow(title: copy.titles[index], preview: copy.previews[index], date: now.addingTimeInterval(offsets[index]), origin: origins[index], courseTitle: index == 0 ? copy.lesson : nil)
        }
        return ChatHistoryContent(rows: rows, totalCount: rows.count, query: .constant(""), onOpen: { _ in }, still: true)
            .environment(\.mikaStill, true)
    }

    private func rtl<V: View>(_ view: V) -> some View {
        view.environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: - Les rendus

    func testEmptyAndConversation() throws {
        try RenderGallery.renderDevice("chat11-vide", screen(ChatSession(preview: [])))
        try RenderGallery.renderDevice("chat11-vide-lecon", devices: [.iPhone15Pro], screen(ChatSession(preview: [], courseTitle: french.lesson)))
        try RenderGallery.renderDevice("chat11-conversation", screen(conversation(french)))
        try RenderGallery.renderDevice("chat11-conversation-lecon", devices: [.iPhone15Pro], screen(conversation(french, linked: true), makeLesson: false))
        try RenderGallery.renderDevice("chat11-ecrit", devices: [.iPhone15Pro], screen(conversation(french, thinking: true)))
    }

    func testPendingPhotos() throws {
        let pending = [
            ChatPendingPhoto(image: page("Ex. 3", tint: .systemGreen), state: .read("x")),
            ChatPendingPhoto(image: page("Ex. 4", tint: .systemOrange), state: .reading),
            ChatPendingPhoto(image: page("?", tint: .systemGray), state: .unreadable),
        ]
        try RenderGallery.renderDevice("chat11-photos", screen(ChatSession(preview: [], pending: pending, draft: french.draft)))
    }

    func testErrorsAndLimits() throws {
        let offline = AIServiceError.network("hors ligne").errorDescription ?? "Pas de réseau."
        try RenderGallery.renderDevice("chat11-erreur", screen(conversation(french, failure: offline)))
        try RenderGallery.renderDevice("chat11-limite", screen(conversation(french, limit: true)))
    }

    func testHistory() throws {
        try RenderGallery.renderDevice("chat11-historique", history(french))
        try RenderGallery.renderDevice("chat11-historique-vide", devices: [.iPhone15Pro], history(french, empty: true))
    }

    func testCamera() throws {
        let backdrop = page("Ex. 3", tint: .systemGreen)
        let shots = [ChatShot(image: page("Ex. 1", tint: .systemBlue)), ChatShot(image: page("Ex. 2", tint: .systemPink))]
        let chrome = ChatCameraChrome(
            shots: shots, room: 6, available: true, torchAvailable: true, torchOn: false,
            onClose: {}, onTorch: {}, onShoot: {}, onRemove: { _ in }, onDone: {}
        ) {
            Image(uiImage: backdrop).resizable().scaledToFill()
        }
        try RenderGallery.renderDevice("chat11-camera", devices: [.iPhone15Pro], chrome)
    }

    func testFocusOnALesson() throws {
        let outcome = FocusOutcome(lessonTitle: french.lesson, minutes: 25, steps: 2, cards: 14, quizzes: 1)
        let finished = FocusFinishedScreen(minutes: 25, award: nil, outcome: outcome, tasks: [], onToggleTask: { _ in }, onContinue: {})
            .environment(\.homeStill, true)
            .environment(\.mikaStill, true)
        try RenderGallery.renderDevice("chat11-focus-bilan", finished)
        let plan = FocusPlan(workMinutes: 25, courseID: UUID(), courseTitle: french.lesson, activity: .cards)
        let form = ScrollView {
            FocusSetupForm(plan: .constant(plan), goalsOpen: .constant(true), tasks: [], onPickLesson: {})
                .padding(.horizontal, 20)
        }
        .background(V3Color.bg)
        try RenderGallery.renderDevice("chat11-focus-preparer", devices: [.iPhone15Pro], form)
    }

    func testOtherLanguages() throws {
        UserDefaults.standard.set(UiLocale.de.rawValue, forKey: UiLocale.storageKey)
        try RenderGallery.renderDevice("chat11-conversation-de", devices: [.iPhone15Pro], screen(conversation(german)))
        try RenderGallery.renderDevice("chat11-vide-de", devices: [.iPhoneSE], screen(ChatSession(preview: [])))
        try RenderGallery.renderDevice("chat11-limite-de", devices: [.iPhoneSE], screen(conversation(german, limit: true)))
        try RenderGallery.renderDevice("chat11-historique-de", devices: [.iPhone15Pro], history(german))
        UserDefaults.standard.set(UiLocale.ar.rawValue, forKey: UiLocale.storageKey)
        try RenderGallery.renderDevice("chat11-conversation-ar", devices: [.iPhone15Pro], rtl(screen(conversation(arabic))))
        try RenderGallery.renderDevice("chat11-vide-ar", devices: [.iPhone15Pro], rtl(screen(ChatSession(preview: []))))
        try RenderGallery.renderDevice("chat11-historique-ar", devices: [.iPhone15Pro], rtl(history(arabic)))
        try RenderGallery.renderDevice("chat11-photos-ar", devices: [.iPhone15Pro], rtl(screen(ChatSession(preview: [], pending: [
            ChatPendingPhoto(image: page("1", tint: .systemBlue), state: .read("x")),
            ChatPendingPhoto(image: page("2", tint: .systemPink), state: .reading),
        ], draft: arabic.draft))))
    }
}

/// La conversation posée telle que l'écran la montre, avec son propre état de focus.
private struct ChatPreview: View {
    let session: ChatSession
    var showsMakeLesson = true
    @FocusState private var focused: Bool

    var body: some View {
        ChatConversationView(session: session, focused: $focused, showsMakeLesson: showsMakeLesson, still: true)
    }
}
