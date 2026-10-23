/** L'offre qui suit la création du compte : la seule page du parcours qui demande une session. */
export const OFFER_PATH = "/commencer/offre";

/**
 * **Où renvoyer après la connexion**, quand c'est l'URL qui le demande (`?next=`, `?suite=`).
 *
 * Une valeur lue dans l'URL est une valeur que n'importe qui peut écrire : un lien
 * `…/commencer/compte?suite=/\evil.example` passait le vieux test « commence par `/`, pas
 * par `//` », et le navigateur, qui lit `\` comme `/`, partait sur `//evil.example` - un
 * autre site, avec la confiance de micabo.app dans la barre d'adresse une seconde plus tôt.
 *
 * On n'accepte donc qu'**une page de l'app** (`/app…`) ou l'offre qui suit le compte, et
 * rien qui puisse se relire comme une autre origine : pas de `//`, pas de `\`, pas de `@`
 * (`/app@evil.example` ne trompe pas un navigateur, mais un analyseur d'URL un peu naïf, si).
 * Tout le reste retombe sur `fallback`.
 */
export function safeAppPath(value: string | null | undefined, fallback = "/app"): string {
  if (!value) return fallback;
  if (value.startsWith("//") || value.includes("\\") || value.includes("@")) return fallback;
  // Les caractères de contrôle (tabulation, retour à la ligne) sont retirés par le
  // navigateur avant l'analyse : `/\t/evil.example` redeviendrait `//evil.example`.
  if (/[\u0000-\u001f\u007f]/.test(value)) return fallback;
  if (value === "/app" || value.startsWith("/app/") || value.startsWith("/app?") || value.startsWith("/app#")) {
    return value;
  }
  if (value === OFFER_PATH || value.startsWith(`${OFFER_PATH}?`)) return value;
  return fallback;
}
