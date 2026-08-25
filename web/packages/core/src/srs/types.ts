/**
 * Les types que partagent l'iPhone et le web.
 *
 * Ils ne sont pas inventés ici : ce sont les valeurs qui voyagent déjà dans les colonnes
 * `flashcards.state` et `review_logs.rating`. Les renommer côté web reviendrait à réécrire la
 * base, donc ils sont recopiés tels quels depuis `Micabo/Models/Flashcard.swift`.
 */

/** États d'une carte, calqués sur ceux d'Anki. */
export type CardState = "new" | "learning" | "review" | "relearning";

/**
 * Les quatre boutons de maîtrise, et **leurs nombres**.
 *
 * La valeur numérique n'est pas décorative : c'est elle qui part dans `review_logs.rating`,
 * où une contrainte de la base la borne entre 1 et 4. Elle sert aussi de raccourci clavier
 * dans la session du web — 1 à 4 sous les doigts, dans cet ordre.
 */
export const ReviewRating = {
  again: 1,
  hard: 2,
  good: 3,
  easy: 4,
} as const;

export type ReviewRating = (typeof ReviewRating)[keyof typeof ReviewRating];

/** Dans l'ordre des boutons, de gauche à droite. */
export const REVIEW_RATINGS: readonly ReviewRating[] = [
  ReviewRating.again,
  ReviewRating.hard,
  ReviewRating.good,
  ReviewRating.easy,
];

/** Les libellés de `MicaboCopy` : « À revoir », et non « Encore » ni « Again ». */
export const REVIEW_RATING_LABELS: Record<ReviewRating, string> = {
  [ReviewRating.again]: "À revoir",
  [ReviewRating.hard]: "Difficile",
  [ReviewRating.good]: "Correct",
  [ReviewRating.easy]: "Facile",
};

/** Instantané de l'état de programmation d'une carte, indépendant de tout stockage. */
export interface CardSnapshot {
  state: CardState;
  intervalDays: number;
  easeFactor: number;
  repetitions: number;
  lapses: number;
  stepIndex: number;
}

/** Résultat d'une réponse : nouvel état, échéance et intervalle. */
export interface ScheduleOutcome {
  rating: ReviewRating;
  state: CardState;
  dueDate: Date;
  /** Intervalle en jours. Reste à la valeur « post-rechute » pendant le réapprentissage. */
  intervalDays: number;
  easeFactor: number;
  repetitions: number;
  lapses: number;
  stepIndex: number;
}

/**
 * Une carte mûre au sens d'Anki : son intervalle a dépassé trois semaines, donc elle est
 * acquise et demande un passage de moins avant un examen.
 */
export const MATURE_INTERVAL_DAYS = 21;

export function isMature(intervalDays: number): boolean {
  return intervalDays >= MATURE_INTERVAL_DAYS;
}
