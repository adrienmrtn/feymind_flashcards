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
  code?: string | null,
): string {
  // Un lien de courriel périmé ou des demandes trop rapprochées : la phrase du catalogue, pas
  // l'anglais de GoTrue. GoTrue les renvoie dans `error_code`, à côté de sa description.
  const email = emailLinkFailureKey({ message: raw, code });
  if (email) return t(email);
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

/** Ce que GoTrue rend d'un refus : un message anglais, parfois un code et un statut HTTP. */
export interface AuthFailure {
  message?: string | null;
  code?: string | null;
  status?: number | null;
}

/** Les codes GoTrue d'une limite de débit : par adresse, par IP, ou pour tout le projet. */
const RATE_LIMIT_CODES = new Set([
  "over_email_send_rate_limit",
  "over_request_rate_limit",
  "over_sms_send_rate_limit",
]);

/**
 * **La clé du catalogue pour un refus de lien par courriel**, ou `null` s'il n'en a pas.
 *
 * GoTrue répond en anglais, et la page affichait sa phrase telle quelle : « For security
 * purposes, you can only request this after 38 seconds. » sous les yeux d'un lycéen turc, ou
 * « Email link is invalid or has expired » au retour d'un lien ouvert deux fois (le premier
 * clic, souvent, est celui de l'antivirus de la messagerie). Deux familles se reconnaissent :
 *
 * - **la limite de débit** (`over_email_send_rate_limit`, un 429, « For security purposes… ») :
 *   un lien vient de partir, ou le projet a envoyé son quota de l'heure ;
 * - **le lien périmé** (`otp_expired`, « invalid or has expired ») : on en redemande un.
 */
export function emailLinkFailureKey(failure: AuthFailure): string | null {
  const code = failure.code?.toLowerCase() ?? "";
  const text = failure.message?.toLowerCase() ?? "";
  if (
    RATE_LIMIT_CODES.has(code) ||
    failure.status === 429 ||
    text.includes("for security purposes") ||
    text.includes("rate limit") ||
    text.includes("too many requests")
  ) {
    return "app.errors.emailRateLimit";
  }
  if (
    code === "otp_expired" ||
    text.includes("otp_expired") ||
    text.includes("invalid or has expired") ||
    text.includes("token has expired")
  ) {
    return "app.errors.linkExpired";
  }
  return null;
}

/** Le refus d'un envoi ou d'une vérification de lien, dans la langue de la page. */
export function emailLinkFailureMessage(t: FailureTranslator, failure: AuthFailure): string {
  const key = emailLinkFailureKey(failure);
  if (key) return t(key);
  return failure.message?.trim() || t("app.errors.tryAgain");
}
