import Foundation

// MARK: - Les quatre cours, en français

/// Le contenu des cours de démonstration, en français. Niveau lycée : ce qu'un professeur
/// écrirait au tableau, avec les définitions exactes, les mécanismes et les exemples.
///
/// **Quatre chapitres par cours, et du texte entre chaque objet.** Un schéma, un tableau ou
/// un graphe ne se lit qu'avec la phrase qui l'amène et celle qui en tire quelque chose :
/// deux objets qui se suivent sans un paragraphe entre eux se lisent comme une galerie, pas
/// comme une fiche. La règle ici est qu'aucun objet riche n'en touche un autre.
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
                .paragraph("En 1945, les vainqueurs de la guerre ne partagent plus rien. Les États-Unis et l'URSS, alliés contre l'Allemagne nazie, deviennent ==les deux superpuissances== d'un monde qui se coupe en deux. Tout ce qui suit — quarante-quatre ans de tension — se comprend à partir de cette rupture."),
                .heading("Un monde coupé en deux"),
                .paragraph("Les conférences de Yalta (février 1945) et de Potsdam (juillet 1945) devaient organiser la paix. Elles organisent en fait le partage : l'Europe de l'Est, libérée par l'Armée rouge, reste sous contrôle soviétique ; l'Europe de l'Ouest, libérée par les Anglo-Américains, entre dans l'orbite de Washington. Dès mars 1946, Churchill parle d'un **rideau de fer** tombé sur le continent."),
                .callout(
                    title: "Guerre froide",
                    text: "Un affrontement **sans guerre directe** entre les États-Unis et l'URSS, de 1947 à 1991, mené par la pression économique, la propagande, la course aux armements et des guerres par procuration.",
                    tone: .definition
                ),
                .paragraph("Le mot « froide » dit l'essentiel : les deux géants ne se battent jamais l'un contre l'autre. Ils s'affrontent partout ailleurs, et par tous les autres moyens. Ce qui les oppose n'est pas seulement une rivalité de puissance, c'est ==deux façons d'organiser une société==, incompatibles l'une avec l'autre."),
                .figure(.split(
                    title: "Deux modèles",
                    left: DemoColumn(title: "Bloc de l'Ouest", items: ["États-Unis", "Démocratie libérale", "Économie de marché", "Plan Marshall (1947)", "OTAN (1949)"]),
                    right: DemoColumn(title: "Bloc de l'Est", items: ["URSS", "Parti unique", "Économie planifiée", "Kominform (1947)", "Pacte de Varsovie (1955)"])
                )),
                .paragraph("À l'Ouest, des élections libres, plusieurs partis, une presse indépendante, et une économie où les entreprises sont privées et les prix libres. À l'Est, un seul parti, le Parti communiste, qui contrôle l'État, la presse et l'économie : c'est le plan, décidé à Moscou, qui fixe ce qu'on produit et à quel prix. Chaque camp se présente comme le monde libre, et décrit l'autre comme une menace."),
                .heading("L'endiguement"),
                .paragraph("En mars 1947, le président Truman promet d'aider tout pays menacé par le communisme : c'est la ==bleu|doctrine Truman==, ou *containment* — endiguer le communisme là où il est, sans chercher à le renverser là où il règne. Le plan Marshall, trois mois plus tard, finance la reconstruction de l'Europe de l'Ouest à hauteur de 13 milliards de dollars, et l'attache au camp américain. L'URSS répond en interdisant à ses satellites de l'accepter, et crée le Kominform pour coordonner les partis communistes."),
                .timeline(title: "Les premières années", events: [
                    DemoEvent(date: "1947", label: "Doctrine Truman et plan Marshall"),
                    DemoEvent(date: "1948", label: "Blocus de Berlin"),
                    DemoEvent(date: "1949", label: "Création de l'OTAN, première bombe soviétique"),
                    DemoEvent(date: "1950", label: "Début de la guerre de Corée"),
                ]),
                .paragraph("Berlin est la première épreuve de force. La ville, enfoncée dans la zone soviétique, est elle-même partagée en quatre secteurs. Quand les Occidentaux créent une monnaie commune pour leurs zones, en juin 1948, Staline coupe toutes les routes et voies ferrées vers Berlin-Ouest : deux millions d'habitants se retrouvent assiégés."),
                .callout(
                    title: "À retenir",
                    text: "Le blocus de Berlin (juin 1948 à mai 1949) est la première crise : l'URSS coupe les routes vers Berlin-Ouest, les Alliés répondent par un ==pont aérien== de onze mois — un avion toutes les deux minutes. Aucun coup de feu, et pourtant tout est dit.",
                    tone: .insight
                ),
                .paragraph("Le blocus échoue, et il fixe la règle du jeu pour quarante ans : chaque camp teste l'autre, mais aucun ne franchit la ligne qui mènerait à la guerre. En 1949, l'URSS fait exploser sa première bombe atomique, quatre ans après Hiroshima. Les deux camps ont désormais l'arme absolue, et c'est **l'équilibre de la terreur** qui s'installe."),
                .list([
                    "Rideau de fer : la frontière qui coupe l'Europe en deux, de la Baltique à l'Adriatique",
                    "Endiguement : la stratégie américaine, contenir sans attaquer",
                    "Satellite : un pays d'Europe de l'Est gouverné par un parti communiste aligné sur Moscou",
                ]),
                .paragraph("La guerre de Corée, en juin 1950, montre ce que devient un conflit dans ce cadre : le Nord communiste envahit le Sud, les Américains interviennent sous le drapeau de l'ONU, la Chine envoie ses « volontaires ». Trois ans de combats, deux millions de morts, et une frontière revenue exactement là où elle était. Le mot d'ordre de chaque camp est le même : ne pas céder un pouce, sans jamais tirer sur l'autre superpuissance."),
            ]),
            DemoChapter(title: "Crises et équilibre de la terreur (1953–1975)", blocks: [
                .paragraph("Après la mort de Staline (1953), Khrouchtchev propose la « coexistence pacifique » : les deux systèmes peuvent vivre côte à côte, et c'est l'économie qui dira lequel est le meilleur. Mais la coexistence n'empêche ni les crises ni la course aux armements. Chaque camp arme ses alliés et se bat **par procuration**, de la Corée au Vietnam."),
                .paragraph("La coexistence a ses limites, et Budapest les montre dès 1956 : quand la Hongrie tente de quitter le pacte de Varsovie, les chars soviétiques écrasent l'insurrection en quelques jours. Les Occidentaux protestent, et ne bougent pas. Chacun reste maître chez soi : c'est la règle non écrite de la guerre froide."),
                .table(title: "Les grandes crises", headers: ["Crise", "Date", "Ce qui se joue"], rows: [
                    ["Guerre de Corée", "1950–1953", "Le 38e parallèle, une Corée coupée en deux"],
                    ["Mur de Berlin", "1961", "L'Est mure sa population pour arrêter les fuites vers l'Ouest"],
                    ["Crise de Cuba", "1962", "Des missiles soviétiques à 150 km de la Floride"],
                    ["Guerre du Vietnam", "1955–1975", "Les États-Unis s'enlisent, puis se retirent"],
                ]),
                .heading("Berlin, encore"),
                .paragraph("Entre 1949 et 1961, près de trois millions d'Allemands de l'Est passent à l'Ouest, la plupart par Berlin, où il suffit de prendre le métro. La RDA se vide de ses médecins, de ses ingénieurs, de ses jeunes. Dans la nuit du 12 au 13 août 1961, elle ferme la frontière : des barbelés d'abord, puis un mur de béton, des miradors, une zone de tir. ==Le Mur== devient le symbole de toute la guerre froide, et de ce que vaut chaque camp aux yeux de l'autre."),
                .keyFigure(value: "13 jours", label: "la durée de la crise de Cuba, en octobre 1962, avant le retrait des missiles"),
                .paragraph("En octobre 1962, les avions espions américains photographient des rampes de missiles soviétiques à Cuba, à cent cinquante kilomètres de la Floride. Kennedy impose un blocus naval de l'île et exige leur retrait ; pendant treize jours, le monde retient son souffle. Khrouchtchev finit par retirer les missiles contre la promesse de ne pas envahir Cuba — et le retrait discret des missiles américains de Turquie. ==La dissuasion a tenu== : c'est le point le plus chaud de toute la guerre froide."),
                .figure(.flow(title: "La logique de la dissuasion", steps: ["Chaque camp a la bombe", "Frapper, c'est être frappé", "Personne ne frappe", "La guerre se joue ailleurs"])),
                .paragraph("Cette logique porte un nom : la **destruction mutuelle assurée**. Aucun des deux camps ne peut détruire l'autre sans être détruit en retour, donc aucun ne frappe le premier. La bombe, paradoxalement, devient une garantie de paix entre les deux géants — et c'est précisément pour ça que la guerre se déplace ailleurs, chez les alliés, où elle peut rester conventionnelle."),
                .callout(
                    title: "Par procuration",
                    text: "Le Vietnam en est l'exemple : les États-Unis soutiennent le Sud, l'URSS et la Chine le Nord. Une guerre réelle, des millions de morts, et jamais un soldat américain face à un soldat soviétique.",
                    tone: .example
                ),
                .paragraph("Les États-Unis s'engagent au Vietnam à partir de 1965 : plus de cinq cent mille soldats en 1968, des bombardements massifs, et une opinion publique qui se retourne quand les images arrivent à la télévision. Ils se retirent en 1973 ; Saïgon tombe en 1975. C'est la première guerre que l'Amérique perd, et elle la perd ==sans avoir jamais affronté l'URSS==."),
                .heading("La course partout"),
                .paragraph("L'affrontement se joue aussi dans le ciel, dans les laboratoires et dans les stades. Chaque satellite, chaque médaille, chaque record est présenté comme la preuve qu'un système vaut mieux que l'autre. La course à l'espace en est la vitrine : l'URSS prend l'avance, l'Amérique la rattrape en se donnant dix ans."),
                .list([
                    "1957 : Spoutnik, le premier satellite, ouvre la course à l'espace",
                    "1961 : Gagarine, premier homme dans l'espace",
                    "1963 : le téléphone rouge relie Washington à Moscou, leçon de Cuba",
                    "1969 : Apollo 11, l'Amérique marche sur la Lune",
                ]),
                .paragraph("Le téléphone rouge, installé après Cuba, résume la période : deux adversaires qui ne se font pas confiance, mais qui savent qu'un malentendu peut tout faire sauter. On se parle pour ne pas se battre. C'est de cette prudence que naît la détente des années 1970."),
            ]),
            DemoChapter(title: "De la détente à la chute du Mur (1975–1991)", blocks: [
                .paragraph("Les années 1970 desserrent l'étau. Les deux camps ont compris qu'ils ne gagneraient pas, et que la course aux armements coûte une fortune : ils négocient. Mais la ==rose|guerre fraîche== reprend en 1979, quand l'URSS envahit l'Afghanistan et que Reagan relance la course aux armements."),
                .heading("La détente"),
                .paragraph("Les accords SALT (1972) limitent pour la première fois le nombre de missiles nucléaires. La conférence d'Helsinki (1975) reconnaît les frontières issues de la guerre — ce que voulait Moscou — en échange d'un engagement sur les droits de l'homme, que les dissidents de l'Est vont brandir pendant quinze ans. Nixon se rend à Pékin et à Moscou ; le commerce reprend ; les deux Allemagnes se reconnaissent."),
                .paragraph("Le répit est court. En décembre 1979, l'Armée rouge entre en Afghanistan pour soutenir un régime communiste chancelant : dix ans de guerre, un million de morts, et l'URSS enlisée dans son Vietnam. Les États-Unis boycottent les Jeux de Moscou, arment la résistance afghane, et Ronald Reagan, élu en 1980, qualifie l'URSS d'« empire du mal ». Son projet de bouclier spatial, l'IDS, lance une course technologique que Moscou ne peut plus suivre."),
                .paragraph("En 1985, Mikhaïl Gorbatchev arrive au pouvoir dans une URSS à bout de souffle : les rayons des magasins sont vides, l'industrie est vétuste, l'armée absorbe une part énorme des richesses. Il lance la **perestroïka** (restructuration de l'économie) et la **glasnost** (transparence dans la vie publique), négocie le désarmement avec Reagan, et cesse de soutenir les régimes communistes d'Europe de l'Est : chacun sera désormais responsable de son destin."),
                .timeline(title: "La fin", events: [
                    DemoEvent(date: "1985", label: "Gorbatchev au pouvoir"),
                    DemoEvent(date: "1987", label: "Traité de Washington : fin des euromissiles"),
                    DemoEvent(date: "9 nov. 1989", label: "Chute du mur de Berlin"),
                    DemoEvent(date: "1990", label: "Réunification allemande"),
                    DemoEvent(date: "25 déc. 1991", label: "Dissolution de l'URSS"),
                ]),
                .paragraph("L'année 1989 emporte tout. En Pologne, le syndicat Solidarność gagne des élections libres en juin. En Hongrie, le gouvernement ouvre sa frontière avec l'Autriche en septembre : les Allemands de l'Est s'y engouffrent par milliers. En RDA, les manifestations du lundi à Leipzig rassemblent des centaines de milliers de personnes, et le régime, sans le soutien de Moscou, ne peut plus tirer."),
                .heading("Pourquoi l'URSS a perdu"),
                .paragraph("La guerre froide s'est jouée sur l'économie autant que sur les armes. L'URSS consacrait à son armée une part de ses richesses que les États-Unis n'ont jamais eu besoin d'atteindre, avec une économie deux fois plus petite. Chaque missile de plus était un hôpital ou une usine de moins, et la population le savait."),
                .bars(title: "Dépenses militaires en part du PIB, vers 1985 (estimation)", unit: "%", bars: [
                    DemoBar(label: "États-Unis", value: 6),
                    DemoBar(label: "URSS", value: 15),
                    DemoBar(label: "France", value: 4),
                ]),
                .paragraph("Le graphique se lit en un coup d'œil : à effort militaire comparable, l'URSS y sacrifie plus du double de ce que les États-Unis y consacrent. C'est cet épuisement que Gorbatchev tente d'enrayer — et c'est en desserrant l'étau qu'il libère les forces qui vont dissoudre le système."),
                .callout(
                    title: "Pourquoi le Mur tombe",
                    text: "Sans le soutien de Moscou, les régimes de l'Est s'effondrent l'un après l'autre en 1989. Le 9 novembre, un porte-parole de la RDA annonce, par erreur, que les frontières sont ouvertes « immédiatement » : en une nuit, des dizaines de milliers de Berlinois passent, et le symbole de la division disparaît.",
                    tone: .insight
                ),
                .paragraph("L'Allemagne se réunifie en octobre 1990, sous la protection de l'OTAN — ce que Moscou aurait refusé cinq ans plus tôt. À l'intérieur de l'URSS, les républiques réclament leur indépendance ; un coup d'État manqué en août 1991 achève de discréditer le parti. Le 25 décembre 1991, le drapeau soviétique est descendu du Kremlin. La guerre froide se termine ==sans bataille==, par l'épuisement d'un des deux camps."),
            ]),
            DemoChapter(title: "Comprendre la guerre froide", blocks: [
                .paragraph("Quarante-quatre ans, des dizaines de crises, des centaines de dates : la guerre froide ne se retient pas date par date, elle se comprend par ses mécanismes. Ce chapitre rassemble ==le vocabulaire, les logiques et la méthode== pour en parler à l'épreuve."),
                .heading("Le vocabulaire"),
                .paragraph("Chaque mot ci-dessous désigne un mécanisme précis, et l'employer à la place d'un autre est une erreur de compréhension, pas de vocabulaire. « Détente » n'est pas « paix », « endiguement » n'est pas « attaque », « satellite » n'est pas « allié »."),
                .table(title: "Les mots à savoir", headers: ["Mot", "Ce qu'il veut dire"], rows: [
                    ["Rideau de fer", "La frontière fermée qui coupe l'Europe en deux"],
                    ["Endiguement", "Contenir le communisme sans l'attaquer là où il règne"],
                    ["Dissuasion", "Ne pas frapper parce qu'on serait frappé en retour"],
                    ["Guerre par procuration", "Une guerre menée par des alliés, pas par les deux géants"],
                    ["Détente", "Le relâchement des tensions, dans les années 1970"],
                    ["Satellite", "Un pays de l'Est gouverné par un parti aligné sur Moscou"],
                ]),
                .paragraph("Ces mots décrivent un même cycle, qui se répète de 1947 à 1991. Une tension monte, une crise éclate, les deux camps négocient parce qu'aucun ne veut la guerre, la tension retombe — puis une nouvelle crise repart d'ailleurs. Berlin, Cuba, le Vietnam, l'Afghanistan : c'est toujours la même boucle."),
                .figure(.cycle(title: "Le cycle des crises", nodes: ["La tension monte", "Une crise éclate", "On négocie", "La tension retombe"])),
                .paragraph("Comprendre ce cycle, c'est pouvoir expliquer n'importe quelle crise sans l'avoir apprise par cœur : qui teste qui, jusqu'où, et pourquoi ça s'arrête avant la guerre. La réponse est presque toujours la même — **la dissuasion nucléaire** —, et c'est elle qui distingue la guerre froide de toutes les rivalités d'avant."),
                .heading("À l'épreuve"),
                .callout(
                    title: "Méthode",
                    text: "Pour une composition : 1. Un plan en trois temps — la formation des blocs, les crises et la coexistence, la détente et la fin. 2. Une date et un exemple précis par idée. 3. Une conclusion qui répond à la question : pourquoi « froide », et pourquoi elle finit sans guerre.",
                    tone: .insight
                ),
                .paragraph("Pour une analyse de document, la question à se poser d'abord est celle du point de vue : qui parle, de quel camp, à quel moment du cycle ? Une affiche soviétique de 1950 et un discours de Kennedy de 1963 ne disent pas la même chose, et c'est précisément leur différence qu'on attend que vous expliquiez."),
                .callout(
                    title: "L'erreur classique",
                    text: "Écrire que les États-Unis et l'URSS se sont fait la guerre. Ils ne se sont **jamais** affrontés directement : c'est la définition même de la guerre froide, et c'est ce que la dissuasion explique.",
                    tone: .warning
                ),
                .list([
                    "1947 : doctrine Truman, plan Marshall — les blocs se forment",
                    "1949 : OTAN, bombe soviétique — l'équilibre de la terreur commence",
                    "1961 : le Mur — la division devient concrète",
                    "1962 : Cuba — la dissuasion tient",
                    "1975 : Helsinki — la détente",
                    "1989 : le Mur tombe — la fin",
                    "1991 : l'URSS disparaît",
                ]),
                .paragraph("Sept dates suffisent pour tenir toute la période, à condition de savoir ce que chacune ouvre ou ferme. Apprenez-les avec leur mécanisme, pas seulement avec leur événement : c'est ce lien qui fait la différence entre réciter une frise et ==expliquer une époque==."),
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
            DemoCard(kind: .basic, front: "Pourquoi les États-Unis et l'URSS ne se sont-ils jamais affrontés directement ?", back: "À cause de la dissuasion nucléaire : chaque camp pouvant détruire l'autre, frapper le premier reviendrait à être frappé en retour. La guerre se joue donc par procuration, chez les alliés.", chapter: 3),
            DemoCard(kind: .cloze, front: "Le relâchement des tensions entre les deux blocs dans les années 1970 s'appelle la … .", back: "détente", chapter: 3),
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
                .paragraph("Une feuille est une usine : elle prend de la lumière, de l'eau et du dioxyde de carbone, et en fait ==du sucre et du dioxygène==. Ce processus s'appelle la photosynthèse, et il nourrit presque toute la vie sur Terre — y compris nous, qui mangeons les plantes ou les animaux qui les mangent."),
                .heading("Une feuille, vue de près"),
                .paragraph("La feuille est faite pour ce travail. Elle est plate et fine, pour offrir le plus de surface possible à la lumière. Sa face inférieure est percée de milliers de **stomates**, de minuscules pores qui s'ouvrent le jour pour laisser entrer le CO₂ de l'air et sortir le dioxygène. Entre les deux faces, des cellules bourrées de chloroplastes ; et des nervures qui apportent l'eau des racines et emportent le sucre fabriqué."),
                .callout(
                    title: "Photosynthèse",
                    text: "La synthèse de matière organique (glucose) par les végétaux chlorophylliens, à partir de matière minérale (CO₂ et eau), grâce à l'énergie lumineuse.",
                    tone: .definition
                ),
                .paragraph("La définition tient en une équation. Six molécules de dioxyde de carbone et six molécules d'eau donnent une molécule de glucose et six molécules de dioxygène. Rien ne se crée : les atomes de carbone du sucre viennent du CO₂ de l'air, l'oxygène rejeté vient de l'eau. C'est ==l'énergie de la lumière== qui rend l'assemblage possible."),
                .formula("6\\,CO_2 + 6\\,H_2O \\rightarrow C_6H_{12}O_6 + 6\\,O_2", caption: "L'équation bilan, sous l'action de la lumière"),
                .paragraph("Tout se passe dans les **chloroplastes**, des organites verts qu'on trouve par dizaines dans chaque cellule du parenchyme de la feuille. Leur couleur vient de la ==menthe|chlorophylle==, le pigment qui absorbe la lumière rouge et bleue, et renvoie le vert. C'est le seul endroit de la cellule où la lumière est captée : sans chloroplaste, pas de photosynthèse."),
                .heading("Du photon au sucre"),
                .paragraph("Ce qui se passe à l'intérieur peut se résumer en quatre étapes, qui s'enchaînent en une fraction de seconde. La lumière frappe la chlorophylle ; l'énergie reçue sert à casser des molécules d'eau, ce qui libère le dioxygène ; cette énergie est stockée sous une forme que la cellule sait utiliser, l'ATP ; et l'ATP sert enfin à fixer le CO₂ pour en faire du glucose."),
                .figure(.flow(title: "Du photon au sucre", steps: ["La chlorophylle absorbe la lumière", "L'eau est cassée : O₂ libéré", "L'énergie est stockée (ATP)", "Le CO₂ est fixé en glucose"])),
                .paragraph("Toutes les couleurs de la lumière ne se valent pas pour la feuille. La lumière blanche du Soleil est un mélange ; la chlorophylle en capte surtout les deux bouts du spectre — le bleu et le rouge — et laisse passer le milieu. On le mesure en éclairant une solution de chlorophylle couleur par couleur, et en regardant ce qui traverse."),
                .bars(title: "Ce que la chlorophylle absorbe, selon la couleur", unit: "%", bars: [
                    DemoBar(label: "Bleu", value: 90),
                    DemoBar(label: "Vert", value: 15),
                    DemoBar(label: "Rouge", value: 80),
                ]),
                .paragraph("Le graphique se lit d'un coup : neuf photons bleus sur dix sont captés, huit rouges sur dix, et à peine un vert sur six. Le vert n'est pas tout à fait perdu — quelques pigments secondaires, les caroténoïdes, en prennent un peu —, mais l'essentiel repart d'où il vient."),
                .callout(
                    title: "Pourquoi les feuilles sont vertes",
                    text: "Parce que le vert est la couleur que la chlorophylle **n'absorbe pas** : elle le réfléchit vers nos yeux. Une feuille est verte pour la même raison qu'un tissu rouge est rouge — c'est la couleur qu'elle rejette.",
                    tone: .insight
                ),
                .paragraph("Une expérience simple le montre : une plante cultivée sous une lumière verte pousse mal, une plante sous lumière rouge ou bleue pousse bien. C'est pour ça que les serres modernes éclairent leurs cultures en rose, mélange de rouge et de bleu — pas un photon n'est gaspillé sur du vert que la plante n'utiliserait pas."),
                .paragraph("On peut aussi vérifier que la feuille fabrique bien du sucre. Une feuille exposée à la lumière, décolorée puis trempée dans de l'eau iodée, vire au bleu-noir : elle contient de l'amidon, la forme sous laquelle la plante stocke son glucose. Une feuille gardée dans le noir reste jaune : ==sans lumière, pas de sucre==."),
            ]),
            DemoChapter(title: "Fabriquer le glucose", blocks: [
                .paragraph("La photosynthèse se déroule en deux temps, dans deux endroits du chloroplaste. La **phase claire** a besoin de lumière : elle casse l'eau, libère le dioxygène et stocke l'énergie. La **phase sombre** n'en a pas besoin directement : elle utilise cette énergie pour fixer le CO₂ et fabriquer le glucose. La première produit le carburant, la seconde le dépense."),
                .heading("La phase claire"),
                .paragraph("Elle se joue dans les **thylakoïdes**, des sacs membraneux empilés à l'intérieur du chloroplaste, où la chlorophylle est ancrée. Quand un photon frappe une molécule de chlorophylle, il arrache un électron, et cet électron est remplacé en cassant une molécule d'eau : c'est la **photolyse de l'eau**. L'oxygène de l'eau est rejeté sous forme de dioxygène — celui que nous respirons —, et l'énergie de l'électron sert à fabriquer de l'ATP, la monnaie énergétique de toute cellule vivante."),
                .table(title: "Les deux phases", headers: ["", "Phase claire", "Phase sombre"], rows: [
                    ["Où", "Membranes des thylakoïdes", "Stroma du chloroplaste"],
                    ["Lumière", "Indispensable", "Pas directement"],
                    ["Entrée", "Eau, lumière", "CO₂, ATP"],
                    ["Sortie", "O₂, ATP", "Glucose"],
                ]),
                .paragraph("Le tableau se lit en colonnes : ce qui sort de la phase claire — l'ATP — est exactement ce dont la phase sombre a besoin. Les deux phases sont donc liées : la seconde s'arrête dès que la première cesse de la fournir, ce qui arrive quelques minutes après le coucher du soleil."),
                .heading("Le cycle de Calvin"),
                .paragraph("La phase sombre se joue dans le **stroma**, le liquide qui baigne les thylakoïdes. Elle porte le nom du chimiste qui l'a décrite en 1950 en suivant du carbone radioactif à la trace : Melvin Calvin. C'est un cycle, c'est-à-dire une suite de réactions qui revient à son point de départ, en ayant fabriqué du sucre au passage."),
                .figure(.cycle(title: "Le cycle de Calvin", nodes: ["Fixation du CO₂", "Réduction avec l'ATP", "Formation de sucre", "Régénération de l'accepteur"])),
                .paragraph("À chaque tour, une molécule de CO₂ est fixée sur une molécule d'accueil, l'accepteur, par une enzyme appelée RuBisCO — la protéine la plus abondante de la planète. Le composé obtenu est réduit grâce à l'ATP de la phase claire, et une part du produit sort du cycle pour faire ==du glucose==, pendant que le reste régénère l'accepteur pour le tour suivant. Il faut **six tours** pour une molécule de glucose : une par atome de carbone."),
                .keyFigure(value: "6 tours", label: "de cycle de Calvin pour fabriquer une seule molécule de glucose"),
                .paragraph("Le glucose fabriqué ne reste pas glucose longtemps. La plante l'assemble en **amidon** pour le stocker dans la feuille ou dans un tubercule — c'est l'amidon de la pomme de terre —, en **saccharose** pour le transporter par la sève jusqu'aux racines et aux fruits, ou en **cellulose** pour construire ses parois. Le bois d'un arbre est du sucre empilé pendant des décennies."),
                .callout(
                    title: "Piège classique",
                    text: "La phase sombre ne se passe pas « la nuit » : elle se déroule le jour aussi, dès que la phase claire lui fournit de l'énergie. « Sombre » veut dire qu'elle n'utilise pas la lumière directement — pas qu'elle attend l'obscurité.",
                    tone: .warning
                ),
                .list([
                    "Phase claire : thylakoïdes, lumière, eau cassée, O₂ rejeté, ATP produit",
                    "Phase sombre : stroma, cycle de Calvin, CO₂ fixé, glucose fabriqué",
                    "Six tours de cycle par molécule de glucose, un par atome de carbone",
                ]),
                .paragraph("Retenez le fil plutôt que les noms : la lumière devient de l'énergie chimique, l'énergie chimique devient du sucre, et le sucre devient tout le reste de la plante. Chaque étape a son lieu et son carburant, et ==aucune ne marche sans la précédente==."),
            ]),
            DemoChapter(title: "La photosynthèse et la planète", blocks: [
                .paragraph("Chaque année, les végétaux fixent environ ==120 milliards de tonnes de carbone==. La photosynthèse est le point d'entrée de la matière organique dans les chaînes alimentaires, et la source de tout le dioxygène que nous respirons. À l'échelle de la planète, c'est le processus qui fait tourner le cycle du carbone."),
                .heading("Le cycle du carbone"),
                .paragraph("Le carbone circule entre l'air, les êtres vivants et le sol, et la photosynthèse en est l'un des deux moteurs. Elle prélève le CO₂ de l'atmosphère et l'enferme dans la matière des plantes. La respiration et la décomposition font le chemin inverse : elles brûlent cette matière et rendent le CO₂ à l'air. Tant que les deux s'équilibrent, la quantité de CO₂ dans l'atmosphère reste stable."),
                .figure(.cycle(title: "Le cycle du carbone", nodes: ["CO₂ dans l'atmosphère", "Photosynthèse : fixé dans les plantes", "Respiration, décomposition", "Retour dans l'atmosphère"])),
                .paragraph("Les plantes sont les **producteurs primaires** : elles fabriquent la matière organique dont tous les autres vivent. Un herbivore mange la plante, un carnivore mange l'herbivore, et à chaque étape le carbone passe d'un organisme à l'autre. Sans photosynthèse, la chaîne n'a pas de premier maillon."),
                .heading("Ce qui la commande"),
                .paragraph("Trois facteurs commandent l'intensité de la photosynthèse : la lumière, la concentration en CO₂ et la température. Quand l'un d'eux manque, augmenter les autres ne sert à rien : c'est le **facteur limitant**, celui qui fixe le rythme de tout le reste, comme le maillon le plus lent d'une chaîne de montage."),
                .figure(.plot(title: "La lumière, jusqu'à un plafond", caption: "Plus de lumière accélère la photosynthèse, jusqu'à un plateau : au-delà, c'est le CO₂ ou la température qui limite.", kind: .saturation)),
                .paragraph("La courbe se lit en deux parties. Au début, elle monte : chaque photon de plus est utilisé, la lumière est le facteur limitant. Puis elle s'aplatit : la plante reçoit plus de lumière qu'elle ne peut en utiliser, et c'est le CO₂ disponible — ou la vitesse des enzymes, qui dépend de la température — qui bride le rythme. Ajouter de la lumière sur le plateau ne change plus rien."),
                .list([
                    "Lumière : plus il y en a, plus la photosynthèse s'accélère, jusqu'à saturation",
                    "CO₂ : à 0,04 % dans l'air, souvent le facteur limitant en plein jour",
                    "Température : un optimum vers 25 à 30 °C, les enzymes s'arrêtent au-delà",
                ]),
                .callout(
                    title: "Dans une serre",
                    text: "Les maraîchers enrichissent parfois l'air en CO₂, jusqu'à trois fois sa concentration naturelle : sous une forte lumière, c'est lui qui bride la croissance, et l'ajouter fait pousser les tomates plus vite.",
                    tone: .example
                ),
                .paragraph("Le même raisonnement explique pourquoi les plantes poussent peu en hiver, même par beau temps : la lumière est là, mais la température bride les enzymes. Et pourquoi une plante d'appartement dépérit loin de la fenêtre : la température est bonne, mais la lumière manque. ==Identifier le facteur limitant==, c'est savoir ce qu'il faut changer."),
                .heading("Les poumons de la planète"),
                .paragraph("On dit souvent que les forêts sont les poumons de la Terre. C'est à moitié vrai : les forêts fixent bien du carbone, mais près de la moitié de la photosynthèse mondiale se fait dans les océans, par le **phytoplancton** — des algues microscopiques en suspension. Un litre d'eau de mer en contient des millions, et c'est à elles que nous devons un souffle sur deux."),
                .keyFigure(value: "≈ 50 %", label: "du dioxygène produit chaque année sur Terre vient du phytoplancton des océans"),
                .paragraph("C'est aussi pour ça que la photosynthèse est au cœur de la question climatique. Depuis deux siècles, nous rendons à l'air, en brûlant charbon et pétrole, du carbone que la photosynthèse avait enfermé sous terre il y a des millions d'années. Les plantes et les océans en réabsorbent une partie, mais pas tout : l'équilibre du cycle est rompu, et le CO₂ s'accumule."),
            ]),
            DemoChapter(title: "Photosynthèse et respiration", blocks: [
                .paragraph("La photosynthèse fabrique du sucre ; la **respiration** le brûle. Les deux processus sont ==l'inverse l'un de l'autre==, et une plante fait les deux — y compris en plein jour. Confondre les deux est l'erreur la plus fréquente sur ce chapitre, et ce chapitre existe pour qu'elle ne vous arrive pas."),
                .heading("Le chemin inverse"),
                .paragraph("La respiration cellulaire prend du glucose et du dioxygène, et libère du CO₂, de l'eau et surtout de l'énergie, sous forme d'ATP. C'est ce que fait chacune de nos cellules, en permanence, et c'est aussi ce que fait chaque cellule végétale : une plante a besoin d'énergie pour pousser, transporter sa sève, ouvrir ses stomates — et elle la tire de son propre sucre."),
                .formula("C_6H_{12}O_6 + 6\\,O_2 \\rightarrow 6\\,CO_2 + 6\\,H_2O + \\text{énergie}", caption: "La respiration : l'équation de la photosynthèse, lue à l'envers"),
                .paragraph("Les deux équations sont symétriques, mais elles ne se passent ni au même endroit ni au même rythme. La photosynthèse est dans les chloroplastes, et seulement à la lumière ; la respiration est dans les **mitochondries**, et tout le temps. Le tableau met les deux face à face."),
                .table(title: "Face à face", headers: ["", "Photosynthèse", "Respiration"], rows: [
                    ["Où", "Chloroplastes", "Mitochondries"],
                    ["Quand", "À la lumière", "Jour et nuit"],
                    ["Consomme", "CO₂, eau, lumière", "Glucose, O₂"],
                    ["Produit", "Glucose, O₂", "CO₂, eau, ATP"],
                    ["Qui", "Végétaux, algues", "Tous les êtres vivants"],
                ]),
                .paragraph("Le jour, une plante fait les deux à la fois, mais la photosynthèse l'emporte largement : elle fixe bien plus de CO₂ que la respiration n'en rejette, et le bilan est un gain de matière. La nuit, seule la respiration continue : la plante consomme un peu de son sucre et rejette un peu de CO₂. Sur vingt-quatre heures, le bilan reste très positif — c'est ce qui fait grandir la plante."),
                .callout(
                    title: "Piège classique",
                    text: "« Les plantes respirent la nuit et font la photosynthèse le jour. » Faux : elles respirent **tout le temps**. Le jour, la photosynthèse masque simplement la respiration, parce qu'elle est beaucoup plus intense.",
                    tone: .warning
                ),
                .heading("D'où vient l'énergie"),
                .paragraph("Mis bout à bout, les deux processus racontent le trajet de l'énergie dans le vivant. Elle arrive du Soleil ; la photosynthèse la stocke dans les liaisons du glucose ; la respiration la libère sous forme d'ATP ; et l'ATP paie tout le travail de la cellule. Chaque calorie que vous dépensez a été, un jour, un photon capté par une feuille."),
                .figure(.flow(title: "Le trajet de l'énergie", steps: ["Lumière du Soleil", "Glucose (photosynthèse)", "ATP (respiration)", "Travail de la cellule"])),
                .paragraph("Ce trajet sépare les êtres vivants en deux familles. Les **autotrophes** — les plantes, les algues, certaines bactéries — fabriquent leur propre matière organique à partir de matière minérale : ils n'ont besoin que de lumière, d'eau et de CO₂. Les **hétérotrophes** — les animaux, les champignons, nous — ne savent pas le faire : ils doivent manger de la matière organique déjà fabriquée, directement ou non, par un autotrophe."),
                .callout(
                    title: "Autotrophe, hétérotrophe",
                    text: "Un organisme **autotrophe** produit sa matière organique à partir de matière minérale ; un organisme **hétérotrophe** doit la prélever sur d'autres êtres vivants. Toute chaîne alimentaire commence par un autotrophe.",
                    tone: .definition
                ),
                .list([
                    "Photosynthèse : fabrique le glucose, à la lumière, dans les chloroplastes",
                    "Respiration : brûle le glucose, tout le temps, dans les mitochondries",
                    "Le jour, la photosynthèse l'emporte ; la nuit, seule la respiration continue",
                    "Autotrophes en tête de chaîne, hétérotrophes derrière",
                ]),
                .paragraph("Ce dernier point est la clé de tout le chapitre, et de bien d'autres : la vie sur Terre fonctionne à l'énergie solaire, ==convertie une seule fois==, par la photosynthèse, puis transmise de bouche en bouche le long des chaînes alimentaires. Tout le reste — respirer, courir, penser — est une façon de dépenser cette énergie-là."),
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
            DemoCard(kind: .basic, front: "Quelle est la différence entre la photosynthèse et la respiration ?", back: "La photosynthèse fabrique du glucose à partir de CO₂ et d'eau, à la lumière, dans les chloroplastes. La respiration brûle ce glucose avec du dioxygène pour libérer de l'énergie (ATP), tout le temps, dans les mitochondries.", chapter: 3),
            DemoCard(kind: .cloze, front: "Un organisme qui fabrique sa propre matière organique à partir de matière minérale est dit … .", back: "autotrophe", chapter: 3),
        ]
    )

    // MARK: Mathématiques : les dérivées

    private static let derivativesFR = OnboardingDemoCourse(
        id: "maths-derivatives",
        emoji: "📐",
        subject: "Mathématiques",
        title: "Les dérivées",
        summary: "Le nombre dérivé, la tangente, les dérivées usuelles et les règles de calcul, le signe de la dérivée qui donne les variations, et les problèmes d'optimisation.",
        accentIndex: 0,
        chapters: [
            DemoChapter(title: "Le nombre dérivé et la tangente", blocks: [
                .paragraph("Dériver, c'est mesurer ==la vitesse à laquelle une fonction change==. Sur une courbe, cette vitesse se voit : c'est la pente de la tangente au point qu'on regarde. Tout le chapitre tient dans cette idée, et le reste n'est que du calcul."),
                .heading("Le taux de variation"),
                .paragraph("Avant la vitesse instantanée, il y a la vitesse moyenne. Entre deux points d'abscisses $a$ et $a+h$, la fonction a varié de $f(a+h) - f(a)$ pendant que $x$ variait de $h$. Le rapport des deux est le **taux de variation** : c'est la pente de la droite qui relie les deux points de la courbe, la sécante."),
                .formula("\\frac{f(a+h) - f(a)}{h}", caption: "Le taux de variation de f entre a et a + h : la pente de la sécante"),
                .paragraph("Ce taux dépend de $h$ : plus les deux points sont proches, plus la sécante ressemble à la courbe elle-même autour de $a$. L'idée de la dérivée est de faire tendre $h$ vers zéro — de rapprocher les deux points jusqu'à ce qu'ils se confondent — et de regarder vers quoi tend la pente."),
                .callout(
                    title: "Nombre dérivé",
                    text: "Le nombre dérivé de $f$ en $a$, noté $f'(a)$, est la limite du taux de variation entre $a$ et $a+h$ quand $h$ tend vers 0. Quand cette limite existe, on dit que $f$ est **dérivable** en $a$.",
                    tone: .definition
                ),
                .formula("f'(a) = \\lim_{h \\to 0} \\frac{f(a+h) - f(a)}{h}", caption: "Le taux de variation, quand h devient infiniment petit"),
                .paragraph("Géométriquement, quand les deux points se rejoignent, la sécante devient ==la tangente== : la droite qui touche la courbe en $a$ en épousant sa direction. Le nombre dérivé est sa pente. Une pente forte, positive, dit que la courbe monte vite ; une pente nulle, que la courbe est horizontale à cet endroit."),
                .figure(.plot(title: "La tangente en un point", caption: "La droite qui « colle » à la courbe en $a$ : sa pente est $f'(a)$.", kind: .tangent)),
                .paragraph("Connaître la pente et un point suffit à écrire la droite. L'équation de la tangente en $a$ s'écrit $y = f'(a)(x - a) + f(a)$ : une droite qui passe par le point $(a, f(a))$ avec la pente $f'(a)$. C'est une formule à savoir par cœur, parce qu'elle tombe à presque tous les contrôles."),
                .callout(
                    title: "Exemple",
                    text: "Pour $f(x) = x^2$ en $a = 1$ : le taux de variation vaut $\\frac{(1+h)^2 - 1}{h} = 2 + h$, qui tend vers $2$. Donc $f'(1) = 2$, et la tangente est $y = 2(x - 1) + 1 = 2x - 1$.",
                    tone: .example
                ),
                .paragraph("Le signe du nombre dérivé se lit directement sur la courbe, et c'est ce qui fera tout le chapitre trois. Une tangente qui monte de gauche à droite a une pente positive ; une tangente qui descend, une pente négative ; une tangente horizontale, une pente nulle — et c'est souvent là qu'il se passe quelque chose."),
                .list([
                    "$f'(a) > 0$ : la courbe monte en $a$",
                    "$f'(a) < 0$ : elle descend",
                    "$f'(a) = 0$ : tangente horizontale, souvent un sommet ou un creux",
                ]),
                .heading("Pourquoi ça compte"),
                .paragraph("La dérivée n'est pas qu'un objet de cours : elle est partout où quelque chose varie. La vitesse est la dérivée de la position par rapport au temps ; l'accélération, la dérivée de la vitesse. En économie, le coût marginal est la dérivée du coût total. Quand un physicien ou un économiste demande « à quel rythme ? », il demande une dérivée."),
                .paragraph("C'est aussi pour ça que la notion a été inventée deux fois, au XVIIe siècle, par Newton pour décrire le mouvement des planètes et par Leibniz pour la géométrie des courbes. Deux problèmes, une seule idée : ==regarder ce qui se passe infiniment près d'un point==."),
            ]),
            DemoChapter(title: "Calculer une dérivée", blocks: [
                .paragraph("On ne calcule presque jamais une limite à la main : on apprend **les dérivées usuelles**, et les règles qui les combinent. Avec un tableau de huit lignes et trois règles, on dérive n'importe quelle fonction du programme — et c'est un exercice qui doit devenir un réflexe."),
                .heading("Les dérivées usuelles"),
                .paragraph("Chaque ligne du tableau se démontre avec la définition du chapitre précédent, et il est bon de l'avoir fait au moins une fois pour $x^2$. Mais à l'usage, on les connaît par cœur. La ligne la plus importante est celle de $x^n$ : la puissance descend en facteur, et l'exposant perd un."),
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
                .paragraph("Deux lignes méritent une remarque. La dérivée d'une constante est nulle : une fonction qui ne change pas a une vitesse nulle, ce qui est logique. Et la dérivée de $e^x$ est $e^x$ elle-même : c'est ==la seule fonction== qui est sa propre dérivée, et c'est exactement pour ça que l'exponentielle est partout en physique — elle décrit tout ce qui croît à un rythme proportionnel à sa taille."),
                .heading("Les règles"),
                .callout(
                    title: "Les trois règles",
                    text: "**Somme** : $(u+v)' = u' + v'$. **Produit** : $(uv)' = u'v + uv'$. **Quotient** : $(u/v)' = (u'v - uv')/v^2$. Et pour une constante $k$ : $(ku)' = ku'$.",
                    tone: .insight
                ),
                .paragraph("La règle de la somme est la plus naturelle : on dérive terme à terme. Exemple : $f(x) = 3x^2 - 5x + 2$ donne $f'(x) = 6x - 5$. Les constantes s'effacent, ==les puissances descendent d'un cran==, les coefficients restent en facteur. Une fonction polynôme se dérive ainsi en une ligne."),
                .formula("(uv)' = u'v + uv'", caption: "La dérivée d'un produit : chaque facteur dérivé à son tour, et on additionne"),
                .paragraph("La règle du produit demande un peu plus de soin. Pour $f(x) = x^2 e^x$, on pose $u = x^2$ et $v = e^x$, donc $u' = 2x$ et $v' = e^x$ : $f'(x) = 2x\\,e^x + x^2 e^x = (2x + x^2)\\,e^x$. On dérive le premier en gardant le second, puis l'inverse, et on additionne. Factoriser à la fin n'est pas une coquetterie : c'est ce qui permettra d'étudier le signe."),
                .callout(
                    title: "L'erreur à ne pas faire",
                    text: "$(uv)' \\neq u'v'$. La dérivée d'un produit **n'est pas** le produit des dérivées : $(x \\cdot x)' = 2x$, pas $1 \\cdot 1$. Même chose pour le quotient.",
                    tone: .warning
                ),
                .paragraph("Le quotient suit la même logique, avec un signe moins et un carré au dénominateur. Pour $f(x) = \\frac{x}{x+1}$ : $u = x$, $v = x + 1$, donc $f'(x) = \\frac{1 \\cdot (x+1) - x \\cdot 1}{(x+1)^2} = \\frac{1}{(x+1)^2}$. Le numérateur se simplifie souvent beaucoup — quand ce n'est pas le cas, vérifiez le calcul."),
                .heading("Une fonction dans une autre"),
                .paragraph("Il reste le cas où une fonction est emboîtée dans une autre : $(2x+1)^3$, $\\sqrt{x^2+1}$, $e^{-x}$. On dérive l'extérieur en gardant l'intérieur, puis on multiplie par la dérivée de l'intérieur. Pour une puissance, ça donne la formule ci-dessous ; pour l'exponentielle, $(e^{u})' = u'\\,e^{u}$."),
                .formula("(u^n)' = n\\,u'\\,u^{n-1}", caption: "Dériver une puissance d'une fonction : l'extérieur, fois la dérivée de l'intérieur"),
                .paragraph("Exemple : $f(x) = (2x+1)^3$. L'intérieur est $u = 2x+1$, de dérivée $u' = 2$ ; donc $f'(x) = 3 \\cdot 2 \\cdot (2x+1)^2 = 6(2x+1)^2$. Oublier le facteur $u'$ est l'erreur la plus fréquente de tout le chapitre : la dérivée de l'intérieur ==ne s'oublie pas==."),
                .list([
                    "Repérer la forme : somme, produit, quotient, ou fonction emboîtée",
                    "Dériver chaque morceau avec le tableau",
                    "Assembler avec la bonne règle",
                    "Simplifier et factoriser, puis vérifier le signe",
                ], ordered: true),
                .paragraph("Ces quatre étapes sont la même routine pour toutes les fonctions. Avec de l'entraînement, elles se font en tête ; sans, elles se font au brouillon. Dans les deux cas, la dernière — factoriser — est celle qui prépare le chapitre suivant."),
            ]),
            DemoChapter(title: "Dérivée et variations", blocks: [
                .paragraph("Le signe de la dérivée dit ==dans quel sens la fonction varie== : positive, elle monte ; négative, elle descend. C'est la clé de tous les tableaux de variations, et la raison pour laquelle on a appris à dériver."),
                .heading("Le théorème"),
                .paragraph("Si $f'$ est positive sur un intervalle, $f$ est croissante sur cet intervalle ; si $f'$ est négative, $f$ est décroissante ; si $f'$ est nulle sur tout l'intervalle, $f$ est constante. L'intuition est celle du chapitre un : une pente positive partout, c'est une courbe qui monte partout."),
                .figure(.plot(title: "Signe de f′ et sens de f", caption: "Là où $f'$ est positive, $f$ monte ; là où elle s'annule en changeant de signe, $f$ atteint un extremum.", kind: .variation)),
                .paragraph("Le graphique montre les deux courbes l'une sous l'autre. Tant que $f'$ est au-dessus de l'axe, $f$ grimpe ; au moment où $f'$ traverse l'axe en descendant, $f$ atteint un sommet et redescend. Le point où $f'$ s'annule **en changeant de signe** est un **extremum local** : un maximum si $f'$ passe du positif au négatif, un minimum dans l'autre sens."),
                .heading("Un exemple complet"),
                .paragraph("Pour $f(x) = x^3 - 3x$ : $f'(x) = 3x^2 - 3 = 3(x-1)(x+1)$. La dérivée s'annule en $-1$ et $1$. Un tableau de signes d'un produit de deux facteurs donne : positive avant $-1$, négative entre $-1$ et $1$, positive après $1$. On en déduit un **maximum local** en $-1$, où $f(-1) = 2$, et un **minimum local** en $1$, où $f(1) = -2$."),
                .table(title: "Tableau de variations de f(x) = x³ − 3x", headers: ["Intervalle", "Signe de f′", "Sens de f"], rows: [
                    ["]−∞ ; −1[", "+", "croissante"],
                    ["]−1 ; 1[", "−", "décroissante"],
                    ["]1 ; +∞[", "+", "croissante"],
                ]),
                .paragraph("Le tableau est la réponse attendue à « étudier les variations de $f$ » : les intervalles en haut, le signe de la dérivée au milieu, les flèches en bas, avec les valeurs de $f$ aux points où elle change de sens. C'est un objet standard, et il faut le présenter exactement dans cet ordre."),
                .callout(
                    title: "Méthode",
                    text: "1. Dériver. 2. Étudier le signe de $f'$ (factoriser !). 3. En déduire les variations. 4. Calculer les valeurs aux bornes et aux extremums. 5. Dresser le tableau.",
                    tone: .insight
                ),
                .paragraph("L'étape deux est celle qui coince. Le signe d'une dérivée ne se lit pas sur $6x - 5$ ou $3x^2 - 3$ tels quels : il faut ==résoudre $f'(x) = 0$== puis dresser un tableau de signes, ou factoriser pour lire le signe de chaque facteur. Une dérivée non factorisée est une dérivée dont on ne sait rien."),
                .keyFigure(value: "f′ = 0", label: "là où la courbe a une tangente horizontale : un sommet, un creux, ou un palier"),
                .paragraph("Une tangente horizontale est donc un signal, pas une preuve : elle dit que la fonction cesse un instant de monter ou de descendre, mais pas si elle repart dans l'autre sens. C'est le tableau de signes qui tranche, et lui seul."),
                .callout(
                    title: "Attention",
                    text: "$f'(a) = 0$ ne suffit pas pour un extremum : $x^3$ a une dérivée nulle en 0 et ne change pas de sens — c'est un palier. Il faut que $f'$ **change de signe** en $a$.",
                    tone: .warning
                ),
                .heading("Lire une courbe"),
                .paragraph("Le lien marche aussi dans l'autre sens : à partir de la courbe de $f$, on peut deviner le signe de $f'$, et à partir de la courbe de $f'$, les variations de $f$. C'est un exercice classique : on vous donne le graphique de la dérivée, et on vous demande où la fonction est croissante. La réponse est : là où la courbe de $f'$ est au-dessus de l'axe des abscisses."),
                .list([
                    "Courbe de $f$ qui monte ⇔ $f'$ positive",
                    "Sommet ou creux de $f$ ⇔ $f'$ s'annule en changeant de signe",
                    "Courbe de $f'$ au-dessus de l'axe ⇔ $f$ croissante",
                ]),
                .paragraph("Cette lecture croisée est ce qui distingue un élève qui applique une recette d'un élève qui comprend : la dérivée n'est pas un calcul de plus, c'est ==la courbe vue autrement==. Et c'est ce qui rend possible le chapitre suivant, où l'on cherche le meilleur point d'une courbe qu'on n'a pas dessinée."),
            ]),
            DemoChapter(title: "Résoudre un problème d'optimisation", blocks: [
                .paragraph("Optimiser, c'est trouver ==la plus grande ou la plus petite valeur== que peut prendre une grandeur : l'aire maximale d'un enclos, le coût minimal d'une boîte, le bénéfice le plus élevé. Ce sont les problèmes où la dérivée sert à quelque chose de concret, et ceux qui rapportent le plus de points."),
                .heading("Un enclos contre un mur"),
                .paragraph("On dispose de 40 mètres de grillage pour clôturer un enclos rectangulaire adossé à un mur : le mur fait un côté, le grillage les trois autres. Quelles dimensions donnent la plus grande aire ? On appelle $x$ la largeur, perpendiculaire au mur. Les deux largeurs prennent $2x$ mètres de grillage ; il en reste $40 - 2x$ pour la longueur. L'aire est donc le produit des deux."),
                .formula("A(x) = x\\,(40 - 2x) = 40x - 2x^2", caption: "L'aire de l'enclos, pour x entre 0 et 20"),
                .paragraph("Le problème est devenu une étude de fonction : on cherche le maximum de $A$ sur $[0 ; 20]$ — au-delà de 20, la longueur serait négative. On dérive : $A'(x) = 40 - 4x$, qui s'annule pour $x = 10$, positive avant, négative après. Le tableau de variations donne la réponse."),
                .table(title: "Variations de A(x) = 40x − 2x²", headers: ["x", "Signe de A′", "Sens de A"], rows: [
                    ["[0 ; 10[", "+", "croissante, de 0 à 200"],
                    ["x = 10", "0", "maximum : A(10) = 200"],
                    ["]10 ; 20]", "−", "décroissante, de 200 à 0"],
                ]),
                .paragraph("L'aire maximale vaut $200$ m², pour une largeur de $10$ m et une longueur de $20$ m. Remarquez que ce n'est pas un carré : parce que le mur remplace un côté, le meilleur rectangle est deux fois plus long que large. Sans la dérivée, on aurait pu essayer des valeurs au hasard ; avec, on a ==la certitude== que c'est le meilleur."),
                .callout(
                    title: "Méthode",
                    text: "1. Choisir la variable, et l'intervalle où elle a un sens. 2. Exprimer la grandeur à optimiser en fonction de cette seule variable. 3. Dériver, étudier le signe, dresser le tableau. 4. Lire l'extremum, et **répondre à la question posée** — avec l'unité.",
                    tone: .insight
                ),
                .heading("Un deuxième exemple"),
                .paragraph("Une entreprise fabrique $x$ centaines d'objets par jour, avec un coût total $C(x) = x^2 + 4x + 16$ (en centaines d'euros), pour $x$ entre 1 et 10. Le coût moyen par centaine d'objets est $M(x) = C(x)/x = x + 4 + 16/x$. Pour quelle production ce coût moyen est-il le plus bas ?"),
                .formula("M'(x) = 1 - \\frac{16}{x^2} = \\frac{x^2 - 16}{x^2} = \\frac{(x-4)(x+4)}{x^2}", caption: "La dérivée, factorisée pour lire son signe"),
                .paragraph("Sur $[1 ; 10]$, le dénominateur et $x + 4$ sont positifs : le signe de $M'$ est celui de $x - 4$, négatif avant 4, positif après. Le coût moyen décroît jusqu'à $x = 4$, puis remonte : le minimum est en $x = 4$, et vaut $M(4) = 4 + 4 + 4 = 12$, soit 1 200 euros par centaine. Produire quatre cents objets par jour est **le rythme le plus économique**."),
                .figure(.flow(title: "La démarche", steps: ["Une variable", "Une fonction", "Sa dérivée", "Son tableau", "La réponse"])),
                .paragraph("Les deux exemples suivent exactement le même chemin, et c'est toujours le même : la difficulté d'un problème d'optimisation n'est presque jamais dans la dérivée, elle est dans la **mise en équation** — trouver la bonne variable et écrire la grandeur en fonction d'elle. Une fois la fonction posée, le reste est le chapitre trois."),
                .callout(
                    title: "Les pièges",
                    text: "Oublier l'intervalle (une longueur négative n'existe pas) ; dériver la mauvaise grandeur (le coût total au lieu du coût moyen) ; s'arrêter à $x = 10$ sans dire que l'aire vaut $200$ m². Le correcteur attend **la réponse à la question**, pas seulement le tableau.",
                    tone: .warning
                ),
                .list([
                    "Enclos, boîte, cylindre : une dimension libre, une contrainte de longueur ou de volume",
                    "Coût, bénéfice, recette : une quantité produite, une fonction économique",
                    "Trajet, vitesse, temps : une position ou un instant à choisir",
                ]),
                .paragraph("Ces trois familles couvrent presque tous les sujets d'examen. Chaque fois, la question cachée est la même : ==pour quelle valeur de $x$ la dérivée s'annule-t-elle en changeant de signe ?== Quand vous savez la reconnaître sous n'importe quel habillage, le chapitre est acquis."),
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
            DemoCard(kind: .basic, front: "Comment trouve-t-on le maximum d'une grandeur dans un problème d'optimisation ?", back: "On exprime la grandeur en fonction d'une seule variable sur son intervalle de sens, on dérive, on étudie le signe de la dérivée, et on lit le maximum dans le tableau de variations là où la dérivée s'annule en passant du positif au négatif.", chapter: 3),
            DemoCard(kind: .cloze, front: "Avec 40 m de grillage contre un mur, l'aire de l'enclos est maximale pour une largeur de … m.", back: "10", chapter: 3),
        ]
    )

    // MARK: Physique : l'énergie

    private static let energyFR = OnboardingDemoCourse(
        id: "physics-energy",
        emoji: "⚡️",
        subject: "Physique",
        title: "L'énergie",
        summary: "Les formes de l'énergie, sa conservation d'une forme à l'autre, la puissance et le rendement, puis les chaînes énergétiques, avec les formules et les ordres de grandeur du programme.",
        accentIndex: 6,
        chapters: [
            DemoChapter(title: "Les formes de l'énergie", blocks: [
                .paragraph("L'énergie ne se voit pas, elle se **transforme** : la chute d'une pomme, la chaleur d'un moteur, la lumière d'une lampe sont la même grandeur sous des formes différentes. Elle se mesure en ==joules (J)==, et un joule est à peu près l'énergie qu'il faut pour soulever une pomme d'un mètre."),
                .heading("Une grandeur, plusieurs formes"),
                .paragraph("Les physiciens ont mis deux siècles à comprendre que la chaleur, le mouvement, la lumière et l'électricité étaient une seule et même chose sous des habits différents. Ce qui les relie, c'est qu'on peut convertir l'une en l'autre — un moteur transforme de la chaleur en mouvement, une dynamo du mouvement en électricité — et que la quantité totale ne change jamais. Le tableau ci-dessous liste les formes du programme."),
                .table(title: "Les formes usuelles", headers: ["Forme", "Dépend de", "Exemple"], rows: [
                    ["Cinétique", "la masse et la vitesse", "une voiture lancée"],
                    ["Potentielle de pesanteur", "la masse et la hauteur", "une pomme dans l'arbre"],
                    ["Thermique", "l'agitation des molécules", "une casserole chaude"],
                    ["Électrique", "le courant", "une batterie"],
                    ["Chimique", "les liaisons", "l'essence, le glucose"],
                ]),
                .paragraph("Deux de ces formes ont une formule à connaître par cœur. L'**énergie cinétique** est celle d'un corps en mouvement : elle grandit avec la masse, et avec le carré de la vitesse. Doubler la masse la double ; doubler la vitesse la quadruple. C'est ce carré qui rend les accidents à grande vitesse si graves."),
                .formula("E_c = \\frac{1}{2} m v^2", caption: "Énergie cinétique : m en kg, v en m/s, E en J"),
                .paragraph("L'**énergie potentielle de pesanteur** est celle d'un corps en hauteur : de l'énergie « en réserve », qui deviendra du mouvement si on le lâche. Elle est proportionnelle à la masse et à la hauteur, et à l'intensité de la pesanteur $g$, qui vaut environ $9{,}8$ N/kg sur Terre — et six fois moins sur la Lune."),
                .formula("E_{pp} = m g h", caption: "Énergie potentielle de pesanteur : g ≈ 9,8 N/kg, h en m"),
                .callout(
                    title: "Ordre de grandeur",
                    text: "Une voiture de 1 000 kg à 50 km/h (≈ 14 m/s) porte $E_c = \\frac{1}{2} \\times 1000 \\times 14^2 \\approx 98\\,000$ J, soit près de 100 kJ. À 100 km/h, **quatre fois plus** : 400 kJ, l'énergie qu'il faudrait pour la hisser à quarante mètres.",
                    tone: .example
                ),
                .paragraph("Cet exemple montre le piège des unités : la vitesse doit être en mètres par seconde, pas en kilomètres par heure, sinon le résultat est faux d'un facteur treize. Pour convertir, on divise les km/h par 3,6. C'est ==la première chose à vérifier== dans tout calcul d'énergie cinétique."),
                .keyFigure(value: "× 4", label: "quand la vitesse double, l'énergie cinétique quadruple : c'est le carré de la formule"),
                .heading("Les unités"),
                .paragraph("Le joule est petit à l'échelle de la vie courante, et on emploie ses multiples : le kilojoule (1 kJ = 1 000 J) pour les aliments, le mégajoule pour les carburants, le kilowattheure pour l'électricité. Un gramme de sucre libère environ 17 kJ ; un litre d'essence, 35 MJ ; une barre de chocolat, 1 000 kJ — de quoi hisser une voiture au sommet de la tour Eiffel, si on savait convertir sans perte."),
                .callout(
                    title: "Unité",
                    text: "L'énergie s'exprime en joules, jamais en watts. Le watt mesure une **puissance** : de l'énergie par seconde. Confondre les deux, c'est confondre un litre et un litre par minute.",
                    tone: .warning
                ),
                .list([
                    "1 kJ = 1 000 J : l'énergie d'un aliment se lit en kJ sur l'emballage",
                    "1 kWh = 3 600 000 J : l'unité de la facture d'électricité",
                    "1 calorie ≈ 4,18 J : l'ancienne unité, encore sur les étiquettes",
                ]),
                .paragraph("Retenez la logique plutôt que les chiffres : une énergie est toujours une quantité, comme un volume, et elle se convertit d'une forme à l'autre sans jamais disparaître. C'est ce principe, le plus important de toute la physique, que le chapitre suivant énonce."),
            ]),
            DemoChapter(title: "Conservation et transferts", blocks: [
                .paragraph("==bleu|L'énergie ne se crée ni ne se perd== : elle passe d'une forme à une autre, d'un système à un autre. C'est le principe de conservation, et il vaut pour tout, de l'atome à la galaxie. Aucune expérience, jamais, ne l'a mis en défaut."),
                .heading("Une chute"),
                .paragraph("Prenez une balle tenue à deux mètres du sol. Elle a de l'énergie potentielle, et pas d'énergie cinétique. Lâchez-la : à mesure qu'elle tombe, sa hauteur diminue et sa vitesse augmente — l'énergie potentielle devient de l'énergie cinétique, exactement dans les mêmes proportions. Au sol, tout est cinétique ; au choc, tout devient chaleur et son."),
                .figure(.flow(title: "La chaîne énergétique d'une chute", steps: ["Énergie potentielle, en haut", "Devient énergie cinétique", "Choc : chaleur et son", "Total inchangé"])),
                .paragraph("Ce raisonnement permet de calculer sans connaître les forces. Une balle lâchée de 2 m perd de l'énergie potentielle et gagne exactement autant d'énergie cinétique, tant qu'on néglige les frottements : $mgh = \\frac{1}{2}mv^2$, donc la masse se simplifie et la vitesse au sol vaut $v = \\sqrt{2gh}$."),
                .formula("v = \\sqrt{2 g h} \\approx \\sqrt{2 \\times 9{,}8 \\times 2} \\approx 6{,}3 \\text{ m/s}", caption: "La vitesse au sol, sans frottements : la même pour une bille et pour une boule"),
                .paragraph("Le résultat ne dépend pas de la masse : une bille et une boule de pétanque lâchées de la même hauteur arrivent à la même vitesse. Galilée l'avait observé du haut de la tour de Pise ; la conservation de l'énergie l'explique en une ligne. C'est ==la force de ce principe== : il donne des réponses là où les équations du mouvement seraient pénibles."),
                .callout(
                    title: "Énergie mécanique",
                    text: "La somme de l'énergie cinétique et de l'énergie potentielle : $E_m = E_c + E_{pp}$. Sans frottements, elle se conserve : ce que l'une perd, l'autre le gagne.",
                    tone: .definition
                ),
                .formula("E_m = E_c + E_{pp} = \\text{constante}", caption: "En l'absence de frottements"),
                .paragraph("Le pendule est l'exemple parfait. Au plus haut de sa course, il s'arrête un instant : tout est potentiel. Au plus bas, il va le plus vite : tout est cinétique. Entre les deux, l'énergie passe sans cesse d'une forme à l'autre, et le pendule remonte exactement à la hauteur d'où il est parti — s'il n'y avait pas l'air."),
                .heading("Et les frottements ?"),
                .paragraph("Dans la vraie vie, le pendule finit par s'arrêter, la balle rebondit moins haut, la voiture s'arrête quand on coupe le moteur. L'énergie mécanique diminue. Elle n'a pas disparu : les frottements l'ont convertie en **énergie thermique**, dans l'air, dans le sol, dans les freins — qui chauffent, et parfois beaucoup."),
                .callout(
                    title: "Ce que font les frottements",
                    text: "Ils ne « détruisent » rien : l'énergie mécanique perdue devient de l'énergie thermique. Le total se conserve toujours, il est juste **moins utile** — une chaleur diffuse ne fait plus rien avancer.",
                    tone: .insight
                ),
                .paragraph("Cette perte d'utilité est une idée profonde. L'énergie se conserve, mais elle se **dégrade** : chaque conversion en laisse un peu sous forme de chaleur tiède, qu'on ne sait plus récupérer. C'est pour ça qu'un mouvement perpétuel est impossible, et qu'un moteur doit être alimenté sans cesse."),
                .list([
                    "Travail : transfert d'énergie par une force qui déplace — pousser, soulever, freiner",
                    "Chaleur : transfert par différence de température — une casserole sur le feu",
                    "Rayonnement : transfert par la lumière — le Soleil qui chauffe la peau",
                ]),
                .paragraph("Ces trois modes sont les seules façons dont l'énergie passe d'un système à un autre. Faire un **bilan énergétique**, c'est choisir un système, lister ce qui entre et ce qui sort par ces trois voies, et vérifier que le compte est bon : ==ce qui entre moins ce qui sort est ce qui reste==."),
            ]),
            DemoChapter(title: "Puissance et rendement", blocks: [
                .paragraph("La **puissance** dit à quelle vitesse l'énergie est transférée. Un chauffage de 2 000 W transfère 2 000 joules chaque seconde. Deux appareils peuvent consommer la même énergie, l'un en une minute et l'autre en une heure : le premier est soixante fois plus puissant."),
                .heading("La puissance"),
                .formula("P = \\frac{E}{\\Delta t}", caption: "P en watts (W), E en joules, Δt en secondes"),
                .paragraph("La formule se lit dans les deux sens. Connaissant la puissance et la durée, on retrouve l'énergie : $E = P \\times \\Delta t$. Un four de 2 000 W allumé une heure consomme $2000 \\times 3600 = 7{,}2 \\times 10^6$ J, soit 7,2 MJ. Les ordres de grandeur du tableau valent la peine d'être retenus."),
                .table(title: "Quelques puissances", headers: ["Quoi", "Puissance"], rows: [
                    ["Un humain au repos", "≈ 100 W"],
                    ["Un cycliste à l'effort", "≈ 300 W"],
                    ["Un four", "2 000 W"],
                    ["Une voiture", "≈ 100 kW"],
                    ["Une éolienne", "≈ 3 MW"],
                    ["Un réacteur nucléaire", "≈ 1 000 MW"],
                ]),
                .paragraph("Un humain au repos dégage à peu près la puissance d'une ampoule d'autrefois : c'est pour ça qu'une salle pleine chauffe vite. Et un réacteur nucléaire produit dix millions de fois plus — de quoi alimenter un million de foyers. La puissance est ==le débit de l'énergie==, comme le débit d'un robinet est celui de l'eau."),
                .callout(
                    title: "Le kilowattheure",
                    text: "1 kWh, c'est 1 000 W pendant une heure : $1000 \\times 3600 = 3{,}6 \\times 10^6$ J. C'est l'unité de la facture d'électricité, et elle coûte une vingtaine de centimes.",
                    tone: .example
                ),
                .paragraph("Le kilowattheure est une énergie, pas une puissance — le « heure » est là pour le rappeler : une puissance multipliée par un temps. Un foyer français consomme environ 4 700 kWh d'électricité par an, soit un peu plus de 500 W en moyenne, jour et nuit. Un radiateur de 2 000 W allumé une nuit de huit heures en consomme 16, à lui seul."),
                .heading("Le rendement"),
                .paragraph("Aucun convertisseur n'est parfait : une part de l'énergie reçue repart en chaleur, et n'a servi à rien. Le ==rendement== compare ce qui est utile à ce qui est fourni. Un moteur thermique reçoit l'énergie chimique de l'essence et n'en rend qu'un tiers en mouvement : le reste chauffe le moteur, le pot d'échappement, et l'air autour."),
                .formula("\\eta = \\frac{E_{utile}}{E_{fournie}}", caption: "Toujours inférieur ou égal à 1 (100 %)"),
                .paragraph("Le rendement s'exprime souvent en pourcentage, et il se multiplie le long d'une chaîne : si une centrale a un rendement de 35 % et le réseau électrique de 90 %, le rendement de l'ensemble est $0{,}35 \\times 0{,}9 \\approx 0{,}32$. Chaque maillon de plus fait perdre quelque chose, et c'est pourquoi on cherche à en avoir le moins possible."),
                .bars(title: "Rendement de quelques convertisseurs", unit: "%", bars: [
                    DemoBar(label: "Moteur thermique", value: 35),
                    DemoBar(label: "Ampoule LED", value: 40),
                    DemoBar(label: "Moteur électrique", value: 90),
                    DemoBar(label: "Radiateur électrique", value: 100),
                ]),
                .paragraph("Le graphique explique une bonne partie de la transition énergétique. Un moteur électrique convertit neuf dixièmes de ce qu'il reçoit en mouvement, un moteur thermique un tiers : à énergie égale au départ, la voiture électrique va presque trois fois plus loin. Une ampoule à incandescence, elle, avait un rendement de 5 % — c'était un radiateur qui éclairait un peu."),
                .callout(
                    title: "Rendement de 100 % ?",
                    text: "Un radiateur électrique convertit tout en chaleur, mais c'est justement la chaleur qu'on veut : son rendement est de 100 %. Pour un moteur, la même chaleur est une perte. **Utile** dépend de ce qu'on demande à l'appareil.",
                    tone: .warning
                ),
                .list([
                    "Puissance : énergie par seconde, en watts",
                    "Énergie : puissance fois durée — en joules, ou en kWh sur la facture",
                    "Rendement : utile sur fourni, jamais plus de 1, et il se multiplie en chaîne",
                ]),
                .paragraph("Ces trois notions permettent de lire n'importe quelle fiche technique et de vérifier n'importe quelle promesse. Un appareil qui annoncerait plus d'énergie utile qu'il n'en reçoit violerait le premier principe ; un rendement supérieur à un ==n'existe pas==, quoi qu'en dise la publicité."),
            ]),
            DemoChapter(title: "Les chaînes énergétiques", blocks: [
                .paragraph("Une **chaîne énergétique** est le schéma qui raconte le voyage de l'énergie : d'où elle vient, par quels convertisseurs elle passe, sous quelle forme elle ressort, et ce qui se perd en route. C'est ==l'outil du bilan==, et c'est presque toujours ce qu'on demande de dessiner à l'examen."),
                .heading("Lire une chaîne"),
                .paragraph("Le schéma se lit de gauche à droite. Aux deux bouts, des **réservoirs** : là où l'énergie est stockée au départ, là où elle finit. Entre eux, des **convertisseurs** : les appareils qui la font changer de forme. Chaque flèche porte une forme d'énergie, et chaque convertisseur laisse échapper une flèche de chaleur — les pertes. Une centrale hydroélectrique en est l'exemple le plus lisible."),
                .figure(.flow(title: "Une centrale hydroélectrique", steps: ["Eau retenue : potentielle", "Chute : cinétique", "Turbine : mécanique", "Alternateur : électrique", "Réseau"])),
                .paragraph("L'eau du barrage a de l'énergie potentielle, à cause de sa hauteur. En tombant dans les conduites, elle la convertit en énergie cinétique. La turbine transforme ce mouvement d'eau en rotation ; l'alternateur transforme la rotation en courant ; les lignes emportent le courant. À chaque étape, un peu de chaleur s'échappe — mais très peu : une centrale hydraulique a un rendement proche de 90 %, le meilleur de toutes."),
                .paragraph("La même logique décrit n'importe quel système, y compris un corps humain. Un cycliste convertit l'énergie chimique de ses aliments en énergie mécanique dans ses muscles, avec un rendement d'environ 25 % : les trois quarts partent en chaleur, et c'est pour ça qu'on transpire."),
                .figure(.flow(title: "Un cycliste", steps: ["Aliments : chimique", "Muscles : mécanique", "Roues : cinétique", "Frottements : chaleur"])),
                .heading("Les convertisseurs"),
                .paragraph("Un convertisseur se définit par ce qu'il reçoit et ce qu'il rend. Le tableau rassemble ceux du programme ; pour chacun, la troisième colonne dit sous quelle forme part ce qui n'a pas servi. On remarque que c'est **toujours de la chaleur** : c'est la forme finale de toute énergie dégradée."),
                .table(title: "Quelques convertisseurs", headers: ["Convertisseur", "Reçoit", "Rend", "Perd"], rows: [
                    ["Moteur électrique", "Électrique", "Mécanique", "Chaleur"],
                    ["Panneau solaire", "Rayonnement", "Électrique", "Chaleur"],
                    ["Pile", "Chimique", "Électrique", "Chaleur"],
                    ["Lampe LED", "Électrique", "Lumière", "Chaleur"],
                    ["Moteur thermique", "Chimique", "Mécanique", "Chaleur, gaz"],
                ]),
                .paragraph("Dessiner la chaîne d'un appareil, c'est déjà comprendre comment il marche — et souvent pourquoi il chauffe. Un ordinateur reçoit de l'énergie électrique et ne rend, au bout du compte, que de la chaleur : le calcul lui-même ne stocke rien. Un chargeur de téléphone tiède est un convertisseur qui perd quelques pour cent en route."),
                .callout(
                    title: "Le grille-pain",
                    text: "Il reçoit 1 000 W d'énergie électrique et rend 1 000 W de chaleur : rendement 100 %. Mais si l'électricité vient d'une centrale thermique à 35 %, il a fallu brûler près de 3 000 W de gaz pour griller le pain. **La chaîne complète** compte, pas le seul dernier maillon.",
                    tone: .example
                ),
                .heading("D'où vient l'électricité"),
                .paragraph("Remonter la chaîne jusqu'au bout mène aux **sources** d'énergie : ce qu'on brûle, ce qu'on fait tomber, ce qu'on capte. Certaines se renouvellent à l'échelle humaine — le soleil, le vent, l'eau, la biomasse —, d'autres s'épuisent — le charbon, le pétrole, le gaz, l'uranium. Le graphique montre d'où vient l'électricité en France, où le nucléaire domine depuis les années 1980."),
                .bars(title: "D'où vient l'électricité en France (ordres de grandeur)", unit: "%", bars: [
                    DemoBar(label: "Nucléaire", value: 65),
                    DemoBar(label: "Hydraulique", value: 12),
                    DemoBar(label: "Éolien", value: 10),
                    DemoBar(label: "Solaire", value: 5),
                    DemoBar(label: "Gaz, charbon", value: 8),
                ]),
                .paragraph("Ces parts changent d'une année à l'autre — un hiver sec vide les barrages, une année ventée gonfle l'éolien — mais l'ordre reste : deux tiers de nucléaire, un quart de renouvelable, et une part fossile qui sert surtout aux pointes de consommation. Ailleurs en Europe, le gaz et le charbon pèsent bien plus lourd, et l'électricité y émet plusieurs fois plus de CO₂."),
                .callout(
                    title: "Renouvelable, pas gratuit",
                    text: "Une source renouvelable se reconstitue, mais la capter a un coût : des matériaux, des surfaces, des pertes en chaîne. Et « renouvelable » ne veut pas dire « sans effet » : un barrage noie une vallée, une éolienne demande du cuivre. **Aucune chaîne n'est sans perte, et aucune source n'est sans conséquence.**",
                    tone: .warning
                ),
                .list([
                    "Réservoirs aux deux bouts, convertisseurs entre eux, une forme d'énergie par flèche",
                    "Chaque convertisseur perd de la chaleur : le rendement le mesure",
                    "Les rendements se multiplient le long de la chaîne",
                    "La source, tout au début, décide de ce que coûte l'énergie — et de ce qu'elle émet",
                ]),
                .paragraph("Avec ces quatre règles, vous pouvez dessiner et commenter n'importe quelle chaîne : celle d'un téléphone, d'un train, d'une centrale. C'est le chapitre qui relie la physique à ce qu'on lit dans le journal, et ==le plus utile== des quatre pour comprendre le monde qui vous entoure."),
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
            DemoCard(kind: .basic, front: "Qu'est-ce qu'une chaîne énergétique ?", back: "Le schéma qui suit l'énergie d'un réservoir à l'autre, à travers des convertisseurs : une forme d'énergie par flèche, et à chaque convertisseur une flèche de pertes, sous forme de chaleur.", chapter: 3),
            DemoCard(kind: .cloze, front: "Dans une centrale hydroélectrique, l'énergie … de l'eau retenue devient de l'énergie cinétique dans la chute.", back: "potentielle", chapter: 3),
        ]
    )
}
