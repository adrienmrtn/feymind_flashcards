/**
 * Le compte que les relecteurs d'Apple ouvrent depuis « Recevoir un lien ».
 *
 * Ils n'ont pas la boîte `review@apple.com` : taper l'adresse ouvre la session
 * tout de suite, sans courriel. Le mot de passe n'est pas dans les notes de
 * relecture — l'écran reste celui du lien magique.
 *
 * **Le mot de passe ne vit plus ici.** Il était dans ce module, donc dans le paquet
 * JavaScript de chaque page qui l'importait : n'importe qui lisait la source, tapait une
 * adresse en `@apple.com`, et entrait dans le compte de relecture partagé. Il est maintenant
 * lu côté serveur seulement, dans `APP_STORE_REVIEW_PASSWORD` (`lib/actions/app-store-review`),
 * et ce module-ci ne garde que ce que le navigateur a le droit de savoir : l'adresse.
 */
export const APP_STORE_REVIEW_EMAIL = "review@apple.com";

/** Le domaine d'Apple, celui qu'aucun lien ne doit atteindre. */
const APPLE_DOMAIN = "apple.com";

function normalized(email: string | null | undefined): string {
  return (email ?? "").trim().toLowerCase();
}

/**
 * Vrai pour **toute** adresse en `@apple.com` : celles-là ne reçoivent jamais de lien.
 *
 * Le 5 septembre, un relecteur a demandé un lien pour `review2@apple.com` - l'adresse des
 * notes, avec un chiffre en plus. Le lien est parti pour de bon, et `apple.com` refuse les
 * boîtes qu'il n'a pas : rebond dur, sur un projet qui envoie dix courriels par semaine.
 * Personne chez Apple ne relève une boîte pour essayer une app, donc aucune adresse de ce
 * domaine n'a de raison de recevoir un lien.
 *
 * Ça ne veut plus dire « ouvre la session de relecture » : voir `isAppStoreReviewEmail`.
 */
export function isAppleAddress(email: string | null | undefined): boolean {
  const address = normalized(email);
  const at = address.lastIndexOf("@");
  if (at <= 0) return false;
  return address.slice(at + 1) === APPLE_DOMAIN;
}

/**
 * Vrai pour **l'adresse des notes de relecture, et elle seule**.
 *
 * Accepter tout le domaine se défendait tant que le mot de passe était public de toute façon.
 * Il ne l'est plus : ouvrir le compte partagé à n'importe quelle variante reviendrait à rendre
 * d'une main ce qu'on vient de retirer de l'autre. Une autre adresse en `@apple.com` reçoit le
 * refus des boîtes injoignables, et l'adresse exacte reste celle que les notes donnent.
 */
export function isAppStoreReviewEmail(email: string | null | undefined): boolean {
  return normalized(email) === APP_STORE_REVIEW_EMAIL;
}
