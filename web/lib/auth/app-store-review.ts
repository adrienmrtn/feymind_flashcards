/**
 * Le compte que les relecteurs d'Apple ouvrent depuis « Recevoir un lien ».
 *
 * Ils n'ont pas la boîte `review@apple.com` : taper l'adresse ouvre la session
 * tout de suite, sans courriel. Le mot de passe n'est pas dans les notes de
 * relecture — l'écran reste celui du lien magique.
 */
export const APP_STORE_REVIEW_EMAIL = "review@apple.com";
export const APP_STORE_REVIEW_PASSWORD = "Micabo-Review-2026-Kx9m";

/** Le domaine d'Apple, celui qu'aucun lien ne doit atteindre. */
const APPLE_DOMAIN = "apple.com";

/**
 * Vrai pour **toute** adresse en `@apple.com`, et pas seulement pour celle des notes.
 *
 * Ça a l'air trop large, et c'est le contraire : c'est la largeur qui manquait. Le
 * 5 septembre, un relecteur a demandé un lien pour `review2@apple.com` - l'adresse des
 * notes, avec un chiffre en plus. L'égalité stricte ne l'a pas reconnue, le lien est parti
 * pour de bon, et `apple.com` refuse les boîtes qu'il n'a pas : rebond dur, sur un projet
 * qui envoie dix courriels par semaine. Les journaux d'authentification gardent la trace du
 * reste de la séance, cinq refus de format en quatre minutes depuis 17.185.64.85 - un
 * appareil d'Apple - pendant que quelqu'un cherchait la formule qui marche.
 *
 * Personne chez Apple ne relève une boîte pour essayer une app. Donc aucune adresse de ce
 * domaine n'a de raison de recevoir un lien, et toutes ont une raison d'ouvrir la session de
 * relecture : c'est ce qu'on leur promet dans les notes.
 *
 * Ça n'ouvre rien de plus que ce qui était déjà ouvert. Le mot de passe est dans le paquet
 * JavaScript du site depuis le premier jour - il faut qu'il y soit, l'écran s'en sert -,
 * donc le compte était déjà atteignable par quiconque lit la source. Ce qui change n'est pas
 * qui peut entrer, c'est le nombre de courriels qui partent pour rien.
 */
export function isAppStoreReviewEmail(email: string | null | undefined): boolean {
  const address = (email ?? "").trim().toLowerCase();
  const at = address.lastIndexOf("@");
  if (at <= 0) return false;
  return address.slice(at + 1) === APPLE_DOMAIN;
}
