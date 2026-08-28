/**
 * Quand le paywall se pose sur le tableau de bord.
 *
 * Pas tout de suite, pas plein écran : l'étudiant arrive d'abord. Ensuite
 * l'offre. Un Pro **payé** ne la voit jamais. Un Pro seulement deviné, si.
 */
export function shouldOpenPaywall(input: {
  isPaid: boolean;
  force: boolean;
  welcome: boolean;
  pending: boolean;
  dismissed: boolean;
  onHome: boolean;
  /** Rejouer le court accueil, même pour un abonné. */
  debug?: boolean;
}): boolean {
  if (input.debug) return true;
  if (input.isPaid) return false;
  if (input.force) return true;
  if (input.dismissed) return false;
  return input.welcome || input.pending || input.onHome;
}
