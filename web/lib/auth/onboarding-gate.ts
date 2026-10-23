import type { TokenVerdict } from "./claims";
import { OFFER_PATH } from "./next-path";

/** L'offre d'après le compte : la seule page du parcours qui demande une session. */
export function isOfferPath(path: string): boolean {
  return path === OFFER_PATH || path.startsWith(`${OFFER_PATH}?`);
}

/**
 * Ce que le middleware fait d'une visite du parcours (`/commencer…`) :
 *
 * - `"app"` : la session est **vérifiée**, le parcours n'a plus rien à lui dire, on l'envoie
 *   dans l'app ;
 * - `"forget"` : le cookie porte une session que Supabase refuse. On l'efface et on reste :
 *   c'est justement la page où l'on se reconnecte ;
 * - `"stay"` : tout le reste - pas de session, une relecture du parcours, l'offre, ou un
 *   verdict incertain. Dans le doute on ne redirige pas : rester sur une page de trop coûte
 *   un clic, une redirection de trop peut coûter une boucle.
 *
 * La règle qui empêche la boucle tient en une ligne : **on ne renvoie vers `/app` que sur le
 * verdict même qui y fait entrer.** `app/app/layout.tsx` laisse entrer sur `getClaims()` ;
 * renvoyer vers lui sur la foi d'un cookie non vérifié, c'est le renvoyer chez quelqu'un qui
 * le renverra ici.
 */
export type OnboardingGate = "app" | "forget" | "stay";

export function onboardingGate(input: {
  pathname: string;
  replaying: boolean;
  hasSession: boolean;
  verdict: TokenVerdict | null;
}): OnboardingGate {
  if (!input.pathname.startsWith("/commencer") || isOfferPath(input.pathname)) return "stay";
  if (!input.hasSession || input.replaying) return "stay";
  if (input.verdict === "valid") return "app";
  if (input.verdict === "refused") return "forget";
  return "stay";
}

/** Vrai quand la visite demande une vérification du jeton - et seulement alors : elle a un coût. */
export function onboardingNeedsVerdict(input: {
  pathname: string;
  replaying: boolean;
  hasSession: boolean;
}): boolean {
  return (
    input.hasSession &&
    !input.replaying &&
    input.pathname.startsWith("/commencer") &&
    !isOfferPath(input.pathname)
  );
}
