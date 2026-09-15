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





/** Ce que la pastille affiche. */
export function windowRemaining(startedAt: number, now: number): number {
  return remaining(startedAt, now, windowSeconds);
}

/** L'offre est encore achetable. Passé vingt-quatre heures, la pastille disparaît. */
export function isLive(startedAt: number, now: number): boolean {
  return windowRemaining(startedAt, now) > 0;
}

/**
 * L'offre peut se relancer : la fenêtre est finie **et** le repos est passé.
 *
 * C'est ce qui fait revenir le cadeau. Sans cette règle, une fenêtre expirée fermait
 * définitivement le tarif réduit : ni pop-up, ni pastille, et aucun autre chemin.
 */
export function hasRested(startedAt: number, now: number): boolean {
  const elapsed = Math.floor((now - startedAt) / 1000);
  if (!Number.isFinite(elapsed)) return false;
  return elapsed >= windowSeconds + restSeconds;
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
