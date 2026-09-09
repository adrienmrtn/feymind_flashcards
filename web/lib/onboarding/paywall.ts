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
 * **Non, par défaut.** Sortir de l'accueil, c'est avoir déposé un cours, vu sa fiche et ses
 * cartes : le produit a fait sa démonstration, et l'offre est la suite, pas une interruption.
 * Le mur qui la porte n'a donc pas de croix.
 *
 * Deux exceptions, et elles ne sont pas des oublis.
 *
 * - `force` (`?offre=1`) est une **demande explicite** de voir l'offre, souvent depuis les
 *   réglages ou un lien. Enfermer quelqu'un qui a demandé à regarder serait un piège.
 * - `demand` est une porte fermée **en cours d'usage** - un deuxième cours, une session. Elle
 *   interrompt un travail commencé ; l'y bloquer ne vend rien, ça fait fermer l'onglet.
 *
 * `debug` rejoue la démonstration et doit pouvoir se refermer, sinon il n'y a plus de moyen
 * d'en sortir pour la relire.
 *
 * La décision ne regarde **pas** `pending` ni `welcome`. Ils vivent dans le stockage local :
 * s'y fier laisserait une sortie triviale, puisque vider les données du site aurait rendu la
 * croix. Le public est de toute façon le même - quelqu'un qui ne paie pas et n'a jamais
 * refermé l'offre.
 */
export function isHardPaywall(input: {
  force: boolean;
  demand?: boolean;
  debug?: boolean;
}): boolean {
  if (input.debug) return false;
  if (input.demand) return false;
  return !input.force;
}
