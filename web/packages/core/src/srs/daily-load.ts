/**
 * Le lien entre le temps que l'étudiant accepte de donner chaque jour et ce que le produit
 * lui sert. Porté depuis `Micabo/SRS/DailyLoad.swift`.
 *
 * Une carte neuve ne coûte pas un seul passage : elle revient `REPETITIONS_PER_CARD` fois
 * avant d'être acquise. Le plafond de nouvelles cartes par jour est donc le nombre de cartes
 * qu'on peut *introduire* sans faire déborder les sessions des jours suivants.
 *
 * Le parcours d'accueil du web ne demande pas ce réglage — la date d'examen est une meilleure
 * question que « combien de minutes par jour » — donc un compte né sur le web arrive avec le
 * défaut de 15 minutes, corrigeable dans les réglages. C'est déjà le défaut de l'app.
 */

/** Paliers du curseur : 5 minutes jusqu'à une demi-heure, puis 15 minutes jusqu'à 2 h. */
export const DAILY_MINUTES_STEPS: readonly number[] = [
  5, 10, 15, 20, 25, 30, 45, 60, 75, 90, 105, 120,
];

export const DEFAULT_DAILY_MINUTES = 15;
export const MINIMUM_DAILY_MINUTES = DAILY_MINUTES_STEPS[0]!;
export const MAXIMUM_DAILY_MINUTES = DAILY_MINUTES_STEPS[DAILY_MINUTES_STEPS.length - 1]!;

/**
 * Les constantes de la projection. Elles sont volontairement affichées à l'écran dans
 * l'app : rien n'est sorti d'un chapeau.
 */
export const CARDS_PER_MINUTE = 4.0;
/** Passages nécessaires, en moyenne, pour ancrer durablement une carte. */
export const REPETITIONS_PER_CARD = 8.0;
export const DAYS_PER_YEAR = 365.0;

/**
 * Plafond de cartes neuves par jour pour que la charge tienne dans le temps choisi.
 *
 * L'arrondi compte, et c'est pour ça que ce port se fait sur le code Swift et pas sur une
 * description : `25` minutes donnent `12,5`, que Swift arrondit **au plus loin de zéro**,
 * donc à 13. Un port qui tronquerait servirait une carte de moins par jour, tous les jours.
 */
export function newCardsPerDay(dailyMinutes: number): number {
  const cardsSeen = dailyMinutes * CARDS_PER_MINUTE;
  const introduced = cardsSeen / REPETITIONS_PER_CARD;
  return Math.max(2, Math.round(introduced));
}

/**
 * Palier le plus proche d'une valeur quelconque : une réponse enregistrée avant l'ajout des
 * paliers longs doit retomber sur un cran existant.
 */
export function nearestStep(minutes: number): number {
  let best = MINIMUM_DAILY_MINUTES;
  for (const step of DAILY_MINUTES_STEPS) {
    if (Math.abs(step - minutes) < Math.abs(best - minutes)) best = step;
  }
  return best;
}

/** Position du palier dans le curseur, qui glisse sur les index et non sur les minutes. */
export function stepIndexFor(minutes: number): number {
  const index = DAILY_MINUTES_STEPS.indexOf(nearestStep(minutes));
  return index < 0 ? 0 : index;
}

export function minutesAtStepIndex(index: number): number {
  return DAILY_MINUTES_STEPS[index] ?? MINIMUM_DAILY_MINUTES;
}

/** « 15 min », « 1 h », « 1 h 30 » : au-delà de l'heure on ne parle plus en minutes. */
export function dailyMinutesLabel(minutes: number): string {
  if (minutes < 60) return `${minutes} min`;
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  return rest === 0 ? `${hours} h` : `${hours} h ${rest}`;
}

export type Pace = "gentle" | "cruising" | "solid" | "intense";

/** Rythme annoncé sous le curseur. */
export function paceFor(dailyMinutes: number): Pace {
  if (dailyMinutes < 15) return "gentle";
  if (dailyMinutes < 30) return "cruising";
  if (dailyMinutes < 60) return "solid";
  return "intense";
}

export const PACE_LABELS: Record<Pace, string> = {
  gentle: "le rythme tranquille",
  cruising: "le rythme de croisière",
  solid: "le rythme soutenu",
  intense: "le rythme intensif",
};

/** Projection annuelle : « dans un an, tu auras appris N cartes sur le bout des doigts ». */
export function cardsPerYear(dailyMinutes: number): number {
  const raw = (dailyMinutes * DAYS_PER_YEAR * CARDS_PER_MINUTE) / REPETITIONS_PER_CARD;
  return Math.round(raw / 10) * 10;
}
