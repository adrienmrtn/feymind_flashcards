/**
 * « Le paywall vient de se refermer, à toi. »
 *
 * La visite guidée attend derrière deux cartes qu'elle ne monte pas
 * elle-même. Quand l'une se referme, rien dans l'arbre React ne le lui dit :
 * le paywall et le cadeau vivent à côté d'elle, pas au-dessus.
 *
 * Un évènement de fenêtre plutôt qu'un contexte partagé, pour la même raison
 * que le drapeau du cadeau est un drapeau de module : ces trois composants se
 * coordonnent sur des instants, pas sur un état commun, et se donner un
 * fournisseur les rendrait interdépendants sans les rendre plus clairs.
 */
export const TOUR_RECHECK_EVENT = "micabo:tour-recheck";

export function requestTourRecheck(): void {
  try {
    window.dispatchEvent(new Event(TOUR_RECHECK_EVENT));
  } catch {
    // Sans fenêtre, la visite se reproposera au prochain chargement.
  }
}
