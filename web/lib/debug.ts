/**
 * Outils de débogage : visibles en local et sur une preview, jamais sur le site.
 *
 * `NODE_ENV` vaut `production` sur Vercel, y compris les previews. Sans
 * `NEXT_PUBLIC_VERCEL_ENV`, le bouton du profil n'existerait que sous `next dev`.
 */
export function isDebugToolsEnabled(): boolean {
  if (process.env.NODE_ENV !== "production") return true;
  return process.env.NEXT_PUBLIC_VERCEL_ENV === "preview";
}
