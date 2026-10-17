/**
 * **Comment on évalue, selon la matière et selon le niveau.**
 *
 * Un examen blanc de mathématiques n'a pas la forme d'un examen d'histoire : l'un se fait de
 * calculs dont les mauvaises réponses sont les erreurs de calcul, l'autre de dates, de causes
 * et de documents. Et un examen de quatrième n'a ni la longueur ni les pièges d'un partiel de
 * master. Ces deux axes se croisent : la matière dit quelles formes de questions lui vont, le
 * niveau dit combien de raisonnement on demande et sur quel ton.
 *
 * Ces consignes servent aux questions (examen blanc, nouvelles questions d'entraînement),
 * jamais aux notes : les notes ont leur propre consigne de matière (`discipline.ts`).
 *
 * Tout est pur et testé (`assessment.test.ts`).
 */

import type { Discipline } from "./discipline.ts";
import type { Tier } from "./learner.ts";

interface DisciplineFormats {
  /** Le nom de la matière, tel qu'on l'écrit dans la consigne. */
  name: string;
  /** Les formes qui lui vont, et sur quoi. */
  mix: string;
  /** Ce qu'est une question d'application dans cette matière. */
  application: string;
  /** D'où viennent les mauvaises réponses. */
  distractors: string;
}

const FORMATS: Record<Discipline, DisciplineFormats> = {
  mathematics: {
    name: "mathématiques",
    mix: "surtout des « choice » dont la réponse est un résultat, des « gap » sur la valeur ou le terme manquant d'une formule, un « order » pour les étapes d'une méthode ou d'une démonstration, des « truefalse » sur les conditions d'application d'un théorème",
    application: "un calcul court sur des valeurs nouvelles, ou une propriété à appliquer à un cas qui n'est pas dans le cours",
    distractors: "les résultats des erreurs classiques : signe, facteur oublié, mauvaise formule, condition non vérifiée",
  },
  physics: {
    name: "physique",
    mix: "des « choice » avec unités, des « gap » sur une grandeur ou son unité, un « match » grandeur ↔ unité ou loi ↔ domaine, un « order » pour un protocole",
    application: "un calcul ou un ordre de grandeur dans une situation expérimentale nouvelle",
    distractors: "les erreurs d'unité, de conversion, de puissance de dix, et la loi appliquée hors de son domaine",
  },
  chemistry: {
    name: "chimie",
    mix: "des « choice » sur une équation équilibrée ou un résultat avec unité, des « gap » sur un coefficient ou une espèce, un « match » espèce ↔ nom ou acide ↔ base conjuguée, un « order » pour un protocole ou un mécanisme",
    application: "un calcul de quantité de matière ou de concentration, ou une réaction nouvelle à équilibrer",
    distractors: "l'équation mal équilibrée, l'erreur de masse molaire ou de conversion, l'acide pris pour sa base conjuguée",
  },
  biology: {
    name: "SVT, biologie",
    mix: "un « order » pour les étapes d'un mécanisme, un « match » structure ↔ fonction, des « truefalse » sur les confusions d'échelle, des « choice » sur l'interprétation d'un résultat",
    application: "un résultat d'expérience décrit en une phrase, à interpréter",
    distractors: "les confusions d'échelle (molécule, cellule, organisme), de cause et d'effet, et les structures voisines",
  },
  history: {
    name: "histoire",
    mix: "un « order » chronologique, un « match » date ou acteur ↔ événement, des « choice » de cause ou de conséquence, des « gap » sur la notion du cours",
    application: "un court extrait ou une situation, à replacer dans son contexte ou à expliquer",
    distractors: "les dates voisines, les acteurs du camp d'en face, l'anachronisme et la conséquence prise pour une cause",
  },
  geography: {
    name: "géographie",
    mix: "des « choice » de cause ou de conséquence, un « match » lieu ↔ phénomène ou notion ↔ définition, des « truefalse » sur l'échelle ou un chiffre, un « order » pour un enchaînement de causes",
    application: "un territoire ou une situation décrite en deux phrases, à expliquer avec les notions du cours",
    distractors: "l'échelle confondue, le chiffre d'une autre année, la cause prise pour une conséquence, le lieu voisin",
  },
  literature: {
    name: "lettres",
    mix: "un « match » auteur ↔ œuvre ou mouvement, des « choice » procédé ↔ effet, des « gap » sur un terme d'analyse, des « truefalse » sur une interprétation",
    application: "une citation courte du cours dont il faut nommer le procédé ou l'effet",
    distractors: "les procédés voisins (métaphore et comparaison, anaphore et répétition), les mouvements et les siècles proches",
  },
  philosophy: {
    name: "philosophie",
    mix: "un « match » auteur ↔ thèse, des « truefalse » sur une thèse mal attribuée, des « choice » sur une distinction conceptuelle",
    application: "un exemple nouveau à rattacher à la bonne notion ou au bon auteur",
    distractors: "la thèse de l'auteur opposé, le contresens courant, la notion voisine",
  },
  language: {
    name: "langue vivante",
    mix: "des « gap » de grammaire ou de vocabulaire DANS la langue étudiée, un « match » mot ↔ traduction, des « choice » sur la construction correcte, des « truefalse » sur une règle",
    application: "une phrase nouvelle à compléter ou à corriger dans la langue étudiée",
    distractors: "les faux amis, les erreurs d'accord ou de temps, les prépositions qu'on confond",
  },
  economics: {
    name: "sciences économiques",
    mix: "des « choice » sur un mécanisme, un « order » pour un enchaînement de causes, un « match » école ou auteur ↔ thèse, des « truefalse » sur un effet",
    application: "une situation chiffrée simple (prix, taux, quantité) dont il faut tirer la conséquence",
    distractors: "l'effet inverse, la confusion de deux notions voisines (inflation et hausse d'un prix), la thèse de l'école opposée",
  },
  law: {
    name: "droit",
    mix: "des « choice » de qualification, un « match » règle ↔ source, des « truefalse » sur une exception, un « order » pour une procédure",
    application: "un mini cas pratique : des faits en deux phrases, la règle qui s'applique",
    distractors: "la règle voisine, l'exception oubliée, la mauvaise juridiction",
  },
  medicine: {
    name: "santé",
    mix: "des « choice » à une seule réponse juste, un « match » structure ↔ fonction ou valeur ↔ unité, des « truefalse » sur les confusions classiques",
    application: "une vignette clinique de deux phrases",
    distractors: "les erreurs fréquentes des QCM de santé : valeur seuil voisine, structure adjacente, mécanisme inversé",
  },
  computing: {
    name: "informatique",
    mix: "un « order » pour les étapes d'un algorithme, des « choice » sur la sortie d'un code court ou sur une complexité, un « match » structure ↔ usage",
    application: "la trace d'un algorithme sur une petite entrée",
    distractors: "l'erreur d'une case (off-by-one), la complexité voisine, la structure qui ne convient pas",
  },
  general: {
    name: "",
    mix: "un mélange équilibré des formes permises",
    application: "une situation nouvelle où appliquer une notion du cours",
    distractors: "les erreurs que font vraiment les élèves sur ces notions",
  },
};

/** Ce que le niveau change à l'épreuve : longueur, raisonnement, difficulté. */
const TIER_EXAMS: Record<Tier, { share: number; line: string }> = {
  lowerSecondary: {
    share: 25,
    line: "Énoncés courts (20 mots au plus), mots simples, surtout « choice », « truefalse » et « gap » ; un « order » ou un « match » de 3 ou 4 éléments au plus. Difficulté 1 et 2, un peu de 3. Les applications partent de la vie courante.",
  },
  upperSecondary: {
    share: 35,
    line: "Le format et le vocabulaire du sujet d'examen de sa classe : définir, expliquer, justifier, calculer, exploiter un document. Toutes les formes. Difficulté surtout 2 et 3.",
  },
  preUniversity: {
    share: 45,
    line: "La rigueur de l'écrit : hypothèses, cas limites, raisonnement sans étape sautée. Difficulté surtout 3, les distracteurs sont les pièges de l'écrit.",
  },
  undergraduate: {
    share: 40,
    line: "Définitions précises, mécanismes détaillés et cas d'application, comme au partiel. Difficulté surtout 2 et 3.",
  },
  graduate: {
    share: 55,
    line: "L'analyse avant la définition : limites, conditions de validité, positions qui s'opposent, comparaison. Rarement une définition seule. Difficulté surtout 3.",
  },
  health: {
    share: 40,
    line: "Le format des QCM des examens de santé : une seule réponse juste, des distracteurs fins qui sont les erreurs fréquentes, nomenclature et valeurs exactes. Difficulté surtout 3.",
  },
  competitive: {
    share: 45,
    line: "Le format et le niveau du concours visé, de plus en plus difficiles : ce qui tombe, les pièges classiques, les chiffres à connaître.",
  },
  other: {
    share: 30,
    line: "Une difficulté qui monte progressivement, chaque terme du cours tel quel.",
  },
};

/** La part de questions d'application ou de raisonnement attendue à ce niveau, en pourcentage. */
export function applicationShare(tier: Tier): number {
  return TIER_EXAMS[tier].share;
}

/** Le nom de la matière, vide pour une matière générale. */
export function disciplineName(discipline: Discipline): string {
  return FORMATS[discipline].name;
}

/**
 * **La consigne des formes**, pour les matières présentes et le niveau de l'élève. Une
 * matière n'y figure qu'une fois, même si plusieurs leçons la partagent.
 */
export function assessmentBrief(options: { tier: Tier; disciplines: Discipline[]; count: number }): string {
  const tier = TIER_EXAMS[options.tier];
  const applications = Math.max(1, Math.round((options.count * tier.share) / 100));
  const seen = [...new Set(options.disciplines)];
  const subjects = seen.filter((discipline) => discipline !== "general");
  const lines = [
    "COMMENT ÉVALUER",
    `- Niveau : ${tier.line}`,
    `- Au moins ${applications} question${applications > 1 ? "s" : ""} d'application ou de raisonnement sur ${options.count}.`,
    "- Varie les formes : au moins trois formes différentes, et aucune forme sur plus de la moitié des questions. Deux questions qui se suivent n'ont pas la même forme quand c'est possible.",
  ];
  for (const discipline of subjects.length ? subjects : ["general" as const]) {
    const formats = FORMATS[discipline];
    const label = formats.name ? `En ${formats.name}` : "Pour ces leçons";
    lines.push(
      `- ${label} : ${formats.mix}. Une application, c'est ${formats.application}. Les propositions fausses : ${formats.distractors}.`,
    );
  }
  return lines.join("\n");
}

/**
 * **Vrai quand une épreuve varie assez ses formes** : au moins trois formes dès dix questions
 * (deux en dessous), et aucune forme sur plus des deux tiers. Une copie qui ne fait que des
 * QCM se réécrit une fois.
 */
export function hasVariedKinds(kinds: readonly string[], allowed: number): boolean {
  if (kinds.length === 0) return false;
  const counts = new Map<string, number>();
  for (const kind of kinds) counts.set(kind, (counts.get(kind) ?? 0) + 1);
  const wanted = Math.min(allowed, kinds.length >= 10 ? 3 : 2);
  const top = Math.max(...counts.values());
  return counts.size >= wanted && top <= Math.ceil((kinds.length * 2) / 3);
}
