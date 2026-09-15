import Foundation

/// **L'agenda d'un examen : tous ses rendez-vous de mesure, passés et à venir.**
///
/// C'est ce que le mini-calendrier de la page d'examen affiche, et ce que « Au programme » lit
/// pour savoir qu'un test tombe aujourd'hui.
///
/// ## Le portage, et pourquoi il existe
///
/// La planification des blancs vivait **uniquement** dans le noyau TypeScript : l'app n'avait
/// jamais eu à savoir quel jour un blanc tombait, elle affichait un bouton « passer un blanc »
/// et c'était tout. Un calendrier ne peut pas s'en contenter — il doit dessiner des jours, hors
/// ligne, sans attendre le réseau.
///
/// Les constantes sont donc recopiées ici **à l'identique**, et un test de parité les compare
/// au TypeScript. Deux calendriers qui ne posent pas les mêmes jours sur le même examen sont
/// deux produits, et l'étudiant qui ouvre le site après son téléphone verrait sa semaine bouger
/// sans avoir rien fait.
///
/// ## Dérivé, et surchargé seulement là où l'étudiant a touché
///
/// Aucun rendez-vous n'est écrit à la création d'un examen. Les blancs se déduisent de
/// ``mockOffsets``, les parcours de ``parcoursOffsets(daysRemaining:)``, et les deux se
/// recalculent depuis la date de l'épreuve à chaque lecture. Déplacer l'examen d'une semaine
/// déplace tout l'agenda sans migrer une ligne.
///
/// Ce qui se persiste, c'est **l'exception** : la date que l'étudiant a choisie. Voir
/// ``AgendaOverride``, et la table `exam_plan_overrides`.
enum ExamAgenda {

    // MARK: - Les rendez-vous d'un examen blanc

    /// Les jours avant l'épreuve où un blanc a un sens. Miroir de `MOCK_OFFSETS`.
    static let mockOffsets: [Int] = [7, 2]

    /// De combien de jours un blanc peut manquer son rendez-vous et compter quand même.
    ///
    /// Trois jours : le blanc de J-7 passé le week-end d'avant reste le blanc de J-7.
    static let mockSlack = 3

    static let minMockQuestions = 8
    static let defaultMockQuestions = 20
    static let maxMockQuestions = 60
    static let minutesPerMockQuestion = 0.75

    /// Combien de questions pour cette épreuve. Miroir de `mockQuestionCount`.
    ///
    /// Assez pour que le score veuille dire quelque chose, jamais plus du quart du programme :
    /// un blanc qui passe tout le paquet est une session de révision déguisée.
    static func mockQuestionCount(cardCount: Int) -> Int {
        guard cardCount >= minMockQuestions else { return 0 }
        let quarter = Int((Double(cardCount) / 4).rounded())
        return max(minMockQuestions, min(maxMockQuestions, min(defaultMockQuestions, quarter)))
    }

    static func mockMinutes(questionCount: Int) -> Int {
        max(5, Int((Double(questionCount) * minutesPerMockQuestion).rounded()))
    }

    // MARK: - Les rendez-vous d'un test de parcours

    /// Le premier rendez-vous, en jours avant l'épreuve. J-1 et le jour J restent aux révisions.
    static let parcoursFirstOffset = 2

    /// En deçà de ce nombre de jours restants, un test tous les deux jours. Au-delà, tous les trois.
    static let parcoursTightWindow = 10
    static let parcoursTightStep = 2
    static let parcoursLooseStep = 3

    /// Au-delà, la préparation devient une suite d'épreuves.
    static let parcoursMax = 8

    /// Cinq QCM et cinq questions orales : le format ne varie pas, c'est ce qui le rend comparable.
    static let parcoursChoiceCount = 5
    static let parcoursOralCount = 5
    static let parcoursQuestionCount = 10
    static let parcoursMinutes = 5

    /// La tolérance d'un parcours est d'un jour, et pas des trois d'un blanc.
    ///
    /// Les parcours sont posés tous les deux ou trois jours : la tolérance large les ferait se
    /// voler leurs sessions, et un seul test coché en effacerait trois.
    static let parcoursSlack = 1

    /// Les rendez-vous de parcours, en jours avant l'épreuve, du plus proche au plus lointain.
    ///
    /// Comptés depuis l'épreuve et non depuis aujourd'hui : c'est la distance au jour J qui
    /// décide de la cadence, et elle ne doit pas changer parce qu'on a ouvert l'app trois jours
    /// plus tard. Miroir de `parcoursOffsets`.
    static func parcoursOffsets(daysRemaining: Int, max limit: Int = parcoursMax) -> [Int] {
        guard daysRemaining >= parcoursFirstOffset else { return [] }

        var offsets: [Int] = []
        var offset = parcoursFirstOffset

        while offset <= daysRemaining && offsets.count < Swift.max(0, limit) {
            offsets.append(offset)
            offset += offset < parcoursTightWindow ? parcoursTightStep : parcoursLooseStep
        }

        return offsets
    }

    static func slack(for kind: AgendaKind) -> Int {
        kind == .mock ? mockSlack : parcoursSlack
    }

    // MARK: - L'agenda

    /// Les rendez-vous d'un examen, triés par date.
    ///
    /// - Parameters:
    ///   - exam: l'épreuve, pour sa date, son type et son volume de cartes.
    ///   - done: les sessions déjà passées, pour savoir ce qui est honoré.
    ///   - overrides: les rendez-vous que l'étudiant a déplacés.
    static func events(
        for exam: Exam,
        cardCount: Int,
        done: [AgendaDone] = [],
        overrides: [AgendaOverride] = [],
        now: Date = Date(),
        calendar: Calendar = MicaboCalendar.shared
    ) -> [AgendaEvent] {
        let today = calendar.startOfDay(for: now)
        let examDay = calendar.startOfDay(for: exam.date)
        let daysRemaining = calendar.dateComponents([.day], from: today, to: examDay).day ?? 0

        var planned: [AgendaEvent] = []

        // Les blancs : deux rendez-vous, et seulement pour les épreuves qui s'y prêtent. On ne
        // s'entraîne pas à un oral avec un QCM.
        let questions = mockQuestionCount(cardCount: cardCount)
        if exam.kind.wantsMock && questions > 0 {
            for (slot, before) in mockOffsets.enumerated() {
                planned.append(AgendaEvent(
                    examId: exam.id,
                    examName: exam.name,
                    kind: .mock,
                    slot: slot,
                    date: calendar.date(byAdding: .day, value: -before, to: examDay) ?? examDay,
                    offset: 0,
                    questionCount: questions,
                    minutes: mockMinutes(questionCount: questions),
                    status: .upcoming,
                    moved: false
                ))
            }
        }

        // Les parcours : la cadence les pose quel que soit le type d'épreuve. Cinq questions
        // orales servent un oral autant qu'un écrit.
        for (slot, before) in parcoursOffsets(daysRemaining: daysRemaining).enumerated() {
            planned.append(AgendaEvent(
                examId: exam.id,
                examName: exam.name,
                kind: .parcours,
                slot: slot,
                date: calendar.date(byAdding: .day, value: -before, to: examDay) ?? examDay,
                offset: 0,
                questionCount: parcoursQuestionCount,
                minutes: parcoursMinutes,
                status: .upcoming,
                moved: false
            ))
        }

        apply(overrides, to: &planned, calendar: calendar)
        separate(&planned, examDay: examDay, calendar: calendar)
        settle(&planned, done: done, today: today, calendar: calendar)

        return planned.sorted { $0.date < $1.date }
    }

    /// La date choisie par l'étudiant remplace celle de la dérivation, et se signale comme telle.
    private static func apply(
        _ overrides: [AgendaOverride],
        to planned: inout [AgendaEvent],
        calendar: Calendar
    ) {
        for index in planned.indices {
            let event = planned[index]
            guard let override = overrides.first(where: {
                $0.examId == event.examId && $0.kind == event.kind && $0.slot == event.slot
            }) else { continue }
            planned[index].date = calendar.startOfDay(for: override.date)
            planned[index].moved = true
        }
    }

    /// **Deux mesures ne partagent pas un jour.**
    ///
    /// Enchaîner un blanc et un parcours ne mesure plus rien : la seconde moitié se passe sur un
    /// étudiant déjà fatigué, et son score dit la fatigue plutôt que le programme. C'est
    /// toujours le parcours qui s'écarte - le blanc est le rendez-vous qui compte - et il
    /// s'écarte **vers l'arrière**. Vers l'avant il finirait la veille de l'épreuve, quand il ne
    /// reste plus le temps de corriger ce qu'il révélerait.
    ///
    /// Un rendez-vous déplacé à la main ne bouge pas : l'étudiant a tranché.
    private static func separate(
        _ planned: inout [AgendaEvent],
        examDay: Date,
        calendar: Calendar
    ) {
        var taken = Set(planned.filter { $0.kind == .mock }.map(\.date))

        for index in planned.indices where planned[index].kind == .parcours {
            if planned[index].moved {
                taken.insert(planned[index].date)
                continue
            }

            var date = planned[index].date
            // On ne remonte pas indéfiniment : passé une semaine de recul, le rendez-vous n'a
            // plus rien à voir avec celui que la cadence avait posé.
            var step = 0
            while step < 7, taken.contains(date) {
                date = calendar.date(byAdding: .day, value: -1, to: date) ?? date
                step += 1
            }

            planned[index].date = date
            taken.insert(date)
        }

        for index in planned.indices where planned[index].date > examDay {
            planned[index].date = examDay
        }
    }

    /// Attribue les sessions passées à leurs rendez-vous, et tranche l'état de chacun.
    ///
    /// Une session honore le rendez-vous de sa sorte dont elle est la plus proche, et seulement
    /// si elle en est assez proche. Un entraînement lancé loin de tout n'en honore aucun : c'est
    /// ce qui évite qu'un blanc passé par curiosité trois semaines avant efface celui de J-7.
    private static func settle(
        _ planned: inout [AgendaEvent],
        done: [AgendaDone],
        today: Date,
        calendar: Calendar
    ) {
        var honoured = Set<Int>()

        for session in done {
            let day = calendar.startOfDay(for: session.finishedAt)
            var best: Int?
            var smallest = Int.max

            for index in planned.indices {
                let event = planned[index]
                guard event.examId == session.examId, event.kind == session.kind else { continue }
                guard !honoured.contains(index) else { continue }
                let gap = abs(calendar.dateComponents([.day], from: event.date, to: day).day ?? 0)
                if gap < smallest {
                    smallest = gap
                    best = index
                }
            }

            if let best, smallest <= slack(for: planned[best].kind) { honoured.insert(best) }
        }

        for index in planned.indices {
            let offset = calendar.dateComponents([.day], from: today, to: planned[index].date).day ?? 0
            planned[index].offset = offset
            planned[index].status = honoured.contains(index) ? .done : (offset < 0 ? .missed : .upcoming)
        }
    }

    /// Les rendez-vous d'un jour donné, pour « Au programme » et pour une case du calendrier.
    static func events(
        _ events: [AgendaEvent],
        on day: Date,
        calendar: Calendar = MicaboCalendar.shared
    ) -> [AgendaEvent] {
        let wanted = calendar.startOfDay(for: day)
        return events.filter { $0.date == wanted }
    }
}

/// Ce qu'un rendez-vous mesure.
enum AgendaKind: String, Codable, CaseIterable, Identifiable {
    case mock
    case parcours

    var id: String { rawValue }
}

/// Où en est un rendez-vous. `missed` n'est pas une punition, c'est un fait : le jour est passé
/// et rien n'a été mesuré.
enum AgendaStatus: String, Codable {
    case done
    case missed
    case upcoming
}

/// Un rendez-vous de mesure, à sa date, avec son état.
struct AgendaEvent: Identifiable, Equatable {
    var examId: UUID
    var examName: String
    var kind: AgendaKind
    /// Rang dans sa série, compté depuis l'épreuve. C'est ce qu'une surcharge désigne.
    var slot: Int
    var date: Date
    /// Jours depuis aujourd'hui. Négatif pour un rendez-vous passé.
    var offset: Int
    var questionCount: Int
    var minutes: Int
    var status: AgendaStatus
    /// Vrai quand la date vient d'une surcharge et non de la dérivation.
    var moved: Bool

    var id: String { "\(examId.uuidString)-\(kind.rawValue)-\(slot)" }
}

/// Une date choisie par l'étudiant, qui remplace celle que la dérivation proposait.
struct AgendaOverride: Equatable {
    var examId: UUID
    var kind: AgendaKind
    var slot: Int
    var date: Date
}

/// Une mesure déjà passée, telle qu'elle revient de `mock_sessions`.
struct AgendaDone: Equatable {
    var examId: UUID
    var kind: AgendaKind
    var finishedAt: Date
}
