import Foundation
import SwiftData

/// Contenu de vitrine pour les captures App Store (goldie / argent).
///
/// L'app part vide, et une file vide ne vend rien. Ce catalogue ne s'insère **que**
/// quand une capture le demande : argument `-GoldieScreenshots`, variable
/// `GOLDIE_SCREENSHOTS=1`, ou fichier `/tmp/micabo.goldie.seed` dans le simulateur.
///
/// Les cours ne sont pas marqués `sample` : `SampleContentPurge` ne doit pas les
/// effacer entre l'insertion et le premier écran.
enum ScreenshotSeed {
    static let argument = "-GoldieScreenshots"
    static let environmentKey = "GOLDIE_SCREENSHOTS"
    static let markerPath = "/tmp/micabo.goldie.seed"
    static let didSeedKey = "micabo.goldie.didSeed"

    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains(argument)
            || ProcessInfo.processInfo.environment[environmentKey] == "1"
            || FileManager.default.fileExists(atPath: markerPath)
    }

    /// À appeler une fois le store ouvert, après le purge des anciens exemples.
    static func prepareIfRequested(
        in context: ModelContext,
        defaults: UserDefaults = .standard
    ) {
        guard isRequested else { return }
        openApp(defaults: defaults)
        seed(in: context, defaults: defaults)
    }

    /// Passe le parcours et la porte de compte : goldie relance l'app, il ne
    /// doit pas retomber sur l'accueil.
    static func openApp(defaults: UserDefaults) {
        defaults.set(true, forKey: OnboardingPreferences.Key.completed)
        defaults.set(true, forKey: AccountGate.skippedKey)
        defaults.set(25, forKey: OnboardingPreferences.Key.dailyMinutes)
        defaults.set(SchoolingCountry.fr.rawValue, forKey: OnboardingPreferences.Key.country)
        defaults.set(true, forKey: DiscountOffer.Key.seen)
        defaults.set(true, forKey: "micabo.sheet.didExplainOnce")
    }

    static func seed(in context: ModelContext, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: didSeedKey) else { return }
        defaults.set(true, forKey: didSeedKey)

        let calendar = Calendar.current
        let now = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now

        let svt = Course(
            title: "La photosynthèse",
            subject: "SVT",
            summary: "Une plante ne mange pas. Elle **fabrique** sa matière à partir de l'air, de l'eau et de la lumière.",
            emoji: "🌿",
            accentHex: "2E7D63",
            source: .pdf,
            sourceFileName: "Chapitre 4 — Photosynthèse.pdf",
            sheet: photosynthesisSheet
        )
        svt.viewCount = 128
        svt.adoptCount = 14
        svt.updatedAt = now
        context.insert(svt)

        let maths = Course(
            title: "Les fonctions affines",
            subject: "Maths",
            summary: "Toute droite non verticale est la courbe d'une fonction affine.",
            emoji: "📐",
            accentHex: "3F5F8A",
            source: .photo,
            sourceFileName: "IMG_2041.HEIC",
            sheet: affineSheet
        )
        maths.viewCount = 64
        maths.adoptCount = 7
        maths.updatedAt = yesterday
        context.insert(maths)

        let hist = Course(
            title: "La Révolution de 1789",
            subject: "Histoire",
            summary: "Ce n'est pas un jour : c'est une bascule, de la convocation des États généraux à la Déclaration.",
            emoji: "⚖️",
            accentHex: "9A5B36",
            source: .youtube,
            sourceFileName: "Cours — 1789",
            sheet: revolutionSheet
        )
        hist.viewCount = 41
        hist.adoptCount = 5
        hist.updatedAt = calendar.date(byAdding: .day, value: -2, to: now) ?? now
        context.insert(hist)

        insertCards(svtCards, on: svt, in: context, now: now)
        insertCards(mathsCards, on: maths, in: context, now: now)
        insertCards(histCards, on: hist, in: context, now: now)

        let examDate = calendar.date(byAdding: .day, value: 3, to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(3 * 86_400)
        let exam = Exam(
            name: "Devoir de SVT",
            date: examDate,
            courseIDs: [svt.id],
            intensity: .intense,
            targetScore: 16
        )
        exam.isPlanned = true
        context.insert(exam)

        let laterExam = Exam(
            name: "Contrôle de maths",
            date: calendar.date(byAdding: .day, value: 12, to: calendar.startOfDay(for: now))
                ?? now.addingTimeInterval(12 * 86_400),
            courseIDs: [maths.id],
            intensity: .standard,
            targetScore: 15
        )
        context.insert(laterExam)

        if let first = svt.cards.first {
            writeStreak(on: first, days: 12, calendar: calendar, now: now, in: context)
        }

        try? context.save()
    }

    // MARK: - Cartes

    private struct CardDraft {
        var front: String
        var back: String
        var hint: String? = nil
        var state: CardState
        var intervalDays: Double = 0
        var dueOffsetHours: Double = -1
    }

    private static func insertCards(
        _ drafts: [CardDraft],
        on course: Course,
        in context: ModelContext,
        now: Date
    ) {
        for (index, draft) in drafts.enumerated() {
            let card = Flashcard(
                front: draft.front,
                back: draft.back,
                hint: draft.hint,
                position: index,
                course: course
            )
            card.state = draft.state
            card.intervalDays = draft.intervalDays
            card.dueDate = now.addingTimeInterval(draft.dueOffsetHours * 3600)
            if draft.state != .new {
                card.repetitions = draft.state == .review ? 4 : 1
                card.lastReviewedAt = now.addingTimeInterval(-86_400)
            }
            context.insert(card)
        }
    }

    private static func writeStreak(
        on card: Flashcard,
        days: Int,
        calendar: Calendar,
        now: Date,
        in context: ModelContext
    ) {
        let start = calendar.startOfDay(for: now)
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: start) else { continue }
            let log = ReviewLog(
                reviewedAt: day.addingTimeInterval(10 * 3600),
                rating: .good,
                stateBefore: .review,
                previousIntervalDays: 2,
                newIntervalDays: 4,
                easeAfter: 2.5
            )
            log.card = card
            context.insert(log)
        }
    }

    private static let svtCards: [CardDraft] = [
        .init(
            front: "D'où vient le dioxygène que nous respirons ?",
            back: "C'est un déchet de la photolyse de l'eau, pendant la phase photochimique.",
            hint: "Pense à ce que la chlorophylle arrache à la molécule d'eau.",
            state: .review,
            intervalDays: 6
        ),
        .init(
            front: "Où se déroule la phase photochimique ?",
            back: "Dans les membranes des thylakoïdes, à l'intérieur du chloroplaste.",
            state: .review,
            intervalDays: 4
        ),
        .init(
            front: "Que fixe la Rubisco ?",
            back: "Une molécule de CO₂ sur le ribulose bisphosphate, au premier temps du cycle de Calvin.",
            state: .review,
            intervalDays: 3
        ),
        .init(
            front: "Écris l'équation-bilan de la photosynthèse.",
            back: "6 CO₂ + 6 H₂O + lumière → C₆H₁₂O₆ + 6 O₂",
            state: .learning
        ),
        .init(
            front: "Qu'est-ce qu'un thylakoïde ?",
            back: "Un sac membranaire empilé dans le chloroplaste. Sa membrane porte les pigments.",
            state: .new
        ),
        .init(
            front: "Pourquoi « phase sombre » est un mauvais nom ?",
            back: "La phase biochimique ne consomme pas de lumière, mais elle s'arrête dès que l'ATP et le NADPH manquent.",
            state: .review,
            intervalDays: 8,
            dueOffsetHours: 72
        ),
        .init(
            front: "Qu'est-ce que le stroma ?",
            back: "Le liquide qui baigne les thylakoïdes. C'est là que le carbone de l'air est fixé.",
            state: .review,
            intervalDays: 2,
            dueOffsetHours: 48
        ),
    ]

    private static let mathsCards: [CardDraft] = [
        .init(
            front: "Que représente b dans f(x) = ax + b ?",
            back: "L'ordonnée à l'origine : la valeur de f(0), là où la droite coupe l'axe vertical.",
            state: .review,
            intervalDays: 5
        ),
        .init(
            front: "Comment calcule-t-on a à partir de deux points ?",
            back: "a = (y₂ − y₁) / (x₂ − x₁)",
            state: .learning
        ),
        .init(
            front: "Que dit le signe de a ?",
            back: "a > 0 : la fonction croît. a < 0 : elle décroît. a = 0 : elle est constante.",
            state: .learning
        ),
        .init(
            front: "Comment place-t-on le point (0 ; b) ?",
            back: "Sur l'axe vertical : c'est là que la droite coupe l'axe des ordonnées.",
            state: .new
        ),
    ]

    private static let histCards: [CardDraft] = [
        .init(
            front: "Quelle assemblée ouvre 1789 ?",
            back: "Les États généraux, convoqués à Versailles au printemps.",
            state: .review,
            intervalDays: 7
        ),
        .init(
            front: "Que proclame la nuit du 4 août ?",
            back: "L'abolition des privilèges.",
            state: .learning
        ),
        .init(
            front: "Qui se proclame Assemblée nationale ?",
            back: "Le tiers état, à Versailles.",
            state: .new
        ),
    ]

    // MARK: - Fiches

    private static let photosynthesisSheet = CourseSheet(blocks: [
        .paragraph(text: "Une plante ne mange pas. Elle **fabrique** sa propre matière organique à partir de trois choses gratuites : le dioxyde de carbone de l'air, l'eau puisée par les racines et la lumière du Soleil."),
        .formula(
            latex: "6\\,CO_2 + 6\\,H_2O + \\text{lumière} \\rightarrow C_6H_{12}O_6 + 6\\,O_2",
            caption: "Six molécules de CO₂ et six d'eau donnent un glucose et six dioxygènes."
        ),
        .heading(level: 1, text: "Où tout se passe"),
        .paragraph(text: "Tout se déroule dans le **chloroplaste**. Il est cloisonné : chacune des deux phases a son compartiment, et les deux ne se mélangent jamais."),
        .definition(
            term: "Thylakoïde",
            text: "Sac membranaire empilé à l'intérieur du chloroplaste. Sa membrane porte les pigments qui captent la lumière."
        ),
        .definition(
            term: "Stroma",
            text: "Le liquide qui baigne les thylakoïdes. C'est là que le carbone de l'air est fixé."
        ),
        .callout(
            tone: .essentiel,
            text: "La lumière casse l'eau et libère l'oxygène. L'énergie récupérée sert à ==coller le carbone de l'air sur du sucre==."
        ),
    ])

    private static let affineSheet = CourseSheet(blocks: [
        .paragraph(text: "Une fonction affine est la plus simple des fonctions qui varient. Sa représentation graphique est **toujours une droite**."),
        .formula(latex: "f(x) = ax + b", caption: "a est le coefficient directeur, b l'ordonnée à l'origine."),
        .heading(level: 1, text: "Lire les deux coefficients"),
        .paragraph(text: "Le nombre **b** se lit sans calcul : c'est f(0). Le nombre **a** mesure la pente : ==avancer de 1 vers la droite fait monter de a==."),
    ])

    private static let revolutionSheet = CourseSheet(blocks: [
        .paragraph(text: "1789 n'est pas un jour. C'est une **bascule** : des États généraux à la Déclaration, l'ordre ancien se défait en quelques mois."),
        .heading(level: 1, text: "Du printemps à l'été"),
        .steps(title: "Les trois seuils", items: [
            "Les États généraux se réunissent à Versailles.",
            "Le tiers se proclame Assemblée nationale.",
            "La nuit du 4 août abolit les privilèges."
        ]),
    ])
}
