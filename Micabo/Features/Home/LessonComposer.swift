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
/// depuis un sujet ou un texte collé ; les imports sont Pro. Le serveur tient la même porte
/// (`begin_lesson`) : celle-ci évite seulement un appel qui serait refusé.
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
        if source.isImport { return .generateCourse }
        return hasUsedFreeLesson(courses: courses) ? .secondCourse : nil
    }
}
