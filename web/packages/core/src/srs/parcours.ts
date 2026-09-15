/**
 * **Le test de parcours : la mesure courte, entre deux blancs.**
 *
 * Un examen blanc mesure tout le programme en temps imparti. C'est la bonne mesure, et elle
 * coûte cher : vingt questions, un quart d'heure, et le sentiment d'un examen. On n'en pose
 * que deux, à J-7 et à J-2, parce qu'en poser six ferait de la préparation une suite
 * d'épreuves.
 *
 * Entre les deux, il ne se passait rien de mesuré. L'étudiant révisait ses cartes, et
 * l'estimation de préparation retombait sur une projection - une formule qui dit 88 % là où un
 * blanc en donne 54. Le test de parcours ferme cet écart sans le coût d'un blanc : cinq QCM et
 * cinq questions orales, cinq minutes, tous les deux ou trois jours.
 *
 * ## Pourquoi la cadence se resserre en approchant
 *
 * « Tous les deux ou trois jours » n'est pas une moyenne : c'est deux régimes. Loin de
 * l'épreuve, l'étudiant construit sa base et un test tous les trois jours suffit à dire où il
 * en est. Dans les dix derniers jours, ce qu'il rate coûte cher et se corrige encore : un test
 * tous les deux jours rattrape une lacune avant qu'elle n'arrive au jour J.
 *
 * ## Pourquoi il y en a huit au plus
 *
 * La cadence se compte **depuis l'épreuve**, pas depuis aujourd'hui. Une échéance à deux mois
 * ne mérite pas vingt tests de parcours : elle mérite les mêmes huit, posés là où ils servent,
 * c'est-à-dire dans les dernières semaines. Avant, il n'y a rien à mesurer qu'une base encore
 * en construction, et huit mesures suffisent à en suivre la montée.
 */

/** Le premier rendez-vous, en jours avant l'épreuve. J-1 et le jour J restent au révisions. */
export const PARCOURS_FIRST_OFFSET = 2;

/** En deçà de ce nombre de jours restants, un test tous les deux jours. Au-delà, tous les trois. */
export const PARCOURS_TIGHT_WINDOW = 10;

export const PARCOURS_TIGHT_STEP = 2;
export const PARCOURS_LOOSE_STEP = 3;

/** Au-delà, la préparation devient une suite d'épreuves. Voir l'en-tête. */
export const PARCOURS_MAX = 8;

/** Cinq QCM et cinq questions orales : le format ne varie pas, c'est ce qui le rend comparable. */
export const PARCOURS_CHOICE_COUNT = 5;
export const PARCOURS_ORAL_COUNT = 5;
export const PARCOURS_QUESTION_COUNT = PARCOURS_CHOICE_COUNT + PARCOURS_ORAL_COUNT;

/** Cinq minutes : assez pour dix questions dont la moitié se répond à voix haute. */
export const PARCOURS_MINUTES = 5;

/**
 * Les rendez-vous d'un examen, en **jours avant l'épreuve**, du plus proche au plus lointain.
 *
 * Comptés depuis l'épreuve et non depuis aujourd'hui : c'est la distance au jour J qui décide
 * de la cadence, et elle ne doit pas changer parce qu'on a ouvert l'app trois jours plus tard.
 *
 * Le résultat ne dépend donc que de la longueur de la fenêtre, ce qui le rend comparable d'un
 * jour à l'autre : un test posé à J-13 y reste tant que l'examen ne bouge pas.
 */
export function parcoursOffsets(daysRemaining: number, max = PARCOURS_MAX): number[] {
  if (!Number.isFinite(daysRemaining) || daysRemaining < PARCOURS_FIRST_OFFSET) return [];

  const offsets: number[] = [];
  let offset = PARCOURS_FIRST_OFFSET;

  while (offset <= daysRemaining && offsets.length < Math.max(0, max)) {
    offsets.push(offset);
    offset += offset < PARCOURS_TIGHT_WINDOW ? PARCOURS_TIGHT_STEP : PARCOURS_LOOSE_STEP;
  }

  return offsets;
}

/**
 * La composition d'un test de parcours, telle qu'elle part à `generate-mock`.
 *
 * Elle ne se déduit pas de `paperQuota` : celui-ci répartit vingt questions entre quatre
 * familles pour imiter une épreuve, alors qu'un parcours a un format arrêté - cinq QCM, cinq
 * explications - et c'est ce format fixe qui rend deux tests comparables d'une semaine à
 * l'autre.
 *
 * **Sans micro, les cinq orales deviennent cinq QCM.** Le test garde ses dix questions notées
 * plutôt que d'en perdre la moitié : une mesure amputée ne se compare à aucune autre. Ce n'est
 * pas tout à fait la même mesure - un QCM se devine, une explication non - mais c'en est une.
 */
export function parcoursQuota(withAudio: boolean): {
  choice: number;
  truefalse: number;
  gap: number;
  feynman: number;
} {
  return {
    choice: withAudio ? PARCOURS_CHOICE_COUNT : PARCOURS_QUESTION_COUNT,
    truefalse: 0,
    gap: 0,
    feynman: withAudio ? PARCOURS_ORAL_COUNT : 0,
  };
}
