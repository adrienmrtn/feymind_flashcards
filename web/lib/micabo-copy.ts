/**
 * Lexique web — préfère `copy.*` via `useI18n()` ou `getTranslator()`.
 *
 * @deprecated Utilise `lib/i18n/copy.ts` avec un traducteur.
 */

import type { Translator } from "@/lib/i18n/copy";
import {
  copyAlreadySubscribed,
  copyCards,
  copyCourses,
  copyHeldBackNew,
  copyPracticeReview,
} from "@/lib/i18n/copy";

/** @deprecated Passe un traducteur depuis `getTranslator()` ou `useI18n().t`. */
export function cards(count: number): string {
  return `${count} carte${count > 1 ? "s" : ""}`;
}

/** @deprecated */
export function heldBackNew(count: number): string {
  const noun = count > 1 ? "nouvelles cartes" : "nouvelle carte";
  return `${count} ${noun} pour plus tard — ton rythme du jour est atteint.`;
}

/** @deprecated */
export const practiceReview = "Réviser sans compter";

/** @deprecated */
export const alreadySubscribed = "Tu es déjà abonné.";

export { copyCards, copyCourses, copyHeldBackNew, copyPracticeReview, copyAlreadySubscribed };
export type { Translator };
