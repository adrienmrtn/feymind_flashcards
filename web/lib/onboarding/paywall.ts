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

/**
 * Ce mur-là se referme-t-il ?
 *
 * **Non, jamais.** Le mur dur a été retiré du site : toutes les portes du paywall gardent
 * désormais leur croix, l'accueil compris. Un mur sans sortie ne vend pas mieux qu'un mur
 * avec croix — il fait fermer l'onglet, et on perd alors la session *et* la vente.
 *
 * La fonction reste, et rend `false` : les appels la lisent encore (`PaywallFlow`), et une
 * règle nommée qu'on peut relire vaut mieux qu'un `false` écrit en dur dans un composant,
 * le jour où l'on voudra rouvrir la question.
 */
export function isHardPaywall(_input: {
  force: boolean;
  demand?: boolean;
  debug?: boolean;
}): boolean {
  return false;
}
