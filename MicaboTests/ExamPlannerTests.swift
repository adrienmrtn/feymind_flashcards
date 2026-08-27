import Foundation
import SwiftData
import XCTest
@testable import Micabo

/// L'échelle de passages d'une carte : c'est la brique du plan, et la seule partie du
/// mode examen qui soit purement arithmétique.
final class ExamLadderTests: XCTestCase {
    func testASinglePassLandsInTheClosingStretch() {
        let offsets = ExamPlanner.ladder(passes: 1, window: 10, phase: 0)

        XCTAssertEqual(offsets, [9])
    }

    /// Tout empiler sur la veille garantirait le pic de rétention et une session de trois
    /// cents cartes que personne ne fait : les derniers passages s'échelonnent.
    func testLastPassesAreSpreadOverTheClosingDays() {
        let lasts = (0..<9).map { phase in
            ExamPlanner.ladder(passes: 3, window: 12, phase: phase).last ?? -1
        }

        XCTAssertEqual(Set(lasts), Set([11, 10, 9]), "Les derniers passages doivent tomber dans les trois derniers jours")
    }

    func testPassesAreRegularlySpaced() {
        let offsets = ExamPlanner.ladder(passes: 4, window: 13, phase: 0)

        XCTAssertEqual(offsets.count, 4)
        XCTAssertEqual(offsets.first, 0)
        XCTAssertEqual(offsets.last, 12)

        let gaps = zip(offsets, offsets.dropFirst()).map { $1 - $0 }
        XCTAssertEqual(Set(gaps).count, 1, "Des passages régulièrement espacés donnent une charge plate : \(offsets)")
    }

    /// On ne voit pas une carte deux fois le même jour : le nombre de passages est borné
    /// par le nombre de jours disponibles.
    func testPassesNeverExceedTheAvailableDays() {
        for window in 1...6 {
            for phase in 0..<5 {
                let offsets = ExamPlanner.ladder(passes: 8, window: window, phase: phase)

                XCTAssertEqual(Set(offsets).count, offsets.count, "Aucun jour en double")
                XCTAssertEqual(offsets, offsets.sorted(), "Les jours doivent être croissants")
                XCTAssertLessThanOrEqual(offsets.count, window)
                for offset in offsets {
                    XCTAssertTrue((0..<window).contains(offset), "Décalage \(offset) hors de la fenêtre de \(window)")
                }
            }
        }
    }

    func testAOneDayWindowGivesASinglePass() {
        XCTAssertEqual(ExamPlanner.ladder(passes: 4, window: 1, phase: 0), [0])
        XCTAssertEqual(ExamPlanner.ladder(passes: 4, window: 1, phase: 7), [0])
    }

    func testAnEmptyWindowGivesNothing() {
        XCTAssertTrue(ExamPlanner.ladder(passes: 3, window: 0, phase: 0).isEmpty)
    }
}

/// Combien de passages, selon l'intensité et l'état de la carte.
final class ExamPassesTests: XCTestCase {
    private func card(state: CardState, interval: Double) -> ExamCard {
        ExamCard(id: UUID(), state: state, intervalDays: interval, dueDate: Date())
    }

    func testIntensityRaisesThePassCount() {
        let young = card(state: .review, interval: 5)

        XCTAssertEqual(ExamPlanner.passes(for: young, intensity: .light), 2)
        XCTAssertEqual(ExamPlanner.passes(for: young, intensity: .standard), 3)
        XCTAssertEqual(ExamPlanner.passes(for: young, intensity: .intense), 4)
    }

    /// Une carte jamais vue doit d'abord être apprise, une carte acquise depuis trois
    /// semaines seulement rafraîchie.
    func testStateAdjustsThePassCount() {
        let fresh = card(state: .new, interval: 0)
        let mature = card(state: .review, interval: 30)

        XCTAssertEqual(ExamPlanner.passes(for: fresh, intensity: .standard), 4)
        XCTAssertEqual(ExamPlanner.passes(for: mature, intensity: .standard), 2)
        // Jamais moins d'un passage : une carte du programme se révise au moins une fois.
        XCTAssertEqual(ExamPlanner.passes(for: mature, intensity: .light), 1)
    }
}

/// Le plan complet et sa projection : ce que l'écran de confirmation annonce.
final class ExamPlanTests: XCTestCase {
    private let calendar = MicaboCalendar.shared
    private lazy var now = calendar.startOfDay(for: Date())

    private func cards(_ count: Int, state: CardState = .review, interval: Double = 6) -> [ExamCard] {
        (0..<count).map { _ in
            ExamCard(id: UUID(), state: state, intervalDays: interval, dueDate: now)
        }
    }

    private func plan(cards: [ExamCard], inDays days: Int, intensity: ExamIntensity = .standard) -> ExamPlan {
        ExamPlanner.plan(
            cards: cards,
            examDate: calendar.date(byAdding: .day, value: days, to: now) ?? now,
            now: now,
            intensity: intensity,
            calendar: calendar
        )
    }

    /// Le contrat de l'écran de confirmation : les quatre chiffres annoncés.
    func testProjectionAnnouncesTheFourFigures() {
        let result = plan(cards: cards(30), inDays: 10)

        XCTAssertEqual(result.projection.cardCount, 30)
        XCTAssertEqual(result.projection.daysRemaining, 10)
        XCTAssertEqual(result.projection.totalReviews, 90, "30 cartes × 3 passages")
        XCTAssertEqual(result.projection.averageDailyLoad, 9, "90 passages sur 10 jours")
        XCTAssertNotNil(result.projection.busiest)
    }

    /// La révision s'arrête la veille : le jour de l'examen ne sert plus à apprendre.
    func testTheWindowStopsOnTheEveOfTheExam() {
        let result = plan(cards: cards(4), inDays: 7)

        XCTAssertEqual(result.windowDays, 7)
        XCTAssertEqual(result.examDay, calendar.date(byAdding: .day, value: 7, to: now))
        XCTAssertEqual(result.lastReviewDay, calendar.date(byAdding: .day, value: 6, to: now))
        XCTAssertLessThan(result.lastReviewDay, result.examDay)
    }

    /// Un examen aujourd'hui ou demain ne laisse qu'une journée, et tout y passe.
    func testAnImminentExamCollapsesToASingleDay() {
        for days in [0, 1] {
            let result = plan(cards: cards(5), inDays: days)

            XCTAssertEqual(result.windowDays, 1, "Examen dans \(days) jour(s)")
            XCTAssertEqual(result.projection.load, [5])
            for offsets in result.days.values {
                XCTAssertEqual(offsets, [0])
            }
        }
    }

    /// La charge doit être tenable. Elle n'est pas parfaitement plate, et c'est voulu : les
    /// derniers jours portent le dernier passage de toutes les cartes, donc ils pèsent plus.
    /// Ce que le test verrouille, c'est qu'aucun jour ne soit vide, que les jours ordinaires
    /// restent près de la moyenne, et que même le pire jour reste dans un ordre de grandeur
    /// faisable.
    func testDailyLoadStaysTenable() {
        let result = plan(cards: cards(120), inDays: 14, intensity: .intense)
        let load = result.projection.load
        let average = Double(result.projection.totalReviews) / Double(load.count)
        let closingStart = result.windowDays - ExamPlanner.closingDays

        XCTAssertEqual(load.count, 14)

        for (offset, count) in load.enumerated() {
            XCTAssertGreaterThan(count, 0, "Le jour \(offset) ne doit pas rester vide")
            XCTAssertLessThanOrEqual(
                Double(count),
                average * 2.5,
                "Le jour \(offset) porte \(count) passages pour une moyenne de \(Int(average))"
            )
            if offset < closingStart {
                XCTAssertLessThanOrEqual(
                    Double(count),
                    average * 1.6,
                    "Un jour ordinaire doit rester près de la moyenne, or le jour \(offset) porte \(count)"
                )
            }
        }
    }

    /// Le pic de charge tombe dans les derniers jours, là où tombent les derniers passages.
    /// C'est exactement ce que « jour le plus chargé » sert à annoncer avant de confirmer.
    func testTheBusiestDayIsInTheClosingStretch() {
        let result = plan(cards: cards(60), inDays: 15)
        let busiest = try? XCTUnwrap(result.projection.busiest)

        XCTAssertNotNil(busiest)
        XCTAssertGreaterThanOrEqual(busiest?.offset ?? -1, result.windowDays - ExamPlanner.closingDays)
    }

    /// Chaque carte a un dernier passage dans les tout derniers jours : c'est ce qui met sa
    /// rétention au sommet le jour J plutôt que trois semaines après.
    func testEveryCardPeaksInTheClosingDays() {
        let result = plan(cards: cards(40), inDays: 12)
        let closingStart = result.windowDays - ExamPlanner.closingDays

        for (card, offsets) in result.days {
            guard let last = offsets.last else {
                XCTFail("La carte \(card) doit avoir au moins un passage")
                continue
            }
            XCTAssertGreaterThanOrEqual(last, closingStart)
            XCTAssertLessThan(last, result.windowDays)
        }
    }

    func testEveryCardIsPlanned() {
        let deck = cards(25)
        let result = plan(cards: deck, inDays: 9)

        XCTAssertEqual(result.days.count, deck.count)
        for card in deck {
            XCTAssertFalse(result.days[card.id]?.isEmpty ?? true)
        }
    }

    func testNoCardsGivesAnEmptyPlan() {
        let result = plan(cards: [], inDays: 8)

        XCTAssertTrue(result.isEmpty)
        XCTAssertTrue(result.projection.isEmpty)
        XCTAssertEqual(result.projection.averageDailyLoad, 0)
    }

    /// Les cartes en retard passent en premier : si le temps manque, c'est ce qui doit être
    /// vu d'abord.
    func testOverdueCardsComeFirst() {
        let overdue = ExamCard(
            id: UUID(),
            state: .review,
            intervalDays: 10,
            dueDate: calendar.date(byAdding: .day, value: -3, to: now) ?? now
        )
        let future = ExamCard(
            id: UUID(),
            state: .review,
            intervalDays: 10,
            dueDate: calendar.date(byAdding: .day, value: 5, to: now) ?? now
        )

        let ordered = ExamPlanner.ordered([future, overdue], now: now)

        XCTAssertEqual(ordered.first?.id, overdue.id)
    }
}

/// Le plafond d'intervalle : le mécanisme qui fait tenir le plan une fois les notes données.
final class ExamDeadlineClampTests: XCTestCase {
    private let now = Date()

    private func outcome(state: CardState, inDays days: Double) -> SM2Outcome {
        SM2Outcome(
            rating: .good,
            state: state,
            dueDate: now.addingTimeInterval(days * SM2Scheduler.day),
            intervalDays: days,
            easeFactor: 2.5,
            repetitions: 3,
            lapses: 0,
            stepIndex: 0
        )
    }

    /// Le cas qui justifie tout le mécanisme : sans lui, la première note donnée renvoie la
    /// carte trois semaines après l'examen.
    func testAnIntervalBeyondTheExamIsBroughtBack() {
        let deadline = now.addingTimeInterval(6 * SM2Scheduler.day)
        let clamped = outcome(state: .review, inDays: 21).clamped(to: deadline, now: now)

        XCTAssertEqual(clamped.dueDate, deadline)
        XCTAssertEqual(clamped.intervalDays, 6, accuracy: 0.02)
    }

    func testAnIntervalInsideTheDeadlineIsLeftAlone() {
        let deadline = now.addingTimeInterval(20 * SM2Scheduler.day)
        let original = outcome(state: .review, inDays: 4)

        XCTAssertEqual(original.clamped(to: deadline, now: now), original)
    }

    func testNoDeadlineChangesNothing() {
        let original = outcome(state: .review, inDays: 30)

        XCTAssertEqual(original.clamped(to: nil, now: now), original)
    }

    /// Un palier d'apprentissage se compte en minutes : le rabattre sur un jour lointain
    /// casserait l'apprentissage au lieu de l'accélérer.
    func testLearningStepsAreNeverClamped() {
        let deadline = now.addingTimeInterval(6 * SM2Scheduler.day)

        for state in [CardState.new, .learning, .relearning] {
            let original = outcome(state: state, inDays: 30)
            XCTAssertEqual(original.clamped(to: deadline, now: now), original, "\(state)")
        }
    }

    /// À moins de vingt-quatre heures, il n'y a plus rien à replanifier : rabattre ferait
    /// revenir la carte dans la minute, en boucle.
    func testAnImminentDeadlineStopsClamping() {
        let original = outcome(state: .review, inDays: 30)

        XCTAssertEqual(original.clamped(to: now.addingTimeInterval(3_600), now: now), original)
        XCTAssertEqual(original.clamped(to: now.addingTimeInterval(-86_400), now: now), original)
    }
}

/// L'application du plan en base, et sa réversibilité.
final class ExamRepositoryTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private let calendar = MicaboCalendar.shared

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: Course.self,
            Flashcard.self,
            ReviewLog.self,
            Exam.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
    }

    private func makeCourse(cards count: Int, dueInDays: Double = 30) throws -> Course {
        let course = try CourseRepository.save(
            GeneratedCourse(title: "La photosynthèse", summary: "Résumé.", contextText: "Contenu."),
            source: .pdf,
            rawText: "Texte source du document.",
            in: context
        )
        let inserted = try CourseRepository.addFlashcards(
            (0..<count).map { GeneratedFlashcard(front: "Question \($0) ?", back: "Réponse \($0)") },
            to: course,
            in: context
        )
        for card in inserted {
            card.state = .review
            card.intervalDays = dueInDays
            card.dueDate = Date().addingTimeInterval(dueInDays * SM2Scheduler.day)
        }
        try context.save()
        return course
    }

    /// Le cas du cahier des charges : des cartes qui retombent bien après l'examen sont
    /// ramenées avant lui.
    func testPlanningPullsEveryCardBeforeTheExam() throws {
        let course = try makeCourse(cards: 12, dueInDays: 30)
        let examDate = calendar.date(byAdding: .day, value: 10, to: Date())!

        let exam = try ExamRepository.create(
            name: "Bac blanc",
            date: examDate,
            courseIDs: [course.id],
            intensity: .standard,
            in: context
        )
        try ExamRepository.plan(exam, in: context)

        XCTAssertTrue(exam.isPlanned)
        XCTAssertNotNil(exam.scheduleBackup)
        for card in course.cards {
            XCTAssertLessThan(card.dueDate, calendar.startOfDay(for: examDate))
        }
    }

    /// Supprimer un examen doit rendre le planning d'avant. Sans ça, les cartes
    /// reviendraient tous les deux jours pour un contrôle qui n'existe plus.
    func testDeletingAPlannedExamRestoresTheSchedule() throws {
        let course = try makeCourse(cards: 8, dueInDays: 30)
        let before = course.orderedCards.map(\.dueDate)

        let exam = try ExamRepository.create(
            name: "Partiel",
            date: calendar.date(byAdding: .day, value: 12, to: Date())!,
            courseIDs: [course.id],
            intensity: .intense,
            in: context
        )
        try ExamRepository.plan(exam, in: context)
        XCTAssertNotEqual(course.orderedCards.map(\.dueDate), before)

        try ExamRepository.delete(exam, in: context)

        XCTAssertEqual(course.orderedCards.map(\.dueDate), before)
        XCTAssertTrue(ExamRepository.all(in: context).isEmpty)
    }

    /// Déplacer un examen replanifie : garder les échéances calculées pour l'ancienne date
    /// donnerait un planning qui ne mène plus nulle part.
    func testMovingAPlannedExamReschedules() throws {
        let course = try makeCourse(cards: 10, dueInDays: 40)
        let exam = try ExamRepository.create(
            name: "Contrôle",
            date: calendar.date(byAdding: .day, value: 20, to: Date())!,
            courseIDs: [course.id],
            intensity: .standard,
            in: context
        )
        try ExamRepository.plan(exam, in: context)

        let moved = calendar.date(byAdding: .day, value: 5, to: Date())!
        try ExamRepository.move(exam, to: moved, in: context)

        XCTAssertTrue(exam.isPlanned)
        XCTAssertEqual(exam.date, calendar.startOfDay(for: moved))
        for card in course.cards {
            XCTAssertLessThan(card.dueDate, calendar.startOfDay(for: moved))
        }
    }

    /// Replanifier deux fois de suite ne doit pas écraser la photographie d'origine par un
    /// état déjà comprimé.
    func testTheBackupKeepsTheOriginalSchedule() throws {
        let course = try makeCourse(cards: 6, dueInDays: 25)
        let before = course.orderedCards.map(\.dueDate)

        let exam = try ExamRepository.create(
            name: "Oral",
            date: calendar.date(byAdding: .day, value: 15, to: Date())!,
            courseIDs: [course.id],
            intensity: .light,
            in: context
        )
        try ExamRepository.plan(exam, in: context)
        try ExamRepository.plan(exam, in: context)
        try ExamRepository.unplan(exam, in: context)

        XCTAssertEqual(course.orderedCards.map(\.dueDate), before)
        XCTAssertFalse(exam.isPlanned)
        XCTAssertNil(exam.scheduleBackup)
    }

    func testAnExamWithoutCardsIsRefused() throws {
        let exam = try ExamRepository.create(
            name: "Sans cours",
            date: calendar.date(byAdding: .day, value: 5, to: Date())!,
            courseIDs: [],
            intensity: .standard,
            in: context
        )

        XCTAssertThrowsError(try ExamRepository.plan(exam, in: context))
        XCTAssertFalse(exam.isPlanned)
    }

    /// Une carte neuve garde son état : elle est déplacée, pas diplômée d'office.
    func testNewCardsKeepTheirStateAndSteps() throws {
        let course = try makeCourse(cards: 5, dueInDays: 0)
        for card in course.cards {
            card.state = .new
            card.intervalDays = 0
        }
        try context.save()

        let exam = try ExamRepository.create(
            name: "Interro",
            date: calendar.date(byAdding: .day, value: 8, to: Date())!,
            courseIDs: [course.id],
            intensity: .standard,
            in: context
        )
        try ExamRepository.plan(exam, in: context)

        for card in course.cards {
            XCTAssertEqual(card.state, .new)
            XCTAssertEqual(card.intervalDays, 0, "Un intervalle en jours sur une carte neuve la sortirait de son apprentissage")
        }
    }
}

/// Les échéances vues par la répétition espacée.
final class ExamDeadlinesTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private let calendar = MicaboCalendar.shared

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: Course.self,
            Flashcard.self,
            ReviewLog.self,
            Exam.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
    }

    private func makeCourse() throws -> Course {
        let course = try CourseRepository.save(
            GeneratedCourse(title: "Cours", summary: "S", contextText: "C"),
            source: .text,
            rawText: "Texte source.",
            in: context
        )
        try CourseRepository.addFlashcards(
            [GeneratedFlashcard(front: "Question ?", back: "Réponse")],
            to: course,
            in: context
        )
        return course
    }

    private func exam(name: String, inDays days: Int, courses: [Course], planned: Bool) throws -> Exam {
        let exam = try ExamRepository.create(
            name: name,
            date: calendar.date(byAdding: .day, value: days, to: Date())!,
            courseIDs: courses.map(\.id),
            intensity: .standard,
            in: context
        )
        if planned { exam.isPlanned = true }
        try context.save()
        return exam
    }

    func testOnlyPlannedAndFutureExamsConstrainTheCards() throws {
        let course = try makeCourse()
        _ = try exam(name: "Non planifié", inDays: 5, courses: [course], planned: false)

        XCTAssertTrue(ExamDeadlines.active(in: context).isEmpty)

        _ = try exam(name: "Passé", inDays: -3, courses: [course], planned: true)
        XCTAssertTrue(ExamDeadlines.active(in: context).isEmpty)

        _ = try exam(name: "À venir", inDays: 4, courses: [course], planned: true)
        XCTAssertFalse(ExamDeadlines.active(in: context).isEmpty)
    }

    /// Deux examens sur la même carte : c'est le plus proche qui commande, parce que c'est
    /// celui qu'on rate en premier.
    func testTheNearestExamWins() throws {
        let course = try makeCourse()
        _ = try exam(name: "Loin", inDays: 20, courses: [course], planned: true)
        _ = try exam(name: "Proche", inDays: 6, courses: [course], planned: true)

        let card = try XCTUnwrap(course.cards.first)
        let deadline = ExamDeadlines.active(in: context).deadline(for: card)

        XCTAssertEqual(deadline, calendar.date(byAdding: .day, value: 6, to: calendar.startOfDay(for: Date())))
        XCTAssertEqual(ExamDeadlines.active(in: context).examName(for: card), "Proche")
    }

    /// Les cartes d'examen passent devant, mais elles restent dans le plafond du jour.
    /// Sans ça, un cours rattaché à deux examens vidait tout le paquet d'un coup.
    func testExamCardsStayWithinTheDailyNewCardCap() throws {
        let course = try CourseRepository.save(
            GeneratedCourse(title: "Cours", summary: "S", contextText: "C"),
            source: .text,
            rawText: "Texte source.",
            in: context
        )
        let cards = try CourseRepository.addFlashcards(
            (0..<30).map { GeneratedFlashcard(front: "Question \($0) ?", back: "Réponse \($0)") },
            to: course,
            in: context
        )
        for card in cards {
            card.state = .new
            card.dueDate = Date().addingTimeInterval(-60)
        }
        try context.save()

        let capped = StudyQueueBuilder.build(from: cards, limits: smallLimits, deadlines: .empty)
        XCTAssertEqual(capped.count, 3)

        _ = try exam(name: "Examen", inDays: 7, courses: [course], planned: true)
        let withExam = StudyQueueBuilder.build(
            from: cards,
            limits: smallLimits,
            deadlines: ExamDeadlines.active(in: context)
        )
        XCTAssertEqual(withExam.count, 3)
        XCTAssertTrue(withExam.allSatisfy { ExamDeadlines.active(in: context).covers($0) })
    }

    /// Un second examen ne ramène pas une carte déjà notée aujourd'hui.
    func testASecondExamDoesNotYankCardsReviewedToday() throws {
        let course = try makeCourse(cards: 4, dueInDays: 30)
        let reviewed = try XCTUnwrap(course.orderedCards.first)
        reviewed.lastReviewedAt = Date()
        let originalDue = reviewed.dueDate
        try context.save()

        let first = try exam(name: "Partiel", inDays: 12, courses: [course], planned: true)
        try ExamRepository.plan(first, in: context)

        let second = try exam(name: "Bac", inDays: 6, courses: [course], planned: true)
        try ExamRepository.plan(second, in: context)

        XCTAssertEqual(reviewed.dueDate, originalDue)
    }

    /// Trois cartes neuves par session : de quoi voir le plafond agir.
    private var smallLimits: StudyQueueBuilder.Limits {
        StudyQueueBuilder.Limits(newPerSession: 3, reviewsPerSession: .max)
    }
}
