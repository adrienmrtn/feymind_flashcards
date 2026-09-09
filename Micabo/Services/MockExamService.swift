import Foundation

/// Une ligne de `mock_sessions` : un examen blanc ouvert, rempli, fermé.
///
/// La même ligne que celle que le site lit et écrit. Elle est **écrite à l'ouverture**, avec
/// la copie dedans : un blanc commencé survit ainsi à l'app qu'on ferme, et le téléphone ne
/// compose jamais ses propres questions - laisser l'appareil tirer permettrait de recommencer
/// jusqu'à tomber sur les faciles.
struct MockSessionRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var user_id: UUID
    var exam_id: UUID?
    /// Le jour, en `yyyy-MM-dd` : la colonne est une date nue.
    var planned_for: String?
    var minutes: Int
    var question_count: Int
    var correct_count: Int
    var questions: [MockQuestion]
    var answers: [MockAnswer]
    var grades: [MockGrade]
    var debrief: MockDebrief?
    var with_audio: Bool
    var started_at: Date
    var finished_at: Date?

    var isFinished: Bool { finished_at != nil }
    var score: Int { MockPaper.score(of: grades) }

    init(
        id: UUID,
        user_id: UUID,
        exam_id: UUID?,
        planned_for: String?,
        minutes: Int,
        question_count: Int,
        correct_count: Int,
        questions: [MockQuestion],
        answers: [MockAnswer],
        grades: [MockGrade],
        debrief: MockDebrief?,
        with_audio: Bool,
        started_at: Date,
        finished_at: Date?
    ) {
        self.id = id
        self.user_id = user_id
        self.exam_id = exam_id
        self.planned_for = planned_for
        self.minutes = minutes
        self.question_count = question_count
        self.correct_count = correct_count
        self.questions = questions
        self.answers = answers
        self.grades = grades
        self.debrief = debrief
        self.with_audio = with_audio
        self.started_at = started_at
        self.finished_at = finished_at
    }

    private enum CodingKeys: String, CodingKey {
        case id, user_id, exam_id, planned_for, minutes, question_count, correct_count
        case questions, answers, grades, debrief, with_audio, started_at, finished_at
    }

    /// Une question d'une forme que cette version ne connaît pas n'empêche pas de lire les
    /// autres : la copie s'affiche avec ce qu'elle sait, au lieu de disparaître de la liste.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        user_id = try container.decode(UUID.self, forKey: .user_id)
        exam_id = try container.decodeIfPresent(UUID.self, forKey: .exam_id)
        planned_for = try container.decodeIfPresent(String.self, forKey: .planned_for)
        minutes = try container.decodeIfPresent(Int.self, forKey: .minutes) ?? 20
        question_count = try container.decodeIfPresent(Int.self, forKey: .question_count) ?? 0
        correct_count = try container.decodeIfPresent(Int.self, forKey: .correct_count) ?? 0
        questions = (try container.decodeIfPresent([Lossy<MockQuestion>].self, forKey: .questions) ?? []).compactMap(\.value)
        answers = (try container.decodeIfPresent([Lossy<MockAnswer>].self, forKey: .answers) ?? []).compactMap(\.value)
        grades = (try container.decodeIfPresent([Lossy<MockGrade>].self, forKey: .grades) ?? []).compactMap(\.value)
        debrief = try? container.decodeIfPresent(MockDebrief.self, forKey: .debrief)
        with_audio = try container.decodeIfPresent(Bool.self, forKey: .with_audio) ?? false
        started_at = try container.decodeIfPresent(Date.self, forKey: .started_at) ?? Date()
        finished_at = try container.decodeIfPresent(Date.self, forKey: .finished_at)
    }
}

/// Un élément qu'on lit si on peut, et qu'on laisse tomber sinon.
private struct Lossy<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}

/// Ce qu'on écrit en remettant la copie. Le reste de la ligne ne bouge pas.
private struct MockSessionClosing: Encodable {
    var answers: [MockAnswer]
    var grades: [MockGrade]
    var debrief: MockDebrief?
    var question_count: Int
    var correct_count: Int
    var finished_at: Date
    var updated_at: Date
}

/// **Ouvrir une copie, la remettre, la faire corriger.**
///
/// Le même parcours que `lib/actions/mocks.ts` sur le site, aux mêmes fonctions Edge :
/// `generate-mock` écrit la copie sur le programme de l'épreuve, `grade-mock` note les
/// explications orales et rend le débriefing. Les questions fermées se corrigent ici, à la
/// comparaison, avant d'appeler le modèle : c'est le socle du score, et il ne dépend de rien.
///
/// Si la correction du modèle échoue, la copie est quand même fermée avec le score des
/// questions fermées : une note incomplète vaut mieux qu'une épreuve passée pour rien.
@Observable
@MainActor
final class MockExamService {
    enum Failure: LocalizedError {
        case notSignedIn
        case noCourse
        case tooLittleMaterial
        case unusable

        var errorDescription: String? {
            let locale = UiLocale.resolved()
            switch self {
            case .notSignedIn: return L10n.t("app.errors.signIn", locale: locale)
            case .noCourse: return L10n.t("app.errors.pickACourse", locale: locale)
            case .tooLittleMaterial: return L10n.t("app.errors.mockTooFewCards", locale: locale)
            case .unusable: return L10n.t("app.mock.failed", locale: locale)
            }
        }
    }

    /// Le programme part au modèle tel qu'il a été écrit à l'import, borné comme sur le site.
    private static let maxContext = 40_000
    /// En dessous, il n'y a pas de quoi écrire vingt questions qui tiennent.
    private static let minContext = 200
    static let table = "mock_sessions"

    private let auth: AuthController
    private let database: SupabaseDatabase
    private let functions = SupabaseFunctions.shared

    init(auth: AuthController) {
        self.auth = auth
        database = SupabaseDatabase(accessToken: { await auth.validAccessToken() })
    }

    /// Les blancs d'une épreuve, du plus récent au plus ancien, en cours compris.
    func sessions(for examID: UUID) async throws -> [MockSessionRecord] {
        try await database.rows(
            MockSessionRecord.self,
            from: Self.table,
            filters: [URLQueryItem(name: "exam_id", value: "eq.\(examID.uuidString)")],
            order: "started_at.desc",
            limit: 40
        )
    }

    /// Le texte sur lequel la copie s'écrit : le programme de l'épreuve, dans l'ordre des cours.
    static func material(for exam: Exam, in courses: [Course]) -> String {
        let wanted = Set(exam.courseIDs)
        let text = courses
            .filter { wanted.contains($0.id) }
            .map { ($0.contextText.nilIfBlank ?? $0.rawText).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        return String(text.prefix(maxContext))
    }

    /// Vrai quand il y a de quoi composer une copie qui veuille dire quelque chose.
    static func canRun(exam: Exam, in courses: [Course]) -> Bool {
        material(for: exam, in: courses).count >= minContext
    }

    /// Compose la copie et l'écrit. Le micro est déjà accordé - ou refusé - avant d'arriver ici.
    func start(exam: Exam, courses: [Course], withAudio: Bool) async throws -> MockSessionRecord {
        guard let userID = auth.user?.id else { throw Failure.notSignedIn }
        let wanted = Set(exam.courseIDs)
        let matter = courses.filter { wanted.contains($0.id) }
        guard !matter.isEmpty else { throw Failure.noCourse }

        let context = Self.material(for: exam, in: courses)
        guard context.count >= Self.minContext else { throw Failure.tooLittleMaterial }

        let quota = MockPaper.quota(withAudio: withAudio)
        var payload: [String: Any] = [
            "title": exam.name,
            "context": context,
            "language": OnboardingPreferences.contentLanguage.rawValue,
            "quota": [
                "choice": quota.choice,
                "truefalse": quota.trueFalse,
                "gap": quota.gap,
                "feynman": quota.feynman,
            ],
        ]
        if let subject = matter.first?.subject?.nilIfBlank {
            payload["subject"] = subject
        }

        let envelope = try await functions.post("generate-mock", payload: payload)
        let questions = Self.numbered(envelope["questions"])
        guard questions.count >= 4 else { throw Failure.unusable }

        let record = MockSessionRecord(
            id: UUID(),
            user_id: userID,
            exam_id: exam.id,
            planned_for: Self.dayStamp(Date()),
            minutes: MockPaper.minutes(for: questions),
            question_count: questions.count,
            correct_count: 0,
            questions: questions,
            answers: [],
            grades: [],
            debrief: nil,
            with_audio: withAudio && questions.contains { !$0.isClosed },
            started_at: Date(),
            finished_at: nil
        )
        try await database.insert([record], into: Self.table)
        return record
    }

    /// Remet la copie : les fermées sont notées ici, les orales par le modèle, et la ligne se
    /// ferme avec le tout. Rend la session telle qu'elle est désormais écrite.
    func finish(_ session: MockSessionRecord, answers: [MockAnswer], examName: String) async throws -> MockSessionRecord {
        if session.isFinished { return session }

        let byID = Dictionary(answers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let closed = session.questions.filter(\.isClosed)
        let spoken = session.questions.filter { !$0.isClosed }

        var grades: [MockGrade] = closed.compactMap { MockPaper.gradeClosed($0, answer: byID[$0.id]) }
        var debrief: MockDebrief?

        if !closed.isEmpty || !spoken.isEmpty {
            let missed = closed.filter { question in
                (grades.first { $0.id == question.id }?.score ?? 0) == 0
            }
            let payload: [String: Any] = [
                "title": examName,
                "language": OnboardingPreferences.contentLanguage.rawValue,
                "closedTotal": closed.count,
                "closedCorrect": grades.filter { $0.score >= 100 }.count,
                "missed": missed.map { ["prompt": $0.prompt, "why": $0.why ?? ""] },
                "spoken": spoken.map {
                    [
                        "id": $0.id,
                        "prompt": $0.prompt,
                        "expected": $0.expected ?? "",
                        "said": byID[$0.id]?.text ?? "",
                    ]
                },
            ]

            // Le modèle qui ne répond pas ne bloque pas la remise : voir l'en-tête.
            if let envelope = try? await functions.post("grade-mock", payload: payload) {
                if let returned = try? functions.decode([MockGrade].self, from: envelope, key: "grades") {
                    for grade in returned where spoken.contains(where: { $0.id == grade.id }) {
                        grades.append(grade)
                    }
                }
                if let read = try? functions.decode(MockDebrief.self, from: envelope, key: "debrief"), !read.isEmpty {
                    debrief = read
                }
            }

            // Une explication non notée compte pour zéro plutôt que de disparaître du
            // dénominateur, sinon rater l'oral remonterait la note.
            for question in spoken where !grades.contains(where: { $0.id == question.id }) {
                grades.append(MockGrade(id: question.id, score: 0))
            }
        }

        var closedSession = session
        closedSession.answers = answers
        closedSession.grades = grades
        closedSession.debrief = debrief
        closedSession.question_count = grades.count
        closedSession.correct_count = MockPaper.correctCount(grades)
        closedSession.finished_at = Date()

        try await database.patch(
            MockSessionClosing(
                answers: answers,
                grades: grades,
                debrief: debrief,
                question_count: grades.count,
                correct_count: MockPaper.correctCount(grades),
                finished_at: closedSession.finished_at ?? Date(),
                updated_at: Date()
            ),
            in: Self.table,
            matching: [URLQueryItem(name: "id", value: "eq.\(session.id.uuidString)")]
        )
        return closedSession
    }

    /// Une question sans identifiant n'est pas corrigeable : on lui en pose un, stable, à
    /// l'écriture - le même `q1`, `q2`… que le site.
    private static func numbered(_ raw: Any?) -> [MockQuestion] {
        guard let list = raw as? [Any] else { return [] }
        var questions: [MockQuestion] = []
        for (index, item) in list.enumerated() {
            guard var object = item as? [String: Any] else { continue }
            object["id"] = "q\(index + 1)"
            guard let data = try? JSONSerialization.data(withJSONObject: object),
                  let question = try? JSONDecoder().decode(MockQuestion.self, from: data) else { continue }
            questions.append(question)
        }
        return questions
    }

    private static func dayStamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
