/**
 * Le retour OAuth / magic link, et les refus qu'on peut traduire.
 *
 * `redirectTo` doit être dans les Redirect URLs du projet. En local c'est
 * `localhost`, en production `micabo.vercel.app` — les deux sont documentés
 * dans `docs/oauth-setup.md`.
 */

export function oauthCallbackUrl(next = "/app"): string {
  return `${window.location.origin}/auth/callback?next=${encodeURIComponent(next)}`;
}

/** Apple web casse souvent sur le secret OAuth ou l'audience du Service ID. */
export function oauthFailureMessage(provider: "apple" | "google", raw: string): string {
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
    return "Apple n'est pas encore branché pour le site. Utilise Google ou le lien par courriel.";
  }
  return raw;
}
