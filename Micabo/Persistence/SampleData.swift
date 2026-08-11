import Foundation
import SwiftData

/// Contenu de démonstration inséré au premier lancement pour que l'application
/// soit immédiatement explorable, même sans clé IA.
enum SampleData {
    static let seedKey = "micabo.didSeedSampleData"

    static func seedIfNeeded(in context: ModelContext) {
        let defaults = UserDefaults.standard
        migrateLegacySeedFlag(in: defaults)
        guard !defaults.bool(forKey: seedKey) else { return }

        let existing = (try? context.fetchCount(FetchDescriptor<Course>())) ?? 0
        guard existing == 0 else {
            defaults.set(true, forKey: seedKey)
            return
        }

        do {
            let photosynthesis = try CourseRepository.save(
                photosynthesisCourse,
                source: .sample,
                rawText: photosynthesisCourse.contextText,
                accentIndex: 1,
                in: context
            )
            photosynthesis.createdAt = Date().addingTimeInterval(-3 * 86_400)
            photosynthesis.updatedAt = Date().addingTimeInterval(-3 * 86_400)
            let biologyCards = try CourseRepository.addFlashcards(photosynthesisCards, to: photosynthesis, in: context)
            schedule(biologyCards, pattern: [.dueNow, .dueNow, .dueNow, .dueNow, .learned(3), .learned(10), .dueNow, .learned(21)])

            let affine = try CourseRepository.save(
                affineFunctionsCourse,
                source: .sample,
                rawText: affineFunctionsCourse.contextText,
                accentIndex: 4,
                in: context
            )
            affine.createdAt = Date().addingTimeInterval(-86_400)
            affine.updatedAt = Date().addingTimeInterval(-86_400)
            let mathCards = try CourseRepository.addFlashcards(affineFunctionsCards, to: affine, in: context)
            schedule(mathCards, pattern: [.dueNow, .dueNow, .learned(2), .dueNow, .learned(6)])

            try context.save()
            defaults.set(true, forKey: seedKey)
        } catch {
            // Le contenu de démonstration ne doit jamais empêcher le lancement.
            defaults.set(true, forKey: seedKey)
        }
    }

    private enum SchedulePattern {
        case dueNow
        case learned(Double)
    }

    private static func schedule(_ cards: [Flashcard], pattern: [SchedulePattern]) {
        for (index, card) in cards.enumerated() {
            let entry = pattern.indices.contains(index) ? pattern[index] : .dueNow
            switch entry {
            case .dueNow:
                card.state = .new
                card.dueDate = Date().addingTimeInterval(-60)
            case .learned(let interval):
                card.state = .review
                card.intervalDays = interval
                card.repetitions = max(1, Int(interval / 3))
                card.easeFactor = 2.5
                card.lastReviewedAt = Date().addingTimeInterval(-interval * 43_200)
                card.dueDate = Date().addingTimeInterval(interval * 43_200)
            }
        }
    }

    // MARK: - Cours de biologie

    static let photosynthesisCourse = GeneratedCourse(
        title: "La photosynthèse",
        subject: "SVT",
        emoji: "🌿",
        summary: "Comment les végétaux transforment la lumière en matière organique, des pigments chlorophylliens jusqu'au cycle de Calvin.",
        contextText: """
        La photosynthèse permet aux végétaux chlorophylliens de fabriquer de la matière organique à partir de matière minérale, en utilisant l'énergie lumineuse.
        Bilan global : 6 CO₂ + 6 H₂O + lumière donnent C₆H₁₂O₆ + 6 O₂.
        Tout se déroule dans le chloroplaste, qui contient les thylakoïdes empilés et le stroma.
        La phase photochimique se déroule dans les thylakoïdes, dépend de la lumière et produit ATP, NADPH et dioxygène.
        La phase biochimique se déroule dans le stroma, consomme ATP et NADPH et fixe le CO₂ sur le ribulose.
        La photolyse de l'eau est la rupture de la molécule d'eau sous l'action de la lumière : elle fournit les électrons et libère le dioxygène.
        Le cycle de Calvin comporte trois étapes : fixation du CO₂ par la Rubisco, réduction en G3P, régénération du RuBP.
        Le cycle de Calvin est parfois appelé phase sombre, mais il dépend des produits fabriqués à la lumière.
        Le rendement est plafonné par le facteur limitant : lumière, CO₂, température ou eau.
        Les pigments qui captent la lumière sont la chlorophylle a et b, épaulées par les caroténoïdes.
        """
    )

    static let photosynthesisCards: [GeneratedFlashcard] = [
        GeneratedFlashcard(front: "Quel est le bilan chimique de la photosynthèse ?", back: "6 CO₂ + 6 H₂O + lumière → C₆H₁₂O₆ + 6 O₂", hint: "Pensez aux six molécules de départ."),
        GeneratedFlashcard(front: "Où se déroule la phase photochimique ?", back: "Dans la membrane des thylakoïdes du chloroplaste.", hint: nil),
        GeneratedFlashcard(front: "Que produit la photolyse de l'eau ?", back: "Des électrons, des protons H⁺ et du dioxygène.", hint: nil),
        GeneratedFlashcard(front: "Quelles sont les trois étapes du cycle de Calvin ?", back: "Fixation du CO₂, réduction en G3P, régénération du RuBP.", hint: nil),
        GeneratedFlashcard(front: "Quelle enzyme fixe le CO₂ ?", back: "La Rubisco, l'enzyme la plus abondante de la biosphère.", hint: nil),
        GeneratedFlashcard(front: "Qu'est-ce qu'un facteur limitant ?", back: "Le paramètre insuffisant qui bloque le rendement de la réaction, même si les autres sont optimaux.", hint: nil),
        GeneratedFlashcard(front: "Pourquoi parler de « phase sombre » est trompeur ?", back: "Le cycle de Calvin ne nécessite pas de lumière directe, mais il dépend de l'ATP et du NADPH produits à la lumière.", hint: nil),
        GeneratedFlashcard(front: "Quels pigments captent la lumière ?", back: "La chlorophylle a et b, épaulées par les caroténoïdes.", hint: nil)
    ]

    // MARK: - Cours de mathématiques

    static let affineFunctionsCourse = GeneratedCourse(
        title: "Les fonctions affines",
        subject: "Mathématiques",
        emoji: "📐",
        summary: "Reconnaître, tracer et interpréter une fonction de la forme f(x) = ax + b.",
        contextText: """
        Une fonction affine s'écrit f(x) = ax + b, où a est le coefficient directeur et b l'ordonnée à l'origine.
        Le coefficient directeur mesure la pente de la droite : positif la fonction croît, négatif elle décroît, nul elle est constante.
        Pour deux points connus, a = (y₂ - y₁) / (x₂ - x₁), soit la variation verticale divisée par la variation horizontale.
        Pour tracer la droite : placer le point (0 ; b), avancer de 1 puis monter de a, relier les deux points.
        La représentation graphique d'une fonction affine est toujours une droite.
        Une fonction linéaire est une fonction affine dont l'ordonnée à l'origine b vaut 0.
        """
    )

    static let affineFunctionsCards: [GeneratedFlashcard] = [
        GeneratedFlashcard(front: "Quelle est la forme générale d'une fonction affine ?", back: "f(x) = ax + b", hint: nil),
        GeneratedFlashcard(front: "Comment calculer le coefficient directeur avec deux points ?", back: "a = (y₂ - y₁) / (x₂ - x₁)", hint: "Variation verticale sur variation horizontale."),
        GeneratedFlashcard(front: "Que représente b graphiquement ?", back: "L'ordonnée à l'origine, c'est-à-dire l'ordonnée du point d'abscisse 0.", hint: nil),
        GeneratedFlashcard(front: "Quand une fonction affine est-elle décroissante ?", back: "Lorsque son coefficient directeur a est strictement négatif.", hint: nil),
        GeneratedFlashcard(front: "Qu'est-ce qu'une fonction linéaire ?", back: "Une fonction affine dont l'ordonnée à l'origine b vaut 0, donc de la forme f(x) = ax.", hint: nil)
    ]

    private static func migrateLegacySeedFlag(in defaults: UserDefaults) {
        let legacy = "feymind.didSeedSampleData"
        guard !defaults.bool(forKey: seedKey), defaults.bool(forKey: legacy) else { return }
        defaults.set(true, forKey: seedKey)
        defaults.removeObject(forKey: legacy)
    }
}
