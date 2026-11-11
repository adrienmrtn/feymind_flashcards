import Foundation
import SwiftData
import SwiftUI

// MARK: - La matière

/// **La matière d'un exercice**, et le fil de Mika où il arrive.
///
/// Six familles et pas la liste des cours : un exercice scanné se range d'un coup d'œil, et
/// « Demande à Mika » garde une conversation par famille (comme une conversation par cours
/// chez les meilleures apps d'aide aux devoirs), pas vingt fils dont dix vides.
///
/// **Toutes les matières** (lot 7) : l'aide aux devoirs n'est plus un scanner de maths. Une
/// question de langue (grammaire, analyse d'un texte, traduction) et une question d'histoire,
/// de géographie, de philosophie ou d'économie ont leur famille et leur fil ; « Autres
/// matières » garde le reste. Un exercice déjà gardé relit sa matière telle quelle
/// (`init(stored:)`) : les valeurs enregistrées ne changent pas.
enum SolverSubject: String, CaseIterable, Identifiable, Codable {
    case math
    case physics
    case biology
    case languages
    case humanities
    case other

    var id: String { rawValue }

    /// La clé de son nom : celles du scanner pour les quatre premières, celles du lot 7 pour
    /// les langues et l'histoire-société.
    var labelKey: String {
        switch self {
        case .math: "ios.solve.subject.math"
        case .physics: "ios.solve.subject.physics"
        case .biology: "ios.solve.subject.biology"
        case .languages: "ios.ku7.subject.languages"
        case .humanities: "ios.ku7.subject.humanities"
        case .other: "ios.solve.subject.other"
        }
    }

    var label: String {
        L10n.t(labelKey, locale: .resolved())
    }

    /// La clé d'une des deux idées de question d'un fil vide (`index` vaut 1 ou 2).
    func suggestionKey(_ index: Int) -> String {
        let rank = index == 2 ? 2 : 1
        switch self {
        case .languages: return rank == 1 ? "ios.ku7.tutor.suggest.languages1" : "ios.ku7.tutor.suggest.languages2"
        case .humanities: return rank == 1 ? "ios.ku7.tutor.suggest.humanities1" : "ios.ku7.tutor.suggest.humanities2"
        default: return "ios.solve.tutor.suggest.\(rawValue)\(rank)"
        }
    }

    func suggestion(_ index: Int) -> String {
        L10n.t(suggestionKey(index), locale: .resolved())
    }

    var icon: MicaboIcon {
        switch self {
        case .math: .calculator
        case .physics: .atom
        case .biology: .brain
        case .languages: .flag
        case .humanities: .scroll
        case .other: .book
        }
    }

    /// La teinte de la pastille : le bleu de la marque, le jaune du crayon, un vert, un violet,
    /// un ambre, le rose. Une pastille, jamais un aplat : la couleur range, elle ne décore pas.
    var tint: Color {
        switch self {
        case .math: MicaboBrand.blue
        case .physics: MicaboBrand.pencil
        case .biology: Color(hex: 0x22A06B)
        case .languages: Color(hex: 0x7C5CE0)
        case .humanities: Color(hex: 0xC27A2C)
        case .other: MicaboBrand.eraser
        }
    }

    init(stored: String?) {
        self = SolverSubject(rawValue: stored ?? "") ?? .other
    }

    /// Ce que le modèle écrit après `[SUBJECT]` : « math », « physics »… ou un mot de sa
    /// langue, qu'on lit avec la même devinette que l'énoncé.
    init?(modelWord: String) {
        let word = SolverSubjectGuess.fold(modelWord)
        if let exact = SolverSubject(rawValue: word.trimmingCharacters(in: .whitespacesAndNewlines)) {
            self = exact
            return
        }
        let guess = SolverSubjectGuess.scores(for: word)
        guard let best = guess.max(by: { $0.value < $1.value }), best.value > 0 else { return nil }
        self = best.key
    }
}

// MARK: - La devinette

/// **La matière d'un énoncé, devinée sur l'appareil**, avant que Mika ne réponde : des mots
/// et des unités, dans les langues de l'app les plus parlées, et quelques signes. L'élève la
/// change d'un appui si elle est fausse, et Mika la confirme dans sa réponse (`[SUBJECT]`).
enum SolverSubjectGuess {
    static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    private static let math: [String] = [
        "equation", "inequation", "derive", "derivee", "derivative", "integrale", "integral", "primitive", "fonction", "function",
        "polynom", "fraction", "factoris", "developp", "simplif", "racine", "square root", "triangle",
        "angle", "cercle", "circle", "rayon", "radius", "perimetre", "perimeter", " aire ", "area",
        "volume d", "probabilit", "probability", "statisti", "moyenne", "median", "matrice", "matrix",
        "limite", "limit", "suite ", "sequence", "logarithm", "exponenti", "theoreme", "theorem",
        "pythagore", "pythagoras", "thales", "trigonom", "cosinus", "sinus", "tangente", "pgcd",
        "gleichung", "funktion", "ableitung", "wahrscheinlichkeit", "ecuacion", "funcion", "derivada", "denklem", "fonksiyon", "equazione", "funzione",
        "vergelijking", "rownanie", "уравнение", "функци",
        "معادلة", "دالة",
    ]

    private static let physics: [String] = [
        "vitesse", "velocity", "speed", "acceleration", "force", "newton", "energie", "energy", "joule",
        "puissance", "power", "watt", " tension", "voltage", "volt", "intensite", "courant", "current",
        "resistance", "ohm", "circuit", "frequence", "frequency", "onde", "wave", "lentille", "lens",
        "pression", "pressure", "temperature", "chaleur", "heat", "masse molaire", "molar", " mol",
        "molecule", "atome", "atom", " ion ", " ions ", "electron", "reaction", "concentration", "solution aqueuse",
        "acide", "acid", "oxyd", "redox", "titrage", "titration", "g/mol", "mol/l", "m/s", "km/h",
        "chimie", "chemistry", "physique", "physics", "gravit", "poids", "weight", "travail d",
        "geschwindigkeit", "kraft", "energie", "spannung", "strom", "chemie", "physik", "velocidad",
        "fuerza", "quimica", "fisica", "hiz", "kuvvet", "kimya", "fizik", "velocita", "chimica",
        "скорость", "сила", "энерги", "химия", "физика", "سرعة", "قوة", "طاقة", "كيمياء", "فيزياء",
    ]

    private static let biology: [String] = [
        "cellule", " cell", " adn", " dna", " arn ", " rna ", "genetique", "genetic", "proteine",
        "protein", "enzyme", "photosynthese", "photosynthesis", "respiration", "mitose", "mitosis",
        "meiose", "meiosis", "chromosome", "evolution", "espece", "species", "ecosysteme", "ecosystem",
        "neurone", "neuron", "hormone", "immun", "bacterie", "bacteria", "virus", "organisme",
        "organism", "svt", "biolog", "geolog", "roche", "plaque tectonique", "tectonic", "seisme",
        "volcan", "digestion", "sang", "blood", "muscle", "plante", "plant", "zelle", "erbgut",
        "celula", "hucre", "cellula", "клетк", "خلية", "مورث",
    ]

    /// Les langues et la littérature : la grammaire, la conjugaison, l'analyse d'un texte, la
    /// traduction, la rédaction.
    private static let languages: [String] = [
        "grammaire", "grammar", "conjug", "orthograph", "spelling", "vocabula", "tradu", "translat",
        "poeme", "poem", "poesie", "poetry", " roman ", "novel", "auteur", "author", "narrat", "metaphor",
        "figure de style", "commentaire", "dissertation", "redaction", "essay", "subjonctif", "subjunctive",
        "imparfait", "passe compose", "present perfect", "past simple", "irregular verb", "verbe", "adjecti",
        "adverb", "pronom", "pronoun", "litterat", "literature", "shakespeare", "moliere", "victor hugo", "goethe",
        "grammatik", "gedicht", "ubersetz", "aufsatz", "erorterung", "literatur",
        "gramatica", "poema", "redaccion", "literatura", "dilbilgisi", "siir", "ceviri", "kompozisyon",
        "grammatica", "poesia", "letteratura", "grammatyka", "wiersz",
        "грамматик", "стихотворен", "перевод", "сочинен", "литератур", "قواعد", "قصيدة", "ترجم", "إنشاء", "أدب",
    ]

    /// L'histoire, la géographie, la philosophie, l'économie.
    private static let humanities: [String] = [
        "histoire", "history", "historique", "guerre", " war ", "revolution", "empire", " roi ",
        "siecle", "century", "traite de", "treaty", "colonis", "democrat", "republique", "republic",
        "geograph", "climat", "mondialisation", "globalization", "territoire",
        "philosoph", "conscience", "liberte", "freedom", "verite", "kant", "platon", "plato", "descartes",
        "economi", "inflation", "chomage", "unemployment", "constitution", "citoyen", "citizen",
        "geschichte", "krieg", "erdkunde", "wirtschaft", "politik",
        "historia", "guerra", "geografia", "filosofia", "economia", "tarih", "savas", "cografya", "felsefe", "ekonomi",
        "storia", "geschiedenis", "история", "войн", "географ", "философ", "экономи",
        "تاريخ", "حرب", "جغرافيا", "فلسفة", "اقتصاد",
    ]

    /// Les points de chaque matière.
    static func scores(for text: String) -> [SolverSubject: Int] {
        let haystack = " " + fold(text) + " "
        var scores: [SolverSubject: Int] = [.math: 0, .physics: 0, .biology: 0, .languages: 0, .humanities: 0]
        for word in math where haystack.contains(word) { scores[.math, default: 0] += 1 }
        for word in physics where haystack.contains(word) { scores[.physics, default: 0] += 1 }
        for word in biology where haystack.contains(word) { scores[.biology, default: 0] += 1 }
        for word in languages where haystack.contains(word) { scores[.languages, default: 0] += 1 }
        for word in humanities where haystack.contains(word) { scores[.humanities, default: 0] += 1 }
        return scores
    }

    /// La matière la plus probable ; « autre » quand rien ne parle.
    static func guess(_ text: String) -> SolverSubject {
        var scores = Self.scores(for: text)
        // Des signes de calcul sans un mot de sciences : c'est des maths.
        let symbols = text.filter { "=+×÷^√∫∑<>≤≥²³πx".contains($0) }.count
        let digits = text.filter(\.isNumber).count
        if symbols >= 2, digits >= 2 {
            scores[.math, default: 0] += 1
        }
        guard let best = scores.max(by: { lhs, rhs in
            lhs.value != rhs.value ? lhs.value < rhs.value : order(lhs.key) > order(rhs.key)
        }), best.value > 0 else { return .other }
        return best.key
    }

    /// À égalité, l'ordre de la liste : les maths, puis la physique, puis la biologie.
    private static func order(_ subject: SolverSubject) -> Int {
        SolverSubject.allCases.firstIndex(of: subject) ?? 0
    }
}

// MARK: - Ce qui se garde

/// D'où vient l'énoncé.
enum SolverSource: String, Codable {
    case camera
    case library
    case typed
}

/// **Un exercice scanné**, et tout ce que Mika en a dit.
///
/// Sur le téléphone seulement : rien ne monte au serveur, et `LocalWipe` l'efface à la sortie
/// d'un compte. La réponse de Mika est gardée **telle qu'elle est arrivée** (`solutionRaw`) et
/// relue à chaque ouverture : un parseur amélioré profite aux anciens exercices.
@Model
final class SolvedExercise {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var subjectRaw: String = SolverSubject.other.rawValue
    var statement: String = ""
    var sourceRaw: String = SolverSource.camera.rawValue
    /// La vignette de la photo recadrée, petite (`SolverImage.thumbnail`).
    @Attribute(.externalStorage) var thumbnail: Data?
    /// La réponse de Mika, brute.
    var solutionRaw: String?
    /// Les étapes déjà dévoilées.
    var revealedSteps: Int = 0
    /// Les explications de « Je ne comprends pas cette étape », par numéro d'étape.
    var helpJSON: Data?
    /// L'exercice d'entraînement, quand il y en a un (`SolverPractice`).
    var practiceJSON: Data?
    /// Vrai une fois `exerciseSolved` gagné pour cet exercice.
    var rewarded: Bool = false

    init(statement: String, subject: SolverSubject, source: SolverSource, thumbnail: Data?) {
        self.id = UUID()
        self.createdAt = Date()
        self.updatedAt = Date()
        self.statement = statement
        self.subjectRaw = subject.rawValue
        self.sourceRaw = source.rawValue
        self.thumbnail = thumbnail
    }

    var subject: SolverSubject {
        get { SolverSubject(stored: subjectRaw) }
        set { subjectRaw = newValue.rawValue }
    }

    var source: SolverSource { SolverSource(rawValue: sourceRaw) ?? .camera }

    var solution: SolverSolution? {
        solutionRaw.flatMap(SolverParser.parse)
    }

    var help: [Int: String] {
        get {
            guard let helpJSON, let decoded = try? JSONDecoder().decode([String: String].self, from: helpJSON) else { return [:] }
            return Dictionary(uniqueKeysWithValues: decoded.compactMap { key, value in Int(key).map { ($0, value) } })
        }
        set {
            let encoded = Dictionary(uniqueKeysWithValues: newValue.map { (String($0.key), $0.value) })
            helpJSON = try? JSONEncoder().encode(encoded)
        }
    }

    var practice: SolverPractice? {
        get { practiceJSON.flatMap { try? JSONDecoder().decode(SolverPractice.self, from: $0) } }
        set { practiceJSON = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }
}

/// **L'exercice d'entraînement** : l'énoncé inventé par Mika, la réponse attendue (cachée), la
/// réponse de l'élève et la correction.
struct SolverPractice: Codable, Equatable {
    var exercise: String
    var expected: String?
    var attempt: String?
    var verdict: SolverVerdict?
    var feedback: String?
    var showsAnswer = false
}

enum SolverVerdict: String, Codable {
    case right
    case wrong
}

/// **Un message du fil d'une matière** dans « Demande à Mika ». Un exercice scanné y arrive en
/// deux messages, celui de l'élève (l'énoncé) et celui de Mika (la réponse), reliés à
/// l'exercice par `exerciseID`.
@Model
final class TutorMessage {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var subjectRaw: String = SolverSubject.other.rawValue
    var roleRaw: String = MikaTurn.Role.user.rawValue
    var text: String = ""
    var exerciseID: UUID?

    init(subject: SolverSubject, role: MikaTurn.Role, text: String, exerciseID: UUID? = nil, createdAt: Date = Date()) {
        self.id = UUID()
        self.createdAt = createdAt
        self.subjectRaw = subject.rawValue
        self.roleRaw = role.rawValue
        self.text = text
        self.exerciseID = exerciseID
    }

    var subject: SolverSubject { SolverSubject(stored: subjectRaw) }
    var role: MikaTurn.Role { MikaTurn.Role(rawValue: roleRaw) ?? .user }
}
