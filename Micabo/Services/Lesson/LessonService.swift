import Foundation

/// **L'appel à `generate-lesson`**, en trois temps : le plan, un thème, la conversion d'un
/// ancien cours. Voir `docs/refonte-parcours.md` § 9 et `supabase/functions/generate-lesson`.
///
/// Un protocole, pour que l'orchestrateur (`LessonBuilder`) se teste sans réseau.
protocol LessonGenerating: Sendable {
    func plan(_ request: LessonPlanRequest) async throws -> LessonPlanResult
    func theme(_ request: LessonThemeRequest) async throws -> LessonThemeResult
    func convert(_ request: LessonConvertRequest) async throws -> LessonConversion
    func practice(_ request: LessonPracticeRequest) async throws -> [GeneratedQuestion]
    func exam(_ request: LessonExamRequest) async throws -> GeneratedExam
}

/// **Pour qui on écrit** : la marche d'études, le pays, le palier, la filière, la classe
/// exacte, l'examen visé, la langue des notes. Voir `supabase/functions/_shared/learner.ts`.
struct LessonAudience: Sendable, Equatable {
    var level: String
    var country: String
    var schoolStage: String
    var language: String
    /// La marche (`EducationTier`) : c'est elle qui règle le registre et le volume. Un
    /// collégien français n'est plus écrit comme un lycéen.
    var tier: String = ""
    /// « Lycée général », « Gymnasium », « YKS hazırlık ».
    var track: String = ""
    /// « Terminale », « Quatrième », « Master 1 », « TYT ».
    var year: String = ""
    /// L'examen visé par cette leçon : « Bac de français, le 2027-06-15 ».
    var exam: String = ""

    static var current: LessonAudience {
        let country = OnboardingPreferences.schoolingCountry
        let track = SchoolSystem.track(id: OnboardingPreferences.schoolTrackID, in: country)
        let year = SchoolSystem.year(id: OnboardingPreferences.schoolYearID, in: track)
        return LessonAudience(
            level: OnboardingPreferences.studyLevel?.rawValue ?? "",
            country: country.rawValue,
            schoolStage: OnboardingPreferences.educationStage?.title ?? "",
            language: OnboardingPreferences.contentLanguage.rawValue,
            tier: (tier(track: track, year: year) ?? OnboardingPreferences.educationTier)?.rawValue ?? "",
            track: track?.title ?? "",
            year: year?.title ?? ""
        )
    }

    /// Les années de master sont rangées dans la filière « université » : leur marche est celle
    /// du master, pas de la licence.
    static let graduateYears: Set<String> = ["fr.m1", "fr.m2", "de.master", "es.master", "tr.yukseklisans"]

    /// La marche d'une filière, corrigée par son année. Une filière ne garde pas la marche du
    /// palier le plus proche du pays : « Collège » reste un collège même là où le pays ne
    /// propose que « Lycée » comme palier.
    static func tier(track: SchoolTrack?, year: SchoolYear?) -> EducationTier? {
        guard let track else { return nil }
        if let year, graduateYears.contains(year.id) { return .graduate }
        return track.tier
    }

    /// La même audience, pour une leçon qui prépare un examen daté.
    func preparing(_ exam: String?) -> LessonAudience {
        var copy = self
        copy.exam = exam ?? ""
        return copy
    }

    var payload: [String: Any] {
        var out: [String: Any] = [
            "level": level, "country": country, "schoolStage": schoolStage, "language": language,
            "kinds": QuizKind.allCases.map(\.rawValue)
        ]
        if !tier.isEmpty { out["tier"] = tier }
        if !track.isEmpty { out["track"] = track }
        if !year.isEmpty { out["year"] = year }
        if !exam.isEmpty { out["exam"] = exam }
        return out
    }
}

// MARK: - Le plan

struct LessonPlanRequest: Sendable {
    var lessonID: UUID
    /// Le sujet tapé dans la barre ; `nil` quand la leçon part de supports.
    var topic: String?
    /// Les supports, mis à plat et bout à bout.
    var text: String
    /// Les pages en JPEG, pour la passe visuelle (six au plus).
    var images: [Data]
    /// D'où vient le texte : text, pdf, photo, audio, youtube, docx, mixed.
    var source: String
    var sourceName: String?
    /// La leçon du parcours d'accueil (voir `LessonCreation.onboarding`).
    var onboarding = false
    var audience: LessonAudience
}

struct LessonPlanResult: Decodable, Sendable, Equatable {
    struct Theme: Decodable, Sendable, Equatable {
        var title: String
        var icon: String
        /// Le pictogramme du thème sur le chemin. Absent d'un serveur d'avant.
        var symbol: String?
        /// Les notions que le thème doit couvrir.
        var points: [String]?
    }

    struct Plan: Decodable, Sendable, Equatable {
        var title: String
        var subject: String
        var icon: String
        var themes: [Theme]
        var groups: [LessonPath.Group]
        var intro: LessonPath.Intro
        var takeaways: [String]
        var shortened: Bool
        var singleQuiz: Bool
    }

    var plan: Plan
    /// Le texte de référence de chaque thème. Vide quand la leçon part d'un sujet.
    var contextText: String
}

// MARK: - Un thème

struct LessonThemeRequest: Sendable {
    var lessonID: UUID
    var lessonTitle: String
    var themeIndex: Int
    var themes: [String]
    var context: String
    var subject: String?
    var audience: LessonAudience
    /// Les notions de chaque thème, dans l'ordre des thèmes.
    var points: [[String]] = []
    /// Ce que l'élève saura faire à la fin : les lignes de l'intro.
    var objectives: [String] = []
    /// D'où vient le texte de référence : les consignes de lecture (OCR, transcription) en
    /// dépendent.
    var source: String = ""
}

/// Une question telle que le serveur la rend : sans identifiant, que l'app donne.
struct GeneratedQuestion: Decodable, Sendable, Equatable {
    var kind: String?
    var prompt: String
    var choices: [String]
    var answer: Int
    var why: String
    var difficulty: Int?
    var matches: [String]?
    /// Le rang du thème, pour une question d'entraînement ou d'examen blanc.
    var theme: Int?
    /// Le rang de la leçon, pour une question d'examen blanc.
    var lesson: Int?

    init(
        kind: String? = nil,
        prompt: String,
        choices: [String],
        answer: Int,
        why: String,
        difficulty: Int? = nil,
        matches: [String]? = nil,
        theme: Int? = nil,
        lesson: Int? = nil
    ) {
        self.kind = kind
        self.prompt = prompt
        self.choices = choices
        self.answer = answer
        self.why = why
        self.difficulty = difficulty
        self.matches = matches
        self.theme = theme
        self.lesson = lesson
    }

    func question(id: String) -> QuizQuestion {
        QuizQuestion(
            id: id,
            kind: kind.flatMap(QuizKind.init(rawValue:)) ?? .choice,
            prompt: prompt,
            choices: choices,
            answer: answer,
            why: why,
            matches: matches ?? [],
            difficulty: difficulty ?? 2
        )
    }
}

struct GeneratedCard: Decodable, Sendable, Equatable {
    /// `basic` ou `cloze` (le recto est une phrase à trou). Absent : recto/verso.
    var kind: String?
    var front: String
    var back: String

    init(kind: String? = nil, front: String, back: String) {
        self.kind = kind
        self.front = front
        self.back = back
    }
}

struct LessonThemeResult: Decodable, Sendable, Equatable {
    var notes: ThemeNotes
    var questions: [GeneratedQuestion]
    var flashcards: [GeneratedCard]
}

// MARK: - La conversion

struct LessonConvertRequest: Sendable {
    struct Chapter: Sendable {
        var title: String
        var text: String
        var needsCards: Bool
    }

    var lessonID: UUID
    var title: String
    var subject: String?
    var chapters: [Chapter]
    var audience: LessonAudience
}

struct LessonConversion: Decodable, Sendable, Equatable {
    struct Chapter: Decodable, Sendable, Equatable {
        var icon: String
        var questions: [GeneratedQuestion]
        var flashcards: [GeneratedCard]
    }

    var icon: String
    var intro: LessonPath.Intro
    var takeaways: [String]
    var groups: [LessonPath.Group]
    var chapters: [Chapter]
}

// MARK: - De nouvelles questions

/// **Un lot de nouvelles questions d'entraînement** sur une leçon déjà écrite : loin de
/// celles déjà posées (`avoid`), surtout sur les thèmes où l'élève se trompe (`focus`).
struct LessonPracticeRequest: Sendable {
    struct Theme: Sendable, Equatable {
        var title: String
        /// Les notes du thème, mises à plat.
        var notes: String
    }

    var lessonID: UUID
    var lessonTitle: String
    var subject: String? = nil
    var themes: [Theme]
    var focus: [Int]
    var avoid: [String]
    var count: Int = 10
    var audience: LessonAudience
}

// MARK: - L'examen blanc

/// **Un examen blanc** sur une ou plusieurs leçons : autant de questions que la durée en
/// laisse le temps, dans le format de l'examen visé, sans retour avant la fin.
struct LessonExamRequest: Sendable {
    struct Lesson: Sendable, Equatable {
        var title: String
        /// La matière, quand la leçon la connaît : elle décide des formes de questions.
        var subject: String? = nil
        var themes: [LessonPracticeRequest.Theme]
    }

    /// L'identifiant de cette copie : chaque examen blanc est une copie neuve.
    var paperID: UUID
    var title: String
    var minutes: Int
    var count: Int
    var lessons: [Lesson]
    var audience: LessonAudience
}

struct GeneratedExam: Decodable, Sendable, Equatable {
    var title: String
    var questions: [GeneratedQuestion]
}

// MARK: - Les refus

/// Ce que la porte du serveur peut refuser, traduit pour l'app : `freeLimit` et `importPro`
/// ouvrent le paywall.
enum LessonServiceError: LocalizedError, Equatable {
    case freeLimit
    case importPro
    /// L'essai gratuit d'un supplément (nouvelles questions, examen blanc) est pris.
    case proRequired
    /// Le plafond Pro du jour est atteint.
    case dailyLimit
    case forbidden
    case notConfigured
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .freeLimit: L10n.t("lesson.error.freeLimit", locale: .resolved())
        case .importPro: L10n.t("lesson.error.importPro", locale: .resolved())
        case .proRequired: L10n.t("lesson.error.proRequired", locale: .resolved())
        case .dailyLimit: L10n.t("lesson.error.dailyLimit", locale: .resolved())
        case .forbidden: L10n.t("lesson.error.forbidden", locale: .resolved())
        case .notConfigured: L10n.t("ios.cloud.notConfigured", locale: .resolved())
        case .failed(let message): message
        }
    }

    /// Vrai pour les refus qui se règlent en passant à Pro.
    var opensPaywall: Bool { self == .freeLimit || self == .importPro || self == .proRequired }

    static func from(_ error: Error) -> LessonServiceError {
        if let error = error as? LessonServiceError { return error }
        switch error as? SupabaseFunctionError {
        case .server(_, let message, let code):
            switch code {
            case "free_limit": return .freeLimit
            case "import_pro": return .importPro
            case "pro_required": return .proRequired
            case "daily_limit": return .dailyLimit
            case "forbidden": return .forbidden
            default: return .failed(ServerMessage.localized(message, fallback: "lesson.error.generic"))
            }
        case .notConfigured:
            return .notConfigured
        case .network(let detail):
            return .failed(L10n.t("ios.ai.network", locale: .resolved(), vars: ["detail": detail]))
        default:
            return .failed(L10n.t("lesson.error.generic", locale: .resolved()))
        }
    }
}

// MARK: - Le transport

struct SupabaseLessonService: LessonGenerating {
    var functions = SupabaseFunctions.shared

    func plan(_ request: LessonPlanRequest) async throws -> LessonPlanResult {
        var payload = request.audience.payload
        payload["stage"] = "plan"
        payload["lessonId"] = request.lessonID.uuidString.lowercased()
        payload["text"] = String(request.text.prefix(120_000))
        payload["images"] = request.images.prefix(6).map { "data:image/jpeg;base64," + $0.base64EncodedString() }
        payload["source"] = request.source
        payload["sourceName"] = request.sourceName ?? ""
        if request.onboarding {
            payload["onboarding"] = true
        }
        if let topic = request.topic {
            payload["topic"] = String(topic.prefix(400))
        }
        return try await call(payload) { envelope in
            LessonPlanResult(
                plan: try functions.decode(LessonPlanResult.Plan.self, from: envelope, key: "plan"),
                contextText: envelope["contextText"] as? String ?? ""
            )
        }
    }

    func theme(_ request: LessonThemeRequest) async throws -> LessonThemeResult {
        var payload = request.audience.payload
        payload["stage"] = "theme"
        payload["lessonId"] = request.lessonID.uuidString.lowercased()
        payload["lessonTitle"] = request.lessonTitle
        payload["themeIndex"] = request.themeIndex
        payload["themes"] = request.themes
        payload["context"] = String(request.context.prefix(60_000))
        payload["subject"] = request.subject ?? ""
        if !request.points.isEmpty { payload["points"] = request.points }
        if !request.objectives.isEmpty { payload["objectives"] = request.objectives }
        if !request.source.isEmpty { payload["source"] = request.source }
        return try await call(payload) { envelope in
            try functions.decode(LessonThemeResult.self, from: envelope, key: "theme")
        }
    }

    func practice(_ request: LessonPracticeRequest) async throws -> [GeneratedQuestion] {
        var payload = request.audience.payload
        payload["stage"] = "practice"
        payload["lessonId"] = request.lessonID.uuidString.lowercased()
        payload["lessonTitle"] = request.lessonTitle
        payload["subject"] = request.subject ?? ""
        payload["practiceThemes"] = request.themes.map { ["title": $0.title, "notes": String($0.notes.prefix(2_000))] }
        payload["focus"] = request.focus
        payload["avoid"] = request.avoid.suffix(80).map { String($0.prefix(200)) }
        payload["count"] = request.count
        return try await call(payload) { envelope in
            try functions.decode([GeneratedQuestion].self, from: envelope, key: "questions")
        }
    }

    func exam(_ request: LessonExamRequest) async throws -> GeneratedExam {
        var payload = request.audience.payload
        payload["stage"] = "exam"
        payload["lessonId"] = request.paperID.uuidString.lowercased()
        payload["examTitle"] = request.title
        payload["minutes"] = request.minutes
        payload["count"] = request.count
        payload["lessons"] = request.lessons.prefix(8).map { lesson in
            [
                "title": lesson.title,
                "subject": lesson.subject ?? "",
                "themes": lesson.themes.prefix(14).map { ["title": $0.title, "notes": String($0.notes.prefix(2_000))] }
            ] as [String: Any]
        }
        return try await call(payload) { envelope in
            try functions.decode(GeneratedExam.self, from: envelope, key: "exam")
        }
    }

    func convert(_ request: LessonConvertRequest) async throws -> LessonConversion {
        var payload = request.audience.payload
        payload["stage"] = "convert"
        payload["lessonId"] = request.lessonID.uuidString.lowercased()
        payload["title"] = request.title
        payload["subject"] = request.subject ?? ""
        payload["chapters"] = request.chapters.map {
            ["title": $0.title, "text": String($0.text.prefix(3_000)), "needsCards": $0.needsCards] as [String: Any]
        }
        return try await call(payload) { envelope in
            try functions.decode(LessonConversion.self, from: envelope, key: "conversion")
        }
    }

    private func call<T>(_ payload: [String: Any], decode: ([String: Any]) throws -> T) async throws -> T {
        do {
            let envelope = try await functions.post("generate-lesson", payload: payload)
            return try decode(envelope)
        } catch {
            throw LessonServiceError.from(error)
        }
    }
}
