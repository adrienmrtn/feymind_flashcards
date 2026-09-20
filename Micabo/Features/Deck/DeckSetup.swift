import Foundation
import Observation

/// **Pourquoi l'étudiant révise ce deck.**
///
/// Le type d'épreuve ne change pas le rythme — c'est la date qui s'en charge, et elle seule.
/// Il décide de deux choses : si l'on demande une date du tout, et quels entraînements ont
/// un sens sur ce deck. On ne propose pas d'examen blanc à quelqu'un qui révise sans épreuve
/// en vue.
enum DeckPurpose: String, CaseIterable, Identifiable, Codable {
    case quickTest
    case test
    case finalExam
    case justStudying

    var id: String { rawValue }

    /// Vrai quand une date d'épreuve a du sens. « J'apprends, c'est tout » en a une aussi,
    /// mais ce n'est pas la même question : voir `deadlineQuestionKey`.
    var isExam: Bool { self != .justStudying }

    /// Le type d'épreuve tel que le reste de l'app le connaît déjà. Un vocabulaire de plus
    /// pour dire la même chose finirait par ne plus dire la même chose.
    var examKind: ExamKind {
        switch self {
        case .quickTest: .quiz
        case .test: .exam
        case .finalExam: .final
        case .justStudying: .exam
        }
    }

    var emoji: String {
        switch self {
        case .quickTest: "⚡️"
        case .test: "📝"
        case .finalExam: "🎓"
        case .justStudying: "🌱"
        }
    }

    var titleKey: String { "ios.deckSetup.purpose.\(rawValue)" }
    var subtitleKey: String { "ios.deckSetup.purpose.\(rawValue).hint" }

    /// **Deux questions pour une même réponse.** « C'est quand, ton épreuve ? » et « tu veux
    /// avoir tout compris pour quand ? » produisent exactement le même effet sur le deck.
    /// Elles ne se posent pas dans les mêmes mots parce qu'elles ne s'adressent pas à la même
    /// situation, et demander « la date de ton examen » à quelqu'un qui n'en passe pas est le
    /// genre de question qui fait répondre n'importe quoi.
    var deadlineQuestionKey: String {
        isExam ? "ios.deckSetup.examDate" : "ios.deckSetup.understandBy"
    }
}

/// D'où vient la matière du deck.
enum DeckMaterialSource: String, Codable {
    /// L'étudiant dépose ses documents.
    case materials
    /// Il n'en a pas, et l'IA écrit le cours depuis le sujet.
    case generated
}

/// **Les réponses du parcours de création d'un deck.**
///
/// Un seul objet observable traversé par tous les écrans, plutôt qu'une pile de `@State`
/// remontés d'écran en écran : le parcours a des branches — on ne demande pas de note visée
/// à quelqu'un qui n'a pas d'épreuve — et une branche se lit beaucoup mieux sur un état
/// commun que sur douze liaisons.
@Observable
final class DeckSetup {
    var subject: String?
    var name: String = ""
    var source: DeckMaterialSource?
    var materials: [DeckMaterial] = []
    /// Ce que l'étudiant veut apprendre précisément, quand l'IA écrit tout. Vide vaut
    /// « tout le programme », ce que l'écran propose explicitement.
    var topic: String = ""
    var purpose: DeckPurpose?
    /// La note visée, sur la droite 10–20 que tout le barème partage. **Elle ne change
    /// rien**, et c'est assumé : elle sert à se dire à voix haute où l'on veut arriver, ce
    /// qui est la seule chose qu'un chiffre décoratif fait vraiment. La stocker permet au
    /// moins de la réafficher sur l'écran du deck, et de la porter sur l'épreuve créée.
    var targetScore: Int = TargetScore.default
    var deadline: Date?
    /// L'auto-évaluation, entre 0 et 1. Décorative elle aussi : personne ne sait ce qu'il
    /// sait, c'est précisément pourquoi on révise.
    var confidence: Double = 0.35

    /// Le barème du pays, pour que « 15/20 » ne s'affiche pas à un étudiant noté en lettres.
    let scale: DesiredGradeScale

    init(
        subject: String? = nil,
        country: SchoolingCountry = OnboardingPreferences.schoolingCountry
    ) {
        self.subject = subject
        self.scale = DesiredGradeScale.for(country)
    }

    // MARK: - Ce que chaque écran attend pour laisser passer

    var hasSubject: Bool { subject?.nilIfBlank != nil }
    var hasName: Bool { name.nilIfBlank != nil }
    var hasMaterials: Bool { materials.contains(where: \.isReady) }

    /// Le titre retenu pour le deck. Le nom saisi passe devant la matière : c'est celui que
    /// l'étudiant reconnaîtra dans sa liste.
    var resolvedTitle: String {
        name.nilIfBlank ?? subject?.nilIfBlank ?? L10n.t("ios.deckSetup.untitled", locale: .resolved())
    }

    /// Le texte de tous les supports, mis bout à bout pour la génération.
    ///
    /// Les documents sont séparés par leur nom : un deck de quatre chapitres photographiés
    /// séparément se lit autrement qu'un seul document de la même longueur, et le modèle a
    /// besoin de savoir où l'un s'arrête.
    func combinedText(limit: Int = 60_000) -> String {
        var out = ""
        for material in materials where material.isReady {
            guard let document = material.document else { continue }
            let header = "\n\n--- \(document.fileName) ---\n\n"
            if out.count + header.count >= limit { break }
            out += header
            out += String(document.text.prefix(max(0, limit - out.count)))
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Les pages rendues en image, tous supports confondus, pour la passe visuelle.
    ///
    /// Bornées : la fonction Edge n'en accepte que six, et lui en envoyer quarante coûterait
    /// le transfert de trente-quatre images qu'elle jettera.
    func combinedImages(limit: Int = 6) -> [Data] {
        var out: [Data] = []
        for material in materials where material.isReady {
            guard let document = material.document else { continue }
            for image in document.pageImages {
                guard out.count < limit else { return out }
                out.append(image)
            }
        }
        return out
    }

    /// La couverture du deck : la première page du premier support qui en a une.
    var coverImage: Data? {
        materials.compactMap { $0.document?.coverImage }.first
    }

    /// La provenance retenue pour le cours créé.
    ///
    /// Un deck fait de trois photos et d'un PDF n'a pas de provenance unique. On prend celle
    /// du premier support, qui est celle que l'étudiant a choisie en premier, plutôt que
    /// d'inventer une catégorie « mixte » qui ne voudrait rien dire dans sa liste de decks.
    var courseSource: CourseSource {
        guard source == .materials else { return .text }
        return materials.first(where: \.isReady)?.document?.source ?? .text
    }
}

/// **Un emplacement de support, rempli ou non.**
///
/// L'écran d'import montre des cases vides avant qu'il n'y ait quoi que ce soit dedans :
/// c'est ce qui fait comprendre qu'on peut en déposer plusieurs, là où un seul bouton
/// « importer un document » fait croire qu'on n'en dépose qu'un. La case existe donc avant
/// son document, et porte son propre état de lecture — un PDF de cent pages met plusieurs
/// secondes à être lu, et les autres cases doivent rester utilisables pendant ce temps.
@Observable
final class DeckMaterial: Identifiable {
    enum State: Equatable {
        case empty
        case reading
        case ready
        case failed(String)
    }

    let id = UUID()
    var state: State = .empty
    var document: ImportedDocument?

    init() {}

    var isReady: Bool {
        if case .ready = state { return document != nil }
        return false
    }

    var isBusy: Bool {
        state == .reading
    }

    var failure: String? {
        if case .failed(let message) = state { return message }
        return nil
    }

    /// Ce qui s'affiche sous la vignette : le nom du fichier, ou la panne.
    var caption: String? {
        if let failure { return failure }
        return document?.fileName
    }
}
