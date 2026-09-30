import Foundation
import SwiftData

#if DEBUG

// MARK: - Les cours de debug

/// **Six cours fichés comme la démonstration du parcours, et un compte qui a l'air vivant.**
///
/// Pour les constructions de développement seulement. Travailler sur l'onglet Réviser, le
/// profil ou le classement demande des semaines de révisions ; ce catalogue les pose d'un
/// coup : six cours riches (schémas, graphes, tableaux, encadrés), une série de jours, des
/// cartes dues, des cartes maîtrisées, trois épreuves à venir, et un cercle d'amis.
///
/// **Rien ne quitte le téléphone.** Chaque cours porte un marqueur (`sourceFileName`), et
/// `CloudSync` écarte tout ce qui s'y rattache : cours, chapitres, cartes, révisions,
/// épreuves. Les amis et le classement sont posés dans `SocialService`, sans un appel au
/// serveur.
///
/// **La fiche se lit avec le rendu riche de la démonstration** (`demoChapter(for:)`) : la
/// fiche enregistrée n'est que sa version texte.
enum DebugCourseCatalog {
    /// Le préfixe du marqueur. Suivi de l'identifiant du cours dans le catalogue.
    static let marker = "debug:"
    static let seededKey = "micabo.debug.didSeedCourses"
    static let languageKey = "micabo.debug.courseLanguage"

    /// La langue des cours de debug, choisie dans les réglages. La langue de l'app par défaut.
    static var language: UiLocale {
        get {
            UserDefaults.standard.string(forKey: languageKey).flatMap(UiLocale.init(rawValue:)) ?? .resolved()
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: languageKey) }
    }

    static func courses(locale: UiLocale) -> [OnboardingDemoCourse] {
        // Les traductions arrivent à part : d'ici là, le français tient lieu de tout.
        switch locale {
        default: french
        }
    }

    // MARK: Reconnaître un cours de debug

    static func isDebug(_ course: Course?) -> Bool {
        course?.sourceFileName?.hasPrefix(marker) == true
    }

    static func isDebug(courseID: UUID, in ids: Set<UUID>) -> Bool {
        ids.contains(courseID)
    }

    /// Les identifiants des cours de debug présents, pour filtrer ce qui s'y rattache.
    static func courseIDs(in context: ModelContext) -> Set<UUID> {
        Set(CourseRepository.allCourses(in: context).filter { isDebug($0) }.map(\.id))
    }

    /// **Le chapitre riche**, quand le chapitre appartient à un cours de debug : c'est lui que
    /// la page du chapitre dessine à la place des blocs texte.
    static func demoChapter(for chapter: Chapter) -> DemoChapter? {
        guard let course = chapter.course, isDebug(course),
              let id = course.sourceFileName?.dropFirst(marker.count) else { return nil }
        let locale = course.language.flatMap { UiLocale(rawValue: $0.rawValue) } ?? language
        guard let demo = courses(locale: locale).first(where: { $0.id == id }),
              demo.chapters.indices.contains(chapter.position) else { return nil }
        return demo.chapters[chapter.position]
    }

    // MARK: Poser, retirer

    /// Au premier lancement d'une construction de debug : les cours et l'activité, une fois.
    @MainActor
    static func seedIfNeeded(in context: ModelContext, social: SocialService, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: seededKey) else {
            // Les amis ne vivent qu'en mémoire : on les repose à chaque lancement.
            if !courseIDs(in: context).isEmpty { DebugSocial.install(in: social, context: context) }
            return
        }
        defaults.set(true, forKey: seededKey)
        install(locale: language, in: context, social: social)
    }

    /// Retire les cours de debug (et ce qui s'y rattache), puis les repose dans `locale`.
    @MainActor
    static func install(locale: UiLocale, in context: ModelContext, social: SocialService) {
        removeAll(in: context)
        language = locale

        var generator = SeededGenerator(seed: 0x6D69_6361_626F)
        let contentLanguage = ContentLanguage(rawValue: locale.rawValue) ?? .fr
        var installed: [(demo: OnboardingDemoCourse, course: Course)] = []

        for (rank, demo) in courses(locale: locale).enumerated() {
            guard let course = try? insert(demo, language: contentLanguage, in: context) else { continue }
            // Le dernier cours vient d'arriver : ses cartes sont neuves, sa date est d'hier.
            let isFresh = rank == courses(locale: locale).count - 1
            course.createdAt = Date().addingTimeInterval(isFresh ? -86_400 : -Double(40 - rank * 5) * 86_400)
            DebugActivity.simulate(course, isFresh: isFresh, using: &generator, in: context)
            installed.append((demo, course))
        }

        DebugActivity.addExams(for: installed.map(\.course), locale: locale, in: context)
        try? context.save()

        ReviewStreakStore.invalidate()
        CourseLedger.noteChange()
        DebugSocial.install(in: social, context: context)
    }

    @MainActor
    static func removeAll(in context: ModelContext) {
        let ids = courseIDs(in: context)
        guard !ids.isEmpty else { return }
        let exams = (try? context.fetch(FetchDescriptor<Exam>())) ?? []
        for exam in exams where !exam.courseIDs.isEmpty && exam.courseIDs.allSatisfy(ids.contains) {
            context.delete(exam)
        }
        // `context.delete` et pas `CourseRepository.delete` : ces cours n'ont jamais été
        // envoyés, il n'y a pas de pierre tombale à poser.
        for course in CourseRepository.allCourses(in: context) where ids.contains(course.id) {
            context.delete(course)
        }
        try? context.save()
        ReviewStreakStore.invalidate()
        CourseLedger.noteChange()
    }

    /// Le cours, comme `OnboardingDemoCatalog.install`, sans l'événement d'import : un cours
    /// de debug ne doit pas compter dans les statistiques.
    @MainActor
    private static func insert(_ demo: OnboardingDemoCourse, language: ContentLanguage, in context: ModelContext) throws -> Course {
        let generated = GeneratedCourse(
            title: demo.title,
            subject: demo.subject,
            emoji: demo.emoji,
            summary: demo.summary,
            sheet: demo.sheet,
            contextText: demo.sheet.plainText()
        )
        let course = try CourseRepository.save(
            generated,
            source: .sample,
            rawText: "",
            fileName: marker + demo.id,
            accentIndex: demo.accentIndex,
            visibility: .private,
            in: context
        )
        course.subject = demo.subject
        course.title = demo.title
        course.emoji = demo.emoji
        course.language = language
        course.sourceFileName = marker + demo.id

        ChapterBuilder.migrate(course, in: context)
        _ = try CourseRepository.addFlashcards(demo.cards.map(\.generated), to: course, in: context)
        return course
    }
}

// MARK: - L'activité simulée

/// **Six semaines de révisions**, tirées d'un générateur à graine fixe : le même compte à
/// chaque réinstallation, donc des captures d'écran qui se refont à l'identique.
enum DebugActivity {
    /// Jours de suite révisés, aujourd'hui compris.
    static let streakDays = 23

    @MainActor
    static func simulate(_ course: Course, isFresh: Bool, using generator: inout SeededGenerator, in context: ModelContext) {
        guard !isFresh else { return }
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        for (index, card) in course.orderedCards.enumerated() {
            // Un profil de carte par rang, pour que chaque cours ait de tout : des cartes
            // maîtrisées, des dues, des en cours d'apprentissage, des neuves, une rétive.
            let profile = index % 8
            switch profile {
            case 0, 1, 2:
                // Maîtrisée : intervalle de trois semaines et plus, prochaine date lointaine.
                let interval = Double(Int.random(in: 22...55, using: &generator))
                let last = now.addingTimeInterval(-Double(Int.random(in: 1...12, using: &generator)) * 86_400)
                schedule(card, state: .review, interval: interval, repetitions: Int.random(in: 5...8, using: &generator),
                         last: last, due: last.addingTimeInterval(interval * 86_400))
                addHistory(to: card, count: Int.random(in: 5...8, using: &generator), endingAt: last, weak: false, using: &generator, in: context)
            case 3, 4:
                // Due aujourd'hui : c'est ce que l'onglet Réviser met en tête.
                let interval = Double(Int.random(in: 3...14, using: &generator))
                let due = startOfToday.addingTimeInterval(Double(Int.random(in: 1...8, using: &generator)) * 3_600)
                let last = due.addingTimeInterval(-interval * 86_400)
                schedule(card, state: .review, interval: interval, repetitions: Int.random(in: 2...4, using: &generator),
                         last: last, due: min(due, now.addingTimeInterval(-60)))
                addHistory(to: card, count: Int.random(in: 2...4, using: &generator), endingAt: last, weak: false, using: &generator, in: context)
            case 5:
                // En apprentissage, ratée hier.
                let last = now.addingTimeInterval(-86_400)
                schedule(card, state: .learning, interval: 0, repetitions: 1, last: last, due: now.addingTimeInterval(-600))
                card.stepIndex = 1
                addHistory(to: card, count: 2, endingAt: last, weak: true, using: &generator, in: context)
            case 6 where index < 8:
                // La rétive : souvent ratée, elle remonte dans « tes points faibles ».
                let last = now.addingTimeInterval(-2 * 86_400)
                schedule(card, state: .relearning, interval: 1, repetitions: 6, last: last, due: now.addingTimeInterval(-3_600))
                card.lapses = 5
                card.easeFactor = 1.4
                addHistory(to: card, count: 7, endingAt: last, weak: true, using: &generator, in: context)
            default:
                // Neuve : jamais vue.
                break
            }
        }
        addDailyStreak(for: course, using: &generator, in: context)
    }

    private static func schedule(_ card: Flashcard, state: CardState, interval: Double, repetitions: Int, last: Date, due: Date) {
        card.state = state
        card.intervalDays = interval
        card.repetitions = repetitions
        card.lastReviewedAt = last
        card.dueDate = due
        card.easeFactor = 2.3 + Double(repetitions % 4) * 0.1
        card.updatedAt = last
    }

    /// L'historique d'une carte : des passages espacés, de plus en plus loin, jusqu'au dernier.
    @MainActor
    private static func addHistory(to card: Flashcard, count: Int, endingAt last: Date, weak: Bool,
                                   using generator: inout SeededGenerator, in context: ModelContext) {
        var date = last
        var interval = max(card.intervalDays, 1)
        for step in 0..<count {
            let rating: ReviewRating = weak
                ? (step % 2 == 0 ? .again : .hard)
                : (Int.random(in: 0..<10, using: &generator) == 0 ? .hard : .good)
            let previous = max(interval / 2.2, 0)
            let log = ReviewLog(
                reviewedAt: date,
                rating: rating,
                stateBefore: step == count - 1 ? .new : .review,
                previousIntervalDays: previous,
                newIntervalDays: interval,
                easeAfter: card.easeFactor
            )
            context.insert(log)
            log.card = card
            date = date.addingTimeInterval(-max(previous, 1) * 86_400)
            interval = previous
        }
    }

    /// **La série** : chaque jour des trois dernières semaines, quelques passages sur les
    /// cartes déjà vues, pour que le profil montre des barres pleines et une flamme vivante.
    @MainActor
    private static func addDailyStreak(for course: Course, using generator: inout SeededGenerator, in context: ModelContext) {
        let seen = course.orderedCards.filter { $0.state != .new }
        guard !seen.isEmpty else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let now = Date()

        for dayOffset in 0..<(DebugActivity.streakDays + 14) {
            // Au-delà de la série, un jour sur deux : une série plus ancienne, cassée.
            if dayOffset == DebugActivity.streakDays { continue }
            if dayOffset > DebugActivity.streakDays, Int.random(in: 0..<2, using: &generator) == 0 { continue }
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let passes = Int.random(in: 2...6, using: &generator)
            for _ in 0..<passes {
                let card = seen[Int.random(in: 0..<seen.count, using: &generator)]
                var time = day.addingTimeInterval(Double(Int.random(in: 8 * 60...21 * 60, using: &generator)) * 60)
                if time > now { time = now.addingTimeInterval(-Double(Int.random(in: 5...90, using: &generator)) * 60) }
                let good = Int.random(in: 0..<6, using: &generator) != 0
                let log = ReviewLog(
                    reviewedAt: time,
                    rating: good ? .good : .again,
                    stateBefore: .review,
                    previousIntervalDays: max(card.intervalDays / 2, 1),
                    newIntervalDays: max(card.intervalDays, 1),
                    easeAfter: card.easeFactor
                )
                context.insert(log)
                log.card = card
            }
        }
    }

    // MARK: Les épreuves

    /// Trois épreuves à venir, sur les cours qui ont le plus de sens pour elles.
    @MainActor
    static func addExams(for courses: [Course], locale: UiLocale, in context: ModelContext) {
        guard courses.count >= 5 else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let names = examNames(locale)
        let plans: [(name: String, days: Int, courses: [Course], kind: ExamKind, target: Int)] = [
            (names[0], 4, [courses[2]], .quiz, 15),
            (names[1], 11, [courses[1], courses[5 < courses.count ? 5 : 1]], .midterm, 14),
            (names[2], 27, [courses[0], courses[3]], .final, 16),
        ]
        for plan in plans {
            guard let date = calendar.date(byAdding: .day, value: plan.days, to: today) else { continue }
            let exam = Exam(
                name: plan.name,
                date: date,
                courseIDs: plan.courses.map(\.id),
                targetScore: plan.target,
                kind: plan.kind,
                startingPoint: .seen
            )
            // Marquée planifiée sans passer par `ExamRepository.plan` : le plan réécrirait les
            // échéances des cartes, et effacerait la journée qu'on vient de poser.
            exam.isPlanned = true
            exam.plannedAt = Date().addingTimeInterval(-3 * 86_400)
            context.insert(exam)
        }
    }

    private static func examNames(_ locale: UiLocale) -> [String] {
        switch locale {
        case .fr: ["Contrôle de probabilités", "Partiel de biologie", "Bac blanc d'histoire-éco"]
        case .en: ["Probability quiz", "Biology midterm", "History & economics mock finals"]
        case .de: ["Stochastik-Test", "Biologie-Klausur", "Probeabitur Geschichte & Wirtschaft"]
        case .es: ["Control de probabilidad", "Parcial de biología", "Simulacro de historia y economía"]
        case .tr: ["Olasılık yazılısı", "Biyoloji ara sınavı", "Tarih ve ekonomi deneme sınavı"]
        }
    }
}

// MARK: - Le cercle d'amis

/// Des amis et un classement de la semaine, posés dans `SocialService` sans serveur.
enum DebugSocial {
    private static let people: [(username: String, school: String, passes: Int)] = [
        ("lea.m", "Lycée Henri-IV", 412),
        ("yanis_42", "Lycée Thiers", 287),
        ("camille.b", "Lycée du Parc", 198),
        ("theo.r", "Lycée Montaigne", 96),
        ("ines", "Lycée Pasteur", 41),
    ]

    @MainActor
    static func install(in social: SocialService, context: ModelContext) {
        let friends = people.prefix(4).enumerated().map { index, person in
            SocialService.Person(
                id: uuid(index),
                username: person.username,
                institutionName: person.school,
                relation: .friends
            )
        }
        let incoming = [
            SocialService.Person(id: uuid(4), username: people[4].username, institutionName: people[4].school, relation: .awaitingMe),
        ]

        // Soi-même : les passages depuis lundi, comptés sur les vraies révisions posées.
        let calendar = Calendar(identifier: .iso8601)
        let monday = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let logs = (try? context.fetch(FetchDescriptor<ReviewLog>(predicate: #Predicate { $0.reviewedAt >= monday }))) ?? []
        var rows = people.prefix(4).enumerated().map { index, person in
            WeekReviewRanking.Row(id: uuid(index), username: person.username, passes: person.passes, isMe: false)
        }
        rows.append(WeekReviewRanking.Row(id: uuid(99), username: "moi.debug", passes: logs.count, isMe: true))
        rows.sort { $0.passes > $1.passes }

        social.debugInstall(username: "moi.debug", friends: friends, incoming: incoming, ranking: rows)
    }

    private static func uuid(_ index: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", index + 1)) ?? UUID()
    }
}

// MARK: - L'examen blanc corrigé

/// **Une copie corrigée**, pour voir l'écran de correction sans passer une épreuve : les
/// examens blancs vivent sur le serveur, et ce compte-là n'y écrit rien.
enum DebugMock {
    @MainActor
    static func gradedSession(in context: ModelContext) -> MockSessionRecord? {
        let demos = DebugCourseCatalog.courses(locale: DebugCourseCatalog.language)
        let cards = demos.flatMap(\.cards)
        let choices = cards.filter { $0.kind == .choice && $0.choices.count >= 2 }.prefix(6)
        let cloze = cards.filter { $0.kind == .cloze }.prefix(3)
        guard !choices.isEmpty else { return nil }

        var questions: [MockQuestion] = []
        var answers: [MockAnswer] = []
        var grades: [MockGrade] = []

        for (index, card) in choices.enumerated() {
            let id = "q\(index)"
            questions.append(.choice(id: id, prompt: card.front, choices: card.choices, answerIndex: card.answerIndex, why: card.back))
            // Une erreur sur trois : la copie a de quoi être commentée.
            let right = index % 3 != 2
            let picked = right ? card.answerIndex : (card.answerIndex + 1) % card.choices.count
            answers.append(MockAnswer(id: id, choiceIndex: picked))
            grades.append(MockGrade(id: id, score: right ? 100 : 0))
        }
        for (offset, card) in cloze.enumerated() {
            let id = "g\(offset)"
            questions.append(.gap(id: id, prompt: card.front, answer: card.back, accepts: [card.back], why: card.back))
            let right = offset != 1
            answers.append(MockAnswer(id: id, text: right ? card.back : "?"))
            grades.append(MockGrade(id: id, score: right ? 100 : 0))
        }

        let texts = debriefTexts(DebugCourseCatalog.language)
        let started = Date().addingTimeInterval(-2 * 86_400)
        return MockSessionRecord(
            id: UUID(),
            user_id: UUID(),
            exam_id: nil,
            kind: "mock",
            planned_for: nil,
            minutes: 25,
            question_count: questions.count,
            correct_count: grades.filter { $0.score == 100 }.count,
            questions: questions,
            answers: answers,
            grades: grades,
            debrief: MockDebrief(headline: texts[0], strengths: [texts[1], texts[2]], gaps: [texts[3]], advice: texts[4]),
            with_audio: false,
            started_at: started,
            finished_at: started.addingTimeInterval(24 * 60)
        )
    }

    private static func debriefTexts(_ locale: UiLocale) -> [String] {
        switch locale {
        case .fr: ["Une bonne copie, avec deux points à reprendre.", "Les définitions sont sûres.", "Le raisonnement est bien mené.", "Les calculs de probabilités conditionnelles.", "Refais les cartes ratées demain, puis un blanc dans une semaine."]
        case .en: ["A solid paper, with two points to revisit.", "Definitions are secure.", "Reasoning is well structured.", "Conditional probability calculations.", "Redo the missed cards tomorrow, then another mock in a week."]
        case .de: ["Eine gute Arbeit mit zwei Punkten zum Wiederholen.", "Die Definitionen sitzen.", "Die Argumentation ist sauber.", "Bedingte Wahrscheinlichkeiten.", "Wiederhole morgen die verpassten Karten, dann in einer Woche ein neuer Test."]
        case .es: ["Un buen examen, con dos puntos que repasar.", "Las definiciones son sólidas.", "El razonamiento está bien llevado.", "Los cálculos de probabilidad condicionada.", "Repite mañana las tarjetas falladas y haz otro simulacro en una semana."]
        case .tr: ["İyi bir kağıt, gözden geçirilecek iki nokta var.", "Tanımlar sağlam.", "Akıl yürütme düzenli.", "Koşullu olasılık hesapları.", "Yarın kaçırdığın kartları tekrar et, bir hafta sonra yeni bir deneme yap."]
        }
    }
}

// MARK: - Un générateur reproductible

/// SplitMix64 : quelques lignes, et la même suite à chaque installation.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

#endif
