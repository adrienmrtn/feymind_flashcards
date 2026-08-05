import Foundation
import SwiftData

/// Contenu de démonstration inséré au premier lancement pour que l'application
/// soit immédiatement explorable, même sans clé IA.
enum SampleData {
    private static let seedKey = "feymind.didSeedSampleData"

    static func seedIfNeeded(in context: ModelContext) {
        let defaults = UserDefaults.standard
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
                rawText: photosynthesisCourse.blocks.map(\.plainText).joined(separator: "\n"),
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
                rawText: affineFunctionsCourse.blocks.map(\.plainText).joined(separator: "\n"),
                accentIndex: 0,
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
        readingMinutes: 7,
        blocks: [
            .paragraph(ParagraphBlock(text: "La photosynthèse est la réaction qui permet aux végétaux chlorophylliens de fabriquer de la **matière organique** à partir de matière minérale, en utilisant l'==énergie lumineuse==. C'est la ==porte d'entrée de l'énergie== dans presque toutes les chaînes alimentaires.")),

            .callout(CalloutBlock(
                variant: .memo,
                title: "L'essentiel en une phrase",
                text: "Lumière + CO₂ + eau donnent du glucose et du dioxygène, grâce à la ==chlorophylle== située dans les chloroplastes."
            )),

            .formula(FormulaBlock(
                expression: "6 CO₂ + 6 H₂O + lumière → C₆H₁₂O₆ + 6 O₂",
                caption: "Bilan global de la photosynthèse"
            )),

            .heading(HeadingBlock(level: 2, text: "1. Où se déroule la réaction ?")),

            .paragraph(ParagraphBlock(text: "Tout se joue dans le **chloroplaste**, un organite délimité par une double membrane. Il contient des empilements de sacs aplatis, les *thylakoïdes*, baignés dans un liquide appelé ==stroma==.")),

            .tree(TreeBlock(
                title: "Organisation du chloroplaste",
                root: TreeNode(
                    label: "Chloroplaste",
                    detail: "Organite de 5 à 10 µm",
                    children: [
                        TreeNode(label: "Thylakoïdes", detail: "Membranes empilées en granum", children: [
                            TreeNode(label: "Chlorophylle a et b", detail: "Captent le bleu et le rouge", children: nil),
                            TreeNode(label: "Caroténoïdes", detail: "Pigments accessoires", children: nil)
                        ]),
                        TreeNode(label: "Stroma", detail: "Milieu liquide riche en enzymes", children: [
                            TreeNode(label: "Cycle de Calvin", detail: "Fixation du CO₂", children: nil)
                        ])
                    ]
                )
            )),

            .heading(HeadingBlock(level: 2, text: "2. Les deux phases")),

            .flow(FlowBlock(
                title: "De la lumière au sucre",
                steps: [
                    StepItem(label: "Capture de la lumière", detail: "Les pigments excitent leurs électrons"),
                    StepItem(label: "Photolyse de l'eau", detail: "H₂O se sépare, le O₂ est libéré"),
                    StepItem(label: "Production d'ATP et de NADPH", detail: "Énergie chimique transportable"),
                    StepItem(label: "Cycle de Calvin", detail: "Le CO₂ devient du glucose")
                ]
            )),

            .comparison(ComparisonBlock(
                title: "Phase claire et phase sombre",
                columns: [
                    ComparisonColumn(title: "Phase photochimique", items: [
                        "Se déroule dans les thylakoïdes",
                        "Nécessite directement la lumière",
                        "Produit ATP, NADPH et O₂",
                        "Très rapide, de l'ordre de la milliseconde"
                    ]),
                    ComparisonColumn(title: "Phase biochimique", items: [
                        "Se déroule dans le stroma",
                        "N'a pas besoin de lumière directe",
                        "Consomme ATP et NADPH",
                        "Fixe le CO₂ sur le ribulose"
                    ])
                ]
            )),

            .definition(DefinitionBlock(
                term: "Photolyse de l'eau",
                text: "Rupture de la molécule d'eau sous l'action de la lumière. Elle fournit les électrons nécessaires à la chaîne photosynthétique et libère le dioxygène que nous respirons."
            )),

            .heading(HeadingBlock(level: 2, text: "3. Le cycle de Calvin")),

            .cycle(CycleBlock(
                title: "Trois étapes qui se répètent",
                steps: [
                    StepItem(label: "Fixation", detail: "Le CO₂ se lie au RuBP grâce à la Rubisco"),
                    StepItem(label: "Réduction", detail: "L'ATP et le NADPH forment du G3P"),
                    StepItem(label: "Régénération", detail: "Le RuBP est reconstitué pour recommencer")
                ]
            )),

            .callout(CalloutBlock(
                variant: .warning,
                title: "Piège classique",
                text: "Le cycle de Calvin est souvent appelé « phase sombre », mais il ne se déroule **pas** la nuit : il dépend des produits fabriqués à la lumière."
            )),

            .heading(HeadingBlock(level: 2, text: "4. Les facteurs limitants")),

            .paragraph(ParagraphBlock(text: "L'intensité de la photosynthèse dépend de plusieurs paramètres. Quand l'un d'eux est insuffisant, il devient le ==facteur limitant== et bloque le rendement, même si les autres sont optimaux.")),

            .chart(ChartBlock(
                title: "Rendement relatif selon l'intensité lumineuse",
                caption: "Au-delà d'un certain seuil, la courbe plafonne : c'est la saturation lumineuse.",
                bars: [
                    ChartBar(label: "Obscurité", value: 0, unit: "%"),
                    ChartBar(label: "Faible", value: 35, unit: "%"),
                    ChartBar(label: "Moyenne", value: 78, unit: "%"),
                    ChartBar(label: "Forte", value: 96, unit: "%"),
                    ChartBar(label: "Saturation", value: 100, unit: "%")
                ]
            )),

            .table(TableBlock(
                headers: ["Facteur", "Effet si insuffisant", "Optimum courant"],
                rows: [
                    ["Lumière", "Moins d'ATP produit", "Forte, sans excès"],
                    ["CO₂", "Cycle de Calvin ralenti", "0,1 % environ"],
                    ["Température", "Enzymes moins actives", "25 à 30 °C"],
                    ["Eau", "Fermeture des stomates", "Sol humide"]
                ]
            )),

            .keyPoints(KeyPointsBlock(
                title: "À retenir",
                items: [
                    "La photosynthèse convertit l'énergie lumineuse en énergie chimique.",
                    "La phase photochimique produit ATP, NADPH et dioxygène.",
                    "Le cycle de Calvin fixe le CO₂ pour former du glucose.",
                    "Le rendement est plafonné par le facteur le plus limitant."
                ]
            )),

            .timeline(TimelineBlock(
                title: "Quelques découvertes clés",
                events: [
                    TimelineEvent(date: "1771", label: "Priestley", detail: "Les plantes « restaurent » l'air vicié"),
                    TimelineEvent(date: "1779", label: "Ingenhousz", detail: "La lumière est indispensable"),
                    TimelineEvent(date: "1948", label: "Calvin et Benson", detail: "Le cycle de fixation du carbone est décrit")
                ]
            )),

            .quote(QuoteBlock(
                text: "La feuille est une usine chimique qui fonctionne à l'énergie solaire, sans bruit et sans déchet.",
                author: "Jean-Marie Pelt"
            )),

            .list(ListBlock(ordered: false, items: [
                "Vérifier que vous savez replacer chaque étape dans le chloroplaste.",
                "Savoir écrire le bilan chimique de mémoire.",
                "Être capable d'expliquer un facteur limitant avec un exemple concret."
            ]))
        ]
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
        readingMinutes: 4,
        blocks: [
            .paragraph(ParagraphBlock(text: "Une fonction affine s'écrit toujours sous la forme **f(x) = ax + b**, où a et b sont deux nombres fixés. Le nombre ==a est le coefficient directeur== et ==b l'ordonnée à l'origine==.")),

            .formula(FormulaBlock(expression: "f(x) = ax + b", caption: "Forme canonique d'une fonction affine")),

            .definition(DefinitionBlock(
                term: "Coefficient directeur",
                text: "Il mesure la pente de la droite. Si a est positif la fonction est croissante, s'il est négatif elle est décroissante, et s'il est nul la fonction est constante."
            )),

            .comparison(ComparisonBlock(
                title: "Lire le signe de a",
                columns: [
                    ComparisonColumn(title: "a > 0", items: ["Droite montante", "Fonction croissante", "Exemple : f(x) = 2x + 1"]),
                    ComparisonColumn(title: "a < 0", items: ["Droite descendante", "Fonction décroissante", "Exemple : f(x) = -3x + 4"])
                ]
            )),

            .heading(HeadingBlock(level: 2, text: "Tracer la droite")),

            .flow(FlowBlock(
                title: "Méthode en trois gestes",
                steps: [
                    StepItem(label: "Placer b", detail: "Le point (0 ; b) est l'ordonnée à l'origine"),
                    StepItem(label: "Utiliser a", detail: "Avancer de 1 puis monter de a"),
                    StepItem(label: "Tracer", detail: "Relier les deux points obtenus")
                ]
            )),

            .callout(CalloutBlock(
                variant: .tip,
                title: "Astuce de calcul",
                text: "Pour deux points connus, a = (y₂ - y₁) / (x₂ - x₁). Retenez-le comme la ==variation verticale divisée par la variation horizontale==."
            )),

            .table(TableBlock(
                headers: ["Fonction", "a", "b", "Sens de variation"],
                rows: [
                    ["f(x) = 2x + 3", "2", "3", "Croissante"],
                    ["g(x) = -x + 1", "-1", "1", "Décroissante"],
                    ["h(x) = 5", "0", "5", "Constante"]
                ]
            )),

            .keyPoints(KeyPointsBlock(
                title: "À retenir",
                items: [
                    "La représentation graphique d'une fonction affine est toujours une droite.",
                    "a se lit comme une pente, b comme un point de départ.",
                    "Une fonction linéaire est une fonction affine avec b = 0."
                ]
            ))
        ]
    )

    static let affineFunctionsCards: [GeneratedFlashcard] = [
        GeneratedFlashcard(front: "Quelle est la forme générale d'une fonction affine ?", back: "f(x) = ax + b", hint: nil),
        GeneratedFlashcard(front: "Comment calculer le coefficient directeur avec deux points ?", back: "a = (y₂ - y₁) / (x₂ - x₁)", hint: "Variation verticale sur variation horizontale."),
        GeneratedFlashcard(front: "Que représente b graphiquement ?", back: "L'ordonnée à l'origine, c'est-à-dire l'ordonnée du point d'abscisse 0.", hint: nil),
        GeneratedFlashcard(front: "Quand une fonction affine est-elle décroissante ?", back: "Lorsque son coefficient directeur a est strictement négatif.", hint: nil),
        GeneratedFlashcard(front: "Qu'est-ce qu'une fonction linéaire ?", back: "Une fonction affine dont l'ordonnée à l'origine b vaut 0, donc de la forme f(x) = ax.", hint: nil)
    ]
}
