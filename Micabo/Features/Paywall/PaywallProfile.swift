import Foundation

/// **Ce que le paywall sait de l'élève**, relu des réponses du parcours d'accueil : son
/// prénom, et l'examen pour lequel son plan est fait.
///
/// Chaque mot vient d'une réponse ; une réponse absente retire le mot au lieu d'en inventer
/// un. Le paywall de l'app et celui de la fin du parcours lisent le même profil : c'est le
/// même écran.
struct PaywallProfile: Equatable {
    /// Le prénom : le premier mot de ce que l'élève a donné.
    var firstName: String?
    /// L'examen de son pays qu'il a choisi et qui n'est pas encore passé (« Bac », « Abitur »,
    /// « SAT »), assez court pour entrer dans un titre. Absent pour un contrôle, des
    /// partiels ou « rien pour l'instant ».
    var examName: String?
    /// L'identifiant de cet examen dans le catalogue (`SchoolExams`) : son préfixe dit de
    /// quel pays il est.
    var examID: String?

    /// La longueur au-delà de laquelle un nom d'examen ne tient plus dans le titre : il
    /// ferait une phrase de cinq lignes, et le titre reste alors celui de tout le monde.
    static let longestExamName = 18

    static func current(now: Date = Date()) -> PaywallProfile {
        let choice = SchoolExams.choice(id: OnboardingPreferences.examID)
        let name = examName(choice: choice, date: OnboardingPreferences.examDate, now: now)
        return PaywallProfile(
            firstName: firstName(OnboardingPreferences.displayName),
            examName: name,
            examID: name == nil ? nil : choice?.id
        )
    }

    /// Le prénom : le premier mot de ce que l'élève a donné, rien s'il n'a rien donné.
    static func firstName(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed.split(whereSeparator: \.isWhitespace).first.map(String.init)
    }

    /// **Le nom de l'examen, tel qu'il entre dans un titre** : celui d'un examen du pays, sans
    /// sa parenthèse (« PAU (Selectividad) » donne « PAU »), et seulement s'il est à venir.
    /// Un contrôle ou des partiels n'ont pas de nom propre : la phrase se construirait mal
    /// dans la moitié des langues.
    static func examName(choice: ExamChoice?, date: Date?, now: Date = Date()) -> String? {
        guard case .named(let exam)? = choice else { return nil }
        if let date, date < MicaboCalendar.shared.startOfDay(for: now) { return nil }
        let name = exam.title
            .components(separatedBy: " (").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty, name.count <= longestExamName else { return nil }
        return name
    }

    // MARK: - L'examen dans la phrase

    /// Les préfixes des examens dont le nom est français : leur article se déduit.
    private static let frenchNamedExams = ["fr.", "be.", "lu.", "ca.", "ma.", "dz.", "tn.", "sn.", "ci.", "ch.maturite", "ch.ef"]

    /// **L'examen, tel qu'il se glisse dans « Ton plan pour {examen} est prêt »** dans cette
    /// langue, ou `nil` quand la phrase ne se construirait pas.
    ///
    /// La plupart des langues accolent le nom tel quel (« Your SAT plan », « Dein
    /// Abitur-Plan », « YKS planın ») : leur gabarit s'en charge. Le français veut un
    /// article, et le genre d'un nom étranger ne se devine pas : il n'est posé que sur les
    /// examens au nom français (« le Bac », « l'Examen régional »). Pour les autres, le titre
    /// reste celui de tout le monde.
    func examPhrase(locale: UiLocale) -> String? {
        guard let examName else { return nil }
        guard locale == .fr else { return examName }
        guard let examID, Self.frenchNamedExams.contains(where: { examID.hasPrefix($0) }) else { return nil }
        return Self.frenchArticled(examName)
    }

    /// « le Bac », « l'Examen régional », « les Épreuves ministérielles ».
    ///
    /// Trois règles suffisent au catalogue : un premier mot au pluriel prend « les » (un sigle
    /// ou « Concours » n'en est pas un), une voyelle ou un h muet en tête fait l'élision, et
    /// tout le reste est masculin — les examens au nom français le sont tous, « épreuve » mis
    /// à part, qui commence par une voyelle.
    static func frenchArticled(_ name: String) -> String {
        let first = name.split(separator: " ").first.map(String.init) ?? name
        let isAcronym = first.count > 1 && first == first.uppercased()
        let plain = first.lowercased().folding(options: .diacriticInsensitive, locale: nil)
        if !isAcronym, plain.hasSuffix("s"), plain != "concours" {
            return "les \(name)"
        }
        if !isAcronym, let initial = plain.first, "aeiouyh".contains(initial) {
            return "l'\(name)"
        }
        return "le \(name)"
    }
}
