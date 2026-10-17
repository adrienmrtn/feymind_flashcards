/**
 * La matière d'un cours, et ce qu'elle change à la façon de l'écrire.
 *
 * Une fiche de philosophie sans auteurs ni œuvres n'est pas une fiche de philosophie, et
 * une fiche d'économie qui donne une seule vision d'un débat est fausse par omission. Le
 * prompt général ne peut pas porter ces exigences : elles se contredisent d'une matière à
 * l'autre, et les empiler toutes ferait un prompt que le modèle survole.
 *
 * La matière est donc détectée, puis une seule consigne est ajoutée. La détection est faite
 * ici plutôt que dans l'application pour une raison simple : à l'import, personne ne connaît
 * encore la matière — c'est le modèle qui la trouve. On la devine donc sur le texte, et
 * quand l'application la connaît déjà (elle regénère une fiche, elle écrit des cartes), elle
 * l'envoie et c'est elle qui gagne.
 *
 * L'app sert vingt-six langues : les mots de chaque matière sont donnés en français, anglais,
 * espagnol, allemand, italien, portugais et turc, repliés comme le texte.
 */

export type Discipline =
  | "philosophy"
  | "economics"
  | "law"
  | "medicine"
  | "history"
  | "geography"
  | "mathematics"
  | "physics"
  | "chemistry"
  | "biology"
  | "literature"
  | "language"
  | "computing"
  | "general";

/**
 * Mots qui trahissent une matière.
 *
 * Ils sont écrits sans accent et en minuscules : la comparaison se fait sur un texte replié,
 * sinon « théorie » et « theorie » ne seraient pas le même mot. Un seul mot ne suffit pas à
 * décider, c'est le nombre d'occurrences distinctes qui compte : « marché » apparaît dans un
 * cours d'histoire, mais pas avec « inflation » et « keynes ».
 *
 * Ce sont souvent des RADICAUX (« economi » couvre économie, economics, economia) : un même
 * mot ne doit pas compter deux fois parce qu'il contient deux radicaux de la liste. Aucun mot
 * de trois lettres qui se cache dans d'autres (« ses », « war ») : il ferait gagner sa matière
 * sur n'importe quel texte.
 */
const KEYWORDS: Record<Exclude<Discipline, "general">, string[]> = {
  philosophy: [
    "philosoph",
    "filosof",
    "felsefe",
    "kant",
    "descartes",
    "nietzsche",
    "platon",
    "plato ",
    "aristot",
    "spinoza",
    "hegel",
    "sartre",
    "socrat",
    "sokrat",
    "metaphysi",
    "metafisic",
    "metafizik",
    "epistemolog",
    "epistemoloji",
    "ontolog",
    "ontoloji",
    "conscience",
    "consciousness",
    "conciencia",
    "coscienza",
    "bewusstsein",
    "libre arbitre",
    "free will",
    "libre albedrio",
    "libero arbitrio",
    "livre-arbitrio",
    "willensfreiheit",
    "ozgur irade",
    "morale",
  ],
  economics: [
    "economi",
    "economy",
    "ekonomi",
    "wirtschaft",
    "inflation",
    "inflacion",
    "inflazione",
    "inflacao",
    "enflasyon",
    "keynes",
    "adam smith",
    "ricardo",
    "marche du travail",
    "labour market",
    "labor market",
    "mercado laboral",
    "arbeitsmarkt",
    "offre et demande",
    "supply and demand",
    "oferta y demanda",
    "angebot und nachfrage",
    "domanda e offerta",
    "oferta e demanda",
    "arz ve talep",
    "pib",
    "gdp",
    "chomage",
    "unemployment",
    "desempleo",
    "arbeitslosigkeit",
    "disoccupazione",
    "desemprego",
    "issizlik",
    "monnaie",
    "banque centrale",
    "central bank",
    "banco central",
    "zentralbank",
    "banca centrale",
    "merkez bankasi",
    "croissance economique",
    "consommation",
    "elastic",
    "elastizitat",
    "esneklik",
    "monetary policy",
    "politique monetaire",
  ],
  law: [
    "droit ",
    "droits ",
    "juridique",
    "juridico",
    "giuridic",
    "constitution",
    "constitucion",
    "costituzione",
    "constituicao",
    "grundgesetz",
    "anayasa",
    "jurisprudence",
    "jurisprudencia",
    "giurisprudenza",
    "rechtsprechung",
    "code civil",
    "codigo civil",
    "codice civile",
    "medeni kanun",
    "code penal",
    "codigo penal",
    "strafrecht",
    "ceza hukuku",
    "article l",
    "alinea",
    "contrat",
    "contract law",
    "vertragsrecht",
    "contratto",
    "sozlesme",
    "responsabilite civile",
    "cassation",
    "conseil constitutionnel",
    "legislateur",
    "arret",
    "tribunal",
    "court of appeal",
    "supreme court",
    "plaintiff",
    "defendant",
    "statute",
    "derecho",
    "diritto",
    "direito",
    "hukuk",
    "mahkeme",
    "yargitay",
    "gericht",
  ],
  medicine: [
    "anatom",
    "physiolog",
    "fisiolog",
    "fizyoloji",
    "patholog",
    "patolog",
    "patoloji",
    "clinique",
    "clinical",
    "clinico",
    "klinisch",
    "symptom",
    "sintoma",
    "sintomo",
    "semptom",
    "diagnos",
    "teshis",
    "traitement",
    "treatment",
    "tratamiento",
    "tedavi",
    "posologie",
    "dosage",
    "muscle",
    "arteres",
    "artery",
    "arteria",
    "nerf",
    "nerve",
    "nervio",
    "cellule",
    "syndrom",
    "sindrom",
    "sendrom",
    "patient",
    "paciente",
    "paziente",
    "pharmacolog",
    "farmacolog",
    "pharmakolog",
    "farmakoloji",
    "semiologie",
  ],
  history: [
    "histoire",
    "history",
    "historia",
    "geschichte",
    "tarih",
    "siecle",
    "century",
    "siglo",
    "secolo",
    "seculo",
    "jahrhundert",
    "yuzyil",
    "revolution",
    "revolucion",
    "rivoluzione",
    "revolucao",
    "devrim",
    "inkilap",
    "guerre",
    "world war",
    "cold war",
    "civil war",
    "guerra",
    "krieg",
    "savas",
    "traite de",
    "treaty of",
    "tratado de",
    "trattato di",
    "vertrag von",
    "antlasma",
    "empire",
    "imperio",
    "impero",
    "kaiserreich",
    "imparatorluk",
    "osmanli",
    "republique",
    "regime",
    "chronologie",
    "chronology",
    "cronologia",
    "moyen age",
    "middle ages",
    "medieval",
    "edad media",
    "medioevo",
    "idade media",
    "mittelalter",
    "antiquite",
    "antiquity",
    "antiguedad",
    "antichita",
    "antiguidade",
    "antike",
    "colonisation",
    "colonization",
    "colonizacion",
    "colonizzazione",
    "colonizacao",
    "kolonial",
    "dynast",
  ],
  geography: [
    "geograph",
    "geografi",
    "erdkunde",
    "cografya",
    "territoire",
    "territory",
    "territorio",
    "relief",
    "clima",
    "klima",
    "iklim",
    "urbanisation",
    "urbanization",
    "urbanizacion",
    "urbanizzazione",
    "urbanizacao",
    "verstadterung",
    "kentlesme",
    "mondialisation",
    "globalization",
    "globalisation",
    "globalizacion",
    "globalizzazione",
    "globalizacao",
    "globalisierung",
    "kuresellesme",
    "metropole",
    "metropolis",
    "littoral",
    "coastline",
    "flux migratoires",
    "migration flows",
    "flujos migratorios",
    "densite de population",
    "population density",
    "densidad de poblacion",
    "densita di popolazione",
    "densidade populacional",
    "bevolkerungsdichte",
    "nufus yogunlugu",
    "amenagement du territoire",
    "continent",
    "hemisphere",
    "latitude",
  ],
  mathematics: [
    "mathemati",
    "matemati",
    "theorem",
    "teorem",
    "satz von",
    "demonstration",
    "derivee",
    "derivative",
    "derivada",
    "derivata",
    "ableitung",
    "turev",
    "integral",
    "equation",
    "ecuacion",
    "equazione",
    "equacao",
    "gleichung",
    "denklem",
    "fonction affine",
    "linear function",
    "matrice",
    "matrix",
    "matriz",
    "matris",
    "probabilit",
    "probabilidad",
    "probabilidade",
    "wahrscheinlichkeit",
    "olasilik",
    "suite",
    "limite",
    "vecteur",
    "vector",
    "vettore",
    "vetor",
    "vektor",
    "polynom",
    "polinom",
  ],
  physics: [
    "physique",
    "physics",
    "physik",
    "fisica",
    "fizik",
    "force",
    "kuvvet",
    "energie cinetique",
    "kinetic energy",
    "energia cinetica",
    "kinetische energie",
    "kinetik enerji",
    "electron",
    "elektron",
    "circuit",
    "stromkreis",
    "devre",
    "tension",
    "voltage",
    "voltaje",
    "acceleration",
    "aceleracion",
    "accelerazione",
    "aceleracao",
    "beschleunigung",
    "ivme",
    "velocity",
    "velocidad",
    "velocita",
    "geschwindigkeit",
    "thermodynami",
    "termodinamic",
    "termodinamik",
    "longueur d'onde",
    "ondes electromagnetiques",
    "wavelength",
    "longitud de onda",
    "gravit",
    "gravedad",
    "gravidade",
    "schwerkraft",
    "yercekimi",
    "newton",
  ],
  chemistry: [
    "chimi",
    "chemi",
    "quimic",
    "kimya",
    "quantite de matiere",
    "amount of substance",
    "molaire",
    "molar",
    "molecul",
    "molecol",
    "molekul",
    "atome",
    "atom ",
    "atomo",
    "acide",
    "acid ",
    "acido",
    "asit-baz",
    "oxyd",
    "oxid",
    "ossida",
    "oksid",
    "stoechiometr",
    "stoichiometr",
    "estequiometr",
    "stechiometr",
    "stochiometr",
    "covalent",
    "kovalent",
    "tableau periodique",
    "periodic table",
    "tabla periodica",
    "tavola periodica",
    "tabela periodica",
    "periodensystem",
    "periyodik",
    "titrage",
    "titration",
    "titulacion",
    "titolazione",
    "titulacao",
    "titrasyon",
    "solution aqueuse",
    "aqueous",
    "precipite",
  ],
  biology: [
    "svt",
    "biolog",
    "biyoloji",
    "genetique",
    "genetic",
    "genetik",
    "adn",
    "dna",
    "chromosom",
    "cromosom",
    "kromozom",
    "photosynth",
    "fotosint",
    "fotosentez",
    "ecosyst",
    "ecosistem",
    "ekosistem",
    "okosystem",
    "mitose",
    "mitosi",
    "mitoz",
    "enzym",
    "enzim",
    "espece",
    "species",
    "especie",
    "evolution",
    "evolucion",
    "evoluzione",
    "evolucao",
    "evrim",
    "natural selection",
    "selection naturelle",
    "geologie",
    "geology",
    "zelle",
    "cell membrane",
    "cellular",
    "celula",
    "hucre",
  ],
  literature: [
    "litterature",
    "literatur",
    "letteratura",
    "edebiyat",
    "francais",
    "roman",
    "novel",
    "romanzo",
    "poesie",
    "poetry",
    "poesia",
    "gedicht",
    "siir",
    "theatre",
    "theater",
    "teatro",
    "registre",
    "figure de style",
    "stilmittel",
    "figura retorica",
    "recurso literario",
    "metaphor",
    "metafor",
    "metapher",
    "narrateur",
    "narrator",
    "narrador",
    "erzahler",
    "commentaire de texte",
    "dissertation",
    "auteur",
    "recit",
    "stanza",
    "strophe",
  ],
  language: [
    "vocab",
    "wortschatz",
    "kelime bilgisi",
    "conjugaison",
    "conjugation",
    "conjugacion",
    "conjugacao",
    "konjugation",
    "coniugazione",
    "grammaire",
    "grammar",
    "gramatica",
    "grammatica",
    "grammatik",
    "dilbilgisi",
    "gramer",
    "declinaison",
    "verbe irregulier",
    "irregular verb",
    "verbo irregular",
    "verbo irregolare",
    "unregelmassige",
    "traduction",
    "traduccion",
    "traduzione",
    "traducao",
    "ubersetzung",
    "ceviri",
    "anglais",
    "espagnol",
    "allemand",
    "italien",
    "prononciation",
    "pronunciation",
    "pronunciacion",
    "pronuncia",
    "aussprache",
    "telaffuz",
    "past tense",
    "present perfect",
  ],
  computing: [
    "informati",
    "computer science",
    "bilgisayar",
    "algorith",
    "algoritm",
    "programmation",
    "programming",
    "programacion",
    "programmazione",
    "programacao",
    "programmierung",
    "programlama",
    "boucle",
    "for loop",
    "while loop",
    "bucle",
    "variable",
    "fonction python",
    "python",
    "javascript",
    "base de donnees",
    "database",
    "base de datos",
    "datenbank",
    "banco de dados",
    "veritaban",
    "compil",
    "complexite",
    "complexity",
    "complejidad",
    "complessita",
    "complexidade",
    "komplexitat",
    "karmasiklik",
    "reseau",
    "network",
    "pseudo-code",
    "pseudocode",
  ],
};

/**
 * **Les noms de matières**, tels qu'une app ou un élève les écrit (« Mathematics »,
 * « Matemáticas », « Mathe », « Geschichte »…). L'ordre compte : « Physique-chimie » est de
 * la physique, « Histoire-géographie » de l'histoire, « English literature » des lettres.
 * Un nom de trois lettres au plus (« SES », « SVT », « NSI ») se compare au mot entier.
 */
const SUBJECTS: [Exclude<Discipline, "general">, string[]][] = [
  ["mathematics", ["math", "matemat", "mathe"]],
  ["physics", ["physique", "physics", "physik", "fisica", "fizik"]],
  ["chemistry", ["chimi", "chemi", "quimica", "kimya"]],
  ["medicine", ["medecine", "medicine", "medicina", "medizin", "tip", "sante", "health", "salud", "saude", "anatom", "physiolog", "pharma", "nursing", "infirmier", "pass", "las"]],
  ["biology", ["biolog", "biyoloji", "svt", "sciences de la vie", "life science", "ciencias naturales", "scienze naturali"]],
  ["history", ["histoire", "history", "historia", "geschichte", "storia", "tarih"]],
  ["geography", ["geograph", "geografi", "erdkunde", "cografya"]],
  ["economics", ["econom", "ekonomi", "wirtschaft", "ses", "business", "finance", "management"]],
  ["law", ["droit", "law", "derecho", "recht", "jura", "diritto", "direito", "hukuk", "juridique"]],
  ["philosophy", ["philo", "filosof", "felsefe", "ethics", "ethik", "etica"]],
  ["literature", ["litter", "literat", "letteratura", "lettres", "edebiyat", "francais", "deutsch", "turkce", "turk dili"]],
  ["language", [
    "anglais", "espagnol", "allemand", "italien", "portugais", "chinois", "arabe", "latin", "grec",
    "english", "spanish", "german", "french", "italian", "portuguese", "chinese",
    "ingles", "espanol", "aleman", "frances", "italiano", "portugues",
    "englisch", "spanisch", "franzosisch", "italienisch",
    "inglese", "spagnolo", "tedesco", "francese",
    "ingilizce", "almanca", "fransizca", "ispanyolca",
    "langue", "language", "idioma", "lingua", "sprache",
  ]],
  ["computing", ["informati", "computer", "computing", "programm", "coding", "nsi", "algorith", "bilgisayar", "yazilim"]],
];

/** Les noms courts qui ne se comparent qu'au mot entier : « pass » n'est pas « passé composé ». */
const WHOLE_WORDS = new Set(["pass", "jura", "grec"]);

/**
 * Ce qu'une matière exige de la fiche, et que le prompt général ne peut pas porter.
 *
 * Ces consignes servent aussi aux fiches (`generate-course`), aux cartes et aux examens : elles
 * disent le FOND, jamais la forme d'un bloc. Les formes de bloc propres aux leçons sont dans
 * `SHAPES` (`lessonShapesBrief`).
 */
const BRIEFS: Record<Discipline, string> = {
  philosophy:
    `MATIÈRE : PHILOSOPHIE. Une notion de philosophie ne s'explique pas sans ceux qui l'ont pensée. **Nomme les auteurs, leurs œuvres et leurs thèses** dès que le document les mentionne, avec le titre exact de l'ouvrage. Quand une notion oppose deux positions, écris les deux et ce qui les sépare, terme à terme. Distingue toujours la thèse, l'argument qui la soutient et l'exemple qui l'illustre : c'est cette distinction que l'épreuve évalue. Garde les distinctions conceptuelles du cours (en soi et pour soi, nécessaire et contingent) : ce sont elles qui font la copie.`,
  economics:
    `MATIÈRE : ÉCONOMIE. Une fiche d'économie qui donne une seule lecture d'un débat est fausse par omission. **Nomme les écoles et les auteurs** (classiques, keynésiens, néoclassiques, hétérodoxes) et, sur chaque question controversée, écris les visions qui s'opposent et le désaccord exact, pas une synthèse molle. Chaque mécanisme s'écrit comme un enchaînement de causes, et les chiffres du document sont repris avec leur unité et leur année. Rappelle en une ligne le prérequis de première quand une notion en dépend (offre et demande, élasticité, marché, facteurs de production) : le programme de terminale s'appuie dessus sans le redire.`,
  law:
    `MATIÈRE : DROIT. Un raisonnement juridique s'appuie sur un texte : **cite la source de chaque règle** telle que le document la donne, article, code, alinéa, et l'arrêt quand il y en a un. Distingue nettement le principe, ses conditions d'application et ses exceptions : c'est la structure d'une copie. Garde la hiérarchie des normes quand elle est en jeu (Constitution, traités, loi, règlement) et le vocabulaire exact, qui est technique et non synonyme du langage courant. Compare terme à terme dès que le cours oppose deux régimes, deux qualifications ou deux juridictions.`,
  medicine:
    `MATIÈRE : SANTÉ. Rien d'approximatif : **nomenclature exacte, valeurs seuils, unités systématiques**, et aucune valeur arrondie sans le dire. Une structure anatomique s'écrit avec sa situation, ses rapports et sa fonction. Un mécanisme physiologique s'écrit comme une chaîne, étape par étape. Signale explicitement les confusions classiques et les pièges de QCM, et compare terme à terme ce qui se confond : c'est comme ça que ces cours se révisent. N'invente jamais une posologie ni une valeur biologique.`,
  history:
    `MATIÈRE : HISTOIRE. Les dates, les lieux et les acteurs sont le contenu, pas l'habillage : **chaque fait porte sa date**, et les enchaînements sont écrits comme des causes et des conséquences, non comme une liste. Distingue le fait de son interprétation, et garde les notions du cours (les termes que l'épreuve attend) avec leur définition. Quand le document cite une source (discours, traité, témoignage), garde-la avec son auteur et sa date.`,
  geography:
    `MATIÈRE : GÉOGRAPHIE. Un phénomène géographique se situe : **nomme les lieux et dis l'échelle** (locale, régionale, nationale, mondiale) sans les mélanger. Chaque chiffre porte son unité et son année. Une carte ou un paysage se décrit en mots (où, quoi, quelle organisation) plutôt que d'être inventé. Écris les causes et les conséquences d'un phénomène, et les acteurs qui l'aménagent. Garde les notions du cours (métropolisation, littoralisation, mondialisation) avec leur définition.`,
  mathematics:
    `MATIÈRE : MATHÉMATIQUES. Un énoncé sans ses hypothèses est faux : **chaque théorème porte ses conditions d'application**. Les démonstrations du document sont conservées dans leurs étapes, pas résumées en conclusion. Les formules s'écrivent en LaTeX entre $…$, avec ce que désigne chaque symbole. Signale les erreurs classiques et les cas limites, et distingue ce qui est équivalence de ce qui est simple implication.`,
  physics:
    `MATIÈRE : PHYSIQUE. Une grandeur sans unité ne veut rien dire : **unités partout**, et l'ordre de grandeur quand il éclaire. Chaque loi porte son domaine de validité. Les formules s'écrivent en LaTeX entre $…$ avec la signification de chaque symbole et son unité, et les valeurs numériques du document sont reprises telles quelles. Un schéma décrit en mots plutôt qu'un schéma inventé.`,
  chemistry:
    `MATIÈRE : CHIMIE. **Une équation de réaction est toujours équilibrée**, avec l'état de chaque espèce quand il compte ((s), (l), (g), (aq)). Les formules s'écrivent en LaTeX ordinaire, indices et flèches compris : $2H_2 + O_2 \\rightarrow 2H_2O$, jamais \\ce{…}. Chaque grandeur porte son unité (mol, mol/L, g/mol). Un mécanisme ou un protocole s'écrit étape par étape, dans l'ordre. Garde la nomenclature exacte des espèces et les valeurs du document telles quelles.`,
  biology:
    `MATIÈRE : SVT. Une notion de biologie s'écrit à son échelle : **dis toujours de quelle échelle tu parles** (molécule, cellule, organisme, écosystème) et ne les mélange pas dans une même phrase. Un mécanisme s'écrit comme une chaîne d'étapes, avec ce qui entre et ce qui sort. Garde la nomenclature exacte des structures et des molécules, et les chiffres du document avec leur unité.`,
  literature:
    `MATIÈRE : LETTRES. Une analyse littéraire sans texte n'est rien : **cite les passages** que le document donne, avec leur auteur et leur œuvre, et nomme les procédés avec leur terme exact (métaphore, anaphore, focalisation) en disant ce qu'ils produisent. Situe l'œuvre dans son mouvement et son siècle. Distingue le procédé, son effet et l'interprétation : c'est le plan d'un commentaire.`,
  language:
    `MATIÈRE : LANGUE VIVANTE. La fiche sert à produire de la langue, pas à en parler. **Garde chaque terme dans sa langue d'origine, suivi de sa traduction**, et signale le genre, le pluriel irrégulier et la construction quand ils comptent. Les règles s'écrivent avec un exemple complet, phrase entière. Signale les faux amis et les pièges de prononciation que le document mentionne.`,
  computing:
    `MATIÈRE : INFORMATIQUE. Un algorithme s'écrit avec ce qu'il prend, ce qu'il rend et son coût : **complexité annoncée** quand le document la donne. Les étapes d'un algorithme s'écrivent dans l'ordre, une par ligne, jamais fondues dans un paragraphe. Garde les noms exacts des structures et des fonctions, et distingue ce qui est syntaxe d'un langage de ce qui est un principe général.`,
  general: "",
};

/**
 * **Les formes de bloc qu'une matière appelle, dans les notes d'une leçon.** Sans elles, chaque
 * thème avait le même squelette (un paragraphe, une liste, un exemple), qu'il parle de Kant ou
 * des dérivées. Ce sont des préférences : c'est le contenu du thème qui décide.
 */
const SHAPES: Record<Discipline, string> = {
  philosophy:
    `FORMES À PRIVILÉGIER (philosophie) : un bloc "quote" pour la phrase d'un auteur, avec l'auteur et l'œuvre ; un "table" quand deux positions s'opposent (une colonne par auteur ou par thèse, une rangée par point de désaccord) ; une "definition" pour chaque notion du cours ; un "example" qui illustre la thèse. Le "callout" "mistake" : confondre la thèse et l'exemple, ou prêter à un auteur la thèse qu'il réfute.`,
  economics:
    `FORMES À PRIVILÉGIER (économie) : un "table" pour comparer deux écoles, deux politiques ou deux situations (une rangée par critère) ; des "steps" pour un mécanisme écrit comme un enchaînement de causes ; un "example" chiffré, avec unité et année ; une "definition" pour chaque notion. Le "callout" "mistake" : confondre corrélation et causalité, valeur nominale et réelle, ou niveau et taux de variation.`,
  law:
    `FORMES À PRIVILÉGIER (droit) : un "table" pour comparer deux régimes, deux qualifications ou deux juridictions ; des "steps" pour une procédure ou la méthode du cas pratique ; une "definition" qui cite sa source (article, code) ; un "example" de cas pratique en deux phrases. Le "callout" "mistake" : appliquer le principe sans vérifier ses conditions, ou confondre deux régimes voisins.`,
  medicine:
    `FORMES À PRIVILÉGIER (santé) : des "steps" pour un mécanisme physiologique ou une démarche diagnostique ; un "table" pour comparer ce qui se confond (deux structures, deux pathologies, valeur ↔ seuil) ; une "definition" à la nomenclature exacte. Le "callout" "mistake" : la valeur seuil voisine, la structure adjacente, le mécanisme pris à l'envers.`,
  history:
    `FORMES À PRIVILÉGIER (histoire) : un bloc "dates" pour une chronologie ; des "steps" pour un enchaînement de causes et de conséquences ; un "quote" pour une source (un discours, un traité, un témoignage) avec son auteur et sa date, seulement si elle est authentique ; une "definition" pour une notion du cours. Le "callout" "mistake" : l'anachronisme, la date voisine, ou la conséquence prise pour la cause.`,
  geography:
    `FORMES À PRIVILÉGIER (géographie) : un "table" pour comparer deux territoires ou deux échelles (une rangée par critère, chiffres avec leur année) ; des "steps" pour les causes puis les conséquences d'un phénomène ; un "example" qui situe un lieu précis ; une "definition" pour une notion du cours. Le "callout" "mistake" : mélanger les échelles, ou un chiffre sans son année.`,
  mathematics:
    `FORMES À PRIVILÉGIER (mathématiques) : une "formula" pour chaque formule à savoir, avec ce que désignent ses lettres ; des "steps" pour un exemple résolu pas à pas ou les étapes d'une démonstration ; une "definition" qui énonce le théorème AVEC ses hypothèses ; un "example" chiffré. Le "callout" "mistake" : l'hypothèse oubliée, l'implication lue comme une équivalence, l'erreur de signe ou de calcul classique.`,
  physics:
    `FORMES À PRIVILÉGIER (physique) : une "formula" avec la signification ET l'unité de chaque grandeur dans la légende ; des "steps" pour une méthode de résolution ou un protocole ; un "example" chiffré avec ses unités ; un "table" grandeur ↔ unité quand il y en a plusieurs. Le "callout" "mistake" : l'unité oubliée ou non convertie, la loi appliquée hors de son domaine, le vecteur traité comme un nombre.`,
  chemistry:
    `FORMES À PRIVILÉGIER (chimie) : une "formula" pour une équation de réaction équilibrée (H_2O, \\rightarrow, jamais \\ce{}), avec les états ; des "steps" pour un mécanisme, un protocole ou un calcul de quantité de matière ; un "table" pour comparer des espèces (acide ↔ base, réactif ↔ produit) ; un "example" chiffré. Le "callout" "mistake" : l'équation non équilibrée, la masse confondue avec la quantité de matière, la concentration sans son unité.`,
  biology:
    `FORMES À PRIVILÉGIER (SVT) : des "steps" pour un mécanisme (ce qui entre, ce qui se passe, ce qui sort) ; un "table" pour comparer deux structures, deux processus (mitose et méiose) ou structure ↔ fonction ; une "formula" pour un bilan chimique ; une "definition" à la nomenclature exacte. Le "callout" "mistake" : mélanger les échelles, ou confondre deux processus voisins (mitose et méiose, gène et allèle).`,
  literature:
    `FORMES À PRIVILÉGIER (lettres) : un "quote" pour un passage court, avec l'auteur et l'œuvre ; un "table" procédé ↔ effet quand plusieurs procédés sont analysés ; des "steps" pour la méthode du commentaire ou de la dissertation ; une "definition" pour un terme d'analyse. Le "callout" "mistake" : nommer un procédé sans dire son effet, ou paraphraser au lieu d'analyser.`,
  language:
    `FORMES À PRIVILÉGIER (langue) : un "table" mot ↔ traduction (genre ou construction dans une troisième colonne si utile) pour le vocabulaire ; un "example" qui donne des phrases entières dans la langue étudiée ; un "table" pour une conjugaison ou une déclinaison ; des "steps" pour construire une phrase (ordre des mots, temps). Le "callout" "mistake" : le faux ami, le calque de la langue maternelle, l'exception à la règle.`,
  computing:
    `FORMES À PRIVILÉGIER (informatique) : des "steps" pour les étapes d'un algorithme ; un "table" pour comparer des structures ou des algorithmes (complexité, usage) ; un "example" qui trace l'algorithme sur une petite entrée ; une "definition" pour un terme. Le "callout" "mistake" : l'erreur d'une case (off-by-one), le cas vide oublié, la complexité mal comptée.`,
  general:
    `FORMES À PRIVILÉGIER : choisis selon le contenu. Des "steps" pour une méthode ou un processus, un "table" pour comparer, une "definition" pour un terme à savoir, un "example" pour rendre concret, un "quote" pour une phrase authentique et attribuée. Le "callout" "mistake" : l'erreur que font vraiment les élèves sur cette notion.`,
};

/** Replie un texte pour la comparaison : sans accents, en minuscules. */
function fold(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    // Le i sans point turc et l'eszett allemand ne se décomposent pas.
    .replace(/ı/g, "i")
    .replace(/ß/g, "ss");
}

/**
 * La matière du document.
 *
 * La matière déclarée par l'application passe devant : quand elle existe, elle a été trouvée
 * par le modèle sur ce même document, ou corrigée à la main, et vaut mieux que des mots
 * comptés. Sinon on compte, sur le début du document et sur son titre, et il faut au moins
 * deux mots distincts pour décider : un seul rangerait un cours d'histoire en économie parce
 * qu'il parle de marchés.
 */
export function detectDiscipline(
  text: string,
  hintTitle?: string,
  declaredSubject?: string,
): Discipline {
  const declared = fromSubject(declaredSubject);
  if (declared !== "general") return declared;

  // Le début suffit, et coûte bien moins cher : un cours annonce sa matière dès ses
  // premières lignes, et compter sur soixante mille caractères ne changerait pas le verdict.
  const haystack = fold(`${hintTitle ?? ""} ${text.slice(0, 6_000)} `);

  let best: Discipline = "general";
  let bestScore = 1;

  for (const [discipline, keywords] of Object.entries(KEYWORDS)) {
    const score = keywords.filter((keyword) => haystack.includes(keyword)).length;
    if (score > bestScore) {
      best = discipline as Discipline;
      bestScore = score;
    }
  }

  return best;
}

function wholeWord(haystack: string, word: string): boolean {
  return new RegExp(`(^|[^\\p{L}])${word}($|[^\\p{L}])`, "u").test(haystack);
}

/** La matière telle que l'application la connaît déjà, quand elle la connaît. */
export function fromSubject(subject?: string): Discipline {
  const folded = fold(subject ?? "").trim();
  if (folded.length < 2) return "general";

  for (const [discipline, names] of SUBJECTS) {
    const hit = names.some((name) =>
      name.length <= 3 || WHOLE_WORDS.has(name) ? wholeWord(folded, name) : folded.includes(name)
    );
    if (hit) return discipline;
  }
  if (folded.length < 3) return "general";
  for (const [discipline, keywords] of Object.entries(KEYWORDS)) {
    if (keywords.some((keyword) => keyword.length > 3 && folded.includes(keyword))) {
      return discipline as Discipline;
    }
  }
  return "general";
}

export function disciplineBrief(discipline: Discipline): string {
  return BRIEFS[discipline];
}

/** Les formes de bloc que la matière appelle dans les notes d'une leçon (jamais vide). */
export function lessonShapesBrief(discipline: Discipline): string {
  return SHAPES[discipline];
}
