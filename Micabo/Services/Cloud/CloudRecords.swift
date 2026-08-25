import Foundation

/// Les lignes de la base, telles qu'elles voyagent.
///
/// Ce sont des structures à part, et pas les modèles SwiftData annotés `Codable` : un modèle
/// porte des relations, des données externes et des propriétés calculées, dont aucune n'a de
/// sens sur le fil. Les traduire ici a un coût, et un bénéfice — le jour où une colonne change
/// de nom côté serveur, un seul fichier bouge.
///
/// **Ce qui ne monte pas, et pourquoi.** Les images d'occlusion, les couvertures et les
/// enregistrements audio restent sur l'appareil : ce sont des mégaoctets par cours, et une
/// colonne `bytea` transforme une base Postgres en disque dur. Leur place est le stockage
/// objet de Supabase, et c'est la première chose à ajouter après cette synchro (voir la note
/// « flywheel » dans le README).
enum CloudTable {
    static let profiles = "profiles"
    static let courses = "courses"
    static let flashcards = "flashcards"
    static let reviewLogs = "review_logs"
    static let exams = "exams"
}

struct ProfileRecord: Codable {
    var id: UUID
    var display_name: String?
    var study_level: String?
    var country_code: String
    var learning_goals: [String]
    var subjects: [String]
    var institution_id: String?
    var institution_name: String?
    var daily_minutes: Int
    var sheet_length: String
    var onboarding_completed_at: Date?

    /// Le profil tel que les réglages locaux le décrivent.
    static func fromLocalPreferences(userID: UUID, displayName: String?) -> ProfileRecord {
        ProfileRecord(
            id: userID,
            display_name: displayName,
            study_level: OnboardingPreferences.level,
            country_code: OnboardingPreferences.schoolingCountry.rawValue,
            learning_goals: OnboardingPreferences.goals,
            subjects: OnboardingPreferences.subjects,
            institution_id: OnboardingPreferences.institutionId,
            institution_name: OnboardingPreferences.institutionName,
            daily_minutes: OnboardingPreferences.dailyMinutes,
            sheet_length: SheetPreferences.length.rawValue,
            onboarding_completed_at: OnboardingPreferences.isCompleted ? Date() : nil
        )
    }

    /// Recopie le profil distant dans les réglages locaux.
    ///
    /// C'est ce qui fait qu'une réinstallation retrouve un étudiant en PASS au Maroc et non un
    /// lycéen français par défaut, sans lui refaire passer l'inscription.
    func applyToLocalPreferences() {
        if let country = SchoolingCountry(rawValue: country_code) {
            OnboardingPreferences.schoolingCountry = country
        }
        if let study_level {
            OnboardingPreferences.level = study_level
            // Le profil distant ne transporte que le registre : il n'y a pas de colonne pour
            // le palier, et il n'en faut pas. Mais les traces du palier local doivent partir
            // avec, sinon elles gagnent contre lui — un lycéen français qui se connecte à un
            // compte « master aux États-Unis » resterait affiché en lycée, et le palier
            // périmé finirait par réécrire le registre au premier passage dans les réglages.
            OnboardingPreferences.educationStageId = nil
            OnboardingPreferences.educationTier = nil
        }
        if !learning_goals.isEmpty { OnboardingPreferences.goals = learning_goals }
        if !subjects.isEmpty { OnboardingPreferences.subjects = subjects }
        if let institution_id { OnboardingPreferences.institutionId = institution_id }
        if let institution_name { OnboardingPreferences.institutionName = institution_name }
        OnboardingPreferences.dailyMinutes = daily_minutes
        if let length = SheetLength(rawValue: sheet_length) { SheetPreferences.length = length }
    }
}

/// Un cours : l'original **et** le transformé, dans la même ligne.
///
/// C'est le choix de schéma qui compte le plus ici. `raw_text` est le document tel qu'il a été
/// lu, `sheet` est la fiche que le modèle en a écrite. Garder les deux côte à côte coûte de la
/// place et ne sert à rien aujourd'hui — c'est pourtant la condition de tout ce qui vient
/// après : réécrire une fiche avec un meilleur modèle, comparer deux versions, mesurer.
struct CourseRecord: Codable {
    var id: UUID
    var user_id: UUID
    var title: String
    var subject: String?
    var summary: String
    var emoji: String?
    var accent_hex: String?
    var source: String
    var source_file_name: String?
    var fingerprint: String
    var raw_text: String
    /// La fiche en JSON, transportée telle quelle. Elle est déjà du JSON côté app
    /// (`Course.sheetData`) : la décoder pour la réencoder ne ferait que risquer de la perdre.
    var sheet: JSONCodable?
    var context_text: String
    var is_from_library: Bool
    var created_at: Date
    var updated_at: Date
    var deleted_at: Date?
}

struct FlashcardRecord: Codable {
    var id: UUID
    var user_id: UUID
    var course_id: UUID?
    var front: String
    var back: String
    var hint: String?
    var position: Int
    var kind: String
    var choices: [String]
    var correct_choice_index: Int
    var mask_x: Double
    var mask_y: Double
    var mask_width: Double
    var mask_height: Double
    var group_id: UUID?
    var is_reversed: Bool
    var is_suspended: Bool
    var state: String
    var due_date: Date
    var interval_days: Double
    var ease_factor: Double
    var repetitions: Int
    var lapses: Int
    var step_index: Int
    var last_reviewed_at: Date?
    var created_at: Date
    var updated_at: Date
    var deleted_at: Date?
}

struct ReviewLogRecord: Codable {
    var id: UUID
    var user_id: UUID
    var card_id: UUID?
    var reviewed_at: Date
    var rating: Int
    var state_before: String
    var previous_interval_days: Double
    var new_interval_days: Double
    var ease_after: Double
}

struct ExamRecord: Codable {
    var id: UUID
    var user_id: UUID
    var name: String
    var exam_date: Date
    var intensity: String
    var course_ids: [UUID]
    var is_planned: Bool
    var planned_at: Date?
    var created_at: Date
    var updated_at: Date
    var deleted_at: Date?
}

/// Un morceau de JSON transporté sans être interprété.
///
/// La fiche d'un cours est déjà stockée en JSON sur l'appareil. La décoder en blocs pour la
/// réencoder ensuite ferait passer chaque fiche par deux traductions de plus à chaque synchro,
/// avec une occasion de perdre quelque chose à chaque fois. Elle traverse donc telle quelle.
struct JSONCodable: Codable {
    let data: Data

    init?(data: Data?) {
        guard let data, !data.isEmpty,
              (try? JSONSerialization.jsonObject(with: data)) != nil else { return nil }
        self.data = data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(JSONValue.self)
        data = try JSONEncoder().encode(value)
    }

    func encode(to encoder: Encoder) throws {
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            var container = encoder.singleValueContainer()
            try container.encodeNil()
            return
        }
        // `JSONSerialization` rend un objet Foundation, que `Encoder` ne sait pas écrire : on
        // repasse par `JSONValue`, qui est codable des deux côtés.
        let normalized = try JSONDecoder().decode(
            JSONValue.self,
            from: try JSONSerialization.data(withJSONObject: object)
        )
        try normalized.encode(to: encoder)
    }
}
