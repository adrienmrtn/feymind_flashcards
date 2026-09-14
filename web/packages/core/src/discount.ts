/**
 * L'offre cadeau, et **les mêmes nombres des deux côtés.**
 *
 * Après le premier cours importé, Micabo offre l'annuel à tarif réduit. L'offre
 * se présente une fois, puis se replie sur une languette qui la rouvre.
 *
 * **La fenêtre ne s'affiche plus.** Vingt-quatre heures courent toujours depuis
 * l'instant où le cadeau a été ouvert — c'est elle qui décide si l'offre est
 * encore achetable, si la languette reste et quand le cadeau revient — mais
 * aucun écran ne montre le temps qui reste. Un décompte posé sur un prix demande
 * de décider vite plutôt que de décider ; l'offre tient sur ce qu'elle vaut, pas
 * sur l'horloge qu'on regarde. Seule la rangée des Réglages de l'app iOS écrit
 * encore ce qu'il reste, et c'est `countdown` qui l'écrit.
 *
 * Une seule durée, une seule origine : deux horloges finiraient par se
 * contredire, et un prix qui revient après avoir expiré ne se croit plus.
 *
 * Le montant, lui, vient de `pricing.DISCOUNT_YEARLY`. Ce module ne décide pas
 * des prix : il décide du temps.
 */

/** Appuis sur le cadeau avant qu'il s'ouvre. Trois : un geste, pas un accident. */
export const taps = 3;

/** La durée de l'offre. Vingt-quatre heures, comptées sans être montrées. */
export const windowSeconds = 86400;


/**
 * **Le repos entre deux fenêtres.** Quarante-huit heures.
 *
 * L'offre ne meurt pas au bout de vingt-quatre heures : elle se retire, puis elle
 * revient. Une offre qui disparaît pour toujours parce qu'on a fermé une carte un
 * soir de semaine est une offre qu'on a perdue sans l'avoir refusée - et, plus
 * gênant, un tarif que plus rien dans le produit ne permet d'atteindre.
 *
 * Deux jours, parce que le repos doit se sentir : une urgence qui repart le
 * lendemain matin n'est plus une urgence, c'est un prix affiché.
 */
export const restSeconds = 172800;

/**
 * Combien de secondes restent sur `span`, depuis `startedAt`.
 *
 * Jamais négatif, et jamais plus que `span` : une horloge locale en avance sur
 * le serveur donnerait sinon un décompte qui grandit.
 */
export function remaining(startedAt: number, now: number, span: number): number {
  const elapsed = Math.floor((now - startedAt) / 1000);
  if (!Number.isFinite(elapsed)) return 0;
  return Math.min(span, Math.max(0, span - elapsed));
}





/** Ce qui reste de la fenêtre. Compté, affiché nulle part sauf dans les Réglages iOS. */
export function windowRemaining(startedAt: number, now: number): number {
  return remaining(startedAt, now, windowSeconds);
}

/** L'offre est encore achetable. Passé vingt-quatre heures, la languette disparaît. */
export function isLive(startedAt: number, now: number): boolean {
  return windowRemaining(startedAt, now) > 0;
}

/**
 * L'offre peut se relancer : la fenêtre est finie **et** le repos est passé.
 *
 * C'est ce qui fait revenir le cadeau. Sans cette règle, une fenêtre expirée fermait
 * définitivement le tarif réduit : ni pop-up, ni languette, et aucun autre chemin.
 */
export function hasRested(startedAt: number, now: number): boolean {
  const elapsed = Math.floor((now - startedAt) / 1000);
  if (!Number.isFinite(elapsed)) return false;
  return elapsed >= windowSeconds + restSeconds;
}

/**
 * « 59:59 » sous l'heure, « 23:14:07 » au-dessus.
 *
 * **Aucun écran du site ne l'appelle** : il n'existe plus que pour rester le
 * miroir de `DiscountOffer.countdown`, que la rangée des Réglages de l'app écrit
 * encore. Aucun paywall ne le porte, et la languette non plus.
 *
 * Les deux-points sont des vrais deux-points et les nombres sont sur deux
 * chiffres : un décompte qui passe de « 9:5 » à « 10:04 » change de largeur à
 * chaque seconde, et une rangée qui tremble attire l'œil pour rien.
 */
export function countdown(seconds: number): string {
  const total = Math.max(0, Math.floor(seconds));
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  const rest = total % 60;
  const pad = (value: number) => String(value).padStart(2, "0");
  if (hours > 0) return `${pad(hours)}:${pad(minutes)}:${pad(rest)}`;
  return `${pad(minutes)}:${pad(rest)}`;
}
