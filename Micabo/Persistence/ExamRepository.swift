import Foundation
import SwiftData

/// Enregistrer un examen, appliquer son plan, et le défaire.
///
/// La règle qui tient tout : **une replanification est toujours réversible.** Le plan écrit
/// de nouvelles échéances, mais il garde d'abord une photographie des anciennes. Sans ça,
/// supprimer un examen laisserait les cartes revenir tous les deux jours pour un contrôle
/// qui n'existe plus, et l'utilisateur n'aurait aucun moyen de revenir en arrière.
enum ExamRepository {
    // MARK: - Lecture

    static func all(in context: ModelContext) -> [Exam] {
        let descriptor = FetchDescriptor<Exam>(sortBy: [SortDescriptor(\.date, order: .forward)])
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Les cours d'un examen, dans l'ordre des cours. Un cours supprimé disparaît de la
    /// liste sans bruit : un examen désigne des cours, il ne les possède pas.
    static func courses(of exam: Exam, in context: ModelContext) -> [Course] {
        let wanted = Set(exam.courseIDs)
        guard !wanted.isEmpty else { return [] }
        return CourseRepository.allCourses(in: context).filter { wanted.contains($0.id) }
    }

    static func cards(of exam: Exam, in context: ModelContext) -> [Flashcard] {
        courses(of: exam, in: context)
            .flatMap(\.cards)
            .filter { !$0.isSuspended }
    }

    /// Le prochain examen à venir, celui qu'annonce l'onglet Réviser.
    static func next(in context: ModelContext, now: Date = Date()) -> Exam? {
        all(in: context).first { !$0.isPast(from: now) }
    }

    // MARK: - Écriture

    @discardableResult
    static func create(
        name: String,
        date: Date,
        courseIDs: [UUID],
        intensity: ExamIntensity,
        in context: ModelContext,
        calendar: Calendar = MicaboCalendar.shared
    ) throws -> Exam {
        let exam = Exam(
            name: TextSanitizer.clean(name).nilIfBlank ?? "Examen",
            date: calendar.startOfDay(for: date),
            courseIDs: courseIDs,
            intensity: intensity
        )
        context.insert(exam)
        try context.save()
        return exam
    }

    /// Modifie un examen. S'il était planifié, son plan est **défait puis refait** : garder
    /// les échéances d'un plan calculé pour une autre date, ou d'autres cours, donnerait un
    /// planning qui ne correspond plus à rien.
    static func update(
        _ exam: Exam,
        name: String,
        date: Date,
        courseIDs: [UUID],
        intensity: ExamIntensity,
        in context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = MicaboCalendar.shared
    ) throws {
        let wasPlanned = exam.isPlanned
        if wasPlanned {
            try unplan(exam, in: context)
        }

        exam.name = TextSanitizer.clean(name).nilIfBlank ?? "Examen"
        exam.date = calendar.startOfDay(for: date)
        exam.courseIDs = courseIDs
        exam.intensity = intensity
        exam.updatedAt = Date()
        try context.save()

        if wasPlanned, !exam.isPast(from: now, calendar: calendar) {
            try plan(exam, in: context, now: now, calendar: calendar)
        }
    }

    /// Déplace un examen d'un jour à l'autre, en replanifiant s'il l'était.
    static func move(
        _ exam: Exam,
        to date: Date,
        in context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = MicaboCalendar.shared
    ) throws {
        try update(
            exam,
            name: exam.name,
            date: date,
            courseIDs: exam.courseIDs,
            intensity: exam.intensity,
            in: context,
            now: now,
            calendar: calendar
        )
    }

    /// Supprimer un examen défait sa replanification. Le planning revient à ce qu'il était.
    static func delete(_ exam: Exam, in context: ModelContext) throws {
        if exam.isPlanned {
            try unplan(exam, in: context)
        }
        context.delete(exam)
        try context.save()
    }

    // MARK: - Planification

    /// Le plan tel qu'il serait appliqué, sans rien écrire. C'est ce que montre l'écran de
    /// confirmation.
    static func projectedPlan(
        for exam: Exam,
        in context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = MicaboCalendar.shared
    ) -> ExamPlan {
        plan(
            cards: cards(of: exam, in: context),
            date: exam.date,
            intensity: exam.intensity,
            now: now,
            calendar: calendar
        )
    }

    static func plan(
        cards: [Flashcard],
        date: Date,
        intensity: ExamIntensity,
        now: Date = Date(),
        calendar: Calendar = MicaboCalendar.shared
    ) -> ExamPlan {
        ExamPlanner.plan(
            cards: cards.map(ExamCard.init),
            examDate: date,
            now: now,
            intensity: intensity,
            calendar: calendar
        )
    }

    /// Applique le plan : photographie des échéances, puis écriture des nouvelles.
    @discardableResult
    static func plan(
        _ exam: Exam,
        in context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = MicaboCalendar.shared
    ) throws -> ExamPlan {
        let cards = cards(of: exam, in: context)
        let plan = plan(
            cards: cards,
            date: exam.date,
            intensity: exam.intensity,
            now: now,
            calendar: calendar
        )

        guard !cards.isEmpty, !plan.isEmpty else {
            throw ExamError.nothingToPlan
        }

        // La photographie est prise avant la première écriture, et une seule fois : un
        // second appel sur un examen déjà planifié écraserait l'état d'origine par un état
        // déjà comprimé.
        if exam.scheduleBackup == nil {
            exam.scheduleBackup = ExamScheduleBackup(cards: cards).encoded()
        }

        for card in cards {
            guard let offset = plan.firstOffset(for: card.id) else { continue }
            card.dueDate = plan.date(atOffset: offset, calendar: calendar)
            // L'intervalle ne se touche que sur une carte en révision. Une carte neuve ou
            // en apprentissage se compte en paliers de minutes : lui poser un intervalle en
            // jours la ferait sortir de son apprentissage sans l'avoir appris.
            if card.state == .review {
                card.intervalDays = max(1, Double(offset))
            }
            card.updatedAt = now
        }

        exam.isPlanned = true
        exam.plannedAt = now
        exam.updatedAt = now
        try context.save()
        return plan
    }

    /// Défait la replanification et rend aux cartes leurs échéances d'avant.
    static func unplan(_ exam: Exam, in context: ModelContext) throws {
        if let backup = ExamScheduleBackup.decode(from: exam.scheduleBackup) {
            backup.restore(on: allCards(in: context))
        }
        exam.scheduleBackup = nil
        exam.isPlanned = false
        exam.plannedAt = nil
        exam.updatedAt = Date()
        try context.save()
    }

    /// Toutes les cartes de la base : la restauration porte sur les identifiants gardés dans
    /// la photographie, pas sur les cours actuels de l'examen, qui ont pu changer.
    private static func allCards(in context: ModelContext) -> [Flashcard] {
        (try? context.fetch(FetchDescriptor<Flashcard>())) ?? []
    }
}

enum ExamError: LocalizedError {
    case nothingToPlan

    var errorDescription: String? {
        switch self {
        case .nothingToPlan:
            "Aucune carte à replanifier. Choisis au moins un cours qui a des cartes."
        }
    }
}
