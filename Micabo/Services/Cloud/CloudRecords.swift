import Foundation

/// Les lignes de la base, telles qu'elles voyagent.
///
/// Ce sont des structures à part, et pas les modèles SwiftData annotés `Codable` : un modèle
/// porte des relations, des données externes et des propriétés calculées, dont aucune n'a de
/// sens sur le fil. Les traduire ici a un coût, et un bénéfice — le jour où une colonne change
/// de nom côté serveur, un seul fichier bouge.
///
/// **Ce qui ne monte pas, et pourquoi.** Les couvertures et les enregistrements audio
/// restent sur l'appareil : ce sont des mégaoctets par cours. Les schémas d'occlusion
/// voyagent en data URL dans `image_path`, comme sur le web — assez petit pour une
/// zone masquée, trop lourd pour une couverture.
enum CloudTable {
    static let profiles = "profiles"
    static let courses = "courses"
    static let flashcards = "flashcards"
    static let reviewLogs = "review_logs"
    static let exams = "exams"
    /// La vitrine d'un profil : le nom d'utilisateur et l'établissement, et rien d'autre.
    ///
    /// `profiles` reste cloisonné au propriétaire. Une politique de lecture dessus aurait
    /// exposé la ligne entière — le cloisonnement de Postgres filtre des lignes, pas des
    /// colonnes — donc le stade d'étude, le pays, les objectifs et le rythme quotidien avec.
    /// Cette table est tenue à jour par un déclencheur : trois colonnes dupliquées contre la
    /// certitude qu'une préférence ne peut pas fuir.
    static let directory = "directory"
    static let friendships = "friendships"
    static let entitlements = "entitlements"
}

/// Les identifiants qu'on a effacés ici, et qu'il ne faut plus faire revivre.
///
/// La suppression locale est immédiate : SwiftData oublie la ligne. Sans cette liste, la
/// prochaine descente recréerait l'objet depuis le cloud — ou la prochaine montée
/// réécrirait `deleted_at: null` et ressusciterait ce que le web a déjà tombstoné.
enum CloudTombstones {
    private static let key = "micabo.cloud.tombstones"

    static var defaults: UserDefaults = .standard

    static func mark(_ table: String, id: UUID) {
        var store = load()
        var ids = Set(store[table] ?? [])
        ids.insert(id.uuidString.lowercased())
        store[table] = Array(ids)
        save(store)
    }

    static func contains(_ table: String, id: UUID) -> Bool {
        load()[table]?.contains(id.uuidString.lowercased()) == true
    }

    static func all() -> [String: [UUID]] {
        load().mapValues { raw in
            raw.compactMap(UUID.init(uuidString:))
        }
    }

    static func removeAll() {
        defaults.removeObject(forKey: key)
    }

    private static func load() -> [String: [String]] {
        (defaults.dictionary(forKey: key) as? [String: [String]]) ?? [:]
    }

    private static func save(_ store: [String: [String]]) {
        defaults.set(store, forKey: key)
    }
}

/// Ce que la montée envoie pour marquer une ligne disparue, sans toucher au reste.
struct TombstonePatch: Encodable {
    var deleted_at: Date
    var updated_at: Date
}

/// Une image d'occlusion, telle qu'elle voyage dans `flashcards.image_path`.
///
/// Le web y pose déjà une data URL. On fait la même chose : pas de bucket Storage, et une
/// carte à schéma revue sur le téléphone reste lisible dans le navigateur.
enum CloudImage {
    static func dataURL(from data: Data?) -> String? {
        guard let data, !data.isEmpty else { return nil }
        return "data:image/jpeg;base64,\(data.base64EncodedString())"
    }

    static func data(from path: String?) -> Data? {
        guard let path, path.hasPrefix("data:"),
              let comma = path.firstIndex(of: ","),
              let data = Data(base64Encoded: String(path[path.index(after: comma)...]))
        else { return nil }
        return data
    }
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
    /// Langue des prochaines fiches, quand elle n'est plus celle du pays.
    var sheet_language: String?
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
            sheet_language: OnboardingPreferences.contentLanguage.rawValue,
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
        if let sheet_language, let language = ContentLanguage(rawValue: sheet_language) {
            OnboardingPreferences.sheetLanguage = language
        }
        if onboarding_completed_at != nil {
            OnboardingPreferences.markCompleted()
        }
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
    /// « public », « friends » ou « private ». Le brut voyage, pas l'énumération : une valeur
    /// inconnue d'une version plus ancienne de l'app ne doit pas faire échouer le décodage de
    /// toute la ligne.
    var visibility: String
    var created_at: Date
    var updated_at: Date
    var deleted_at: Date?
    /// Lus à la descente, jamais renvoyés : une synchro ne doit pas écraser
    /// les compteurs publics que seuls les RPC incrémentent.
    var view_count: Int? = nil
    var adopt_count: Int? = nil

    enum CodingKeys: String, CodingKey {
        case id, user_id, title, subject, summary, emoji, accent_hex, source
        case source_file_name, fingerprint, raw_text, sheet, context_text
        case is_from_library, visibility, created_at, updated_at, deleted_at
        case view_count, adopt_count
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(user_id, forKey: .user_id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(subject, forKey: .subject)
        try container.encode(summary, forKey: .summary)
        try container.encodeIfPresent(emoji, forKey: .emoji)
        try container.encodeIfPresent(accent_hex, forKey: .accent_hex)
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(source_file_name, forKey: .source_file_name)
        try container.encode(fingerprint, forKey: .fingerprint)
        try container.encode(raw_text, forKey: .raw_text)
        try container.encodeIfPresent(sheet, forKey: .sheet)
        try container.encode(context_text, forKey: .context_text)
        try container.encode(is_from_library, forKey: .is_from_library)
        try container.encode(visibility, forKey: .visibility)
        try container.encode(created_at, forKey: .created_at)
        try container.encode(updated_at, forKey: .updated_at)
        try container.encodeIfPresent(deleted_at, forKey: .deleted_at)
    }
}

/// Un cours de quelqu'un d'autre, tel qu'on peut le lire.
///
/// C'est volontairement moins qu'un `CourseRecord` : ni empreinte, ni couverture, ni
/// horodatage de suppression. Ce qu'on reprend d'un cours partagé, c'est **sa fiche**
/// et le contenu de ses cartes — pas l'état de répétition de l'auteur.
struct SharedCourseRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var user_id: UUID
    var title: String
    var subject: String?
    var summary: String
    var emoji: String?
    var accent_hex: String?
    var raw_text: String
    var sheet: JSONCodable?
    var context_text: String
    var visibility: String
    var updated_at: Date
    var view_count: Int? = nil
    var adopt_count: Int? = nil

    /// Les colonnes demandées à PostgREST. Écrites ici et pas à l'appel : une liste qui
    /// diverge des propriétés ci-dessus donne un décodage qui échoue à l'exécution.
    static let columns = [
        "id", "user_id", "title", "subject", "summary", "emoji", "accent_hex",
        "raw_text", "sheet", "context_text", "visibility", "updated_at",
        "view_count", "adopt_count"
    ].joined(separator: ",")

    static func == (lhs: SharedCourseRecord, rhs: SharedCourseRecord) -> Bool {
        lhs.id == rhs.id && lhs.updated_at == rhs.updated_at
    }
}

/// Le contenu d'une carte partagée, sans l'état de répétition de l'auteur.
struct SharedCardRecord: Codable, Identifiable, Equatable {
    var id: UUID
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

    static let columns = [
        "id", "front", "back", "hint", "position", "kind", "choices",
        "correct_choice_index", "mask_x", "mask_y", "mask_width", "mask_height",
        "group_id", "is_reversed"
    ].joined(separator: ",")
}

struct SharedCardCountRow: Codable {
    var course_id: UUID?
}

/// Une entrée de l'annuaire : de quoi désigner quelqu'un et le reconnaître.
struct DirectoryRecord: Codable, Identifiable, Hashable {
    var id: UUID
    var username: String
    var institution_id: String?
    var institution_name: String?
}

/// Le nom d'utilisateur, seul, pour l'écrire sans toucher au reste du profil.
///
/// La synchro envoie le profil entier à chaque passage. Si le nom d'utilisateur voyageait
/// avec, une synchro partie d'un appareil dont la copie locale est en retard écraserait le nom
/// qu'on vient de changer sur l'autre. Il s'écrit donc seul, et il se relit depuis l'annuaire.
struct UsernameRecord: Codable {
    var username: String
}

/// Une demande d'amitié, ou une amitié : la même ligne, et son état.
///
/// Le sens est conservé — qui a demandé à qui — parce que l'écran des demandes en dépend, et
/// parce qu'accepter n'appartient qu'au destinataire.
struct FriendshipRecord: Codable, Identifiable, Hashable {
    var requester_id: UUID
    var addressee_id: UUID
    var status: String
    var created_at: Date?
    var responded_at: Date?

    /// La paire, dans un ordre stable : il n'y a qu'une ligne pour deux personnes.
    var id: String { "\(requester_id)-\(addressee_id)" }

    static let pending = "pending"
    static let accepted = "accepted"

    var isAccepted: Bool { status == Self.accepted }

    /// L'autre personne, vue de `me`.
    func other(than me: UUID) -> UUID {
        requester_id == me ? addressee_id : requester_id
    }
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
    /// Data URL du schéma. Absente des cartes sans image.
    var image_path: String?

    enum CodingKeys: String, CodingKey {
        case id, user_id, course_id, front, back, hint, position, kind, choices
        case correct_choice_index, mask_x, mask_y, mask_width, mask_height, group_id
        case is_reversed, is_suspended, state, due_date, interval_days, ease_factor
        case repetitions, lapses, step_index, last_reviewed_at, created_at, updated_at
        case deleted_at, image_path
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(user_id, forKey: .user_id)
        try container.encodeIfPresent(course_id, forKey: .course_id)
        try container.encode(front, forKey: .front)
        try container.encode(back, forKey: .back)
        try container.encodeIfPresent(hint, forKey: .hint)
        try container.encode(position, forKey: .position)
        try container.encode(kind, forKey: .kind)
        try container.encode(choices, forKey: .choices)
        try container.encode(correct_choice_index, forKey: .correct_choice_index)
        try container.encode(mask_x, forKey: .mask_x)
        try container.encode(mask_y, forKey: .mask_y)
        try container.encode(mask_width, forKey: .mask_width)
        try container.encode(mask_height, forKey: .mask_height)
        try container.encodeIfPresent(group_id, forKey: .group_id)
        try container.encode(is_reversed, forKey: .is_reversed)
        try container.encode(is_suspended, forKey: .is_suspended)
        try container.encode(state, forKey: .state)
        try container.encode(due_date, forKey: .due_date)
        try container.encode(interval_days, forKey: .interval_days)
        try container.encode(ease_factor, forKey: .ease_factor)
        try container.encode(repetitions, forKey: .repetitions)
        try container.encode(lapses, forKey: .lapses)
        try container.encode(step_index, forKey: .step_index)
        try container.encodeIfPresent(last_reviewed_at, forKey: .last_reviewed_at)
        try container.encode(created_at, forKey: .created_at)
        try container.encode(updated_at, forKey: .updated_at)
        try container.encodeIfPresent(deleted_at, forKey: .deleted_at)
        try container.encodeIfPresent(image_path, forKey: .image_path)
    }
}

/// La ligne `entitlements`, lue seulement. Personne ne l'écrit depuis l'app.
struct EntitlementRecord: Decodable {
    var is_pro: Bool
    var expires_at: Date?
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
    var target_score: Int?
    var course_ids: [UUID]
    var is_planned: Bool
    var planned_at: Date?
    var created_at: Date
    var updated_at: Date
    var deleted_at: Date?
    /// Photographie des échéances d'avant le plan, pour pouvoir le défaire.
    var schedule_backup: JSONCodable?

    enum CodingKeys: String, CodingKey {
        case id, user_id, name, exam_date, intensity, target_score, course_ids
        case is_planned, planned_at, created_at, updated_at, deleted_at, schedule_backup
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(user_id, forKey: .user_id)
        try container.encode(name, forKey: .name)
        try container.encode(exam_date, forKey: .exam_date)
        try container.encode(intensity, forKey: .intensity)
        try container.encodeIfPresent(target_score, forKey: .target_score)
        try container.encode(course_ids, forKey: .course_ids)
        try container.encode(is_planned, forKey: .is_planned)
        try container.encodeIfPresent(planned_at, forKey: .planned_at)
        try container.encode(created_at, forKey: .created_at)
        try container.encode(updated_at, forKey: .updated_at)
        try container.encodeIfPresent(deleted_at, forKey: .deleted_at)
        try container.encodeIfPresent(schedule_backup, forKey: .schedule_backup)
    }
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
