import Foundation
import Observation

/// **Ce que l'élève prépare dans la barre de Home** : un sujet tapé, et jusqu'à cinq supports
/// lus sur l'appareil. Voir `docs/refonte-parcours.md` § 3 et § 4.
///
/// Les supports se lisent dès qu'on les dépose : un PDF illisible le dit sur sa pastille, pas
/// trente secondes plus tard sur l'écran de génération. Envoyer assemble le tout en une seule
/// demande (`LessonCreation`).
@MainActor
@Observable
final class LessonComposer {
    static let maximumSupports = 5
    /// La limite que le serveur lit : ce qui dépasse est coupé, et la leçon le signale.
    static let maximumCharacters = 60_000
    /// Les pages envoyées à la passe visuelle.
    static let maximumImages = 6

    /// Une icône d'import sous la barre.
    enum Kind: String, CaseIterable, Identifiable {
        case pdf
        case photo
        case audio
        case youtube
        case text

        var id: String { rawValue }

        var icon: MicaboIcon {
            switch self {
            case .pdf: .pdf
            case .photo: .photo
            case .audio: .audio
            case .youtube: .link
            case .text: .text
            }
        }

        var titleKey: String { "lesson.import.\(rawValue)" }
    }

    struct Support: Identifiable, Equatable {
        enum State: Equatable {
            case reading
            case ready
            case failed(String)
        }

        let id: UUID
        let kind: Kind
        var title: String
        var state: State = .reading
        var document: ImportedDocument?

        static func == (lhs: Support, rhs: Support) -> Bool {
            lhs.id == rhs.id && lhs.title == rhs.title && lhs.state == rhs.state && (lhs.document == nil) == (rhs.document == nil)
        }
    }

    var draft = ""
    private(set) var supports: [Support] = []

    /// **L'identifiant de la leçon en préparation**, gardé jusqu'à ce qu'elle arrive.
    ///
    /// Le serveur réserve la leçon sous cet identifiant (`begin_lesson`). Il vivait dans
    /// l'écran de génération, et un écran fermé pendant l'attente puis rouvert en tirait un
    /// neuf : la réservation du premier essai comptait encore, et un élève sans abonnement
    /// tombait sur le paywall avant d'avoir reçu sa leçon offerte. Le compositeur vit autant
    /// que Home : « Réessayer », comme un écran rouvert, reprend la même réservation.
    @ObservationIgnored private(set) var lessonID = UUID()
    /// La source sous laquelle `lessonID` a été demandé. Le serveur garde la source d'une
    /// réservation : une demande d'une autre nature part sous un identifiant neuf.
    @ObservationIgnored private var reservedSource: LessonSourceKind?

    var hasRoom: Bool { supports.count < Self.maximumSupports }
    var isReading: Bool { supports.contains { $0.state == .reading } }
    var readySupports: [Support] { supports.filter { $0.state == .ready && $0.document != nil } }

    private var topic: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// On envoie un sujet d'au moins deux lettres, ou des supports lus.
    var canSend: Bool {
        guard !isReading else { return false }
        return !readySupports.isEmpty || topic.count >= 2
    }

    /// D'où vient la leçon, pour la porte du gratuit et pour le serveur.
    var source: LessonSourceKind {
        let kinds = Set(readySupports.map(Self.sourceKind(of:)))
        guard !kinds.isEmpty else { return .topic }
        return kinds.count == 1 ? kinds.first! : .mixed
    }

    // MARK: Les supports

    /// Une pastille « en lecture » ; le support arrive avec `finish` ou échoue avec `fail`.
    @discardableResult
    func begin(_ kind: Kind, title: String) -> UUID? {
        guard hasRoom else { return nil }
        let id = UUID()
        supports.append(Support(id: id, kind: kind, title: title))
        return id
    }

    func finish(_ id: UUID, with document: ImportedDocument) {
        guard let index = supports.firstIndex(where: { $0.id == id }) else { return }
        guard document.hasUsableText || !document.pageImages.isEmpty else {
            supports[index].state = .failed(L10n.t("lesson.import.unreadable", locale: .resolved()))
            return
        }
        supports[index].document = document
        supports[index].title = document.fileName
        supports[index].state = .ready
    }

    func fail(_ id: UUID, message: String) {
        guard let index = supports.firstIndex(where: { $0.id == id }) else { return }
        supports[index].state = .failed(message)
    }

    func remove(_ id: UUID) {
        supports.removeAll { $0.id == id }
    }

    func reset() {
        draft = ""
        supports = []
        lessonDelivered()
    }

    /// L'identifiant sous lequel envoyer la demande : celui de l'essai précédent tant que la
    /// leçon n'est pas arrivée, un neuf si la source a changé de nature.
    func reserveLessonID(for source: LessonSourceKind) -> UUID {
        if let reservedSource, reservedSource != source {
            lessonID = UUID()
        }
        reservedSource = source
        return lessonID
    }

    /// **La leçon existe** : son plan est arrivé et elle est dans la liste. La demande
    /// suivante en est une autre, et ne doit pas reprendre l'identifiant d'un cours déjà créé.
    func lessonDelivered() {
        lessonID = UUID()
        reservedSource = nil
    }

    // MARK: La demande

    /// Tout ce qui part au serveur. Un sujet seul part comme sujet ; avec des supports, ce qui
    /// est tapé devient la consigne de l'élève, en tête du texte.
    func creation(examDate: Date? = nil) -> LessonCreation {
        let ready = readySupports
        guard !ready.isEmpty else {
            return LessonCreation(topic: topic, source: .topic, examDate: examDate)
        }

        var parts: [String] = []
        if !topic.isEmpty {
            parts.append(L10n.t("lesson.import.instruction", locale: .resolved(), vars: ["text": topic]))
        }
        for support in ready {
            guard let document = support.document, !document.text.isEmpty else { continue }
            parts.append(ready.count > 1 ? "--- \(document.fileName) ---\n\(document.text)" : document.text)
        }
        let text = String(parts.joined(separator: "\n\n").prefix(Self.maximumCharacters))
        let images = Array(ready.compactMap(\.document).flatMap(\.pageImages).prefix(Self.maximumImages))
        return LessonCreation(
            topic: nil,
            text: text,
            images: images,
            source: source,
            sourceName: ready.count == 1 ? ready[0].document?.fileName : nil,
            coverImage: ready.compactMap(\.document?.coverImage).first,
            examDate: examDate
        )
    }

    static func sourceKind(of support: Support) -> LessonSourceKind {
        switch support.kind {
        case .pdf: support.document?.source == .docx ? .docx : .pdf
        case .photo: .photo
        case .audio: .audio
        case .youtube: .youtube
        case .text: .text
        }
    }
}

/// **La porte du gratuit, côté app** (`docs/refonte-parcours.md` § 7) : une leçon offerte, à vie,
/// depuis un sujet, un texte collé **ou un import** (`docs/refonte-knowunity.md` § 7 : la leçon
/// offerte importée part avec `onboarding: true`, que `begin_lesson(p_onboarding)` accepte) ;
/// une fois servie, les imports sont Pro. Le serveur tient la même porte (`begin_lesson`) :
/// celle-ci évite seulement un appel qui serait refusé.
enum LessonAllowance {
    /// Vrai quand l'élève a déjà un cours à lui : une leçon créée, un ancien cours importé ou
    /// généré. Les cours de démonstration, de la bibliothèque et les paquets faits à la main
    /// ne comptent pas, comme côté serveur.
    static func hasUsedFreeLesson(courses: [Course]) -> Bool {
        courses.contains { course in
            !course.isFromLibrary && ![.sample, .library, .deck].contains(course.source)
        }
    }

    /// Le paywall à ouvrir avant d'envoyer, ou `nil` si la demande peut partir.
    static func gate(isPro: Bool, source: LessonSourceKind, courses: [Course]) -> PaywallTrigger? {
        if isPro { return nil }
        // La leçon offerte n'a pas servi : elle part, d'un sujet comme d'un import.
        guard hasUsedFreeLesson(courses: courses) else { return nil }
        if source.isImport { return .generateCourse }
        return .secondCourse
    }

    /// Vrai quand cette demande est la leçon offerte **depuis un import** : elle part avec
    /// `onboarding: true`. Un sujet ou un texte n'en a pas besoin, le serveur les offre déjà.
    static func sendsAsFreeLesson(isPro: Bool, source: LessonSourceKind, courses: [Course]) -> Bool {
        !isPro && source.isImport && !hasUsedFreeLesson(courses: courses)
    }

    // MARK: Quand le paywall s'ouvre

    /// **Où mène l'envoi.** La règle reste celle de `gate` ; seul le moment du paywall change :
    /// un élève qui a déposé des supports les voit lus, puis le paywall s'ouvre au moment de
    /// débloquer la leçon. Un sujet seul n'a rien à lire : son paywall s'ouvre tout de suite,
    /// comme avant.
    enum SendRoute: Equatable {
        /// La demande part au serveur.
        case create
        /// Le paywall tout de suite, sans rien d'autre.
        case paywall(PaywallTrigger)
        /// La lecture (déjà faite sur l'appareil), l'aperçu de ce qui a été lu, puis le paywall
        /// `lessonReady`. Rien ne part au serveur avant l'achat : il refuserait la leçon.
        case lockedPreview
    }

    static func sendRoute(isPro: Bool, source: LessonSourceKind, courses: [Course]) -> SendRoute {
        guard let trigger = gate(isPro: isPro, source: source, courses: courses) else { return .create }
        return source == .topic ? .paywall(trigger) : .lockedPreview
    }

    /// Le paywall que Home ouvre **avant** l'écran de création : seulement celui d'un sujet
    /// seul. Les supports déposés passent par l'aperçu verrouillé (`LessonCreationFlow`).
    static func immediatePaywall(isPro: Bool, source: LessonSourceKind, courses: [Course]) -> PaywallTrigger? {
        if case .paywall(let trigger) = sendRoute(isPro: isPro, source: source, courses: courses) {
            return trigger
        }
        return nil
    }

    /// **Un import n'est jamais fermé, et ne porte plus de couronne.** Lire un PDF, des
    /// photos, un audio ou une vidéo se fait sur l'appareil ; c'est l'écriture de la leçon qui
    /// est dans Pro, et son paywall vient à la fin de la lecture (`sendRoute`). Home lit cette
    /// fonction pour la couronne d'`ImportGrid` comme pour le paywall de `tapImport`.
    static func locksImport(_ kind: LessonComposer.Kind, isPro: Bool, freeLessonLeft: Bool) -> Bool {
        false
    }
}

/// **Ce que Mika a vraiment lu**, pour l'aperçu verrouillé : rien d'inventé, tout vient des
/// supports lus sur l'appareil.
struct LessonReadSummary: Equatable {
    /// Les supports lus.
    var supports: Int
    /// Les pages d'un PDF, d'un Word ou de photos ; zéro pour une vidéo, un audio ou un texte
    /// collé, qui n'en ont pas (la ligne ne s'affiche alors pas).
    var pages: Int
    var words: Int
    /// Le titre deviné : le titre d'une vidéo, sinon la première vraie ligne du texte, sinon
    /// le nom du fichier.
    var title: String
    /// Les premières lignes du texte, floutées derrière le cadenas.
    var previewLines: [String]

    static let previewLineCount = 4
    static let maximumLineLength = 90

    init(documents: [ImportedDocument]) {
        supports = documents.count
        pages = documents
            .filter { [.pdf, .photo, .docx].contains($0.source) }
            .reduce(0) { $0 + max(1, $1.pageCount) }
        words = documents.reduce(0) { $0 + Self.wordCount($1.text) }

        let first = documents.first
        let lines = first.map { Self.meaningfulLines($0.text) } ?? []
        if let first, first.source == .youtube, let name = first.fileName.nilIfBlank {
            title = name
            previewLines = Array(lines.prefix(Self.previewLineCount))
        } else if let line = lines.first {
            title = Self.clip(line, to: 80)
            previewLines = Array(lines.dropFirst().prefix(Self.previewLineCount))
        } else {
            title = first?.fileName ?? ""
            previewLines = []
        }
        previewLines = previewLines.map { Self.clip($0, to: Self.maximumLineLength) }
    }

    /// Les mots : ce qui, entre deux blancs, contient une lettre ou un chiffre.
    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .filter { $0.contains(where: { $0.isLetter || $0.isNumber }) }
            .count
    }

    /// Les lignes qui disent quelque chose : au moins trois lettres, pas un numéro de page,
    /// pas une rangée de tirets.
    static func meaningfulLines(_ text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in line.filter(\.isLetter).count >= 3 }
    }

    private static func clip(_ line: String, to length: Int) -> String {
        line.count > length ? String(line.prefix(length - 1)) + "…" : line
    }
}
