import Foundation

/// **Ce que le serveur a dit en écrivant une leçon**, gardé sur l'appareil.
///
/// `generate-lesson` renvoie `meta.promptVersion` (« lesson-v4.2.0 ») avec chaque plan, et
/// l'app ne le gardait pas. Le modèle `Course` n'a pas de colonne pour lui, et la base ne peut
/// pas en recevoir une sans migration : la version et la nature exacte de la source (un sujet,
/// un audio et un texte collé deviennent tous `CourseSource.text`) vivent donc ici, par leçon,
/// le temps qu'un avis (`lesson_rated`) les emporte. Une leçon écrite ailleurs, ou avant cette
/// version de l'app, n'a pas d'entrée : l'avis le dit (`inconnue`).
enum LessonGenerationLog {
    struct Entry: Equatable {
        /// `LessonSourceKind.rawValue` : topic, text, pdf, photo, audio, youtube, docx, mixed.
        var source: String
        var promptVersion: String?
    }

    static let key = "micabo.lesson.generationLog"
    /// Les plus anciennes tombent au-delà : un avis se donne dans les jours qui suivent.
    static let limit = 300

    static func record(lessonID: UUID, source: String, promptVersion: String?, in defaults: UserDefaults = .standard) {
        let id = lessonID.uuidString.lowercased()
        var rows = (defaults.array(forKey: key) as? [[String: String]] ?? []).filter { $0["id"] != id }
        var row = ["id": id, "source": source]
        if let promptVersion = promptVersion?.nilIfBlank {
            row["version"] = String(promptVersion.prefix(40))
        }
        rows.append(row)
        defaults.set(Array(rows.suffix(limit)), forKey: key)
    }

    static func entry(for lessonID: UUID, in defaults: UserDefaults = .standard) -> Entry? {
        let id = lessonID.uuidString.lowercased()
        guard let row = (defaults.array(forKey: key) as? [[String: String]])?.last(where: { $0["id"] == id }),
              let source = row["source"] else { return nil }
        return Entry(source: source, promptVersion: row["version"])
    }

    /// La version d'écriture lue dans la réponse du serveur (`meta.promptVersion`).
    static func promptVersion(in envelope: [String: Any]) -> String? {
        (envelope["meta"] as? [String: Any])?["promptVersion"] as? String
    }
}

/// **« Cette leçon t'a aidé ? »** : 👍 ou 👎, et pourquoi, une fois par leçon.
///
/// Le contrôle qualité des leçons écrites par le modèle. L'avis part dans `app_events`
/// (`lesson_rated`), la table qui existe déjà : aucun appel serveur nouveau. La carte se
/// propose après la première étape de contenu terminée, puis à « Leçon terminée » si l'élève
/// n'a pas encore répondu ; une réponse donnée, elle ne revient plus. Elle ne bloque jamais
/// rien : on peut l'ignorer ou la fermer.
enum LessonRating {
    enum Value: String {
        case up
        case down
    }

    /// Où la carte s'est montrée.
    enum Moment: String {
        /// Juste après la première étape de contenu (des notes, un quiz) cochée.
        case firstCircle = "first_circle"
        /// Sur « Leçon terminée ».
        case finished
    }

    /// Les raisons d'un 👎, dans l'ordre des pastilles.
    enum Reason: String, CaseIterable, Identifiable {
        case tooLong = "too_long"
        case tooShort = "too_short"
        case errors
        case wrongLevel = "wrong_level"
        case badlyOrganized = "badly_organized"
        case wrongLanguage = "wrong_language"
        case other

        var id: String { rawValue }

        var titleKey: String {
            switch self {
            case .tooLong: "ios.conv.rate.reason.tooLong"
            case .tooShort: "ios.conv.rate.reason.tooShort"
            case .errors: "ios.conv.rate.reason.errors"
            case .wrongLevel: "ios.conv.rate.reason.level"
            case .badlyOrganized: "ios.conv.rate.reason.organized"
            case .wrongLanguage: "ios.conv.rate.reason.language"
            case .other: "ios.conv.rate.reason.other"
            }
        }
    }

    static let commentLimit = 120

    // MARK: Une fois par leçon

    static let ratedKey = "micabo.lessonRating.rated"
    static let offeredKey = "micabo.lessonRating.offered"
    private static let memory = 500

    static func isRated(_ lessonID: UUID, in defaults: UserDefaults = .standard) -> Bool {
        list(ratedKey, in: defaults).contains(lessonID.uuidString.lowercased())
    }

    static func markRated(_ lessonID: UUID, in defaults: UserDefaults = .standard) {
        append(lessonID.uuidString.lowercased(), to: ratedKey, in: defaults)
    }

    static func wasOffered(_ lessonID: UUID, at moment: Moment, in defaults: UserDefaults = .standard) -> Bool {
        list(offeredKey, in: defaults).contains("\(lessonID.uuidString.lowercased()):\(moment.rawValue)")
    }

    static func markOffered(_ lessonID: UUID, at moment: Moment, in defaults: UserDefaults = .standard) {
        append("\(lessonID.uuidString.lowercased()):\(moment.rawValue)", to: offeredKey, in: defaults)
    }

    /// **La règle, à part pour être testée** : jamais après une réponse, et une fois par
    /// moment.
    static func shouldOffer(rated: Bool, alreadyOfferedHere: Bool) -> Bool {
        !rated && !alreadyOfferedHere
    }

    static func shouldOffer(_ lessonID: UUID, at moment: Moment, in defaults: UserDefaults = .standard) -> Bool {
        shouldOffer(
            rated: isRated(lessonID, in: defaults),
            alreadyOfferedHere: wasOffered(lessonID, at: moment, in: defaults)
        )
    }

    /// **La première étape de contenu** : l'Intro ne compte pas (on n'y a rien appris), et une
    /// étape de contenu déjà cochée avant celle-ci veut dire que le moment est passé.
    static func isFirstContentCircle(_ circle: PathCircle, doneBefore: Set<String>, circles: [PathCircle]) -> Bool {
        guard circle.kind != .intro, !doneBefore.contains(circle.id) else { return false }
        return !circles.contains { $0.kind != .intro && doneBefore.contains($0.id) }
    }

    // MARK: Ce qui part

    /// La source telle que l'élève l'a donnée : celle du journal, sinon celle du cours (un
    /// `text` sans texte gardé est un sujet tapé).
    static func sourceKind(of course: Course, logged: LessonGenerationLog.Entry?) -> String {
        if let logged { return logged.source }
        if course.source == .text && course.rawText.nilIfBlank == nil { return LessonSourceKind.topic.rawValue }
        return course.source.rawValue
    }

    static func properties(
        lessonID: UUID,
        value: Value,
        reasons: [Reason],
        comment: String,
        moment: Moment,
        source: String,
        promptVersion: String?,
        pathVersion: Int?,
        created: Date,
        language: UiLocale,
        level: String?
    ) -> [String: AnalyticsValue] {
        var props: [String: AnalyticsValue] = [
            "lesson_id": .text(lessonID.uuidString.lowercased()),
            "rating": .text(value.rawValue),
            "moment": .text(moment.rawValue),
            "source": .text(source),
            "prompt_version": .text(promptVersion?.nilIfBlank ?? "inconnue"),
            "app_language": .text(language.rawValue),
            "level": .text(level?.nilIfBlank ?? "inconnu"),
            "created": .text(dayFormatter.string(from: created)),
        ]
        if let pathVersion {
            props["path_version"] = .number(Double(pathVersion))
        }
        if value == .down {
            props["reasons"] = .text(Reason.allCases.filter { reasons.contains($0) }.map(\.rawValue).joined(separator: ","))
            if let comment = comment.nilIfBlank {
                props["comment"] = .text(String(comment.prefix(commentLimit)))
            }
        }
        return props
    }

    /// Envoie l'avis sur une leçon et le note comme donné.
    @MainActor
    static func send(_ value: Value, reasons: [Reason], comment: String, course: Course, moment: Moment) {
        let logged = LessonGenerationLog.entry(for: course.id)
        Analytics.track(.lessonRated, properties(
            lessonID: course.id,
            value: value,
            reasons: reasons,
            comment: comment,
            moment: moment,
            source: sourceKind(of: course, logged: logged),
            promptVersion: logged?.promptVersion,
            pathVersion: course.lessonPath?.version,
            created: course.createdAt,
            language: .resolved(),
            level: OnboardingPreferences.educationStageId
        ))
        markRated(course.id)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func list(_ key: String, in defaults: UserDefaults) -> [String] {
        defaults.stringArray(forKey: key) ?? []
    }

    private static func append(_ value: String, to key: String, in defaults: UserDefaults) {
        var values = list(key, in: defaults)
        guard !values.contains(value) else { return }
        values.append(value)
        defaults.set(Array(values.suffix(memory)), forKey: key)
    }
}
