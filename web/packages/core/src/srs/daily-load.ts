/**
 * Ce que coûte une carte, en temps.
 *
 * Ce module portait un **plafond** : combien de cartes neuves on avait le droit d'introduire
 * dans une journée, déduit d'un budget de minutes déclaré au réglage. Le plafond est parti,
 * et avec lui l'idée qu'un étudiant sait à l'avance combien de minutes il donnera. Ce qui
 * décide de la journée, c'est **la charge de travail** : ce que les échéances demandent
 * aujourd'hui, et rien d'autre. Le produit dit alors combien de temps ça prendra, au lieu de
 * décider combien il a le droit de prendre.
 *
 * Ne restent ici que les deux constantes qui convertissent des cartes en minutes, et
 * l'écriture d'une durée.
 */

/** Cartes vues par minute, à défaut d'une mesure. `calibration.ts` la remplace dès qu'il en a une. */
export const CARDS_PER_MINUTE = 4.0;

/** Passages nécessaires, en moyenne, pour ancrer durablement une carte. */
export const REPETITIONS_PER_CARD = 8.0;

/** « 15 min », « 1 h », « 1 h 30 » : au-delà de l'heure on ne parle plus en minutes. */
export function dailyMinutesLabel(minutes: number): string {
  if (minutes < 60) return `${minutes} min`;
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  return rest === 0 ? `${hours} h` : `${hours} h ${rest}`;
}
