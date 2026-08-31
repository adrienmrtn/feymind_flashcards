import Foundation
import SwiftData

/// **Le mode examen, une fois en marche.**
///
/// Replanifier les échéances au moment de déclarer l'examen ne suffit pas : à la première
/// note donnée, SM-2 renverrait la carte à trois semaines et le plan serait défait. Il faut
/// donc que la répétition espacée connaisse la date butoir tant que l'examen approche.
///
/// C'est tout ce que fait ce type : pour chaque carte concernée, il donne le dernier moment
/// où elle doit repasser. `SM2Scheduler` n'en sait rien et n'a pas changé d'une ligne ; son
/// résultat est simplement rabattu sur l'échéance avant d'être appliqué.
struct ExamDeadlines {
    /// Par carte, le jour de l'examen le plus proche qui la concerne.
    private let byCard: [UUID: Date]
    /// Le nom de cet examen, pour la pastille posée sur la carte.
    private let names: [UUID: String]

    /// Aucun examen en cours : c'est le cas ordinaire, et le défaut partout.
    static let empty = ExamDeadlines(byCard: [:], names: [:])

    init(byCard: [UUID: Date], names: [UUID: String] = [:]) {
        self.byCard = byCard
        self.names = names
    }

    var isEmpty: Bool {
        byCard.isEmpty
    }

    func deadline(for card: Flashcard) -> Date? {
        byCard[card.id]
    }

    func examName(for card: Flashcard) -> String? {
        names[card.id]
    }

    func covers(_ card: Flashcard) -> Bool {
        byCard[card.id] != nil
    }

    /// Les examens en cours, résumés carte par carte.
    ///
    /// Un examen passé ne contraint plus rien, et un examen déclaré mais non planifié
    /// n'a encore rien demandé. Quand deux examens portent sur la même carte, c'est le plus
    /// proche qui commande : c'est lui qu'on rate en premier.
    static func active(
        exams: [Exam],
        courses: [Course],
        now: Date = Date(),
        calendar: Calendar = MicaboCalendar.shared
    ) -> ExamDeadlines {
        let coursesByID = Dictionary(courses.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var byCard: [UUID: Date] = [:]
        var names: [UUID: String] = [:]

        for exam in exams where exam.isPlanned {
            let examDay = calendar.startOfDay(for: exam.date)
            guard examDay >= calendar.startOfDay(for: now) else { continue }
            let label = exam.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = label.isEmpty ? "Examen" : label

            for courseID in exam.courseIDs {
                guard let course = coursesByID[courseID] else { continue }
                for card in course.cards where !card.isSuspended {
                    if let existing = byCard[card.id], existing <= examDay { continue }
                    byCard[card.id] = examDay
                    names[card.id] = name
                }
            }
        }

        return ExamDeadlines(byCard: byCard, names: names)
    }

    /// La date butoir d'un **seul cours**, sans relire tous les cours et toutes leurs cartes.
    ///
    /// Les écrans Fiche et Cartes connaissent déjà leur cours et ses cartes. L'ancienne
    /// forme reconstruisait pourtant le dictionnaire de toute la bibliothèque à chaque
    /// poussée de navigation, uniquement pour revenir à ce même sous-ensemble.
    static func active(
        exams: [Exam],
        cards: [Flashcard],
        courseID: UUID,
        now: Date = Date(),
        calendar: Calendar = MicaboCalendar.shared
    ) -> ExamDeadlines {
        var byCard: [UUID: Date] = [:]
        var names: [UUID: String] = [:]
        let activeCards = cards.filter { !$0.isSuspended }
        let today = calendar.startOfDay(for: now)

        for exam in exams where exam.isPlanned && exam.courseIDs.contains(courseID) {
            let examDay = calendar.startOfDay(for: exam.date)
            guard examDay >= today else { continue }
            let label = exam.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = label.isEmpty ? "Examen" : label

            for card in activeCards {
                if let existing = byCard[card.id], existing <= examDay { continue }
                byCard[card.id] = examDay
                names[card.id] = name
            }
        }

        return ExamDeadlines(byCard: byCard, names: names)
    }

    /// Même chose, lue directement depuis la base : c'est la forme dont une session a besoin.
    static func active(in context: ModelContext, now: Date = Date()) -> ExamDeadlines {
        let exams = (try? context.fetch(FetchDescriptor<Exam>())) ?? []
        guard !exams.isEmpty else { return .empty }
        return active(exams: exams, courses: CourseRepository.allCourses(in: context), now: now)
    }
}

extension SM2Outcome {
    /// Rabat l'échéance calculée sur la date butoir de l'examen.
    ///
    /// Trois refus, et chacun compte. Un **palier d'apprentissage** se mesure en minutes :
    /// le rabattre sur un jour lointain casserait l'apprentissage au lieu de l'accélérer.
    /// Une échéance **déjà en deçà** de la butoir n'a rien à corriger. Et à **moins de
    /// vingt-quatre heures** de l'examen, il n'y a plus de planning à faire : rabattre
    /// ferait revenir la carte dans la minute, en boucle.
    func clamped(to deadline: Date?, now: Date) -> SM2Outcome {
        guard let deadline,
              state == .review,
              dueDate > deadline,
              deadline.timeIntervalSince(now) >= SM2Scheduler.day else {
            return self
        }

        var result = self
        result.dueDate = deadline
        // L'intervalle doit rester cohérent avec l'échéance : c'est lui qu'affichent les
        // statistiques, et lui que SM-2 reprendra au passage suivant.
        result.intervalDays = max(1, (deadline.timeIntervalSince(now) / SM2Scheduler.day * 100).rounded() / 100)
        return result
    }
}
