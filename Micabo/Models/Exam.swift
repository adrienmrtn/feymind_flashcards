import Foundation
import SwiftData

/// À quel point on veut réviser avant l'examen.
///
/// L'intensité ne change pas *quoi* réviser, mais **combien de fois** chaque carte repasse
/// avant le jour J. C'est le seul réglage : demander un nombre de cartes par jour serait
/// demander à l'étudiant de faire le calcul que l'app est là pour faire.
enum ExamIntensity: String, Codable, CaseIterable, Identifiable {
    case light
    case standard
    case intense

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light: "Légère"
        case .standard: "Normale"
        case .intense: "Intensive"
        }
    }

    /// Passages de base, avant l'ajustement dû à l'état de la carte.
    ///
    /// Deux pour un chapitre déjà su, trois pour un contrôle ordinaire, quatre pour un examen
    /// qui compte. Ces phrases s'écrivaient sous les trois pastilles ; elles ont disparu avec
    /// les autres notes explicatives, et la projection juste en dessous dit la même chose en
    /// chiffres — combien de cartes, sur combien de jours, et à quoi ressemble le pire jour.
    var basePasses: Int {
        switch self {
        case .light: 2
        case .standard: 3
        case .intense: 4
        }
    }
}

/// Un examen déclaré par l'utilisateur : un nom, un jour, des cours, une intensité.
///
/// Les cours sont référencés par leur identifiant et non par une relation SwiftData. Un
/// examen ne possède pas ses cours, il les désigne : supprimer un cours ne doit pas
/// supprimer l'examen, ni l'empêcher de s'ouvrir. Le cours disparu sort simplement de la
/// liste à la lecture.
@Model
final class Exam {
    var id: UUID = UUID()
    var name: String = ""
    /// Le jour de l'examen, ramené au début de la journée.
    var date: Date = Date()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var intensityRaw: String = ExamIntensity.standard.rawValue
    /// Note visée, sur la droite 10–20. L'intensité s'en déduit.
    var targetScore: Int = 15
    /// Identifiants des cours au programme.
    var courseIDs: [UUID] = []
    /// Vrai quand la replanification a été appliquée aux cartes.
    var isPlanned: Bool = false
    var plannedAt: Date?
    /// Les échéances d'avant la replanification.
    ///
    /// Sans cette photographie, supprimer un examen laisserait le planning comprimé sans
    /// plus rien pour le justifier : les cartes reviendraient tous les deux jours pour un
    /// examen qui n'existe plus.
    @Attribute(.externalStorage) var scheduleBackup: Data?

    init(
        id: UUID = UUID(),
        name: String,
        date: Date,
        courseIDs: [UUID] = [],
        intensity: ExamIntensity = .standard,
        targetScore: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.date = date
        self.createdAt = Date()
        self.updatedAt = Date()
        let score = TargetScore.clamp(targetScore ?? TargetScore.score(from: intensity))
        self.targetScore = score
        self.intensityRaw = TargetScore.intensity(from: score).rawValue
        self.courseIDs = courseIDs
        self.isPlanned = false
    }

    var intensity: ExamIntensity {
        get { ExamIntensity(rawValue: intensityRaw) ?? .standard }
        set { intensityRaw = newValue.rawValue }
    }

    /// Jours restants, en journées entières. Négatif une fois l'examen passé.
    func daysRemaining(from now: Date = Date(), calendar: Calendar = MicaboCalendar.shared) -> Int {
        let today = calendar.startOfDay(for: now)
        let day = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: today, to: day).day ?? 0
    }

    func isPast(from now: Date = Date(), calendar: Calendar = MicaboCalendar.shared) -> Bool {
        daysRemaining(from: now, calendar: calendar) < 0
    }

    /// « demain », « J-5 », « aujourd'hui ». Le compte à rebours est ce qu'on lit en premier.
    func countdownLabel(
        from now: Date = Date(),
        calendar: Calendar = MicaboCalendar.shared,
        locale: UiLocale = .resolved()
    ) -> String {
        let days = daysRemaining(from: now, calendar: calendar)
        switch days {
        case ..<0: return L10n.t("app.exams.countdown.past", locale: locale)
        case 0: return L10n.t("app.exams.countdown.today", locale: locale)
        case 1: return L10n.t("app.exams.countdown.tomorrow", locale: locale)
        default: return L10n.t("app.exams.countdown.inDays", locale: locale, vars: ["days": "\(days)"])
        }
    }
}

/// Les échéances d'avant une replanification, pour pouvoir la défaire.
struct ExamScheduleBackup: Codable, Equatable {
    struct Entry: Codable, Equatable {
        var card: UUID
        var dueDate: Date
        var intervalDays: Double
        var state: String
    }

    var entries: [Entry]

    init(entries: [Entry]) {
        self.entries = entries
    }

    init(cards: [Flashcard]) {
        entries = cards.map { card in
            Entry(
                card: card.id,
                dueDate: card.dueDate,
                intervalDays: card.intervalDays,
                state: card.state.rawValue
            )
        }
    }

    func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func decode(from data: Data?) -> ExamScheduleBackup? {
        guard let data, !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(ExamScheduleBackup.self, from: data)
    }

    /// Remet les cartes encore présentes dans l'état où elles étaient. Une carte supprimée
    /// entre-temps est ignorée : elle n'a plus de planning à restaurer.
    func restore(on cards: [Flashcard]) {
        let byID = Dictionary(cards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for entry in entries {
            guard let card = byID[entry.card] else { continue }
            card.dueDate = entry.dueDate
            card.intervalDays = entry.intervalDays
            card.state = CardState(rawValue: entry.state) ?? card.state
            card.updatedAt = Date()
        }
    }
}

/// Le calendrier de l'app.
///
/// Micabo parle français : la semaine commence le lundi, partout et quel que soit le
/// réglage régional du téléphone. Une grille de calendrier qui démarre le dimanche dans une
/// interface française se lit de travers.
enum MicaboCalendar {
    static let shared: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = UiLocale.resolved().foundation
        calendar.firstWeekday = 2
        return calendar
    }()

    /// Initiales des jours, dans l'ordre de la grille.
    static let weekdayInitials = ["L", "M", "M", "J", "V", "S", "D"]

    /// « mardi 8 septembre », sans l'année quand c'est cette année-ci.
    static func dayLabel(_ date: Date, from reference: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = UiLocale.resolved().foundation
        formatter.calendar = shared
        let sameYear = shared.component(.year, from: date) == shared.component(.year, from: reference)
        formatter.setLocalizedDateFormatFromTemplate(sameYear ? "EEEE d MMMM" : "EEEE d MMMM yyyy")
        return formatter.string(from: date)
    }

    /// « 8 sept. », pour les endroits étroits.
    static func shortDayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = UiLocale.resolved().foundation
        formatter.calendar = shared
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter.string(from: date)
    }

    /// « Septembre 2026 », en tête du calendrier.
    static func monthLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = UiLocale.resolved().foundation
        formatter.calendar = shared
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: date).capitalizedFirstLetter
    }
}
