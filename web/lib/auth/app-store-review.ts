/**
 * Le compte que les relecteurs d'Apple ouvrent depuis « Recevoir un lien ».
 *
 * Ils n'ont pas la boîte `review@apple.com` : taper l'adresse ouvre la session
 * tout de suite, sans courriel. Le mot de passe n'est pas dans les notes de
 * relecture — l'écran reste celui du lien magique.
 */
export const APP_STORE_REVIEW_EMAIL = "review@apple.com";
export const APP_STORE_REVIEW_PASSWORD = "Micabo-Review-2026-Kx9m";

export function isAppStoreReviewEmail(email: string | null | undefined): boolean {
  return (email ?? "").trim().toLowerCase() === APP_STORE_REVIEW_EMAIL;
}
