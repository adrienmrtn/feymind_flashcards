import Foundation

struct CourseGenerationRequest {
    var rawText: String
    /// Pages rendues en JPEG (base64) pour que le modèle lise schémas et figures.
    var pageImages: [Data]
    var hintTitle: String?
    var sourceName: String?
    /// Pour qui la fiche est écrite. Absent, le modèle écrit sans niveau supposé.
    var studyLevel: StudyLevel? = nil
    /// Où l'étudiant est scolarisé : « attendus du bac » ne veut rien dire en Belgique.
    var country: SchoolingCountry? = nil
    /// La langue de **cette** fiche. `nil` reste dans la langue du document ;
    /// une valeur force une autre langue.
    var language: ContentLanguage? = nil
    var sheetLength: SheetLength = .default
    /// Le volume exact demandé, en blocs. Le format ci-dessus reste envoyé : une
    /// fonction déployée avant le curseur continu le comprend encore.
    var sheetBlocks: Int = SheetLength.default.defaultBlocks
    /// Matière, quand elle est déjà connue. À l'import elle ne l'est pas : c'est le modèle
    /// qui la trouve, et la fonction la devine sur le texte pour choisir ses consignes.
    var subject: String? = nil
    /// Comment le texte a été obtenu. Une photo passée à l'OCR ne se relit pas comme un
    /// document Word, et c'est ce qui permet de se méfier des mots mal lus.
    var sourceKind: CourseSource? = nil
}

struct FlashcardGenerationRequest {
    var courseTitle: String
    var courseContext: String
    var existingFronts: [String]
    var quota: QuestionQuota = .default
    var subject: String? = nil
    /// Les cartes se posent dans la langue de la fiche : un paquet moitié français moitié
    /// anglais ne se révise pas.
    var language: ContentLanguage = .fr
}

/// Un passage de la fiche que l'utilisateur a sélectionné et veut comprendre.
///
/// Le passage seul ne suffit pas : « la Rubisco » n'a de sens que dans son cours. On envoie
/// donc aussi le contexte, et le modèle répond en s'appuyant dessus au lieu de réciter une
/// définition d'encyclopédie.
struct SelectionExplanationRequest {
    var selection: String
    var courseTitle: String
    var subject: String?
    var courseContext: String
    var language: ContentLanguage = .fr
}

/// Ce que l'IA renvoie sur un passage sélectionné.
///
/// La réponse est découpée, et pas rendue en un bloc de texte, pour une raison
/// d'affichage : `headline` est ce qu'on lit en premier et doit répondre seule, `body`
/// développe, et les deux derniers champs n'apparaissent que s'ils apportent quelque
/// chose. Le texte porte le balisage de la fiche, donc du gras et du surlignage.
struct SelectionExplanation: Codable, Equatable {
    /// Une phrase qui répond, sans préambule.
    var headline: String
    /// Deux à quatre phrases qui développent.
    var body: String
    /// Un exemple concret, s'il éclaire vraiment.
    var example: String?
    /// La confusion classique sur ce point.
    var watchOut: String?
    /// Une carte prête à être ajoutée au cours, pour ne pas reperdre ce qu'on vient de
    /// comprendre.
    var card: GeneratedFlashcard?

    var isUsable: Bool {
        !headline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Format de fiche demandé au modèle.
///
/// **Ce sont des usages, pas des tailles** : « L'essentiel » se relit dans le couloir avant
/// l'épreuve, « Approfondie » remplace le cours quand on a manqué l'amphi. Les trois noms
/// restent la seule chose que la fonction Edge connaisse, et la seule que le profil
/// synchronise.
///
/// Le réglage fin, lui, est un **nombre de blocs** (`SheetPreferences.blocks`) : le curseur
/// n'avait que trois positions, et pousser un curseur de trois crans ne se distingue pas de
/// trois boutons. Le format se déduit du nombre.
enum SheetLength: String, CaseIterable, Identifiable {
    case brief
    case standard
    case deep

    static let `default` = SheetLength.standard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .brief: "L'essentiel"
        case .standard: "Équilibrée"
        case .deep: "Approfondie"
        }
    }

    /// Les bornes de blocs du format, celles-là mêmes que la fonction demande au modèle.
    var blockRange: ClosedRange<Int> {
        switch self {
        case .brief: 8...12
        case .standard: 14...22
        case .deep: 24...34
        }
    }

    /// Le nombre de blocs à retenir quand on choisit le format sans toucher au curseur :
    /// le milieu de sa plage, qui est ce que le format décrit le mieux.
    var defaultBlocks: Int {
        (blockRange.lowerBound + blockRange.upperBound) / 2
    }

    /// Le format auquel appartient un nombre de blocs.
    ///
    /// Les plages ont des trous — treize et vingt-trois blocs ne tombent dans aucune —, et
    /// c'est voulu côté modèle : ce sont des consignes, pas une partition. Le curseur, lui,
    /// est continu, donc il faut décider où bascule le nom. Il bascule au milieu du trou.
    static func containing(blocks: Int) -> SheetLength {
        if blocks <= 13 { return .brief }
        if blocks <= 23 { return .standard }
        return .deep
    }

    /// Ce que le curseur couvre, d'un bout à l'autre.
    static let blockBounds = 8...34
}

/// La longueur de fiche retenue, réglée à l'import comme dans les réglages.
enum SheetPreferences {
    static let lengthKey = "micabo.sheet.length"
    /// Le nombre de blocs visé, et **la source de vérité** depuis que le curseur est continu.
    static let blocksKey = "micabo.sheet.blocks"

    static var defaultBlocks: Int { SheetLength.default.defaultBlocks }

    /// Le nombre de blocs demandé, entre 8 et 34.
    ///
    /// À la première lecture sur un appareil qui n'a connu que les trois formats, il se
    /// déduit du format enregistré : personne ne doit voir son réglage sauter parce que la
    /// façon de le stocker a changé.
    static var blocks: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: blocksKey)
            guard stored > 0 else { return storedLength?.defaultBlocks ?? defaultBlocks }
            return min(max(stored, SheetLength.blockBounds.lowerBound), SheetLength.blockBounds.upperBound)
        }
        set {
            let clamped = min(max(newValue, SheetLength.blockBounds.lowerBound), SheetLength.blockBounds.upperBound)
            UserDefaults.standard.set(clamped, forKey: blocksKey)
            // Le format reste écrit à côté : c'est lui que le profil synchronise, et lui que
            // la fonction Edge comprend depuis toujours.
            UserDefaults.standard.set(SheetLength.containing(blocks: clamped).rawValue, forKey: lengthKey)
        }
    }

    /// Le format, déduit du nombre de blocs. L'écrire replace le curseur au milieu de sa
    /// plage, sauf s'il y est déjà : choisir « Équilibrée » quand on est à 20 blocs ne doit
    /// pas ramener à 18.
    static var length: SheetLength {
        get { SheetLength.containing(blocks: blocks) }
        set {
            guard newValue != SheetLength.containing(blocks: blocks) else { return }
            blocks = newValue.defaultBlocks
        }
    }

    /// La durée de lecture annoncée à côté du format, tirée du volume demandé et non d'une
    /// estimation d'ambiance.
    static func readingHint(forBlocks blocks: Int) -> String {
        "≈ \(max(1, Int((Double(blocks) / 4.5).rounded()))) min"
    }

    private static var storedLength: SheetLength? {
        UserDefaults.standard.string(forKey: lengthKey).flatMap(SheetLength.init(rawValue:))
    }
}

/// Combien de cartes de chaque format une génération doit produire.
///
/// Ce qui vivait ici était une paire d'interrupteurs : ils disaient « j'accepte des QCM »,
/// et le modèle en écrivait deux ou onze selon son humeur. **Un nombre par format est une
/// commande, pas une autorisation** : l'étudiant qui veut cinq QCM et cinq textes à trou
/// pour son contrôle de la semaine peut désormais le demander.
struct QuestionQuota: Equatable {
    var basic: Int
    var cloze: Int
    var choice: Int

    /// Vingt-quatre cartes, en trois parts : de quoi tenir une vraie session dès le
    /// premier paquet.
    static let `default` = QuestionQuota(basic: 10, cloze: 7, choice: 7)

    /// Ce qu'un format accepte. Zéro veut dire « pas de ce format », et c'est un choix
    /// légitime : le plafond, lui, protège la session qui suivra.
    static let perFormatRange = 0...24
    /// Une carte ne suffit pas à faire une session ; au-delà, c'est trop pour une génération.
    static let totalRange = 3...48

    var total: Int { basic + cloze + choice }

    func count(of kind: CardKind) -> Int {
        switch kind {
        case .basic: basic
        case .cloze: cloze
        case .choice: choice
        case .occlusion: 0
        }
    }

    /// Les formats réellement demandés. Un format à zéro n'a rien à faire dans la consigne.
    var kinds: [CardKind] {
        [CardKind.basic, .cloze, .choice].filter { count(of: $0) > 0 }
    }

    var wireKinds: [String] {
        kinds.map(\.rawValue)
    }

    var wireCounts: [String: Int] {
        ["basic": basic, "cloze": cloze, "choice": choice]
    }

    /// Chaque format dans ses bornes, sans toucher au total. C'est la forme sous laquelle un
    /// quota se retient : ce que l'utilisateur a réglé, y compris un total nul, qui veut dire
    /// qu'il n'a pas encore choisi.
    func formatBounded() -> QuestionQuota {
        QuestionQuota(basic: Self.clamp(basic), cloze: Self.clamp(cloze), choice: Self.clamp(choice))
    }

    /// Ramène le quota dans ses bornes, total compris. C'est la forme sous laquelle il part
    /// au modèle.
    ///
    /// Un quota entièrement à zéro ne demande rien : plutôt que de partir écrire zéro
    /// carte, on retombe sur le recto verso, le seul format qui marche sur n'importe quel
    /// cours. Un total au-delà du plafond est rogné en commençant par le format le plus
    /// nombreux, pour que les petites commandes soient respectées à la carte près.
    func clamped() -> QuestionQuota {
        var result = formatBounded()

        if result.total == 0 {
            return QuestionQuota(basic: Self.totalRange.lowerBound, cloze: 0, choice: 0)
        }

        while result.total > Self.totalRange.upperBound {
            if result.basic >= result.cloze, result.basic >= result.choice {
                result.basic -= 1
            } else if result.cloze >= result.choice {
                result.cloze -= 1
            } else {
                result.choice -= 1
            }
        }

        // Sous le plancher, on complète en recto verso : c'est le format qu'on peut ajouter
        // à n'importe quel cours sans que la carte sonne faux.
        if result.total < Self.totalRange.lowerBound {
            result.basic += Self.totalRange.lowerBound - result.total
        }

        return result
    }

    private static func clamp(_ value: Int) -> Int {
        min(perFormatRange.upperBound, max(perFormatRange.lowerBound, value))
    }
}

/// Les réglages de génération, retenus d'un cours à l'autre : personne n'a envie de les
/// refaire à chaque fois.
enum QuestionQuotaPreferences {
    enum Key {
        static let basic = "micabo.generation.basicCount"
        static let cloze = "micabo.generation.clozeCount"
        static let choice = "micabo.generation.choiceCount"

        /// Les clés d'avant les quotas : un volume total et deux interrupteurs.
        static let legacyCount = "micabo.generation.count"
        static let legacyCloze = "micabo.generation.cloze"
        static let legacyChoice = "micabo.generation.choice"
    }

    /// Le quota courant, ou sa traduction depuis les anciens réglages.
    ///
    /// Un utilisateur qui avait coupé les QCM ne doit pas les retrouver au premier
    /// lancement : ses interrupteurs sont relus tant que les nouvelles clés n'ont pas été
    /// écrites, et son volume est réparti entre les formats qu'il gardait.
    ///
    /// Le total n'est pas rétabli ici : ce qui a été réglé se relit tel quel, et c'est la
    /// génération qui refuse de partir sans rien à écrire.
    static var current: QuestionQuota {
        let defaults = UserDefaults.standard

        if let basic = defaults.object(forKey: Key.basic) as? Int {
            return QuestionQuota(
                basic: basic,
                cloze: defaults.object(forKey: Key.cloze) as? Int ?? 0,
                choice: defaults.object(forKey: Key.choice) as? Int ?? 0
            ).formatBounded()
        }

        return migrated(from: defaults).formatBounded()
    }

    static func save(_ quota: QuestionQuota) {
        let bounded = quota.formatBounded()
        let defaults = UserDefaults.standard
        defaults.set(bounded.basic, forKey: Key.basic)
        defaults.set(bounded.cloze, forKey: Key.cloze)
        defaults.set(bounded.choice, forKey: Key.choice)
    }

    private static func migrated(from defaults: UserDefaults) -> QuestionQuota {
        let legacyKeys = [Key.legacyCount, Key.legacyCloze, Key.legacyChoice]
        guard legacyKeys.contains(where: { defaults.object(forKey: $0) != nil }) else {
            // Rien à traduire : c'est une première génération.
            return .default
        }

        let total = defaults.object(forKey: Key.legacyCount) as? Int ?? QuestionQuota.default.total
        let keepsCloze = defaults.object(forKey: Key.legacyCloze) as? Bool ?? true
        let keepsChoice = defaults.object(forKey: Key.legacyChoice) as? Bool ?? true

        let shares = 1 + (keepsCloze ? 1 : 0) + (keepsChoice ? 1 : 0)
        let share = max(1, total / shares)
        return QuestionQuota(
            basic: total - (keepsCloze ? share : 0) - (keepsChoice ? share : 0),
            cloze: keepsCloze ? share : 0,
            choice: keepsChoice ? share : 0
        )
    }
}

struct GeneratedFlashcard: Codable, Hashable {
    var front: String
    var back: String
    var hint: String? = nil
    /// Format annoncé par le modèle : « basic », « cloze » ou « choice ». Absent vaut
    /// recto verso.
    var kind: String? = nil
    /// Propositions d'un QCM, dans l'ordre d'affichage.
    var choices: [String]? = nil
    /// Index de la bonne proposition dans `choices`.
    var answerIndex: Int? = nil

    /// Format retenu côté app. Une occlusion ne se génère pas depuis du texte : elle se
    /// dessine sur une image, donc on la refuse ici.
    var resolvedKind: CardKind {
        guard let kind, let parsed = CardKind(rawValue: kind), parsed != .occlusion else {
            return .basic
        }
        return parsed
    }
}

enum AIServiceError: LocalizedError {
    case notConfigured
    case emptySource
    case network(String)
    case server(String)
    case invalidResponse
    case missingProviderKey

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "L'accès à l'IA n'est pas configuré. Renseignez l'URL Supabase dans Profil, Réglages."
        case .emptySource:
            "Il n'y a pas assez de texte à analyser."
        case .network(let message):
            "Connexion impossible. \(message)"
        case .server(let message):
            message
        case .invalidResponse:
            "La réponse de l'IA n'a pas pu être lue. Réessaie."
        case .missingProviderKey:
            "La clé fal.ai est absente côté Supabase. Ajoute le secret FAL_KEY à ton projet."
        }
    }
}

protocol AIService {
    /// Analyse un import et en écrit la fiche.
    func generateCourse(_ request: CourseGenerationRequest) async throws -> GeneratedCourse
    /// Écrit des cartes à partir d'un cours déjà fiché.
    func generateFlashcards(_ request: FlashcardGenerationRequest) async throws -> [GeneratedFlashcard]
    /// Explique un passage sélectionné dans la fiche.
    func explain(_ request: SelectionExplanationRequest) async throws -> SelectionExplanation
}
