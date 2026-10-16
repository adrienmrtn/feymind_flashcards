import Foundation

/// **L'appel à `generate-lesson`**, en trois temps : le plan, un thème, la conversion d'un
/// ancien cours. Voir `docs/refonte-parcours.md` § 9 et `supabase/functions/generate-lesson`.
///
/// Un protocole, pour que l'orchestrateur (`LessonBuilder`) se teste sans réseau.
protocol LessonGenerating: Sendable {
    func plan(_ request: LessonPlanRequest) async throws -> LessonPlanResult
    func theme(_ request: LessonThemeRequest) async throws -> LessonThemeResult
    func convert(_ request: LessonConvertRequest) async throws -> LessonConversion
}

/// Pour qui on écrit : le palier, le pays, la classe précise, la langue des notes.
struct LessonAudience: Sendable, Equatable {
    var level: String
    var country: String
    var schoolStage: String
    var language: String

    static var current: LessonAudience {
        LessonAudience(
            level: OnboardingPreferences.studyLevel?.rawValue ?? "",
            country: OnboardingPreferences.schoolingCountry.rawValue,
            schoolStage: OnboardingPreferences.educationStage?.title ?? "",
            language: OnboardingPreferences.contentLanguage.rawValue
        )
    }

    var payload: [String: Any] {
        ["level": level, "country": country, "schoolStage": schoolStage, "language": language]
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
}

/// Une question telle que le serveur la rend : sans identifiant, que l'app donne.
struct GeneratedQuestion: Decodable, Sendable, Equatable {
    var prompt: String
    var choices: [String]
    var answer: Int
    var why: String

    func question(id: String) -> QuizQuestion {
        QuizQuestion(id: id, prompt: prompt, choices: choices, answer: answer, why: why)
    }
}

struct GeneratedCard: Decodable, Sendable, Equatable {
    var front: String
    var back: String
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

// MARK: - Les refus

/// Ce que la porte du serveur peut refuser, traduit pour l'app : `freeLimit` et `importPro`
/// ouvrent le paywall.
enum LessonServiceError: LocalizedError, Equatable {
    case freeLimit
    case importPro
    case forbidden
    case notConfigured
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .freeLimit: L10n.t("lesson.error.freeLimit", locale: .resolved())
        case .importPro: L10n.t("lesson.error.importPro", locale: .resolved())
        case .forbidden: L10n.t("lesson.error.forbidden", locale: .resolved())
        case .notConfigured: L10n.t("ios.cloud.notConfigured", locale: .resolved())
        case .failed(let message): message
        }
    }

    /// Vrai pour les refus qui se règlent en passant à Pro.
    var opensPaywall: Bool { self == .freeLimit || self == .importPro }

    static func from(_ error: Error) -> LessonServiceError {
        if let error = error as? LessonServiceError { return error }
        switch error as? SupabaseFunctionError {
        case .server(_, let message, let code):
            switch code {
            case "free_limit": return .freeLimit
            case "import_pro": return .importPro
            case "forbidden": return .forbidden
            default: return .failed(message.isEmpty ? L10n.t("lesson.error.generic", locale: .resolved()) : message)
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
        return try await call(payload) { envelope in
            try functions.decode(LessonThemeResult.self, from: envelope, key: "theme")
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
