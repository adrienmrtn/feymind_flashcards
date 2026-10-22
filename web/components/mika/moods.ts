/**
 * Les huit humeurs de Mika, celles du design et de `MikaMood` côté Swift.
 *
 * | Humeur | Quand |
 * | --- | --- |
 * | `idle` | au repos : il respire, cligne, regarde autour. Les écrans calmes |
 * | `wave` | coucou : l'aile qui salue. L'accueil |
 * | `happy` | joie : il saute, des cœurs. Une bonne réponse, une action réussie |
 * | `sleep` | dodo : les yeux fermés, des « z ». Une liste vide |
 * | `think` | réflexion : une bulle à trois points. Les chargements |
 * | `surprise` | surprise : un point d'exclamation. Une nouveauté |
 * | `celebrate` | fête : il saute, des confettis. Une leçon terminée |
 * | `sad` | oups : une larme. Une erreur, une mauvaise réponse |
 */
export const MIKA_MOODS = [
  "idle",
  "wave",
  "happy",
  "sleep",
  "think",
  "surprise",
  "celebrate",
  "sad",
] as const;

export type MikaMood = (typeof MIKA_MOODS)[number];

export function isMikaMood(value: string | null | undefined): value is MikaMood {
  return (MIKA_MOODS as readonly string[]).includes(value ?? "");
}
