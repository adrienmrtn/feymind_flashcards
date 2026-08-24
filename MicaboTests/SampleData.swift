import Foundation
@testable import Micabo

/// Deux fiches écrites à la main, servant de **matériel de test**.
///
/// Elles vivaient dans l'app, avec leurs cours et leurs cartes, insérées au premier
/// lancement pour qu'elle soit immédiatement explorable. Elles n'y sont plus : une app
/// d'apprentissage qui s'ouvre sur deux cours qui ne sont pas les tiens ne montre pas ce
/// qu'elle fait, elle montre ce que quelqu'un d'autre a importé, et le premier geste devient
/// de les supprimer. L'app part donc vide, sur ses écrans d'accueil.
///
/// Les deux fiches, elles, avaient une seconde vie : elles servent de **référence à ce qu'une
/// bonne fiche est censée être**, du dosage du surlignage à la longueur des paragraphes, et
/// les tests de mise en page s'appuient dessus. Les cours et les cartes qui les accompagnaient
/// n'avaient pas cette excuse et sont partis avec le reste.
enum SampleData {
    // MARK: - Sciences de la vie

    /// Fiche de référence : elle exerce presque tous les blocs de mise en page, du tableau
    /// au graphe en passant par le surlignage et les encadrés.
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

    // MARK: - Mathématiques

    /// Seconde fiche de référence, de matière scientifique : formules dans le texte,
    /// tableau de signes, et un graphe qui n'illustre pas un chiffre mais une régularité.
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
}
