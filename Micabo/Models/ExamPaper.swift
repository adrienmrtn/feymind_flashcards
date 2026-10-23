import Foundation

/// **Une copie d'examen blanc** : les questions écrites pour ce passage, rattachées à leur
/// leçon et à leur thème, et la durée qu'on s'est donnée.
///
/// Une copie ne se garde pas en base : elle se joue tout de suite. Ce qui reste, c'est son
/// résultat (`ExamPaperResult`), dans l'historique de l'onglet Examen.
struct ExamPaper: Codable, Equatable, Identifiable {
    struct Lesson: Codable, Equatable {
        var courseID: UUID
        var title: String
        /// Les chapitres, dans l'ordre des thèmes : une question ratée devient une carte du
        /// bon thème.
        var chapterIDs: [UUID]
    }

    struct Item: Codable, Equatable, Identifiable {
        var question: QuizQuestion
        /// Le rang de la leçon dans `lessons`.
        var lesson: Int
        /// Le rang du thème dans la leçon.
        var theme: Int

        var id: String { question.id }
    }

    var id: UUID
    /// L'examen déclaré que la copie prépare, s'il y en a un.
    var examID: UUID?
    var title: String
    var minutes: Int
    var createdAt: Date
    var lessons: [Lesson]
    var items: [Item]

    /// Le résultat de cette copie, rendue avec ces réponses. Une question sans réponse est
    /// fausse : c'est la règle d'un vrai examen.
    func result(answers: [String: QuizAnswer], seconds: Int, date: Date = Date()) -> ExamPaperResult {
        var perLesson = lessons.map { ExamPaperResult.LessonScore(title: $0.title, correct: 0, total: 0) }
        var correct = 0
        for item in items {
            let right = answers[item.id]?.right == true
            if right { correct += 1 }
            guard perLesson.indices.contains(item.lesson) else { continue }
            perLesson[item.lesson].total += 1
            if right { perLesson[item.lesson].correct += 1 }
        }
        return ExamPaperResult(
            id: id,
            examID: examID,
            title: title,
            date: date,
            correct: correct,
            total: items.count,
            seconds: seconds,
            minutes: minutes,
            lessons: perLesson.filter { $0.total > 0 }
        )
    }
}

/// Ce qu'il reste d'un examen blanc une fois rendu.
struct ExamPaperResult: Codable, Equatable, Identifiable {
    struct LessonScore: Codable, Equatable {
        var title: String
        var correct: Int
        var total: Int

        var fraction: Double { total == 0 ? 0 : Double(correct) / Double(total) }
    }

    var id: UUID
    var examID: UUID?
    var title: String
    var date: Date
    var correct: Int
    var total: Int
    /// Le temps passé, en secondes.
    var seconds: Int
    var minutes: Int
    var lessons: [LessonScore]

    var fraction: Double { total == 0 ? 0 : Double(correct) / Double(total) }
}

/// **L'historique des examens blancs**, sur l'appareil. Les trente derniers suffisent à
/// voir où l'on en est.
enum ExamHistory {
    private static let key = "micabo.exams.mockResults"
    static let limit = 30

    static func all(defaults: UserDefaults = .standard) -> [ExamPaperResult] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([ExamPaperResult].self, from: data)) ?? []
    }

    static func record(_ result: ExamPaperResult, defaults: UserDefaults = .standard) {
        var results = all(defaults: defaults).filter { $0.id != result.id }
        results.insert(result, at: 0)
        if let data = try? JSONEncoder().encode(Array(results.prefix(limit))) {
            defaults.set(data, forKey: key)
        }
    }

    /// Oublie l'historique, à la sortie d'un compte : ces copies sont les siennes.
    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }

    static func results(for examID: UUID, defaults: UserDefaults = .standard) -> [ExamPaperResult] {
        all(defaults: defaults).filter { $0.examID == examID }
    }
}

/// L'examen blanc offert, une fois. Le serveur tient la même règle (`begin_extra`, `exam`).
enum ExamAllowance {
    private static let key = "micabo.exams.freeMockUsed"

    static var freeMockUsed: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    /// Vrai quand une copie fraîchement écrite doit consommer l'examen offert : seulement
    /// hors Pro, et seulement si elle a des questions à jouer. Une copie vide est un échec de
    /// génération, pas un examen passé.
    static func consumesFreeMock(isPro: Bool, questionCount: Int) -> Bool {
        !isPro && questionCount > 0
    }
}

/// **La note d'une copie, dans le barème du pays** : 13,5/20 en France, 2,3 en Allemagne,
/// 4,5 en Suisse, B+ aux États-Unis. Le même pourcentage, dit comme l'élève le lit sur ses
/// copies.
///
/// Les seuils suivent ceux de la note visée (`DesiredGradeScale`) : la moitié des points
/// fait la moyenne partout, et la note visée se compare à la note obtenue.
enum ExamGrade {
    static func label(_ fraction: Double, country: SchoolingCountry, locale: UiLocale = .resolved()) -> String {
        let value = min(1, max(0, fraction))
        let number: (Double, Int) -> String = { amount, digits in
            amount.formatted(.number.precision(.fractionLength(0...digits)).locale(locale.foundation))
        }
        switch country {
        case .fr, .be, .ma, .dz, .tn, .sn, .ci, .pt, .gr:
            return "\(number((value * 40).rounded() / 2, 1))/20"
        case .it, .es:
            return "\(number((value * 20).rounded() / 2, 1))/10"
        case .lu:
            return "\(Int((value * 60).rounded()))/60"
        case .ca, .tr:
            return "\(Int((value * 100).rounded())) %"
        case .ch:
            return number(((value * 5 + 1) * 2).rounded() / 2, 1)
        case .nl:
            return number(((value * 9 + 1) * 10).rounded() / 10, 1)
        case .ro:
            return number((max(1, value * 10) * 10).rounded() / 10, 1)
        case .de:
            let steps: [(Double, String)] = [
                (0.95, "1,0"), (0.90, "1,3"), (0.85, "1,7"), (0.80, "2,0"), (0.75, "2,3"), (0.70, "2,7"),
                (0.65, "3,0"), (0.60, "3,3"), (0.55, "3,7"), (0.50, "4,0"), (0.30, "5,0")
            ]
            return steps.first { value >= $0.0 }?.1 ?? "6,0"
        case .cz:
            return pick(value, [(0.9, "1"), (0.75, "2"), (0.6, "3"), (0.5, "4")], else: "5")
        case .hu:
            return pick(value, [(0.9, "5"), (0.7, "4"), (0.5, "3"), (0.35, "2")], else: "1")
        case .pl:
            return pick(value, [(0.98, "6"), (0.9, "5"), (0.7, "4"), (0.5, "3"), (0.3, "2")], else: "1")
        case .se:
            return pick(value, [(0.9, "A"), (0.8, "B"), (0.7, "C"), (0.6, "D"), (0.5, "E")], else: "F")
        case .uk:
            return pick(value, [(0.9, "A*"), (0.8, "A"), (0.7, "B"), (0.6, "C"), (0.5, "D"), (0.4, "E")], else: "U")
        case .us, .other:
            return pick(value, [
                (0.97, "A+"), (0.93, "A"), (0.90, "A-"), (0.87, "B+"), (0.83, "B"), (0.80, "B-"),
                (0.77, "C+"), (0.73, "C"), (0.70, "C-"), (0.60, "D")
            ], else: "F")
        }
    }

    /// Vrai quand la copie a la moyenne.
    static func passes(_ fraction: Double) -> Bool { fraction >= 0.5 }

    private static func pick(_ value: Double, _ steps: [(Double, String)], else fallback: String) -> String {
        steps.first { value >= $0.0 }?.1 ?? fallback
    }
}
