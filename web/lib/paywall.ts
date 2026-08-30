/**
 * Ouvre le paywall depuis n'importe quelle porte : deuxième cours, fin de
 * fiche, plafond de session, entraînement libre.
 *
 * L'hôte écoute l'événement. Une query `?offre=1` fait la même chose, pour
 * les liens qui n'ont pas de JavaScript sous la main.
 */
export const PAYWALL_EVENT = "micabo:paywall";

export function requestPaywall() {
  if (typeof window === "undefined") return;
  window.dispatchEvent(new Event(PAYWALL_EVENT));
}
