/**
 * **Pour qui la leçon s'écrit** : la marche d'études, le pays, la classe exacte, la filière,
 * l'examen visé. Voir `docs/refonte-parcours.md` § 9.3.
 *
 * `generate-course/prompt.ts` décrit un registre de **fiche** pour sept niveaux et douze
 * pays. Une leçon a besoin de plus, et de plus juste :
 *
 * - **La marche (`tier`) plutôt que le registre.** Le registre `lycee` couvrait aussi le
 *   collège : un élève de 4e recevait des notes de lycéen. La marche dit ce qu'il en est
 *   (`lowerSecondary`), et c'est elle qui règle le vocabulaire, la longueur et le volume.
 * - **Chaque pays proposé par l'app a sa ligne**, avec ses examens par marche et son barème.
 *   Une Allemande qui prépare l'Abitur ne doit pas lire « ce qui tombe au bac ».
 * - **La classe exacte, la filière et l'examen** arrivent tels que l'élève les a choisis :
 *   « Terminale », « Lycée général », « YKS hazırlık · TYT », « Bac de français ».
 *
 * Tout est pur et testé (`learner.test.ts`).
 */

export type Tier =
  | "lowerSecondary"
  | "upperSecondary"
  | "preUniversity"
  | "undergraduate"
  | "graduate"
  | "health"
  | "competitive"
  | "other";

export interface Learner {
  /** La marche d'études : `EducationTier` côté app. */
  tier: Tier;
  /** Le pays de scolarité, en code de deux lettres (`fr`, `tr`…), ou `other`. */
  country: string;
  /** Le palier tel que le pays le nomme (« Lycée », « Lise, YKS »). */
  stage: string;
  /** La filière (« Lycée général », « Gymnasium »). */
  track: string;
  /** L'année ou la classe (« Terminale », « 4e », « Master 1 », « TYT »). */
  year: string;
  /** L'examen visé, quand l'élève l'a donné (« Bac de français, le 2027-06-15 »). */
  exam: string;
  /** Son niveau actuel, de 0 à 100 sur l'échelle de l'app, quand il l'a donné. */
  currentScore?: number;
  /** Son objectif, de 0 à 100 sur la même échelle. */
  targetScore?: number;
  /** Sa note actuelle telle qu'il la dit (« 12/20 », « B+ »). */
  scoreLabel?: string;
  /** Son objectif tel qu'il le dit (« 16/20 », « A »). */
  targetLabel?: string;
  /** Ce qui le freine, parmi `WORRIES`. */
  worries?: Worry[];
}

/** Ce qui freine l'élève, tel que l'app le demande à l'accueil. */
export type Worry = "examStress" | "hardLessons" | "homework" | "forgetting" | "noStart" | "motivation";

/** Une phrase par frein : elles vont dans chaque prompt, elles restent courtes. */
const WORRIES: Record<Worry, string> = {
  examStress: "L'examen le stresse : des questions au format exact de son examen, pour qu'il s'y habitue.",
  hardLessons: "Certaines notions lui résistent : explique les passages difficiles lentement, avec un exemple.",
  homework: "Il bute sur ses exercices : montre la méthode sur un exercice type, étape par étape.",
  forgetting: "Il oublie vite : plus de faits nets à mettre en flashcards, et des repères pour s'en souvenir (un lien, une image, un moyen mnémotechnique).",
  noStart: "Il a du mal à s'y mettre : une structure claire, des blocs courts, une étape après l'autre.",
  motivation: "Sa motivation flanche : des exemples concrets, proches de sa vie.",
};

const TIERS: readonly Tier[] = [
  "lowerSecondary",
  "upperSecondary",
  "preUniversity",
  "undergraduate",
  "graduate",
  "health",
  "competitive",
  "other",
];

/** Le registre ancien (`StudyLevel`) quand l'app n'envoie pas encore la marche. */
const TIER_OF_LEVEL: Record<string, Tier> = {
  lycee: "upperSecondary",
  prepa: "preUniversity",
  licence: "undergraduate",
  master: "graduate",
  sante: "health",
  concours: "competitive",
  other: "other",
};

function clean(value: unknown, max: number): string {
  return typeof value === "string" ? value.replace(/[\r\n<>{}]/g, " ").replace(/\s+/g, " ").trim().slice(0, max) : "";
}

/**
 * **Une note, ramenée sur 100.** Un nombre de 0 à 100 passe tel quel ; sinon on lit le libellé
 * quand il se calcule (« 12/20 » → 60, « 75 % » → 75). Une lettre (« B+ ») ne se convertit
 * pas : elle reste un libellé, sans seuil.
 */
export function readScore(value: unknown, label?: unknown): number | undefined {
  if (typeof value === "number" && Number.isFinite(value)) return Math.round(Math.min(100, Math.max(0, value)));
  if (typeof value === "string" && /^\s*\d+(?:[.,]\d+)?\s*$/.test(value)) return readScore(Number(value.replace(",", ".")));
  if (typeof label !== "string") return undefined;
  const fraction = /(\d+(?:[.,]\d+)?)\s*\/\s*(\d+(?:[.,]\d+)?)/.exec(label);
  if (fraction) {
    const [got, out] = [Number(fraction[1]!.replace(",", ".")), Number(fraction[2]!.replace(",", "."))];
    return out > 0 ? readScore((got / out) * 100) : undefined;
  }
  const percent = /(\d+(?:[.,]\d+)?)\s*%/.exec(label);
  return percent ? readScore(Number(percent[1]!.replace(",", "."))) : undefined;
}

function readWorries(raw: unknown): Worry[] {
  const out: Worry[] = [];
  for (const item of Array.isArray(raw) ? raw : []) {
    if (typeof item === "string" && item in WORRIES && !out.includes(item as Worry)) out.push(item as Worry);
  }
  return out;
}

/** Ce que la requête dit de l'élève, remis au propre. Une marche inconnue retombe sur le registre. */
export function readLearner(body: {
  tier?: unknown;
  level?: unknown;
  country?: unknown;
  schoolStage?: unknown;
  track?: unknown;
  year?: unknown;
  exam?: unknown;
  currentScore?: unknown;
  targetScore?: unknown;
  scoreLabel?: unknown;
  targetLabel?: unknown;
  worries?: unknown;
}): Learner {
  const rawTier = clean(body.tier, 40) as Tier;
  const level = clean(body.level, 40).toLowerCase();
  const tier = TIERS.includes(rawTier) ? rawTier : (TIER_OF_LEVEL[level] ?? "other");
  const country = clean(body.country, 8).toLowerCase() || "other";
  const learner: Learner = {
    tier,
    country: COUNTRIES[country] ? country : "other",
    stage: clean(body.schoolStage, 80),
    track: clean(body.track, 80),
    year: clean(body.year, 60),
    exam: clean(body.exam, 120),
  };
  const currentScore = readScore(body.currentScore, body.scoreLabel);
  const targetScore = readScore(body.targetScore, body.targetLabel);
  const scoreLabel = clean(body.scoreLabel, 20);
  const targetLabel = clean(body.targetLabel, 20);
  const worries = readWorries(body.worries);
  if (currentScore !== undefined) learner.currentScore = currentScore;
  if (targetScore !== undefined) learner.targetScore = targetScore;
  if (scoreLabel) learner.scoreLabel = scoreLabel;
  if (targetLabel) learner.targetLabel = targetLabel;
  if (worries.length) learner.worries = worries;
  return learner;
}

/**
 * **Le niveau de l'élève et ce qui le freine**, en quelques lignes : elles vont dans chaque
 * prompt de la leçon (thèmes, entraînement, examen blanc). Vide quand l'élève n'a rien dit.
 */
export function difficultyBrief(learner: Learner): string {
  const lines: string[] = [];
  const current = learner.currentScore;
  const target = learner.targetScore;
  const said = (label: string | undefined, score: number | undefined) =>
    label ? `« ${label} »` : score !== undefined ? `${score}/100` : "";
  if (current !== undefined && current <= 50) {
    lines.push(`Il est en difficulté (niveau actuel ${said(learner.scoreLabel, current)}) : plus d'exemples résolus pas à pas, rappelle en une ligne le prérequis dont dépend une notion, des phrases plus simples, sans appauvrir le vocabulaire du cours.`);
  } else if (current !== undefined && current >= 75) {
    lines.push(`Il a de bonnes bases (niveau actuel ${said(learner.scoreLabel, current)}) : ne réexplique pas l'évident, va vers l'application.`);
  }
  const gap = current !== undefined && target !== undefined ? target - current : 0;
  if ((target !== undefined && target >= 80) || gap >= 25) {
    lines.push(`Il vise ${said(learner.targetLabel, target) || "haut"} : ajoute des questions d'application plus exigeantes et signale les pièges qui coûtent des points.`);
  } else if (target === undefined && learner.targetLabel) {
    lines.push(`Son objectif : « ${learner.targetLabel} ».`);
  }
  for (const worry of learner.worries ?? []) lines.push(WORRIES[worry]);
  return lines.join("\n");
}

// MARK: - La marche

/**
 * Comment on écrit pour chaque marche. Ces lignes décrivent une façon d'écrire des NOTES de
 * leçon et des questions, jamais un examen : c'est le pays qui les nomme.
 */
const TIER_BRIEFS: Record<Tier, string> = {
  lowerSecondary:
    `Un COLLÉGIEN (11 à 15 ans). Des mots simples, des phrases de 15 mots au plus, une seule notion nouvelle par bloc. Chaque terme technique est défini la première fois, avec un exemple de la vie courante. Les questions vérifient d'abord qu'il a compris, puis qu'il sait appliquer sur un cas simple. Aucun jargon de lycée ni d'université.`,
  upperSecondary:
    `Un LYCÉEN. Le vocabulaire exact de son programme, les définitions telles que l'examen les attend, les méthodes qu'on lui demande (définir, expliquer, justifier, calculer, analyser un document). Les exemples sont ceux d'un sujet d'examen. Les questions vont de la définition à l'application, avec au moins une question de raisonnement par thème.`,
  preUniversity:
    `Un élève de CLASSE PRÉPARATOIRE ou d'équivalent (cégep, foundation year). La rigueur prime : conditions d'application, hypothèses, cas limites, enchaînements logiques sans étape sautée. Les questions testent le raisonnement et les pièges de l'écrit, pas la récitation.`,
  undergraduate:
    `Un étudiant de PREMIER CYCLE universitaire (licence, bachelor, grado, lisans). Le vocabulaire du cours tel quel, les mécanismes détaillés, les nuances que le support porte. Les questions mélangent définitions précises, mécanismes et cas d'application.`,
  graduate:
    `Un étudiant de MASTER ou plus. Les bases sont acquises : ce qui compte, ce sont les limites, les conditions de validité, les positions qui s'opposent. Les questions portent sur l'analyse et la comparaison, rarement sur la définition seule.`,
  health:
    `Un étudiant en ÉTUDES DE SANTÉ. Densité et précision : nomenclature exacte, valeurs seuils avec leurs unités, confusions classiques. Les questions ressemblent aux QCM des examens de santé : pièges fins, une seule réponse juste, des distracteurs qui sont les erreurs fréquentes.`,
  competitive:
    `Un CANDIDAT À UN CONCOURS ou à un examen d'entrée. Ce qui tombe passe avant ce qui est intéressant : chiffres à connaître, définitions à réciter, méthodes, pièges classiques. Les questions ont le format et le niveau du concours visé, de plus en plus difficiles.`,
  other:
    `Un apprenant dont le niveau n'est pas connu. Écris de façon équilibrée : chaque terme technique est défini la première fois, aucun prérequis n'est supposé, et la difficulté monte progressivement.`,
};

// MARK: - Le pays

interface Country {
  /** Le pays, en clair, tel qu'on le dit à un professeur. */
  name: string;
  /** Les examens par marche, avec leurs vrais noms. */
  exams: string;
  /** Le barème des notes, pour les examens blancs et le vocabulaire. */
  grading: string;
  /** Ce qu'il ne faut jamais invoquer là-bas. */
  never?: string;
}

const NOT_FRENCH = "Ne parle jamais du baccalauréat français, du brevet, des classes préparatoires ni du PASS.";

export const COUNTRIES: Record<string, Country> = {
  fr: {
    name: "en France",
    exams: "collège : le brevet (DNB) ; lycée : le bac de français en Première, les épreuves de spécialité, la philosophie et le grand oral en Terminale ; prépa : les concours des grandes écoles et les khôlles ; université : partiels et examens de licence et de master ; santé : PASS et L.AS.",
    grading: "notes sur 20, la moyenne est 10",
  },
  be: {
    name: "en Belgique",
    exams: "secondaire : CE1D puis CESS ; supérieur : examens de bachelier et de master, examen d'entrée en médecine.",
    grading: "notes sur 20, la réussite est à 10",
    never: NOT_FRENCH,
  },
  ch: {
    name: "en Suisse",
    exams: "secondaire : maturité gymnasiale ; supérieur : examens de bachelor et de master, test d'aptitude aux études de médecine.",
    grading: "notes de 1 à 6, 6 est la meilleure, 4 est suffisant",
    never: NOT_FRENCH,
  },
  ca: {
    name: "au Québec (Canada)",
    exams: "secondaire : épreuves ministérielles ; cégep : examens et épreuve uniforme de français ; université : examens du baccalauréat universitaire (diplôme de 1er cycle) et de la maîtrise.",
    grading: "notes en pourcentage, la réussite est à 60 %",
    never: "Au Québec, « baccalauréat » désigne un diplôme universitaire, jamais un examen de fin de secondaire. Ne parle ni de brevet ni de classes préparatoires.",
  },
  lu: {
    name: "au Luxembourg",
    exams: "secondaire : examen de fin d'études secondaires (diplôme) ; supérieur : bachelor et master.",
    grading: "notes sur 60, la réussite est à 30",
    never: NOT_FRENCH,
  },
  ma: {
    name: "au Maroc",
    exams: "collège : examen régional de 3e année ; lycée : examen régional de 1re année du bac puis examen national du baccalauréat marocain ; supérieur : classes préparatoires, concours des grandes écoles et de médecine, licence, master.",
    grading: "notes sur 20, la moyenne est 10",
  },
  dz: {
    name: "en Algérie",
    exams: "moyen : BEM ; lycée : baccalauréat algérien ; supérieur : licence, master, concours des écoles.",
    grading: "notes sur 20, la moyenne est 10",
  },
  tn: {
    name: "en Tunisie",
    exams: "collège : diplôme de fin d'études de l'enseignement de base ; lycée : baccalauréat tunisien ; supérieur : licence, mastère, concours d'accès aux études de santé.",
    grading: "notes sur 20, la moyenne est 10",
  },
  sn: {
    name: "au Sénégal",
    exams: "moyen : BFEM ; lycée : baccalauréat ; supérieur : licence, master, concours des grandes écoles.",
    grading: "notes sur 20, la moyenne est 10",
  },
  ci: {
    name: "en Côte d'Ivoire",
    exams: "collège : BEPC ; lycée : baccalauréat ; supérieur : licence, master, concours des grandes écoles.",
    grading: "notes sur 20, la moyenne est 10",
  },
  uk: {
    name: "au Royaume-Uni",
    exams: "secondary : GCSE ; sixth form : A-Levels ; university : undergraduate and postgraduate exams, medical school entry (UCAT).",
    grading: "GCSE graded 9 to 1, A-Levels graded A* to E, degrees classified First, 2:1, 2:2, Third",
    never: NOT_FRENCH,
  },
  us: {
    name: "aux États-Unis",
    exams: "middle and high school : unit tests, finals, state tests, AP exams, SAT or ACT ; college : midterms and finals ; pre-med : MCAT.",
    grading: "letter grades A to F (GPA on 4.0), AP exams scored 1 to 5",
    never: NOT_FRENCH,
  },
  de: {
    name: "en Allemagne",
    exams: "Mittelstufe : Klassenarbeiten, Mittlerer Schulabschluss ; Oberstufe : Klausuren et Abitur (Grund- und Leistungskurs) ; Berufsschule : Abschlussprüfung ; Universität : Klausuren, Bachelor- und Masterprüfungen, Staatsexamen en médecine.",
    grading: "Noten von 1 (sehr gut) bis 6 (ungenügend) ; en Oberstufe, Punkte von 0 à 15 ; à l'université, de 1,0 à 5,0",
    never: NOT_FRENCH,
  },
  it: {
    name: "en Italie",
    exams: "scuola media : esame di terza media ; liceo : Esame di Maturità ; università : esami del corso di laurea triennale e magistrale, test di medicina.",
    grading: "voti da 1 a 10 a scuola (6 è la sufficienza), Maturità su 100, università su 30 (18 per passare, 30 e lode)",
    never: NOT_FRENCH,
  },
  es: {
    name: "en Espagne",
    exams: "ESO : exámenes de evaluación ; Bachillerato : PAU / EBAU (Selectividad) ; FP : módulos y prueba final ; universidad : exámenes del grado y del máster ; medicina : MIR.",
    grading: "notas de 0 a 10, se aprueba con 5",
    never: NOT_FRENCH,
  },
  pt: {
    name: "au Portugal",
    exams: "ensino básico : provas finais do 9.º ano ; secundário : exames nacionais ; universidade : exames de licenciatura e mestrado.",
    grading: "notas de 0 a 20 no secundário e na universidade, 10 para passar",
    never: NOT_FRENCH,
  },
  cz: {
    name: "en Tchéquie",
    exams: "základní škola : přijímací zkoušky ; střední škola : maturita ; vysoká škola : zkoušky bakalářského a magisterského studia.",
    grading: "známky 1 (výborně) až 5 (nedostatečně)",
    never: NOT_FRENCH,
  },
  nl: {
    name: "aux Pays-Bas",
    exams: "VMBO, HAVO, VWO : schoolexamens en centraal eindexamen ; universiteit en hbo : tentamens bachelor en master.",
    grading: "cijfers van 1 tot 10, voldoende vanaf 5,5",
    never: NOT_FRENCH,
  },
  gr: {
    name: "en Grèce",
    exams: "γυμνάσιο : εξετάσεις ; λύκειο : Πανελλαδικές εξετάσεις ; πανεπιστήμιο : εξετάσεις πτυχίου και μεταπτυχιακού.",
    grading: "βαθμοί από 0 έως 20, βάση το 10",
    never: NOT_FRENCH,
  },
  hu: {
    name: "en Hongrie",
    exams: "általános iskola : központi felvételi ; gimnázium : érettségi (közép- és emelt szint) ; egyetem : vizsgák BSc és MSc képzésben.",
    grading: "jegyek 1-től 5-ig, az 5 a legjobb",
    never: NOT_FRENCH,
  },
  pl: {
    name: "en Pologne",
    exams: "szkoła podstawowa : egzamin ósmoklasisty ; liceum : matura ; uczelnia : egzaminy licencjackie i magisterskie, LEK w medycynie.",
    grading: "oceny od 1 do 6, matura w procentach",
    never: NOT_FRENCH,
  },
  ro: {
    name: "en Roumanie",
    exams: "gimnaziu : Evaluarea Națională ; liceu : Bacalaureat ; universitate : examene de licență și master, rezidențiat în medicină.",
    grading: "note de la 1 la 10, promovare cu 5",
    never: NOT_FRENCH,
  },
  se: {
    name: "en Suède",
    exams: "grundskola : nationella prov ; gymnasium : nationella prov och kurser ; högskola : tentor, högskoleprovet för antagning.",
    grading: "betyg A till F, E är godkänt",
    never: NOT_FRENCH,
  },
  tr: {
    name: "en Turquie",
    exams: "ortaokul : LGS ; lise : yazılı sınavlar ve YKS (TYT, AYT, YDT) ; üniversite : vize ve final sınavları, KPSS, ALES, YDS ; tıp : TUS.",
    grading: "lisede 0-100 arası notlar (50 geçer), üniversitede AA-FF harf notları",
    never: NOT_FRENCH,
  },
  other: {
    name: "dans un pays non précisé",
    exams: "aucun examen nommé : parle de « l'examen », de « ton programme ».",
    grading: "barème non précisé",
    never: "N'invoque aucun examen national ni aucun diplôme nommé : une épreuve inventée est pire qu'une épreuve absente.",
  },
};

/** Le barème du pays, en une ligne : les examens blancs le reprennent. */
export function gradingOf(country: string): string {
  return (COUNTRIES[country] ?? COUNTRIES.other!).grading;
}

/**
 * **La consigne « pour qui tu écris »** de la leçon. La marche règle la façon d'écrire, le
 * pays nomme les examens, la classe et la filière précisent, et l'examen visé tranche.
 */
export function learnerBrief(learner: Learner): string {
  const country = COUNTRIES[learner.country] ?? COUNTRIES.other!;
  const where = [learner.track, learner.year].filter(Boolean).join(", ") || learner.stage;
  const lines = [
    "POUR QUI TU ÉCRIS",
    TIER_BRIEFS[learner.tier],
    `Il étudie ${country.name}${where ? `, en ${where}` : ""}. Examens de ce système : ${country.exams} Barème : ${country.grading}.`,
  ];
  if (country.never) lines.push(country.never);
  if (learner.exam) {
    lines.push(`Il prépare précisément : ${learner.exam}. Les exemples, les mots attendus et le format des questions sont ceux de cet examen.`);
  }
  lines.push("Le niveau, les mots et les exemples sont ceux de CETTE classe dans CE pays : ni plus simples, ni plus savants.");
  const difficulty = difficultyBrief(learner);
  if (difficulty) lines.push(difficulty);
  return lines.join("\n");
}

// MARK: - Le volume

export interface Volume {
  /** Le nombre de thèmes quand la leçon part d'un sujet tapé. */
  topicThemes: [number, number];
  /** Le plafond de thèmes quand elle part d'un document. */
  maxThemes: number;
  /** Les questions par thème, question de fin comprise. */
  questions: number;
  /** Les flashcards par thème. */
  flashcards: number;
}

/**
 * **Combien écrire, selon la marche.** Un collégien a des thèmes plus courts et moins
 * nombreux ; un étudiant en santé, plus de questions pièges. Les nombres restent dans les
 * bornes de `schema.ts` (`LIMITS`).
 */
export function volumeOf(tier: Tier): Volume {
  switch (tier) {
    case "lowerSecondary":
      return { topicThemes: [4, 6], maxThemes: 8, questions: 5, flashcards: 4 };
    case "upperSecondary":
      return { topicThemes: [5, 8], maxThemes: 10, questions: 6, flashcards: 5 };
    case "health":
    case "competitive":
      return { topicThemes: [5, 8], maxThemes: 12, questions: 7, flashcards: 6 };
    case "other":
      return { topicThemes: [5, 7], maxThemes: 10, questions: 6, flashcards: 5 };
    default:
      return { topicThemes: [5, 8], maxThemes: 12, questions: 6, flashcards: 6 };
  }
}

// MARK: - La profondeur

/**
 * Le registre des notes : `fiche` une fiche condensée de niveau avancé, en puces denses qui
 * commencent par leur terme de tête ; `explained` des notes structurées qui expliquent ;
 * `guided` des notes pas à pas, pour les plus jeunes.
 */
export type NoteRegister = "fiche" | "explained" | "guided";

export interface Depth {
  /** Le nombre de blocs des notes d'un thème, sous-titres non compris : [au moins, au plus]. */
  blocks: [number, number];
  /** La longueur d'un paragraphe, en mots. */
  paragraphWords: number;
  /** Comment expliquer à cette marche : analogies, densité, rigueur. Une ligne du prompt. */
  style: string;
  /** Vrai quand la marche prépare un examen au format connu : une question le reprend. */
  examFormat: boolean;
  /** Le registre des notes (`NoteRegister`). */
  register: NoteRegister;
  /** Le nombre de puces d'une liste, au plus. */
  listItems: number;
  /** La longueur d'une puce, en mots. */
  listItemWords: number;
}

/**
 * **Jusqu'où expliquer, selon la marche.** Deux à cinq blocs de soixante mots faisaient un
 * résumé, pas une leçon : un thème enseigne (une accroche, le mécanisme, un exemple travaillé,
 * le piège), et il lui faut la place de le faire. Un collégien a moins de blocs et plus
 * d'images ; un étudiant, plus de blocs et plus denses. Les nombres restent sous les plafonds
 * de `schema.ts` (`LIMITS.blocksHardMax`, `LIMITS.paragraphHardWords`).
 *
 * La ligne `style` dit la FAÇON d'expliquer ; le vocabulaire et le registre sont dans
 * `TIER_BRIEFS`, elle ne les répète pas.
 *
 * **Des paragraphes qui ont la place d'expliquer.** Le plafond seul ne suffisait pas : un
 * modèle à qui l'on dit « quatre-vingt-dix mots au plus » en écrit quarante-cinq, deux phrases
 * par écran, et l'élève tournait des pages presque vides. Les plafonds ont monté d'un cran, et
 * le prompt donne aussi un plancher (`PARAGRAPH_FLOOR`, dans `generate-lesson/prompt.ts`).
 *
 * **Une fiche, pas un manuel, aux niveaux avancés.** De la prépa au master, en santé et pour un
 * concours, les notes se lisent comme une fiche de révision dense : moins de blocs, mais des
 * listes plus longues dont chaque puce porte un terme de tête et son information (un auteur et
 * son année, un chiffre, un mécanisme en une ligne). Les paragraphes y sont rares et courts. Au
 * lycée, les notes restent expliquées ; au collège, guidées pas à pas.
 */
export function depthOf(tier: Tier): Depth {
  switch (tier) {
    case "lowerSecondary":
      return {
        blocks: [4, 6],
        paragraphWords: 85,
        style: "Explique pas à pas, sans rien sauter : une analogie de la vie courante (le sport, l'argent de poche, la cuisine, un jeu) pour chaque idée abstraite, un exemple de son âge, et la raison de chaque règle dite simplement.",
        examFormat: false,
        register: "guided",
        listItems: 5,
        listItemWords: 16,
      };
    case "upperSecondary":
      return {
        blocks: [5, 8],
        paragraphWords: 110,
        style: "Explique chaque mécanisme jusqu'au bout, avec ses causes et ses conséquences ; une analogie quand la notion est abstraite ; des exemples du niveau d'un sujet d'examen.",
        examFormat: true,
        register: "explained",
        listItems: 6,
        listItemWords: 22,
      };
    case "preUniversity":
    case "health":
    case "competitive":
      return {
        blocks: [4, 8],
        paragraphWords: 95,
        style: "Dense et rigoureux : hypothèses, conditions d'application, cas limites et valeurs exactes, chaque étape d'un raisonnement écrite, le tout en puces serrées ; pas d'analogie.",
        examFormat: true,
        register: "fiche",
        listItems: 8,
        listItemWords: 28,
      };
    case "undergraduate":
    case "graduate":
      return {
        blocks: [4, 8],
        paragraphWords: 95,
        style: "Dense et rigoureux : le mécanisme, ses conditions de validité, ses limites, les auteurs et les nuances du cours, le tout en puces serrées ; pas d'analogie.",
        examFormat: false,
        register: "fiche",
        listItems: 8,
        listItemWords: 28,
      };
    default:
      return {
        blocks: [5, 7],
        paragraphWords: 95,
        style: "Explique chaque idée avec sa raison et un exemple concret ; une analogie quand la notion est abstraite.",
        examFormat: false,
        register: "explained",
        listItems: 6,
        listItemWords: 22,
      };
  }
}
