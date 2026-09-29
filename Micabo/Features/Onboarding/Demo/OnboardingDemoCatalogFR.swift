import Foundation

// MARK: - Les quatre cours, en français

/// Le contenu des cours de démonstration, en français. Niveau lycée : ce qu'un professeur
/// écrirait au tableau, avec les définitions exactes, les mécanismes et les exemples.
///
/// Les matières sont les noms canoniques du catalogue (`SubjectCatalog`) : c'est ce qui les
/// range dans les bons filtres, et `SubjectDisplay` les traduit à l'affichage.
extension OnboardingDemoCatalog {
    static let french: [OnboardingDemoCourse] = [
        coldWarFR, photosynthesisFR, derivativesFR, energyFR,
    ]

    // MARK: Histoire : la guerre froide

    private static let coldWarFR = OnboardingDemoCourse(
        id: "history-cold-war",
        emoji: "🏛️",
        subject: "Histoire",
        title: "La guerre froide (1947–1991)",
        summary: "Deux blocs, deux modèles, et jamais d'affrontement direct : quarante-quatre ans de tension, de crises et de détente, jusqu'à la chute du Mur.",
        accentIndex: 3,
        chapters: [
            DemoChapter(title: "Deux blocs face à face (1947–1953)", blocks: [
                .paragraph("En 1945, les vainqueurs de la guerre ne partagent plus rien. Les États-Unis et l'URSS, alliés contre l'Allemagne nazie, deviennent ==les deux superpuissances== d'un monde qui se coupe en deux."),
                .callout(
                    title: "Guerre froide",
                    text: "Un affrontement **sans guerre directe** entre les États-Unis et l'URSS, de 1947 à 1991, mené par la pression économique, la propagande, la course aux armements et des guerres par procuration.",
                    tone: .definition
                ),
                .figure(.split(
                    title: "Deux modèles",
                    left: DemoColumn(title: "Bloc de l'Ouest", items: ["États-Unis", "Démocratie libérale", "Économie de marché", "Plan Marshall (1947)", "OTAN (1949)"]),
                    right: DemoColumn(title: "Bloc de l'Est", items: ["URSS", "Parti unique", "Économie planifiée", "Kominform (1947)", "Pacte de Varsovie (1955)"])
                )),
                .paragraph("En mars 1947, le président Truman promet d'aider tout pays menacé par le communisme : c'est la ==bleu|doctrine Truman==, ou *containment*. Le plan Marshall, trois mois plus tard, finance la reconstruction de l'Europe de l'Ouest, et l'attache au camp américain."),
                .timeline(title: "Les premières années", events: [
                    DemoEvent(date: "1947", label: "Doctrine Truman et plan Marshall"),
                    DemoEvent(date: "1948", label: "Blocus de Berlin"),
                    DemoEvent(date: "1949", label: "Création de l'OTAN, première bombe soviétique"),
                    DemoEvent(date: "1950", label: "Début de la guerre de Corée"),
                ]),
                .callout(
                    title: "À retenir",
                    text: "Le blocus de Berlin (juin 1948 à mai 1949) est la première crise : l'URSS coupe les routes vers Berlin-Ouest, les Alliés répondent par un ==pont aérien== de onze mois. Aucun coup de feu, et pourtant tout est dit.",
                    tone: .insight
                ),
                .paragraph("Le mot d'ordre de chaque camp est le même : ne pas céder un pouce, sans jamais tirer sur l'autre. C'est **l'équilibre de la terreur** qui s'installe dès que les deux ont la bombe."),
            ]),
            DemoChapter(title: "Crises et équilibre de la terreur (1953–1975)", blocks: [
                .paragraph("Après la mort de Staline (1953), la « coexistence pacifique » de Khrouchtchev n'empêche ni les crises ni la course aux armements. Chaque camp arme ses alliés et se bat **par procuration**, de la Corée au Vietnam."),
                .table(title: "Les grandes crises", headers: ["Crise", "Date", "Ce qui se joue"], rows: [
                    ["Guerre de Corée", "1950–1953", "Le 38e parallèle, une Corée coupée en deux"],
                    ["Mur de Berlin", "1961", "L'Est mure sa population pour arrêter les fuites vers l'Ouest"],
                    ["Crise de Cuba", "1962", "Des missiles soviétiques à 150 km de la Floride"],
                    ["Guerre du Vietnam", "1955–1975", "Les États-Unis s'enlisent, puis se retirent"],
                ]),
                .keyFigure(value: "13 jours", label: "la durée de la crise de Cuba, en octobre 1962, avant le retrait des missiles"),
                .paragraph("En octobre 1962, les avions américains photographient des rampes de missiles soviétiques à Cuba. Kennedy impose un blocus naval ; Khrouchtchev finit par retirer les missiles contre la promesse de ne pas envahir l'île. ==La dissuasion a tenu== : c'est le point le plus chaud de toute la guerre froide."),
                .figure(.flow(title: "La logique de la dissuasion", steps: ["Chaque camp a la bombe", "Frapper, c'est être frappé", "Personne ne frappe", "La guerre se joue ailleurs"])),
                .callout(
                    title: "Par procuration",
                    text: "Le Vietnam en est l'exemple : les États-Unis soutiennent le Sud, l'URSS et la Chine le Nord. Une guerre réelle, des milliers de morts, et jamais un soldat américain face à un soldat soviétique.",
                    tone: .example
                ),
                .list([
                    "1957 : Spoutnik, le premier satellite, ouvre la course à l'espace",
                    "1963 : le téléphone rouge relie Washington à Moscou",
                    "1969 : Apollo 11, l'Amérique marche sur la Lune",
                ]),
            ]),
            DemoChapter(title: "De la détente à la chute du Mur (1975–1991)", blocks: [
                .paragraph("Les années 1970 desserrent l'étau : accords SALT sur les armements (1972), conférence d'Helsinki (1975). Mais la ==rose|guerre fraîche== reprend en 1979, quand l'URSS envahit l'Afghanistan et que Reagan relance la course aux armements."),
                .paragraph("En 1985, Mikhaïl Gorbatchev arrive au pouvoir dans une URSS à bout de souffle. Il lance la **perestroïka** (restructuration) et la **glasnost** (transparence), et cesse de soutenir les régimes communistes d'Europe de l'Est."),
                .timeline(title: "La fin", events: [
                    DemoEvent(date: "1985", label: "Gorbatchev au pouvoir"),
                    DemoEvent(date: "1987", label: "Traité de Washington : fin des euromissiles"),
                    DemoEvent(date: "9 nov. 1989", label: "Chute du mur de Berlin"),
                    DemoEvent(date: "1990", label: "Réunification allemande"),
                    DemoEvent(date: "25 déc. 1991", label: "Dissolution de l'URSS"),
                ]),
                .bars(title: "Dépenses militaires en part du PIB, vers 1985 (estimation)", unit: "%", bars: [
                    DemoBar(label: "États-Unis", value: 6),
                    DemoBar(label: "URSS", value: 15),
                    DemoBar(label: "France", value: 4),
                ]),
                .callout(
                    title: "Pourquoi le Mur tombe",
                    text: "Sans le soutien de Moscou, les régimes de l'Est s'effondrent l'un après l'autre en 1989. Le 9 novembre, la RDA ouvre ses frontières : en une nuit, le symbole de la division disparaît.",
                    tone: .insight
                ),
                .paragraph("Le 25 décembre 1991, le drapeau soviétique est descendu du Kremlin. La guerre froide se termine ==sans bataille==, par l'épuisement d'un des deux camps."),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "Quels sont les deux blocs de la guerre froide, et qui les mène ?",
                back: "Le bloc de l'Ouest, mené par les États-Unis (démocratie libérale, économie de marché), et le bloc de l'Est, mené par l'URSS (parti unique, économie planifiée).",
                figure: .split(
                    title: "Deux modèles",
                    left: DemoColumn(title: "Ouest", items: ["États-Unis", "OTAN"]),
                    right: DemoColumn(title: "Est", items: ["URSS", "Pacte de Varsovie"])
                ),
                chapter: 0
            ),
            DemoCard(
                kind: .choice,
                front: "Quelle crise amène le monde au bord de la guerre nucléaire en 1962 ?",
                back: "La crise de Cuba : des missiles soviétiques installés à Cuba, treize jours de bras de fer, puis le retrait contre la promesse de ne pas envahir l'île.",
                choices: ["Le blocus de Berlin", "La crise de Cuba", "La guerre de Corée", "L'invasion de l'Afghanistan"],
                answerIndex: 1,
                chapter: 1
            ),
            DemoCard(
                kind: .cloze,
                front: "Le mur de Berlin tombe le 9 novembre …, deux ans avant la dissolution de l'URSS.",
                back: "1989",
                chapter: 2
            ),
            DemoCard(kind: .basic, front: "Qu'est-ce que la doctrine Truman ?", back: "L'engagement des États-Unis, en mars 1947, d'aider tout pays menacé par le communisme : la politique d'endiguement (containment).", chapter: 0),
            DemoCard(kind: .cloze, front: "Le plan … (1947) finance la reconstruction de l'Europe de l'Ouest.", back: "Marshall", chapter: 0),
            DemoCard(kind: .choice, front: "Qui lance la perestroïka et la glasnost ?", back: "Mikhaïl Gorbatchev, arrivé au pouvoir en 1985, tente de réformer l'URSS de l'intérieur.", choices: ["Staline", "Khrouchtchev", "Gorbatchev", "Brejnev"], answerIndex: 2, chapter: 2),
        ]
    )

    // MARK: SVT : la photosynthèse

    private static let photosynthesisFR = OnboardingDemoCourse(
        id: "biology-photosynthesis",
        emoji: "🌿",
        subject: "SVT",
        title: "La photosynthèse",
        summary: "Comment une feuille fabrique du sucre avec de la lumière, de l'eau et du dioxyde de carbone, et pourquoi presque toute la vie en dépend.",
        accentIndex: 4,
        chapters: [
            DemoChapter(title: "Capter la lumière", blocks: [
                .paragraph("Une feuille est une usine : elle prend de la lumière, de l'eau et du dioxyde de carbone, et en fait ==du sucre et du dioxygène==. Ce processus s'appelle la photosynthèse, et il nourrit presque toute la vie sur Terre."),
                .callout(
                    title: "Photosynthèse",
                    text: "La synthèse de matière organique (glucose) par les végétaux chlorophylliens, à partir de matière minérale (CO₂ et eau), grâce à l'énergie lumineuse.",
                    tone: .definition
                ),
                .formula("6\\,CO_2 + 6\\,H_2O \\rightarrow C_6H_{12}O_6 + 6\\,O_2", caption: "L'équation bilan, sous l'action de la lumière"),
                .paragraph("Tout se passe dans les **chloroplastes**, des organites verts des cellules de la feuille. Leur couleur vient de la ==menthe|chlorophylle==, le pigment qui absorbe la lumière rouge et bleue, et renvoie le vert."),
                .figure(.flow(title: "Du photon au sucre", steps: ["La chlorophylle absorbe la lumière", "L'eau est cassée : O₂ libéré", "L'énergie est stockée (ATP)", "Le CO₂ est fixé en glucose"])),
                .bars(title: "Ce que la chlorophylle absorbe, selon la couleur", unit: "%", bars: [
                    DemoBar(label: "Bleu", value: 90),
                    DemoBar(label: "Vert", value: 15),
                    DemoBar(label: "Rouge", value: 80),
                ]),
                .callout(
                    title: "Pourquoi les feuilles sont vertes",
                    text: "Parce que le vert est la couleur que la chlorophylle **n'absorbe pas** : elle le réfléchit vers nos yeux.",
                    tone: .insight
                ),
            ]),
            DemoChapter(title: "Fabriquer le glucose", blocks: [
                .paragraph("La photosynthèse se déroule en deux temps. La **phase claire** a besoin de lumière : elle casse l'eau, libère le dioxygène et stocke l'énergie. La **phase sombre** n'en a pas besoin : elle utilise cette énergie pour fixer le CO₂ et fabriquer le glucose."),
                .table(title: "Les deux phases", headers: ["", "Phase claire", "Phase sombre"], rows: [
                    ["Où", "Membranes des thylakoïdes", "Stroma du chloroplaste"],
                    ["Lumière", "Indispensable", "Pas directement"],
                    ["Entrée", "Eau, lumière", "CO₂, ATP"],
                    ["Sortie", "O₂, ATP", "Glucose"],
                ]),
                .figure(.cycle(title: "Le cycle de Calvin", nodes: ["Fixation du CO₂", "Réduction avec l'ATP", "Formation de sucre", "Régénération de l'accepteur"])),
                .paragraph("Le cycle de Calvin tourne dans le stroma : à chaque tour, une molécule de CO₂ est fixée sur un accepteur, réduite grâce à l'ATP, et une part du produit sort du cycle pour faire ==du glucose==. Il faut **six tours** pour une molécule de glucose."),
                .keyFigure(value: "6 tours", label: "de cycle de Calvin pour fabriquer une seule molécule de glucose"),
                .callout(
                    title: "Piège classique",
                    text: "La phase sombre ne se passe pas « la nuit » : elle se déroule le jour aussi, dès que la phase claire lui fournit de l'énergie. « Sombre » veut dire qu'elle n'utilise pas la lumière directement.",
                    tone: .warning
                ),
            ]),
            DemoChapter(title: "La photosynthèse et la planète", blocks: [
                .paragraph("Chaque année, les végétaux fixent environ ==120 milliards de tonnes de carbone==. La photosynthèse est le point d'entrée de la matière organique dans les chaînes alimentaires, et la source de tout le dioxygène que nous respirons."),
                .figure(.cycle(title: "Le cycle du carbone", nodes: ["CO₂ dans l'atmosphère", "Photosynthèse : fixé dans les plantes", "Respiration, décomposition", "Retour dans l'atmosphère"])),
                .paragraph("Trois facteurs commandent son intensité : la lumière, la concentration en CO₂ et la température. Quand l'un d'eux manque, augmenter les autres ne sert à rien : c'est le **facteur limitant**."),
                .figure(.plot(title: "La lumière, jusqu'à un plafond", caption: "Plus de lumière accélère la photosynthèse, jusqu'à un plateau : au-delà, c'est le CO₂ ou la température qui limite.", kind: .saturation)),
                .list([
                    "Lumière : plus il y en a, plus la photosynthèse s'accélère, jusqu'à saturation",
                    "CO₂ : à 0,04 % dans l'air, souvent le facteur limitant en plein jour",
                    "Température : un optimum vers 25 à 30 °C, les enzymes s'arrêtent au-delà",
                ]),
                .callout(
                    title: "Dans une serre",
                    text: "Les maraîchers enrichissent parfois l'air en CO₂ : sous une forte lumière, c'est lui qui bride la croissance, et l'ajouter fait pousser les tomates plus vite.",
                    tone: .example
                ),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "Quels sont les réactifs et les produits de la photosynthèse ?",
                back: "Réactifs : le dioxyde de carbone (CO₂) et l'eau (H₂O), avec l'énergie lumineuse. Produits : le glucose (C₆H₁₂O₆) et le dioxygène (O₂).",
                figure: .flow(title: "Du photon au sucre", steps: ["Lumière", "Eau cassée, O₂", "ATP", "Glucose"]),
                chapter: 0
            ),
            DemoCard(
                kind: .choice,
                front: "Où se déroule la phase claire de la photosynthèse ?",
                back: "Dans les membranes des thylakoïdes, à l'intérieur du chloroplaste. Le stroma, lui, accueille le cycle de Calvin.",
                choices: ["Dans le stroma", "Dans les membranes des thylakoïdes", "Dans le noyau", "Dans les mitochondries"],
                answerIndex: 1,
                chapter: 1
            ),
            DemoCard(
                kind: .cloze,
                front: "La chlorophylle absorbe surtout le bleu et le rouge, et réfléchit le …, d'où la couleur des feuilles.",
                back: "vert",
                chapter: 0
            ),
            DemoCard(kind: .basic, front: "Qu'est-ce qu'un facteur limitant ?", back: "Le facteur (lumière, CO₂ ou température) dont le manque bride la photosynthèse : tant qu'il manque, augmenter les autres ne change rien.", chapter: 2),
            DemoCard(kind: .cloze, front: "Il faut … tours de cycle de Calvin pour fabriquer une molécule de glucose.", back: "six", chapter: 1),
            DemoCard(kind: .choice, front: "Quel gaz la photosynthèse libère-t-elle ?", back: "Le dioxygène (O₂), issu de la cassure des molécules d'eau pendant la phase claire.", choices: ["Le dioxyde de carbone", "Le dioxygène", "L'azote", "L'hydrogène"], answerIndex: 1, chapter: 0),
        ]
    )

    // MARK: Mathématiques : les dérivées

    private static let derivativesFR = OnboardingDemoCourse(
        id: "maths-derivatives",
        emoji: "📐",
        subject: "Mathématiques",
        title: "Les dérivées",
        summary: "Le nombre dérivé, la tangente, les dérivées usuelles et les règles de calcul, puis le signe de la dérivée qui donne les variations d'une fonction.",
        accentIndex: 0,
        chapters: [
            DemoChapter(title: "Le nombre dérivé et la tangente", blocks: [
                .paragraph("Dériver, c'est mesurer ==la vitesse à laquelle une fonction change==. Sur une courbe, cette vitesse se voit : c'est la pente de la tangente au point qu'on regarde."),
                .callout(
                    title: "Nombre dérivé",
                    text: "Le nombre dérivé de $f$ en $a$, noté $f'(a)$, est la limite du taux de variation entre $a$ et $a+h$ quand $h$ tend vers 0.",
                    tone: .definition
                ),
                .formula("f'(a) = \\lim_{h \\to 0} \\frac{f(a+h) - f(a)}{h}", caption: "Le taux de variation, quand h devient infiniment petit"),
                .figure(.plot(title: "La tangente en un point", caption: "La droite qui « colle » à la courbe en $a$ : sa pente est $f'(a)$.", kind: .tangent)),
                .paragraph("L'équation de la tangente en $a$ s'écrit $y = f'(a)(x - a) + f(a)$ : une droite qui passe par le point $(a, f(a))$ avec la pente $f'(a)$."),
                .callout(
                    title: "Exemple",
                    text: "Pour $f(x) = x^2$ en $a = 1$ : $f'(1) = 2$, donc la tangente est $y = 2(x - 1) + 1 = 2x - 1$.",
                    tone: .example
                ),
                .list([
                    "$f'(a) > 0$ : la courbe monte en $a$",
                    "$f'(a) < 0$ : elle descend",
                    "$f'(a) = 0$ : tangente horizontale, souvent un sommet ou un creux",
                ]),
            ]),
            DemoChapter(title: "Calculer une dérivée", blocks: [
                .paragraph("On ne calcule presque jamais une limite à la main : on apprend **les dérivées usuelles**, et les règles qui les combinent."),
                .table(title: "Les dérivées usuelles", headers: ["f(x)", "f′(x)"], rows: [
                    ["k (constante)", "0"],
                    ["x", "1"],
                    ["x²", "2x"],
                    ["xⁿ", "n · xⁿ⁻¹"],
                    ["1/x", "−1/x²"],
                    ["√x", "1/(2√x)"],
                    ["eˣ", "eˣ"],
                    ["ln x", "1/x"],
                ]),
                .callout(
                    title: "Les trois règles",
                    text: "**Somme** : $(u+v)' = u' + v'$. **Produit** : $(uv)' = u'v + uv'$. **Quotient** : $(u/v)' = (u'v - uv')/v^2$.",
                    tone: .insight
                ),
                .formula("(uv)' = u'v + uv'", caption: "La dérivée d'un produit : chaque facteur dérivé à son tour, et on additionne"),
                .paragraph("Exemple : $f(x) = 3x^2 - 5x + 2$. On dérive terme à terme : $f'(x) = 6x - 5$. Les constantes s'effacent, ==les puissances descendent d'un cran==."),
                .callout(
                    title: "L'erreur à ne pas faire",
                    text: "$(uv)' \\neq u'v'$. La dérivée d'un produit **n'est pas** le produit des dérivées : $(x \\cdot x)' = 2x$, pas $1 \\cdot 1$.",
                    tone: .warning
                ),
                .list([
                    "Repérer la forme : somme, produit, quotient",
                    "Dériver chaque morceau avec le tableau",
                    "Assembler avec la bonne règle",
                    "Simplifier, puis vérifier le signe",
                ], ordered: true),
            ]),
            DemoChapter(title: "Dérivée et variations", blocks: [
                .paragraph("Le signe de la dérivée dit ==dans quel sens la fonction varie== : positive, elle monte ; négative, elle descend. C'est la clé de tous les tableaux de variations."),
                .figure(.plot(title: "Signe de f′ et sens de f", caption: "Là où $f'$ est positive, $f$ monte ; là où elle s'annule en changeant de signe, $f$ atteint un extremum.", kind: .variation)),
                .paragraph("Pour $f(x) = x^3 - 3x$ : $f'(x) = 3x^2 - 3 = 3(x-1)(x+1)$. Elle s'annule en $-1$ et $1$ : un **maximum local** en $-1$ (valeur 2) et un **minimum local** en $1$ (valeur $-2$)."),
                .table(title: "Tableau de variations de f(x) = x³ − 3x", headers: ["Intervalle", "Signe de f′", "Sens de f"], rows: [
                    ["]−∞ ; −1[", "+", "croissante"],
                    ["]−1 ; 1[", "−", "décroissante"],
                    ["]1 ; +∞[", "+", "croissante"],
                ]),
                .callout(
                    title: "Méthode",
                    text: "1. Dériver. 2. Étudier le signe de $f'$ (factoriser !). 3. En déduire les variations. 4. Calculer les valeurs aux bornes et aux extremums.",
                    tone: .insight
                ),
                .keyFigure(value: "f′ = 0", label: "là où la courbe a une tangente horizontale : un sommet, un creux, ou un palier"),
                .callout(
                    title: "Attention",
                    text: "$f'(a) = 0$ ne suffit pas pour un extremum : $x^3$ a une dérivée nulle en 0 et ne change pas de sens. Il faut que $f'$ **change de signe**.",
                    tone: .warning
                ),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "Que représente géométriquement le nombre dérivé $f'(a)$ ?",
                back: "La pente de la tangente à la courbe de $f$ au point d'abscisse $a$.",
                figure: .plot(title: "La tangente en a", caption: "", kind: .tangent),
                chapter: 0
            ),
            DemoCard(
                kind: .choice,
                front: "Quelle est la dérivée de $f(x) = 3x^2 - 5x + 2$ ?",
                back: "$f'(x) = 6x - 5$ : la puissance descend d'un cran, le terme en $x$ devient sa pente, la constante disparaît.",
                choices: ["$6x - 5$", "$3x - 5$", "$6x + 2$", "$x^2 - 5$"],
                answerIndex: 0,
                chapter: 1
            ),
            DemoCard(
                kind: .cloze,
                front: "Sur un intervalle où $f'$ est …, la fonction $f$ est croissante.",
                back: "positive",
                chapter: 2
            ),
            DemoCard(kind: .basic, front: "Quelle est la formule de la dérivée d'un produit ?", back: "$(uv)' = u'v + uv'$ : on dérive chaque facteur à son tour et on additionne.", chapter: 1),
            DemoCard(kind: .cloze, front: "La dérivée de $e^x$ est … .", back: "$e^x$", chapter: 1),
            DemoCard(kind: .choice, front: "En quels points $f(x) = x^3 - 3x$ admet-elle un extremum local ?", back: "En $x = -1$ (maximum, valeur 2) et $x = 1$ (minimum, valeur $-2$) : là où $f'(x) = 3(x-1)(x+1)$ s'annule en changeant de signe.", choices: ["$x = 0$", "$x = -1$ et $x = 1$", "$x = 3$", "Aucun"], answerIndex: 1, chapter: 2),
        ]
    )

    // MARK: Physique : l'énergie

    private static let energyFR = OnboardingDemoCourse(
        id: "physics-energy",
        emoji: "⚡️",
        subject: "Physique",
        title: "L'énergie",
        summary: "Les formes de l'énergie, sa conservation d'une forme à l'autre, puis la puissance et le rendement, avec les formules et les ordres de grandeur du programme.",
        accentIndex: 6,
        chapters: [
            DemoChapter(title: "Les formes de l'énergie", blocks: [
                .paragraph("L'énergie ne se voit pas, elle se **transforme** : la chute d'une pomme, la chaleur d'un moteur, la lumière d'une lampe sont la même grandeur sous des formes différentes. Elle se mesure en ==joules (J)==."),
                .table(title: "Les formes usuelles", headers: ["Forme", "Dépend de", "Exemple"], rows: [
                    ["Cinétique", "la masse et la vitesse", "une voiture lancée"],
                    ["Potentielle de pesanteur", "la masse et la hauteur", "une pomme dans l'arbre"],
                    ["Thermique", "l'agitation des molécules", "une casserole chaude"],
                    ["Électrique", "le courant", "une batterie"],
                    ["Chimique", "les liaisons", "l'essence, le glucose"],
                ]),
                .formula("E_c = \\frac{1}{2} m v^2", caption: "Énergie cinétique : m en kg, v en m/s, E en J"),
                .formula("E_{pp} = m g h", caption: "Énergie potentielle de pesanteur : g ≈ 9,8 N/kg, h en m"),
                .callout(
                    title: "Ordre de grandeur",
                    text: "Une voiture de 1 000 kg à 50 km/h (≈ 14 m/s) porte $E_c = \\frac{1}{2} \\times 1000 \\times 14^2 \\approx 98\\,000$ J, soit près de 100 kJ. À 100 km/h, **quatre fois plus**.",
                    tone: .example
                ),
                .keyFigure(value: "× 4", label: "quand la vitesse double, l'énergie cinétique quadruple : c'est le carré de la formule"),
                .callout(
                    title: "Unité",
                    text: "L'énergie s'exprime en joules, jamais en watts. Le watt mesure une **puissance** : de l'énergie par seconde.",
                    tone: .warning
                ),
            ]),
            DemoChapter(title: "Conservation et transferts", blocks: [
                .paragraph("==bleu|L'énergie ne se crée ni ne se perd== : elle passe d'une forme à une autre, d'un système à un autre. C'est le principe de conservation, et il vaut pour tout, de l'atome à la galaxie."),
                .figure(.flow(title: "La chaîne énergétique d'une chute", steps: ["Énergie potentielle, en haut", "Devient énergie cinétique", "Choc : chaleur et son", "Total inchangé"])),
                .paragraph("Une balle lâchée de 2 m perd de l'énergie potentielle et gagne exactement autant d'énergie cinétique, tant qu'on néglige les frottements. Au sol, sa vitesse vaut $v = \\sqrt{2gh} \\approx 6{,}3$ m/s."),
                .callout(
                    title: "Énergie mécanique",
                    text: "La somme de l'énergie cinétique et de l'énergie potentielle : $E_m = E_c + E_{pp}$. Sans frottements, elle se conserve.",
                    tone: .definition
                ),
                .formula("E_m = E_c + E_{pp} = \\text{constante}", caption: "En l'absence de frottements"),
                .callout(
                    title: "Et les frottements ?",
                    text: "Ils ne « détruisent » rien : l'énergie mécanique perdue devient de l'énergie thermique. Le total se conserve toujours, il est juste moins utile.",
                    tone: .insight
                ),
                .list([
                    "Travail : transfert d'énergie par une force qui déplace",
                    "Chaleur : transfert par différence de température",
                    "Rayonnement : transfert par la lumière, comme le Soleil",
                ]),
            ]),
            DemoChapter(title: "Puissance et rendement", blocks: [
                .paragraph("La **puissance** dit à quelle vitesse l'énergie est transférée. Un chauffage de 2 000 W transfère 2 000 joules chaque seconde."),
                .formula("P = \\frac{E}{\\Delta t}", caption: "P en watts (W), E en joules, Δt en secondes"),
                .callout(
                    title: "Le kilowattheure",
                    text: "1 kWh, c'est 1 000 W pendant une heure : $1000 \\times 3600 = 3{,}6 \\times 10^6$ J. C'est l'unité de la facture d'électricité.",
                    tone: .example
                ),
                .paragraph("Aucun convertisseur n'est parfait : une part de l'énergie reçue repart en chaleur. Le ==rendement== compare ce qui est utile à ce qui est fourni."),
                .formula("\\eta = \\frac{E_{utile}}{E_{fournie}}", caption: "Toujours inférieur ou égal à 1 (100 %)"),
                .bars(title: "Rendement de quelques convertisseurs", unit: "%", bars: [
                    DemoBar(label: "Moteur thermique", value: 35),
                    DemoBar(label: "Ampoule LED", value: 40),
                    DemoBar(label: "Moteur électrique", value: 90),
                    DemoBar(label: "Radiateur électrique", value: 100),
                ]),
                .callout(
                    title: "Rendement de 100 % ?",
                    text: "Un radiateur électrique convertit tout en chaleur, mais c'est justement la chaleur qu'on veut. Pour un moteur, la chaleur est une perte.",
                    tone: .warning
                ),
            ]),
        ],
        cards: [
            DemoCard(
                kind: .basic,
                front: "Que devient l'énergie potentielle d'une balle qui tombe ?",
                back: "Elle se convertit en énergie cinétique pendant la chute (la vitesse augmente), puis en énergie thermique et sonore au choc. Le total est conservé.",
                figure: .flow(title: "Chaîne énergétique", steps: ["Potentielle", "Cinétique", "Chaleur et son"]),
                chapter: 1
            ),
            DemoCard(
                kind: .choice,
                front: "Si la vitesse d'une voiture double, son énergie cinétique est…",
                back: "Quadruplée : $E_c = \\frac{1}{2} m v^2$ dépend du carré de la vitesse.",
                choices: ["doublée", "quadruplée", "inchangée", "divisée par deux"],
                answerIndex: 1,
                chapter: 0
            ),
            DemoCard(
                kind: .cloze,
                front: "La puissance est l'énergie transférée par unité de … : elle s'exprime en watts.",
                back: "temps",
                chapter: 2
            ),
            DemoCard(kind: .basic, front: "Quelle est la formule de l'énergie potentielle de pesanteur ?", back: "$E_{pp} = m g h$, avec m en kg, g ≈ 9,8 N/kg et h en mètres.", chapter: 0),
            DemoCard(kind: .cloze, front: "Le rendement est le rapport entre l'énergie … et l'énergie fournie.", back: "utile", chapter: 2),
            DemoCard(kind: .choice, front: "Quelle est l'unité de l'énergie ?", back: "Le joule (J). Le watt mesure une puissance, c'est-à-dire une énergie par seconde.", choices: ["Le watt", "Le joule", "Le newton", "Le volt"], answerIndex: 1, chapter: 0),
        ]
    )
}
