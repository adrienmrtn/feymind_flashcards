import { gradeTicks, TARGET_SCORE_MIN } from "@micabo/core";

/**
 * **Les moyennes qu'on peut choisir, dans le barème du pays.**
 *
 * L'échelle canonique du produit est un nombre de 10 à 20 : c'est elle qui décide de
 * l'intensité du plan, et c'est elle qu'on enregistre. Ce qui s'affiche, en revanche, est
 * toujours le barème local - `17/20` en France, `1,3` en Allemagne, `A-` aux États-Unis.
 * Demander une moyenne sur vingt à un Allemand, c'est lui demander de convertir avant de
 * répondre, et une question à laquelle on doit réfléchir deux fois est une question qu'on
 * saute.
 *
 * Deux corrections sur les onze crans bruts :
 *
 * - **Les doublons partent.** Onze crans pour neuf lettres, ça fait deux `C-` de suite dans la
 *   liste ; c'est invisible sur un curseur, c'est incompréhensible sur des boutons. On garde
 *   le premier cran de chaque libellé, donc le plus bas : celui qui répond `B` obtient bien la
 *   plus petite valeur que `B` peut vouloir dire, et personne n'est crédité d'un point qu'il
 *   n'a pas dit avoir.
 * - **Un cran de plus, en dessous.** Le barème part de la moyenne, ce qui laisse sans réponse
 *   celui qui est en dessous - c'est-à-dire précisément celui à qui ce produit sert le plus.
 */

export interface GradeChoice {
  /** La valeur canonique enregistrée. `BELOW_SCORE` pour « en dessous ». */
  score: number;
  /** Ce qui s'écrit sur le bouton. */
  label: string;
}

/** En dessous du premier cran du barème. Hors échelle, donc jamais une moyenne visée. */
export const BELOW_SCORE = TARGET_SCORE_MIN - 1;

/** Les moyennes affichables, de la plus basse à la plus haute, sans doublon. */
export function gradeChoices(country?: string | null): GradeChoice[] {
  const seen = new Set<string>();
  const choices: GradeChoice[] = [];

  for (const tick of gradeTicks(country)) {
    if (seen.has(tick.label)) continue;
    seen.add(tick.label);
    choices.push({ score: tick.score, label: tick.label });
  }

  return choices;
}

/** Le libellé d'une valeur enregistrée, `null` quand elle est hors barème. */
export function gradeLabel(score: number, country?: string | null): string | null {
  return gradeChoices(country).find((choice) => choice.score === score)?.label ?? null;
}

/** Ce qu'on peut viser quand on part de là. Toujours strictement au-dessus. */
export function targetChoices(current: number | undefined, country?: string | null): GradeChoice[] {
  const floor = current ?? BELOW_SCORE;
  return gradeChoices(country).filter((choice) => choice.score > floor);
}
