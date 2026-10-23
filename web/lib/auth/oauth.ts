/**
 * Le retour OAuth / magic link, et les refus qu'on peut traduire.
 *
 * `redirectTo` doit être dans les Redirect URLs du projet. En local c'est
 * `localhost`, en production `micabo.vercel.app` — les deux sont documentés
 * dans `docs/oauth-setup.md`.
 */

/**
 * Le traducteur de la page ou de la route. Ces messages s'affichent dans les vingt-six langues :
 * une phrase écrite ici en dur, en français, tombait telle quelle sous les yeux d'un étudiant
 * turc ou arabe, au moment précis où il ne comprend déjà pas pourquoi la connexion échoue.
 */
export type FailureTranslator = (key: string) => string;

export function oauthCallbackUrl(next = "/app", provider?: "apple" | "google"): string {
  const from = provider ? `&provider=${provider}` : "";
  return `${window.location.origin}/auth/callback?next=${encodeURIComponent(next)}${from}`;
}

/** Apple web casse souvent sur le secret OAuth ou l'audience du Service ID. */
export function oauthFailureMessage(
  t: FailureTranslator,
  provider: "apple" | "google",
  raw: string,
): string {
  const text = raw.toLowerCase();
  if (
    provider === "apple" &&
    (text.includes("audience") ||
      text.includes("invalid_client") ||
      text.includes("provider is not enabled") ||
      text.includes("missing oauth secret") ||
      text.includes("unsupported provider") ||
      text.includes("redirect"))
  ) {
    return t("app.errors.appleNotWired");
  }
  return raw;
}

/**
 * **Un retour qui échoue, sans savoir d'où il vient.**
 *
 * Le retour ne disait pas son fournisseur, et tout échec y passait pour Apple : un refus
 * Google affichait « Apple n'est pas encore branché ». Le fournisseur vient maintenant du
 * lien quand il le porte ; sinon, seuls les refus propres à Apple sont traduits comme tels.
 *
 * Un lien de courriel ouvert dans un autre navigateur que celui de la demande (le
 * navigateur intégré d'une messagerie, le plus souvent) n'a pas le vérificateur PKCE gardé
 * au départ : l'échange échoue, et le message brut de Supabase ne dit pas quoi faire.
 */
export function callbackFailureMessage(
  t: FailureTranslator,
  provider: string | null,
  raw: string,
): string {
  const text = raw.toLowerCase();
  if (
    text.includes("code verifier") ||
    text.includes("code_verifier") ||
    text.includes("flow state") ||
    text.includes("both auth code and code verifier")
  ) {
    return t("app.errors.linkOtherBrowser");
  }
  if (provider === "apple" || provider === "google") return oauthFailureMessage(t, provider, raw);
  if (text.includes("audience") || text.includes("missing oauth secret")) {
    return oauthFailureMessage(t, "apple", raw);
  }
  return raw;
}
