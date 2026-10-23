import { stableHash } from "./picking";

/**
 * **Les cinq tons de Micabo, et la couleur d'une leçon.** Jumeau de `LessonTone.swift`.
 *
 * Chaque leçon reçoit un ton à sa création, et le garde : c'est la couleur de son chemin
 * (étapes cochées, trait, barre) et le fond de ses encadrés « En une phrase » et « À retenir ».
 * Trois nuances par ton (pâle, vive, encre), posées en jetons CSS (`--color-tone-<ton>-<nuance>`).
 */
export const LESSON_TONES = ["yellow", "mint", "blue", "pink", "lilac"] as const;
export type LessonTone = (typeof LESSON_TONES)[number];

/** Un ton lu depuis le stockage ; un nom inconnu (ou absent) retombe sur le bleu. */
export function readTone(raw: string | null | undefined): LessonTone {
  return (LESSON_TONES as readonly string[]).includes(raw ?? "") ? (raw as LessonTone) : "blue";
}

/** Le ton de la leçon suivante : jamais celui de la précédente, et les cinq tournent. */
export function nextTone(previous: LessonTone | null | undefined): LessonTone {
  if (!previous) return "yellow";
  const position = LESSON_TONES.indexOf(previous);
  return LESSON_TONES[(Math.max(0, position) + 1) % LESSON_TONES.length]!;
}

/**
 * Le ton d'une leçon qui n'en a pas encore (un ancien cours), tiré de son identifiant.
 * Stable d'un lancement à l'autre et d'un appareil à l'autre : Swift hache `uuidString`, qui
 * est en majuscules, et on fait pareil.
 */
export function stableTone(id: string): LessonTone {
  return LESSON_TONES[Number(stableHash(id.toUpperCase()) % BigInt(LESSON_TONES.length))]!;
}

/** Le ton d'une leçon : le sien, sinon un ton stable tiré de son identifiant. */
export function lessonTone(id: string, raw: string | null | undefined): LessonTone {
  return raw ? readTone(raw) : stableTone(id);
}

/** Les jetons CSS d'un ton, pour un style en ligne. */
export function toneVars(tone: LessonTone): { pale: string; vivid: string; ink: string } {
  return {
    pale: `var(--color-tone-${tone}-pale)`,
    vivid: `var(--color-tone-${tone}-vivid)`,
    ink: `var(--color-tone-${tone}-ink)`,
  };
}
