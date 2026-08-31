/**
 * Lexique web, aligné sur `MicaboCopy` iOS.
 *
 * Un seul mot par concept, tutoiement, et « réviser » — jamais « entraînement ».
 */

export function cards(count: number): string {
  return `${count} carte${count > 1 ? "s" : ""}`;
}

/** Cartes neuves reportées parce que le rythme du jour est atteint. */
export function heldBackNew(count: number): string {
  const noun = count > 1 ? "nouvelles cartes" : "nouvelle carte";
  return `${count} ${noun} pour plus tard — ton rythme du jour est atteint.`;
}

export const practiceReview = "Réviser sans compter";

export const alreadySubscribed = "Tu es déjà abonné.";
