/**
 * **Le calibrage par niveau** : ce que le profil scolaire de l'élève change à la leçon.
 *
 * La marche (`Tier`, `learner.ts`) range tout le collège ensemble et tout le lycée ensemble :
 * un élève de Sixième et un élève de Troisième recevaient le même nombre de blocs, les mêmes
 * paragraphes, les mêmes questions ; un élève de Seconde et un élève de Terminale aussi. Ici,
 * la marche est affinée par **l'année exacte** (son rang dans la filière, et pour les pays les
 * plus utilisés son numéro de classe) en un **palier** (`Band`), et chaque palier a sa ligne
 * dans une table explicite (`CALIBRATION`) :
 *
 * - la profondeur et les prérequis qu'on peut supposer ;
 * - le vocabulaire ;
 * - la longueur des notes (blocs, mots par paragraphe, puces) et le nombre de thèmes ;
 * - le nombre de questions et de cartes, et la difficulté visée ;
 * - le type d'exercices ;
 * - le format de l'examen blanc.
 *
 * **L'année se compare d'un pays à l'autre par sa classe internationale** (`grade`) : le
 * nombre d'années depuis l'entrée à l'école élémentaire, comme le « grade » américain. La
 * Sixième française, la Year 7 anglaise, la 6. Klasse allemande et le 1º de ESO espagnol sont
 * tous en classe 6 ou 7 ; la Terminale, la Year 13, le 2º de Bachillerato et la 12. sınıf en
 * classe 12 ou 13. Les filières des pays décrits dans l'app ont leur première classe dans
 * `FIRST_GRADE` ; une filière qui n'y est pas se place par le rang de l'année dans la
 * filière (le collège finit en classe 9, le lycée en classe 12). Un pays non décrit, ou un
 * élève qui n'a pas dit son année, retombe sur la marche seule : c'est le repli sain.
 *
 * Tout est pur et testé (`calibration.test.ts`).
 */
import type { Depth, Tier, Volume } from "./learner.ts";
import { depthOf, volumeOf } from "./learner.ts";

/** Le palier : la marche, affinée par l'année quand on la connaît. */
export type Band =
  | "lowerEarly"
  | "lowerLate"
  | "upperEarly"
  | "upperFinal"
  | "preUniversity"
  | "undergraduate"
  | "graduate"
  | "health"
  | "competitive"
  | "unknown";

/** Ce que l'app dit de l'année : son identifiant de catalogue et sa place dans la filière. */
export interface YearPlace {
  /** La marche (`EducationTier`). */
  tier: Tier;
  /** L'identifiant de la filière dans le catalogue de l'app (`fr.college`, `uk.gcse`). */
  trackId?: string;
  /** L'identifiant de l'année (`fr.6e`, `uk.y10`). */
  yearId?: string;
  /** Le rang de l'année dans sa filière, à partir de 1. */
  yearRank?: number;
  /** Le nombre d'années de la filière. */
  yearCount?: number;
}

/**
 * **La classe internationale de la première année de chaque filière secondaire**, pour les
 * pays les plus utilisés. Écrit d'après le catalogue de l'app (`SchoolSystem.swift`,
 * `SchoolSystemWorld.swift`) : la classe d'une année est celle de la première, plus son rang.
 */
export const FIRST_GRADE: Record<string, number> = {
  // France : 6e = 6 … 3e = 9 ; Seconde = 10 … Terminale = 12.
  "fr.college": 6,
  "fr.lyceeGeneral": 10,
  "fr.lyceeTechno": 10,
  "fr.lyceePro": 10,
  // Royaume-Uni : Year 7 = 6 … Year 13 = 12.
  "uk.ks3": 6,
  "uk.gcse": 9,
  "uk.alevels": 11,
  // États-Unis : le grade lui-même.
  "us.middle": 6,
  "us.high": 9,
  // Allemagne : la Klasse elle-même.
  "de.mittelstufe": 5,
  "de.realschule": 5,
  "de.gymnasium": 11,
  // Espagne : 1º ESO = 7 … 2º Bachillerato = 12.
  "es.eso": 7,
  "es.bachCiencias": 11,
  "es.bachHumanidades": 11,
  "es.bachArtes": 11,
  // Turquie : la sınıf elle-même.
  "tr.ortaokul": 5,
  "tr.anadolu": 9,
  "tr.fen": 9,
  "tr.meslek": 9,
  "tr.imamhatip": 9,
  // Italie : prima media = 6 ; liceo, cinq ans = 9 … 13.
  "it.media": 6,
  "it.liceo": 9,
  "it.tecnico": 9,
};

/** Le rang d'une année, borné, ou `undefined`. */
function rankOf(place: YearPlace): { rank: number; count: number } | undefined {
  const count = Math.round(place.yearCount ?? 0);
  const rank = Math.round(place.yearRank ?? 0);
  if (!(count >= 1 && count <= 15 && rank >= 1 && rank <= count)) return undefined;
  return { rank, count };
}

/**
 * **La classe internationale de l'année**, ou `undefined` quand on ne la connaît pas. Une
 * filière de `FIRST_GRADE` la donne exactement ; une autre filière secondaire se place depuis
 * la fin de son cycle (le collège finit en classe 9, le lycée en classe 12).
 */
export function gradeOf(place: YearPlace): number | undefined {
  const position = rankOf(place);
  if (!position) return undefined;
  const first = place.trackId ? FIRST_GRADE[place.trackId] : undefined;
  if (first !== undefined) return first + position.rank - 1;
  if (place.tier === "lowerSecondary") return 9 - (position.count - position.rank);
  if (place.tier === "upperSecondary") return 12 - (position.count - position.rank);
  return undefined;
}

/**
 * **Le palier de l'élève.** Au collège : les deux premières années (classe 7 au plus) sont
 * le début, la suite la fin. Au lycée : la dernière année de la filière est celle de
 * l'examen final. Sans année, le palier « du milieu » de la marche : c'est ce que la leçon
 * faisait avant, rien ne se dégrade.
 */
export function bandOf(place: YearPlace): Band {
  switch (place.tier) {
    case "lowerSecondary": {
      const grade = gradeOf(place);
      return grade !== undefined && grade <= 7 ? "lowerEarly" : "lowerLate";
    }
    case "upperSecondary": {
      const position = rankOf(place);
      const grade = gradeOf(place);
      const last = position !== undefined && position.rank === position.count && position.count > 1;
      return last || (grade !== undefined && grade >= 13) ? "upperFinal" : "upperEarly";
    }
    case "preUniversity":
    case "undergraduate":
    case "graduate":
    case "health":
    case "competitive":
      return place.tier;
    default:
      return "unknown";
  }
}

/** Une ligne de la table de calibrage. */
export interface Calibration {
  band: Band;
  /** Le palier en clair, avec ses équivalents dans d'autres pays. */
  label: string;
  /** Ce qu'on peut supposer acquis. */
  prerequisites: string;
  /** Les mots qu'on emploie. */
  vocabulary: string;
  /** Les formes d'exercices qui conviennent. */
  exercises: string;
  /** La difficulté visée, sur l'échelle 1 à 3 des questions. */
  difficulty: string;
  /** Le format de l'examen blanc. */
  mockExam: string;
  /** Combien de thèmes, de questions et de cartes. */
  volume: Volume;
  /** Jusqu'où expliquer, et la longueur des notes. */
  depth: Depth;
}

/**
 * **La table.** Les volumes et les profondeurs restent sous les plafonds de
 * `generate-lesson/schema.ts` (`LIMITS`) : au plus 12 thèmes, 8 questions et 8 cartes par
 * thème, 12 blocs, 120 mots par paragraphe ; au moins 4 thèmes et 3 questions.
 */
export const CALIBRATION: Record<Band, Calibration> = {
  lowerEarly: {
    band: "lowerEarly",
    label: "début du collège, 10 à 12 ans (en France : Sixième, Cinquième ; Year 7-8 ; 5.-6. Klasse ; 1º-2º ESO ; 5.-6. sınıf ; 6th-7th grade)",
    prerequisites: "Seuls les acquis de l'école primaire sont supposés : lire, les quatre opérations, les nombres décimaux simples, quelques repères de temps et d'espace. Rien du collège n'est supposé connu : rappelle en une phrase ce qui sert.",
    vocabulary: "Des mots de tous les jours, des phrases de 15 mots au plus. Au plus un mot technique nouveau par bloc, toujours défini avec un exemple de sa vie (l'école, le sport, la cuisine, un jeu).",
    exercises: "QCM, vrai ou faux, texte à trous, associer, remettre dans l'ordre ; un calcul ou un cas en une seule étape. Pas de rédaction.",
    difficulty: "Surtout de la difficulté 1 et 2 (reconnaître, comprendre, appliquer sur un cas très simple), une seule question de difficulté 3.",
    mockExam: "Une interrogation de classe : des questions courtes, une notion par question, des consignes d'une ligne.",
    volume: { topicThemes: [4, 5], maxThemes: 7, questions: 5, flashcards: 4 },
    depth: {
      blocks: [3, 5],
      paragraphWords: 70,
      style: "Un cours court et concret : une idée par bloc, une image ou une situation de la vie courante pour chaque idée, la règle dite simplement avec sa raison. Rien d'abstrait sans exemple.",
      examFormat: false,
      register: "guided",
      listItems: 4,
      listItemWords: 14,
    },
  },
  lowerLate: {
    band: "lowerLate",
    label: "fin du collège, 13 à 15 ans (en France : Quatrième, Troisième et le brevet ; Year 9-11 et les GCSE ; 7.-10. Klasse ; 3º-4º ESO ; 7.-8. sınıf et le LGS ; 8th grade)",
    prerequisites: "Les notions des premières années du collège sont supposées connues ; rappelle en une ligne celle dont dépend la notion du jour.",
    vocabulary: "Le vocabulaire du programme du collège, chaque terme défini la première fois ; des phrases simples, sans jargon de lycée.",
    exercises: "QCM, vrai ou faux, texte à trous, associer, remettre dans l'ordre ; un calcul ou un cas en deux étapes, une courte justification, la lecture d'un document simple.",
    difficulty: "De la difficulté 1 à 3, surtout 2 ; une ou deux questions d'application en deux étapes.",
    mockExam: "Au format de l'examen de fin de collège quand il y en a un (brevet, GCSE, LGS…) : questions de cours, exercices courts, une application ; sinon, un contrôle de classe.",
    volume: volumeOf("lowerSecondary"),
    depth: depthOf("lowerSecondary"),
  },
  upperEarly: {
    band: "upperEarly",
    label: "premières années du lycée, 15 à 17 ans (en France : Seconde, Première ; Year 12 (AS) ; 10.-11. Klasse ; 1º Bachillerato ; 9.-11. sınıf ; 9th-11th grade)",
    prerequisites: "Le programme du collège est acquis : ne le réexplique pas, rappelle-le en une ligne quand il sert.",
    vocabulary: "Le vocabulaire exact du programme du lycée, les définitions telles que le professeur les attend.",
    exercises: "Toutes les formes ; des questions de raisonnement (justifier, expliquer un mécanisme, analyser un document, un calcul en plusieurs étapes).",
    difficulty: "Surtout de la difficulté 2, avec au moins une question de difficulté 3 par thème.",
    mockExam: "Un devoir surveillé de lycée : questions de cours, exercices d'application, une question de synthèse.",
    volume: volumeOf("upperSecondary"),
    depth: depthOf("upperSecondary"),
  },
  upperFinal: {
    band: "upperFinal",
    label: "dernière année du secondaire, l'année de l'examen final, 17 à 18 ans (en France : Terminale et le bac ; Year 13 et les A-levels ; Abitur ; 2º Bachillerato et la PAU ; 12. sınıf et le YKS ; 12th grade)",
    prerequisites: "Tout le programme des années précédentes est supposé connu ; rappelle en une ligne la notion antérieure dont dépend celle du jour.",
    vocabulary: "Le vocabulaire exact de l'examen final : les mots des consignes (définir, justifier, démontrer, analyser), les définitions attendues mot pour mot.",
    exercises: "Toutes les formes ; des questions au format de l'épreuve finale, des cas nouveaux, un raisonnement en plusieurs étapes, l'erreur classique à repérer.",
    difficulty: "Surtout de la difficulté 2 et 3 : au moins deux questions de difficulté 3 par thème, dont une au format exact de l'épreuve.",
    mockExam: "Au format de l'épreuve finale du pays : ses types d'exercices, ses consignes, son barème, une question de synthèse.",
    volume: { topicThemes: [6, 8], maxThemes: 12, questions: 7, flashcards: 6 },
    depth: {
      blocks: [6, 9],
      paragraphWords: 115,
      style: "Un cours au niveau de l'examen final : chaque mécanisme jusqu'au bout, la méthode attendue à l'épreuve (comment on rédige, comment on justifie), les pièges qui coûtent des points, un exemple du niveau d'un sujet d'examen.",
      examFormat: true,
      register: "explained",
      listItems: 7,
      listItemWords: 24,
    },
  },
  preUniversity: {
    band: "preUniversity",
    label: "classe préparatoire ou équivalent (cégep, foundation year)",
    prerequisites: "Tout le secondaire est acquis, y compris la dernière année.",
    vocabulary: "Le vocabulaire rigoureux de la discipline, sans simplification.",
    exercises: "Des questions de raisonnement, de démonstration, de cas limites ; des pièges d'écrit de concours.",
    difficulty: "Surtout de la difficulté 3.",
    mockExam: "Au format des écrits du concours visé : peu de questions, longues, enchaînées.",
    volume: volumeOf("preUniversity"),
    depth: depthOf("preUniversity"),
  },
  undergraduate: {
    band: "undergraduate",
    label: "premier cycle universitaire (licence, bachelor, grado, lisans)",
    prerequisites: "Le secondaire est acquis ; les cours des semestres précédents aussi.",
    vocabulary: "Le vocabulaire du cours tel quel, les auteurs et les notions précises.",
    exercises: "Définitions précises, mécanismes, cas d'application, comparaison de positions.",
    difficulty: "Surtout de la difficulté 2 et 3.",
    mockExam: "Au format d'un partiel : questions de cours, cas pratiques, une question de réflexion.",
    volume: volumeOf("undergraduate"),
    depth: depthOf("undergraduate"),
  },
  graduate: {
    band: "graduate",
    label: "master ou plus",
    prerequisites: "Les bases de la discipline sont acquises.",
    vocabulary: "Le vocabulaire de spécialiste, les débats et les auteurs.",
    exercises: "Analyse, comparaison, limites, conditions de validité.",
    difficulty: "Surtout de la difficulté 3.",
    mockExam: "Au format d'un examen de master : peu de questions, d'analyse et de comparaison.",
    volume: volumeOf("graduate"),
    depth: depthOf("graduate"),
  },
  health: {
    band: "health",
    label: "études de santé",
    prerequisites: "Les sciences du secondaire sont acquises.",
    vocabulary: "La nomenclature exacte, les valeurs seuils avec leurs unités.",
    exercises: "QCM à pièges fins, une seule réponse juste, des distracteurs qui sont les confusions classiques.",
    difficulty: "Surtout de la difficulté 2 et 3.",
    mockExam: "Au format des QCM des examens de santé, chronométrés.",
    volume: volumeOf("health"),
    depth: depthOf("health"),
  },
  competitive: {
    band: "competitive",
    label: "candidat à un concours ou à un examen d'entrée",
    prerequisites: "Le programme du concours est supposé vu au moins une fois.",
    vocabulary: "Les mots et les formats du concours visé.",
    exercises: "Au format du concours : ce qui tombe, de plus en plus difficile.",
    difficulty: "De la difficulté 2 à 3, en montée.",
    mockExam: "Au format exact du concours visé, chronométré.",
    volume: volumeOf("competitive"),
    depth: depthOf("competitive"),
  },
  unknown: {
    band: "unknown",
    label: "niveau non précisé",
    prerequisites: "Aucun prérequis n'est supposé.",
    vocabulary: "Chaque terme technique est défini la première fois.",
    exercises: "Des formes variées, de la compréhension à l'application.",
    difficulty: "Une difficulté qui monte de 1 à 3.",
    mockExam: "Un contrôle de connaissances équilibré, sans format d'examen nommé.",
    volume: volumeOf("other"),
    depth: depthOf("other"),
  },
};

/** La ligne de calibrage d'un élève. */
export function calibrationOf(place: YearPlace): Calibration {
  return CALIBRATION[bandOf(place)];
}

/**
 * **Le calibrage, en consignes**, pour le prompt. La marche dit déjà comment écrire
 * (`TIER_BRIEFS`) ; ces lignes disent CE palier-là.
 */
export function calibrationBrief(calibration: Calibration, grade?: number): string {
  const lines = [
    "CALIBRAGE DU NIVEAU",
    `- Palier : ${calibration.label}${grade !== undefined ? ` ; classe ${grade} sur l'échelle internationale (années depuis l'entrée à l'école élémentaire, âge d'environ ${grade + 5} ans)` : ""}.`,
    `- Prérequis : ${calibration.prerequisites}`,
    `- Vocabulaire : ${calibration.vocabulary}`,
    `- Exercices : ${calibration.exercises}`,
    `- Difficulté : ${calibration.difficulty}`,
    `- Examen blanc : ${calibration.mockExam}`,
  ];
  return lines.join("\n");
}

// MARK: - Les longueurs

/**
 * **Le nombre de thèmes, proportionné au support.** Une page (≈ 2 500 caractères) ne fait
 * pas autant de thèmes qu'un chapitre de dix pages, et un chapitre de dix pages ne tient pas
 * en quatre thèmes. Un thème de plus tous les huit mille caractères (environ trois pages),
 * borné par le plafond du palier.
 */
export function sourceThemeRange(characters: number, maxThemes: number): [number, number] {
  const max = Math.max(4, Math.min(12, maxThemes));
  const low = Math.min(max - 1, 4 + Math.floor(Math.max(0, characters) / 8_000));
  return [Math.max(4, low), Math.max(4, Math.min(max, low + 2))];
}

/** Le nombre de pages, à peu près, d'un texte : pour le dire au modèle. */
export function pagesOf(characters: number): number {
  return Math.max(1, Math.round(characters / 2_500));
}

/**
 * **Les blocs d'un thème, selon la part du support qu'il couvre.** Un thème qui couvre trois
 * pages d'un cours ne se résume pas dans le même nombre de blocs qu'un thème qui en couvre une
 * demi : un bloc de plus au-delà de quatre mille caractères, deux au-delà de huit mille. Le
 * plafond (`LIMITS.blocksHardMax`, 12) laisse encore deux blocs de marge à `noteLimits`.
 */
export function blocksForShare(blocks: readonly [number, number], shareCharacters: number): [number, number] {
  const extra = shareCharacters > 8_000 ? 2 : shareCharacters > 4_000 ? 1 : 0;
  const high = Math.min(10, blocks[1] + extra);
  const low = Math.min(high, blocks[0] + (extra > 1 ? 1 : 0));
  return [low, high];
}
