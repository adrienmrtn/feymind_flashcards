/**
 * Quand la visite a le droit de s'ouvrir.
 *
 * Une fonction pure, pour que la règle se relise sans navigateur. Elle dit
 * surtout **non** : c'est le troisième objet qui peut se poser sur cette app,
 * après le paywall et le cadeau, et deux cartes empilées ne se lisent pas.
 *
 * L'ordre est celui de la valeur : le cadeau porte un prix réduit, le paywall
 * porte l'offre, la visite ne porte que des explications. Elle passe donc en
 * dernier, et elle attend le tour suivant sans rien perdre.
 */
export function shouldOpenTour(input: {
  /** Abonnement payé : le paywall ne s'ouvrira plus. */
  isPaid: boolean;
  /** La croix du paywall a été cliquée sur cet appareil. */
  paywallDismissed: boolean;
  /** Le paywall est ouvert, ou son ouverture est déjà programmée. */
  paywallWillOpen: boolean;
  /** Le cadeau tient l'écran. */
  offerClaimed: boolean;
  /** « Passer la visite » a été cliqué une fois, pour de bon. */
  skipped: boolean;
  seen: readonly string[];
  tourId: string;
  /** Rejouer depuis les réglages, ou `?debug=visite`. */
  debug?: boolean;
}): boolean {
  if (input.debug) return true;
  if (input.skipped) return false;
  if (input.seen.includes(input.tourId)) return false;
  if (input.offerClaimed) return false;
  if (input.paywallWillOpen) return false;
  // « Après le paywall » a deux sens, et les deux comptent : l'offre a été
  // refusée, ou elle a été prise. Avant ça, la visite arriverait par-dessus.
  return input.isPaid || input.paywallDismissed;
}
