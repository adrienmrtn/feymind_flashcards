import { isPaywallTrigger, type PaywallTrigger } from "@micabo/core";

/**
 * Ouvre le paywall depuis une des trois portes du gratuit — l'envoi d'une leçon, une
 * question à Mika, un supplément — ou depuis « Passer en Pro ». L'hôte (`PaywallHost`)
 * écoute l'événement et dit, en une ligne au-dessus de l'offre, pourquoi il s'ouvre.
 *
 * Une query `?offre=1` fait la même chose, pour les liens qui n'ont pas de JavaScript sous
 * la main. Passé en `onClick` tel quel, l'événement de la souris arrive en premier argument :
 * il est ignoré, et la porte vaut « Passer en Pro ».
 */
export const PAYWALL_EVENT = "micabo:paywall";

export interface PaywallRequest {
  trigger: PaywallTrigger;
}

export function requestPaywall(trigger?: PaywallTrigger | unknown) {
  if (typeof window === "undefined") return;
  const detail: PaywallRequest = { trigger: isPaywallTrigger(trigger) ? trigger : "upgrade" };
  window.dispatchEvent(new CustomEvent<PaywallRequest>(PAYWALL_EVENT, { detail }));
}
