/**
 * L'offre cadeau, et **les mêmes nombres des deux côtés.**
 *
 * Après le premier cours importé, Micabo offre l'annuel à tarif réduit. L'offre
 * se présente une fois, puis se replie sur une pastille qui garde le décompte.
 *
 * Une seule durée, une seule origine. Le pop-up et la pastille montrent le même
 * temps restant : vingt-quatre heures depuis l'instant où le cadeau a été
 * ouvert. Deux horloges différentes finissent par se contredire — le pop-up
 * disait « terminé » alors que la pastille comptait encore — et un prix qui
 * revient après avoir dit « terminé » ne se croit plus.
 *
 * Le montant, lui, vient de `pricing.DISCOUNT_YEARLY`. Ce module ne décide pas
 * des prix : il décide du temps.
 */

/** Appuis sur le cadeau avant qu'il s'ouvre. Trois : un geste, pas un accident. */
export const taps = 3;

/** La durée de l'offre, sur le pop-up comme sur la pastille. Vingt-quatre heures. */
export const windowSeconds = 86400;

/** Même nombre que `windowSeconds` : le pop-up ne peut pas dire autre chose que la pastille. */
export const urgencySeconds = 86400;

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

/**
 * La même durée, **au millième**, pour la minuterie qui affiche des centièmes.
 *
 * `remaining` arrondit à la seconde, ce qui suffit à une pastille mais fait
 * bégayer un affichage qui montre deux chiffres après la virgule : deux images
 * de suite tombent dans la même seconde, et le décompte a l'air arrêté.
 */
export function remainingMillis(startedAt: number, now: number, span: number): number {
  const total = span * 1000;
  const left = total - (now - startedAt);
  if (!Number.isFinite(left)) return 0;
  return Math.min(total, Math.max(0, left));
}

/** Ce que le pop-up et la pastille décomptent, au millième. */
export function windowMillisRemaining(startedAt: number, now: number): number {
  return remainingMillis(startedAt, now, windowSeconds);
}

/** Ce que la minuterie du paywall décompte, au millième — la même fenêtre. */
export function urgencyMillisRemaining(startedAt: number, now: number): number {
  return windowMillisRemaining(startedAt, now);
}

/** Ce que la minuterie du paywall affiche — la même fenêtre que la pastille. */
export function urgencyRemaining(startedAt: number, now: number): number {
  return windowRemaining(startedAt, now);
}

/** Ce que la pastille affiche. */
export function windowRemaining(startedAt: number, now: number): number {
  return remaining(startedAt, now, windowSeconds);
}

/** L'offre est encore achetable. Passé vingt-quatre heures, la pastille disparaît. */
export function isLive(startedAt: number, now: number): boolean {
  return windowRemaining(startedAt, now) > 0;
}

/**
 * « 59:59 » sous l'heure, « 23:14:07 » au-dessus.
 *
 * Les deux-points sont des vrais deux-points et les nombres sont sur deux
 * chiffres : un décompte qui passe de « 9:5 » à « 10:04 » change de largeur à
 * chaque seconde, et une pastille qui tremble attire l'œil pour rien.
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

/**
 * **Le décompte du paywall : « 00 : 29 : 48 . 69 ».**
 *
 * Les centièmes sont là pour une raison, et ce n'est pas la précision : une
 * minuterie qui bouge à chaque image se regarde, une minuterie qui saute d'une
 * seconde à l'autre se lit une fois puis s'oublie. C'est le seul endroit du
 * produit où l'on demande de décider maintenant.
 *
 * Les séparateurs sont espacés — « 00 : 29 » et non « 00:29 » — parce qu'à cette
 * taille deux-points collés entre deux chiffres se lisent comme une faute de
 * frappe. Tous les nombres sont sur deux chiffres : un décompte qui change de
 * largeur à chaque centième ferait trembler la pastille qui le porte.
 */
export function preciseCountdown(millis: number): string {
  const total = Math.max(0, Math.floor(millis));
  const pad = (value: number) => String(value).padStart(2, "0");
  const hours = Math.floor(total / 3_600_000);
  const minutes = Math.floor((total % 3_600_000) / 60_000);
  const seconds = Math.floor((total % 60_000) / 1000);
  const hundredths = Math.floor((total % 1000) / 10);
  return `${pad(hours)} : ${pad(minutes)} : ${pad(seconds)} . ${pad(hundredths)}`;
}

/**
 * Ce que lit un lecteur d'écran, où « 23:14:07 » ne veut rien dire.
 *
 * La phrase commence par « il reste » : l'accord du participe suivrait sinon le
 * nombre, et « 1 heure restantes » se lit comme une faute.
 */
export function countdownLabel(seconds: number): string {
  const total = Math.max(0, Math.floor(seconds));
  if (total === 0) return "offre terminée";

  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);

  if (hours > 0) {
    const heures = hours === 1 ? "1 heure" : `${hours} heures`;
    if (minutes === 0) return `il reste ${heures}`;
    const mots = minutes === 1 ? "1 minute" : `${minutes} minutes`;
    return `il reste ${heures} et ${mots}`;
  }

  if (minutes === 0) return "il reste moins d'une minute";
  return minutes === 1 ? "il reste 1 minute" : `il reste ${minutes} minutes`;
}
