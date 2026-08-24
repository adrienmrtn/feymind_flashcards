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
        sheet: SampleData.photosynthesisSheet,
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

    /// La fiche du cours de démonstration.
    ///
    /// Elle est écrite à la main, et pas générée au premier lancement : la première fiche
    /// qu'on voit dans Micabo doit montrer ce que la mise en page sait faire, sans dépendre
    /// d'une clé d'API ni d'une connexion. Elle sert donc aussi de référence à ce qu'une
    /// bonne fiche est censée être, du dosage du surlignage à la longueur des paragraphes.
    static let photosynthesisSheet = CourseSheet(blocks: [
        .paragraph(text: "Une plante ne mange pas. Elle **fabrique** sa propre matière organique à partir de trois choses gratuites : le dioxyde de carbone de l'air, l'eau puisée par les racines et la lumière du Soleil. C'est par cette réaction que presque toute la matière vivante de la planète entre dans les chaînes alimentaires."),

        .formula(
            latex: "6\\,CO_2 + 6\\,H_2O + \\text{lumière} \\rightarrow C_6H_{12}O_6 + 6\\,O_2",
            caption: "Six molécules de dioxyde de carbone et six d'eau donnent un glucose et six dioxygènes."
        ),

        .heading(level: 1, text: "Où tout se passe"),

        .paragraph(text: "Tout se déroule dans le **chloroplaste**, un organite que les cellules animales n'ont pas. Il est cloisonné, et ce cloisonnement n'est pas un détail d'anatomie : chacune des deux phases de la réaction a son compartiment, ses réactifs et ses produits, et les deux ne se mélangent jamais."),

        .definition(
            term: "Thylakoïde",
            text: "Sac membranaire empilé à l'intérieur du chloroplaste. Sa membrane porte les pigments qui captent la lumière."
        ),

        .definition(
            term: "Stroma",
            text: "Le liquide qui baigne les thylakoïdes. C'est là que le carbone de l'air est fixé sur des molécules organiques."
        ),

        .table(SheetTable(
            title: "Les deux phases, côte à côte",
            headers: ["", "Photochimique", "Biochimique"],
            rows: [
                ["Lieu", "Thylakoïdes", "Stroma"],
                ["Lumière", "Indispensable", "Pas directement"],
                ["Consomme", "Eau, lumière", "CO₂, ATP, NADPH"],
                ["Produit", "ATP, NADPH, O₂", "Glucose"]
            ],
            caption: "La phase biochimique a longtemps été appelée phase sombre. Le nom est trompeur."
        )),

        .heading(level: 1, text: "La lumière casse l'eau"),

        .paragraph(text: "La chlorophylle absorbe un photon et perd un électron. Pour le remplacer, elle arrache des électrons à une molécule d'eau, qui se disloque : c'est la **photolyse**. Les protons libérés servent à fabriquer de l'ATP, les électrons à réduire le NADP en NADPH, et l'oxygène part dans l'atmosphère. ==Le dioxygène que nous respirons est un déchet de la photosynthèse.=="),

        .definition(
            term: "Photolyse de l'eau",
            text: "Rupture de la molécule d'eau sous l'action de la lumière. Elle fournit les électrons de la chaîne photosynthétique et libère le dioxygène."
        ),

        .callout(
            tone: .attention,
            text: "La phase biochimique est souvent appelée *phase sombre*, ce qui laisse croire qu'elle a lieu la nuit. Elle ne consomme pas de lumière, mais elle tourne avec l'ATP et le NADPH fabriqués à la lumière : à l'obscurité prolongée, elle s'arrête faute de carburant."
        ),

        .heading(level: 1, text: "Le cycle de Calvin"),

        .paragraph(text: "Le carbone entre dans le vivant par un cycle de trois temps, qui se répète tant qu'il reste du CO₂ et de l'énergie. Il faut six tours pour sortir un seul glucose."),

        .steps(title: "Les trois temps du cycle", items: [
            "**Fixation.** La *Rubisco* attache une molécule de CO₂ sur le ribulose bisphosphate.",
            "**Réduction.** L'ATP et le NADPH transforment le produit obtenu en G3P, un sucre à trois carbones.",
            "**Régénération.** Cinq G3P sur six reconstruisent le RuBP de départ, le sixième part vers le glucose."
        ]),

        .definition(
            term: "Rubisco",
            text: "L'enzyme qui fixe le CO₂, et la protéine la plus abondante de la biosphère. Elle est *lente*, et c'est elle qui plafonne le rendement de toute la photosynthèse."
        ),

        .heading(level: 1, text: "Ce qui limite le rendement"),

        .paragraph(text: "La réaction ne va jamais plus vite que son paramètre le plus faible. Doubler l'éclairage d'une serre où le CO₂ manque ne change presque rien : c'est la **loi du facteur limitant**, et c'est la raison pour laquelle les serres professionnelles enrichissent leur air en dioxyde de carbone plutôt que d'ajouter des lampes."),

        .chart(SheetChart(
            title: "Gain de production quand un seul paramètre est corrigé",
            bars: [
                SheetChart.Bar(label: "Air enrichi en CO₂", value: 45),
                SheetChart.Bar(label: "Température ramenée à 25 °C", value: 22),
                SheetChart.Bar(label: "Éclairage doublé", value: 11),
                SheetChart.Bar(label: "Arrosage régulier", value: 7)
            ],
            unit: "%",
            caption: "Ordres de grandeur relevés sur une culture sous serre déjà bien éclairée."
        )),

        .callout(
            tone: .essentiel,
            text: "Tiens la chaîne complète et le reste se déduit : la lumière casse l'eau et libère l'oxygène, l'énergie récupérée sert à ==coller le carbone de l'air sur du sucre==. Les noms d'enzymes et de compartiments viennent ensuite."
        )
    ])

    static let photosynthesisCards: [GeneratedFlashcard] = [
        GeneratedFlashcard(front: "Quel est le bilan chimique de la photosynthèse ?", back: "6 CO₂ + 6 H₂O + lumière → C₆H₁₂O₆ + 6 O₂", hint: "Pense aux six molécules de départ."),
        GeneratedFlashcard(front: "Où se déroule la phase photochimique ?", back: "Dans la membrane des thylakoïdes du chloroplaste.", hint: nil),
        GeneratedFlashcard(front: "Que produit la photolyse de l'eau ?", back: "Des électrons, des protons H⁺ et du dioxygène.", hint: nil),
        GeneratedFlashcard(front: "Quelles sont les trois étapes du cycle de Calvin ?", back: "Fixation du CO₂, réduction en G3P, régénération du RuBP.", hint: nil),
        GeneratedFlashcard(front: "Quelle enzyme fixe le CO₂ ?", back: "La Rubisco, l'enzyme la plus abondante de la biosphère.", hint: nil),
        GeneratedFlashcard(front: "Qu'est-ce qu'un facteur limitant ?", back: "Le paramètre insuffisant qui bloque le rendement de la réaction, même si les autres sont optimaux.", hint: nil),
        GeneratedFlashcard(front: "Pourquoi parler de « phase sombre » est trompeur ?", back: "Le cycle de Calvin ne nécessite pas de lumière directe, mais il dépend de l'ATP et du NADPH produits à la lumière.", hint: nil),
        GeneratedFlashcard(front: "Quels pigments captent la lumière ?", back: "La chlorophylle a et b, épaulées par les caroténoïdes.", hint: nil),
        // Les deux formats venus s'ajouter au recto verso : la démonstration les montre
        // sans qu'il faille générer un cours pour ça.
        GeneratedFlashcard(
            front: "La phase photochimique se déroule dans les thylakoïdes et produit de l'ATP, du NADPH et du …",
            back: "dioxygène",
            kind: CardKind.cloze.rawValue
        ),
        GeneratedFlashcard(
            front: "Où se déroule le cycle de Calvin ?",
            back: "Dans le stroma, à partir de l'ATP et du NADPH fabriqués à la lumière.",
            kind: CardKind.choice.rawValue,
            choices: ["Dans le stroma", "Dans les thylakoïdes", "Dans la mitochondrie", "Dans le noyau"],
            answerIndex: 0
        )
    ]

    // MARK: - Cours de mathématiques

    static let affineFunctionsCourse = GeneratedCourse(
        title: "Les fonctions affines",
        subject: "Mathématiques",
        emoji: "📐",
        summary: "Reconnaître, tracer et interpréter une fonction de la forme f(x) = ax + b.",
        sheet: SampleData.affineFunctionsSheet,
        contextText: """
        Une fonction affine s'écrit f(x) = ax + b, où a est le coefficient directeur et b l'ordonnée à l'origine.
        Le coefficient directeur mesure la pente de la droite : positif la fonction croît, négatif elle décroît, nul elle est constante.
        Pour deux points connus, a = (y₂ - y₁) / (x₂ - x₁), soit la variation verticale divisée par la variation horizontale.
        Pour tracer la droite : placer le point (0 ; b), avancer de 1 puis monter de a, relier les deux points.
        La représentation graphique d'une fonction affine est toujours une droite.
        Une fonction linéaire est une fonction affine dont l'ordonnée à l'origine b vaut 0.
        """
    )

    /// La fiche du second cours de démonstration. Elle existe surtout pour montrer une
    /// fiche de matière scientifique : formules dans le texte, tableau de signes, et un
    /// graphe qui n'illustre pas un chiffre mais une régularité.
    static let affineFunctionsSheet = CourseSheet(blocks: [
        .paragraph(text: "Une fonction affine est la plus simple des fonctions qui varient, et c'est celle qu'on croise partout : un abonnement avec frais d'ouverture, un trajet à vitesse constante, une facture au compteur. Sa représentation graphique est **toujours une droite**, et la réciproque est vraie : toute droite non verticale est la courbe d'une fonction affine."),

        .formula(
            latex: "f(x) = ax + b",
            caption: "a est le coefficient directeur, b l'ordonnée à l'origine."
        ),

        .heading(level: 1, text: "Lire les deux coefficients"),

        .paragraph(text: "Le nombre **b** se lit sans aucun calcul : c'est l'ordonnée du point où la droite coupe l'axe vertical, autrement dit la valeur de $f(0)$. Le nombre **a** mesure la pente, et une seule phrase suffit à s'en souvenir : ==avancer de 1 vers la droite fait monter de a==."),

        .definition(
            term: "Coefficient directeur",
            text: "Le nombre a. Il donne la variation de f quand x augmente de 1, et son signe donne le sens de variation de la fonction."
        ),

        .table(SheetTable(
            title: "Le signe de a commande tout",
            headers: ["Signe de a", "La fonction", "La droite"],
            rows: [
                ["a > 0", "croissante", "monte vers la droite"],
                ["a < 0", "décroissante", "descend vers la droite"],
                ["a = 0", "constante", "horizontale"]
            ],
            caption: nil
        )),

        .heading(level: 1, text: "Retrouver la fonction à partir de deux points"),

        .paragraph(text: "Deux points suffisent à fixer une droite, donc à retrouver ses deux coefficients. On calcule d'abord la pente comme un rapport de variations, puis on remonte à b en réinjectant l'un des deux points dans l'expression."),

        .formula(
            latex: "a = \\frac{y_2 - y_1}{x_2 - x_1}",
            caption: "La variation verticale divisée par la variation horizontale."
        ),

        .steps(title: "Tracer la droite en trois gestes", items: [
            "Place le point de coordonnées (0 ; b) sur l'axe vertical.",
            "Depuis ce point, avance de 1 vers la droite et monte de a. Si a est négatif, tu descends.",
            "Trace la droite qui passe par ces deux points, et prolonge-la des deux côtés."
        ]),

        .callout(
            tone: .exemple,
            text: "Un abonnement à 12 € par mois avec 25 € de frais d'ouverture coûte $f(x) = 12x + 25$ après x mois. Le coefficient directeur est le prix mensuel, l'ordonnée à l'origine ce qu'on paie même sans rien consommer."
        ),

        .chart(SheetChart(
            title: "Ce que coûte cet abonnement",
            bars: [
                SheetChart.Bar(label: "Après 1 mois", value: 37),
                SheetChart.Bar(label: "Après 3 mois", value: 61),
                SheetChart.Bar(label: "Après 6 mois", value: 97),
                SheetChart.Bar(label: "Après 12 mois", value: 169)
            ],
            unit: "€",
            caption: "D'un mois au suivant, l'écart est toujours le même : c'est la signature d'une fonction affine."
        )),

        .callout(
            tone: .attention,
            text: "Une fonction **linéaire** est une fonction affine dont b vaut 0. La réciproque est fausse : *f(x) = 2x + 3* est affine et n'est pas linéaire. La distinction compte, parce que seule la fonction linéaire traduit une situation de proportionnalité."
        ),

        .callout(
            tone: .essentiel,
            text: "Trois choses tiennent tout le chapitre : la courbe est une droite, ==a est la pente et b l'ordonnée à l'origine==, et deux points suffisent à retrouver les deux."
        )
    ])

    static let affineFunctionsCards: [GeneratedFlashcard] = [
        GeneratedFlashcard(front: "Quelle est la forme générale d'une fonction affine ?", back: "f(x) = ax + b", hint: nil),
        GeneratedFlashcard(front: "Comment calculer le coefficient directeur avec deux points ?", back: "a = (y₂ - y₁) / (x₂ - x₁)", hint: "Variation verticale sur variation horizontale."),
        GeneratedFlashcard(front: "Que représente b graphiquement ?", back: "L'ordonnée à l'origine, c'est-à-dire l'ordonnée du point d'abscisse 0.", hint: nil),
        GeneratedFlashcard(front: "Quand une fonction affine est-elle décroissante ?", back: "Lorsque son coefficient directeur a est strictement négatif.", hint: nil),
        GeneratedFlashcard(front: "Qu'est-ce qu'une fonction linéaire ?", back: "Une fonction affine dont l'ordonnée à l'origine b vaut 0, donc de la forme f(x) = ax.", hint: nil),
        GeneratedFlashcard(
            front: "Dans f(x) = ax + b, le nombre a porte le nom de … directeur.",
            back: "coefficient",
            kind: CardKind.cloze.rawValue
        ),
        GeneratedFlashcard(
            front: "Que vaut le coefficient directeur de la droite passant par (0 ; 1) et (2 ; 5) ?",
            back: "a = (5 - 1) / (2 - 0) = 2",
            kind: CardKind.choice.rawValue,
            choices: ["2", "3", "4", "0,5"],
            answerIndex: 0
        )
    ]

    private static func migrateLegacySeedFlag(in defaults: UserDefaults) {
        let legacy = "feymind.didSeedSampleData"
        guard !defaults.bool(forKey: seedKey), defaults.bool(forKey: legacy) else { return }
        defaults.set(true, forKey: seedKey)
        defaults.removeObject(forKey: legacy)
    }
}
